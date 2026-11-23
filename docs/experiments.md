# Eksperymenty: kolejność przestrzeni (Spaces)

Cel: zapisać kolejność przestrzeni (głównie apek na pełnym ekranie) i przypisanie do monitorów,
a po podłączeniu / odłączeniu monitora przywrócić je automatycznie i szybko.

Środowisko testów: macOS 27.0.1 (26A434), MacBook Pro (Mac16,8), sam ekran laptopa.
Ustawienia: „Automatycznie porządkuj przestrzenie” wyłączone (`mru-spaces = 0`),
„Monitory mają osobne przestrzenie” włączone.

Statusy: ✅ działa · ❌ nie działa · ⏳ do zrobienia · 🔬 w trakcie

---

## Ustalone fakty

- **Brak publicznego API** do tworzenia, usuwania, przestawiania przestrzeni i przenoszenia okien
  między nimi. Moom, SpaceKeeper i inni piszą to wprost.
- **Odczyt przestrzeni:** `SLSCopyManagedDisplaySpaces` (prywatne, tylko odczyt) daje na żywo
  kolejność per monitor, aktualną przestrzeń (`Current Space`), a dla pełnoekranowych `pid` i `fs_wid`
  (ID okna). Plik `com.apple.spaces` **nie** jest aktualny na bieżąco (Dock zapisuje go z opóźnieniem).
- **ID przestrzeni pełnoekranowej zmienia się** przy każdym ponownym wejściu w pełny ekran.
  Dopasowujemy więc po apce (bundle ID), nie po ID.
- **Nowa przestrzeń pełnoekranowa zawsze ląduje na końcu paska** swojego monitora.
- **Dostępność (AX) widzi okna tylko z bieżącej przestrzeni.** Okna pełnoekranowe z innych przestrzeni
  są niewidoczne, dopóki na nie nie przejdziemy.
- **Skróty Ctrl+←/→** (symbolic hotkeys 79/81) działają z kodu, gdy wyślemy pełną sekwencję:
  Control w dół → strzałka (z flagami fn + numpad) → Control w górę.
- **Aktywacja apki** (`NSRunningApplication.activate()`) przeskakuje od razu na jej przestrzeń
  (jedna animacja). Przy apce z kilkoma oknami pełnoekranowymi (Brave) trafia tylko do jednego.
- **Mission Control na macOS 27:** drzewo AX jest w procesie `com.apple.WindowManager` (nie w Docku).
  Pasek: `mc.spaces` → `mc.spaces.list` → przyciski. Okna mają identyfikatory `<bundle>.space.<ID>`.
  Pasek pokazuje same nazwy, dopóki kursor nie najedzie; dopiero wtedy miniaturki się rozwijają.
  Ramki AX miniaturek mają złe Y (podane ~119 niżej); poprawny wiersz to środek ramki `mc.spaces.list`.
- **Akcje AX miniaturek:** tylko `AXPress` (przełącz) i `AXRemoveDesktop` (na biurkach).
  Przycisk `mc.spaces.add` dodaje biurko. **Akcji „przesuń” brak.**
- **Dostępne prywatne symbole (27.0.1):** `SLSMoveWindowsToManagedSpace`, `SLSSpaceSetCompatID`,
  `SLSSetWindowListWorkspace`, `SLSSpaceCreate`, `SLSSpaceDestroy`, `SLSShowSpaces`, `SLSHideSpaces`,
  `SLSManagedDisplaySetCurrentSpace`, `SLSAddWindowsToSpaces`, `SLSRemoveWindowsFromSpaces`,
  `SLSCopySpacesForWindows`, `SLSProcessAssignToSpace`, `SLEventSetIOHIDEvent`.
  **Brak:** `SLSMoveSpace`. IOKit: `IOHIDEventCreate`, `IOHIDEventCreateButtonEvent`,
  `IOHIDEventCreateMouseEvent`, `IOHIDEventCreateRelativePointerEvent`, `IOHIDEventAppendEvent`.
- **macOS 27 waliduje sztuczne gesty:** muszą mieć dołączony rekord IOHIDEvent
  (przez `SLEventSetIOHIDEvent` albo zserializowany w polu 4205). Bez niego są po cichu ignorowane
  (noswoosh, Mac Mouse Fix f92d2d53a, MouseDragFix).
- **macOS sam oddaje przestrzenie po ponownym podłączeniu, ale tylko w łatwym przypadku** (T33):
  ten sam monitor, ta sama sesja, bez uśpienia, bez restartu i bez zmian w międzyczasie.
  Użytkownicy w sieci opisują, kiedy to się psuje:
  - po uśpieniu i wybudzeniu przestrzenie zmieniają monitory albo lądują na laptopie;
  - przy dwóch zewnętrznych monitorach ich przestrzenie się zamieniają;
  - po restarcie przestrzenie zbierają się na jednym monitorze;
  - pierwsza przestrzeń monitora znika przy odłączeniu;
  - od macOS 15.4 u części osób przestrzenie przestały wracać na monitor.
  Przestrzeń na pełnym ekranie dostaje też nowe ID po ponownym wejściu (patrz wyżej), więc
  zamknięcie i ponowne otwarcie aplikacji psuje kolejność niezależnie od monitora.

---

## Testy wykonane

| # | Test | Wynik | Wniosek |
|---|------|-------|---------|
| T1 | Ręczne wyjście z pełnego ekranu i powrót (Bitwarden) | ✅ przestrzeń przeskoczyła na koniec, nowe ID | podstawa obecnego `restore` |
| T2 | `list` z AX z innej przestrzeni | ❌ AX widzi 0 okien | trzeba przejść na przestrzeń |
| T3 | `peek`: aktywacja apki, potem AX | ✅ okno widoczne | skok przez aktywację działa |
| T4 | `goto`: Ctrl+→ jako sama strzałka z flagą Ctrl | ❌ trafiało do Terminala jako `^[[1;5C` | trzeba wysłać Control osobno |
| T5 | `goto`: pełna sekwencja Control↓ → strzałka → Control↑ | ✅ | |
| T6 | `restore` v1 (zdejmuje wszystko, przerywa przy błędzie) | ❌ urwał w połowie, 4 okna zostały poza pełnym ekranem | nigdy nie przerywać w połowie |
| T7 | `restore` v2 (pomija błędy, podnosi okna z biurka) | ✅ 6 przestrzeni, 28 s | |
| T8 | `restore` v3 (tylko nie na miejscu, skok zamiast przewijania) | ⚠️ 2 przestrzenie, 7,8 s, Bitwarden ✗ | następne okno ruszone w trakcie animacji |
| T9 | `restore` v4 (czeka na koniec animacji, ponawia raz) | ✅ 5 przestrzeni 16,3 s / 15,6 s | ~1,5 s na zmianę pełnego ekranu; drugie okno Brave ~3,4 s (przewijanie) |
| T10 | `mcdump`: odczyt Mission Control | ✅ pasek i miniaturki widoczne | |
| T11 | `mcdrag`: przeciąganie, Y z ramki miniaturki | ❌ kursor pod miniaturkami | złe Y w AX |
| T12 | `mcdrag`: Y ze środka paska | ❌ kursor nad miniaturkami, nic się nie przesuwa | |
| T13 | `mcdrag`: kopia sposobu PaperWM (wspólny `mouseEventNumber`, krok 8 px + ~100 px co 10 ms) | ❌ | |
| T14 | `mcdrag slow` (przytrzymanie, kroki 10 px, nacisk) | ❌ | |
| T15 | `mcclick`: zwykły klik w miniaturkę | ❌ „klik zignorowany” | MC ignoruje nawet klik |
| T16 | `mcclick` przez session tap (jak Hammerspoon) | ❌ | |
| T17 | Hammerspoon `t.click(7)` / `t.drag(7, 3)` (kod PaperWM) | ❌ / ❌ | to nie wina naszego programu z terminala |
| T18 | Hammerspoon `t.actions()` | tylko `AXPress`, `AXRemoveDesktop` | brak akcji przesuwania |
| T19 | P1: `mcclick` / `mcdrag` z dołączonym IOHIDEvent Pointer+Button (`hidev`) | ❌ / ❌ | sam rekord HID nie wystarcza (albo zły typ/pola) |
| T20 | P1f: `mcrecord` prawdziwego przeciągnięcia (trackpad) | ✅ nagrane 211 zdarzeń | różnice opisane niżej |
| T21 | P1f: `mcreplay`, czyli odtworzenie nagrania bajt w bajt (z rekordami HID) | ❌ kolejność bez zmian | Mission Control odrzuca wszystko, co wysłała apka (`CGEventPost`), nawet wierną kopię. Najpewniej patrzy na nadawcę, którego nie podrobimy. Przy okazji: `restore` jednej przestrzeni = 1,9 s |
| T24 | P1g: `mcclickv 7`, czyli klik wirtualną myszą Karabinera | ✅ **przełączyło na Bitwarden** | Mission Control przyjmuje wejście z wirtualnego urządzenia HID |
| T25 | P1g: `mcdragv 7 3`, upuszczenie na środek miniaturki 3 | ⚠️ przeciąganie działa, ale Bitwarden wpadł **do** przestrzeni Brave (Split View) | upuszczać w szczelinę między miniaturkami, nie na środek. 6,8 s (w tym ~1,5 s start wirtualnej myszy) |
| T26 | P1g: `mcdragv 7 3` z upuszczeniem w szczelinę, gdy na pasku był Split View | ⚠️ przesunęło *inne* okno; Split View się rozpadł, kolejność wyszła zgodna z zapisem | wybór miniaturki po numerze jest kruchy (Split View zmienia liczbę i szerokość miniaturek). Trzeba wybierać po tytule / ID przestrzeni i sprawdzać wynik po każdym ruchu |
| T27 | `restore-drag` (5 przesunięć) | ✅ **9,2 s** (mysz 1,5 s, ~1,3 s na przeciągnięcie) | działa; za dużo ruchów: przeciąga każdą przestrzeń po kolei, a wystarczyłoby przenieść tylko te poza najdłuższym ciągiem w dobrej kolejności |
| T28 | `restore` przy takim samym pomieszaniu | ✅ 13,3 s | wersja z przeciąganiem już szybsza |
| T29 | `restore-drag` z minimalną liczbą ruchów | ✅ **5,5 s**, 2 przeciągnięcia | mysz 1,5 s + Mission Control i pierwszy ruch ~2,5 s + drugi ruch 1,5 s |
| T30 | `restore-drag` przyspieszony (mysz równolegle, sygnał gotowości, 0,08 s przytrzymania, 0,18 s przed upuszczeniem, szybszy ruch z wciśniętym przyciskiem) | ⚠️ gotowe po **1,2 s** (było ~2,5 s), ale Claude wylądował o miejsce za daleko, a następny ruch połączył przestrzenie w Split View | szybki start zostaje; przeciąganie wraca do tempa z T29 (0,15 s / 0,3 s, wolniejszy ruch z wciśniętym) |
| T31 | `restore-drag`: szybki start + bezpieczne tempo przeciągania | ✅ **3,6 s**, 2 przeciągnięcia (gotowe po 1,2 s, ruchy ~1,2 s) | aktualna najlepsza wersja |
| T32 | `watch --auto-save` z monitorem podłączanym kablem | ❌ `CGDisplayRegisterReconfigurationCallback` w CLI nie zadziałał ani razu: nie było restore, a auto-zapis dwa razy zapisał przejściowy układ macOS dla zestawu „laptop + monitor”. `CGGetActiveDisplayList` widział nowy monitor | zmiana monitorów wykrywana przez sprawdzanie listy ekranów co 1 s |
| T33 | `watch` (bez auto-zapisu) z kablem: odłączenie, Claude przeciągnięty na koniec paska laptopa, ponowne podłączenie | ✅ 2× odłączenie / podłączenie bez bałaganu: macOS sam oddał przestrzenie, `watch` wypisał „Już ułożone”. Z przestawionym Claude `watch` przywrócił zapisany układ obu monitorów pełnym ekranem w **10,9 s** (3 wyjścia + 3 wejścia, bo pełnym ekranem da się tylko dopisać na koniec). macOS dodał pusty Biurko na monitorze, czego dopasowanie nie liczy | automat działa; przy 2 monitorach potrzebny `restore-drag` (1 przeciągnięcie zamiast 6 ruchów), krok 2 / P6 |
| T34 | Apka z automatem, 3 ekrany (otwarcie klapy): przywracanie pełnym ekranem | ⚠️ 18,6 s, 2× „Ctrl+strzałka nie przełączył przestrzeni”: skrót działa na monitorze pod kursorem | `goTo` przenosi kursor na monitor przestrzeni; przy kilku monitorach przeciąganie |
| T35 | `restore-drag` na 2 monitorach (DELL główny, PL po lewej) | ✅ odkrycie: **Mission Control przyjmuje wirtualną mysz tylko na monitorze, z którego go otwarto.** Otwarty z DELL-a: na PL brak reakcji na klik i przeciąganie (kursor dokładnie nad miniaturką). Otwarty z PL: Bitwarden przesunięty. Przeciągnięcie z paska PL na pasek DELL-a nie działa w żadnym wariancie. Każdy monitor ma własny `mc.spaces.list` z ramką na swoim ekranie; paski rozwijają się dopiero przy ruchu wirtualnej myszy (samo `CGWarpMouseCursorPosition` nie wystarcza) | przestrzeń na złym monitorze: pełny ekran (wyjście, okno na monitor, wejście), potem kolejność przeciąganiem w osobnym Mission Control otwartym z każdego monitora |
| T36 | Powtarzane przeciągania na DELL-u | ⚠️ część prób chybia: ramki AX miniaturek są czasem przesunięte o jedną miniaturkę względem ekranu (np. 704… zamiast 896…), kursor trafia obok (potwierdzone wzrokiem). Trafienie po 1–2 powtórkach. `AXUIElementCopyElementAtPosition` nic nie zwraca w Mission Control | przeciąganie, które nie zmieniło paska, ponawiane do 3 razy ze świeżymi ramkami; przywracanie PL 3,6 s, DELL 3,3 s |
| T37 | „Przywróć” w apce po przestawieniu Forka na DELL-u | ⚠️ 3 próby przeciągania chybiły (11,2 s), zapasowy pełny ekran ułożył Forka. Wcześniejszy test przestawił biurko na PL na koniec, a apka tego nie widziała, bo zapis nie miał biurek | biurka w zapisie i w przywracaniu; ponowienia przesuwają przeciąganie o ±1 miniaturkę; powrót na poprzednią przestrzeń |
| T38 | „Przywróć” z biurkami w zapisie i ponowieniami przesuniętymi o ±1 miniaturkę | ❌ ponowienie z przesunięciem złapało sąsiednie przestrzenie (Brave przed Claude, biurko DELL-a na koniec), po 2 ruchach apka zniknęła bez raportu awarii. Najpewniej SIGPIPE: zapis do rury pomocnika myszy, który już nie działał | przesunięcie usunięte; SIGPIPE ignorowany, `send` sprawdza, czy pomocnik żyje. Otwarte: dwa układy ramek AX na DELL-u (start 704 albo 896) |
| T39 | Pełny zrzut ekranu DELL-a (2560 pt → 2000 px) przy otwartym Mission Control, porównany z AX | ✅ środki miniaturek na ekranie: 895, 1087, 1279, 1471, 1664 pt, czyli dokładnie wartości `minX` z AX (896, 1088…). Miniaturka ma 160 pt szerokości, odstęp 192 pt, rząd wyśrodkowany na monitorze. Ramki AX (190 pt) są przesunięte o pół miniaturki w prawo, więc celowanie w ich środek trafiało w samą krawędź | pozycje liczone z modelu: środek paska + (i − (n−1)/2) × 192; upuszczanie w połowie szczeliny |
| T40 | `restore-drag` z modelem pozycji: DELL (biurko na końcu, Brave przed Claude) i PL (biurko na końcu) | ✅ 4 przeciągnięcia, każde za pierwszym razem, **7,5 s**, układ zgodny z zapisem razem z biurkami | aktualna wersja |
| T41 | P8: własna wirtualna mysz przez CoreHID (`HIDVirtualDevice`, macOS 15+), program w scratchpadzie | ❌ bez uprawnienia: urządzenie nie powstaje (`nil`); z `com.apple.developer.hid.virtual.device` (ad-hoc i nasz certyfikat): macOS zabija program przy starcie (kod 137) | własna mysz tylko z kontem Apple i uprawnieniem od Apple |
| T42 | P8: `fsprobe` (tylko odczyt): okna pełnoekranowe z innych przestrzeni przez `axWindow` (zdalny token) | ✅ wszystkie 6 okien: element AX jest, `AXFullScreen` = true i **ustawialne**, także gdy okno nie jest widoczne | do sprawdzenia, czy ustawienie działa bez przechodzenia na przestrzeń (T43) |
| T43 | P8: `fstest Fork`: `AXFullScreen` off i on przez `axWindow`, bez przechodzenia na przestrzeń (widoczne było biurko) | ✅ **0,85 s na cały cykl**: przestrzeń znika po 0,28 s, ekran zostaje na biurku; po „on” nowa przestrzeń jest po 0,06 s na końcu paska, a ~1 s później macOS sam na nią przechodzi | etap 1 restore bez `goTo`; po ułożeniu i tak wracamy na poprzednie przestrzenie |
| T44 | P8: `restore-fast` (restore z `fast`: wyjście przez `axWindow`, wejście bez czekania na pokazanie przestrzeni), Fork na końcu, 2 przestrzenie do przestawienia | ✅ kolejność zgodna z zapisem, **3,2 s**; wyjścia 0,2 s każde, IntelliJ wszedł po 0,1 s, Bitwarden za pierwszym razem zgubiony (trafił na animację przejścia macOS na IntelliJ), ponowiony po 2 s | czekanie przed ponowieniem skrócone do 0,8 s |
| T45 | P9: `spmove 892 . 1`, czyli `SLSBridgedMoveManagedSpaceToDisplayIndexOperation` przez `-performWithWMBridgeDelegate` (Bitwarden z końca na 2. miejsce, sam laptop) | ✅ **80 ms**, bez myszy, bez Mission Control, bez przełączenia przestrzeni | przełom: przestawianie bez Karabinera |
| T46 | P9: `mcorder` (kolejność miniatur w Mission Control z AX) po T45 | ✅ Mission Control pokazuje tę samą kolejność co SkyLight | raport floe (26.5.2: „Dock nie widzi zmiany”) na 27.0.1 się nie potwierdza |
| T47 | P9: biurko na koniec i z powrotem, Fork na 2. miejsce i z powrotem | ✅ każdy ruch 73–81 ms, biurko też się przestawia, Mission Control zgodny | działa dla biurek i przestrzeni pełnoekranowych |
| T48 | P9: Bitwarden na 2. miejscu, `killall Dock`, odczyt po 4 s | ✅ kolejność przetrwała restart Docka (SkyLight i Mission Control), potem przywrócona | stan trwały, nie tylko w WindowServerze |
| T49 | P9: `spmove 884 DDC3 1`: Fork z laptopa na DELL (za biurko DELL-a), potem z powrotem na laptopa na 4. miejsce | ✅ **95 ms** i 113 ms, Mission Control pokazuje Forka na pasku DELL-a, potem z powrotem | przenoszenie między monitorami działa |
| T50 | Hipoteza „aktywnej przestrzeni nie da się przeciągnąć” (po nieudanym przeciąganiu 16:24 z biurkiem 4): `mcmove` na samym laptopie: A) pokazany Claude, B) niepokazany Fork, C) pokazane biurko | ❌ hipoteza obalona: A, B i C przesunięte za pierwszym razem | 16:24 (laptop + DELL): „↔” znaczy tylko „pasek się zmienił”; mysz chybiała i ruszała sąsiadów (widziane przez użytkownika), biurko 4 stało ciągle na miejscu 4. Sprawdzenie sukcesu za słabe, model pozycji przy dwóch monitorach do zweryfikowania |
| T51 | `restore-drag` z nowym sprawdzaniem (czy właściwa przestrzeń stoi za właściwą, kalibracja po chybieniu), laptop + DELL, 3 przestawienia na laptopie | ✅ 3 przeciągnięcia, każde trafione za pierwszym razem, **5,2 s**, kolejność zgodna z zapisem | chybienie z 16:24 się nie powtórzyło; ścieżka kalibracji czeka na prawdziwe chybienie (log „✗ chybione”) |
| T52 | 4 rundy: mieszanie laptopa przez `spmove` (także biurko w środku i na końcu), potem `restore-drag`, laptop + DELL | ✅ 10 przeciągnięć, wszystkie trafione za pierwszym razem, rundy 4,3–5,2 s | chybienia z 16:24 nie da się wywołać na żądanie; kalibracja zostaje na wypadek, log „✗ chybione” pokaże dane celowania |
| T53 | Po restarcie Maca: apki otwarte jako zwykłe okna. „Bezpośrednio”: „Już ułożone” (nie było przestrzeni do przestawienia); „Pełny ekran”: część okien nie znaleziona (szukał tylko na widocznym biurku), dźwięki blokady (Ctrl+strzałka na końcu paska) | ❌ | brakujące okna trzeba najpierw wstawić na pełny ekran; okna szukać wszędzie (`axAllWindows`) |
| T54 | `restore-bridge` z `enterMissingFullScreen`: drugie okno Brave zwykłym oknem na innym biurku | ✅ Brave na pełnym ekranie po 0,9 s, ułożenie 0,3 s; ❌ kolejność zła: Bitwarden przed Forkiem | po restarcie numery okien są nadawane od nowa, numer zapisanego Bitwardena trafił do innej apki; numer okna liczy się teraz tylko w obrębie tej samej apki |
| T55 | `restore-bridge` po poprawce | ✅ kolejność zgodna z zapisem, 0,16 s | |
| T56 | `fson <okno>`: `AXFullScreen` = true wprost, bez aktywowania apki: (a) okno Brave na widocznym biurku, (b) Fork na biurku niewidocznym (pokazany Claude) | ✅ (a) i (b): nowa przestrzeń na końcu paska, ekran zostaje na tym, co pokazane | test użytkownika po restarcie (13:13): drugie Brave ✗, bo stary sposób aktywował Brave, a macOS skakał do jego okna na pełnym ekranie. Teraz najpierw wprost, aktywacja tylko jako zapas (`enterFullScreen`) |
| T57 | `restore-bridge`: Fork zwykłym oknem na niewidocznym biurku | ✅ Fork na pełnym ekranie po 0,5 s, kolejność zgodna z zapisem (0,2 s) | przy okazji: `fson … off` dla okna Brave i Bitwardena na niewidocznej przestrzeni nie zadziałał (Fork tak); dotyczy tylko wyjścia z pełnego ekranu w metodzie „Pełny ekran” |
| T58 | `fson 88`: okno Brave „Raport” na niewidocznym biurku (pokazany Claude) | ❌ Brave ignoruje pełny ekran dla okna na niewidocznym biurku (Fork przyjmował, T56); stary zapas (aktywacja Brave) skakał do drugiego okna Brave na pełnym ekranie | zapas: biurko okna z `SLSCopySpacesForWindows`, przejście na nie, potem pełny ekran |
| T59 | `restore-bridge` po poprawce, „Raport” zwykłym oknem, pokazany Claude | ✅ Brave na pełnym ekranie po 0,5 s, kolejność zgodna z zapisem | |
| T60 | `axwhich`: element, który `axWindow` zwraca dla okien pełnoekranowych | ❌ Claude, Brave, Bitwarden: rola AXUnknown bez tytułu (element ze środka okna z tym samym numerem), Fork i IntelliJ: AXWindow | przyczyna pustych tytułów i ignorowanego pełnego ekranu w Brave/Bitwardenie (T57, T58 były fałszywe). `axWindow` przyjmuje tylko rolę AXWindow |
| T61 | po poprawce: „Raport” (Brave) z pełnego ekranu i z powrotem wprost, pokazany Claude | ✅ wyjście i wejście działają bez przechodzenia na biurko, tytuły wszystkich okien widoczne | przejście na biurko okna zostaje jako zapas |
| T62 | Dwuklik w kafelek: aktywacja apki, potem AX raise + `AXMain` | ⚠️ Fork, Bitwarden, Claude ✅; trzecie okno Brave: skok na ostatnio używane okno Brave, potem Ctrl+strzałki | aktywacja wybiera ostatnio używane okno apki |
| T63 | Skok po numerze okna: `_SLPSSetFrontProcessWithOptions` + `SLPSPostEventRecordTo` + `AXRaise` (jak AltTab) | ✅ wszystkie poza nowym oknem Brave #9403 (ekran stoi). JumpTest (osobna apka, tylko SkyLight, bez AXRaise, z uprawnieniem i prawdziwym kliknięciem): **żadne okno nie przełącza przestrzeni**, apka tylko wychodzi na wierzch | przestrzeń przełącza **AXRaise**, SkyLight tylko aktywuje. Mission Control `AXPress` po `….space.<ID>`: brak takiej miniaturki, odrzucone |
| T64 | Sonda: element AX okna #9403 | element **6063** (AXWindow), `axWindow` szukał do 2000 | Chromium numeruje elementy jednym licznikiem; nowe okno po długiej pracy ma wysoki numer. Zakres 0..<50000 (~10 µs na element), skok ✅ 0,6 s |
| T22 | P2: zwykły `killall Dock` | kolejność bez zmian, plik dalej nieaktualny (stare ID 316) | Dock nie zapisuje pliku przy wyjściu; po restarcie bierze stan z WindowServera |
| T23 | P2: zamiana IntelliJ ↔ Fork w pliku (`defaults import`) + `killall -9 Dock` | ❌ kolejność bez zmian | Dock przy starcie **nie** czyta kolejności z pliku. Kopia przywrócona |

#### T20: prawdziwe vs nasze zdarzenie (leftMouseDown)
- **Prawdziwe** pola niezerowe: `0=4090 1=1 2=255 7=3 39=… 40=79995 45=1 50=248 53=3 55=1 58=… 85=… 87=… 89 90 101=28 107=982 108=1 169=<HID timestamp>`.
  - `7=3` subtyp myszy (`kCGMouseEventSubtype`), `45=1` stan źródła = HID system,
    `40` docelowy PID, `169` znacznik czasu HID. **Brak** pól 41/43/44 (PID/UID/GID nadawcy).
- **Nasze**: `1=1 2=255 41=<nasz PID> 43=501 44=20 50=248 55=1 102=63 108=1`. Mamy PID nadawcy, nie mamy 7/45/169.
- **Dołączony IOHIDEvent** w prawdziwym down/up (676 B): `Pointer` (Relative, Flags 0x10,
  SenderID `0x0000000100000CCB`, BuiltIn 1, ButtonMask) z dziećmi:
  `Button` (Mask, Number 1, State, Pressure, ClickCount 1) **oraz dwa `VendorDefined`**
  (UsagePage 0xFF00, Usage 24, 124 B danych). W P1 brakowało SenderID, BuiltIn i rekordów VendorDefined.
- Zdarzenia `leftMouseDragged` (268 B) **nie mają** dołączonego IOHIDEvent. Czyli kluczowe są down/up.

---

## Pomysły do przetestowania (po kolei)

### P1 ❌ Kliknięcia i przeciąganie z dołączonym IOHIDEvent (Pointer + Button)
Wynik (T19): `mcclick 7 hidev` → „klik zignorowany”, `mcdrag 7 3 hidev` → kolejność bez zmian.
Następny krok: P1f (nagrać prawdziwy klik i go odtworzyć).

Do każdego zdarzenia myszy dołączamy rekord IOHIDEvent typu Pointer (17) z dzieckiem Button (2)
przez `SLEventSetIOHIDEvent`. Tak Mac Mouse Fix i MouseDragFix naprawili gesty na macOS 27.
- Kod: `Sources/MissionControl.swift`, `enum HID`, włączane słowem `hidev`.
- Test:
  ```bash
  ./.build/release/spaces-layout mcclick 7 hidev
  ./.build/release/spaces-layout mcdrag 7 3 hidev
  ```
- Jeśli zadziała: restore przez przeciąganie (~3 s zamiast ~16 s) + przenoszenie przestrzeni między monitorami.
- Warianty, jeśli nie zadziała:
  - P1b: sam rekord Button, bez Pointer,
  - P1c: `IOHIDEventCreateMouseEvent` / `IOHIDEventCreateRelativePointerEvent` zamiast ogólnego `IOHIDEventCreate`,
  - P1d: rekord Digitizer (jak trackpad),
  - P1e: zserializowany payload w polu 4205 (sposób noswoosh) zamiast `SLEventSetIOHIDEvent`,
  - P1f 🔬: nagrać prawdziwe przeciągnięcie i je odtworzyć (`Sources/Recorder.swift`).
    `mcrecord` podsłuchuje zdarzenia przycisku, zapisuje je (`recorded-drag.plist`) i wypisuje
    wszystkie niezerowe pola + dołączony IOHIDEvent (`CGEventCopyIOHIDEvent`) dla prawdziwego
    i naszego zdarzenia. `mcreplay` odtwarza nagranie 1:1.
    - Odtworzenie działa → budujemy zdarzenia z nagranych szablonów.
    - Nie działa → Mission Control filtruje po czymś, czego nie skopiujemy (np. proces nadawcy);
      wtedy porównanie pól pokaże, co jeszcze się różni.

### P1g ✅ (częściowo) Prawdziwe zdarzenia HID z wirtualnego urządzenia (Karabiner)
**Przełom (T24, T25):** klik i przeciąganie w Mission Control działają. Do zrobienia:
upuszczanie w szczelinę (`dropPoint`), `list`/`restore` muszą rozumieć przestrzenie Split View
(dwa okna w jednej przestrzeni), szybszy start (stały pomocnik z otwartym gniazdem zamiast `sudo` przy każdym ruchu).

**`restore-drag`** (`Sources/DragRestore.swift`): druga wersja restore, obok `restore` (pełny ekran), do porównania.
Jedno `sudo` (pomocnik `vhid-serve` z jedną wirtualną myszą na cały restore), jedno otwarcie Mission Control,
miniaturki dopasowane do przestrzeni po kolejności (pasek = kolejność z SkyLight), upuszczanie w szczelinę
na lewo od docelowego miejsca, sprawdzenie kolejności po każdym ruchu, przerwanie przy Split View.
Na razie tylko pierwszy monitor.

Kod: `Sources/VirtualHID.swift`. Własny klient protokołu (bez biblioteki C++), opis ramek w nagłówku pliku.
Demon: Karabiner-DriverKit-VirtualHIDDevice 8.5.0, protokół klienta 7, gniazdo
`…/rootonly/karabiner_virtual_hid_device_service.sock` (unix stream). Część z myszą działa jako root
(`sudo -n spaces-layout vhid-click|vhid-drag …`), część z Mission Control jako użytkownik.
Test: `sudo -v`, potem `mcclickv 7` i `mcdragv 7 3`.

Skoro Mission Control odrzuca wszystko wysłane przez `CGEventPost` (T21), zostaje źródło, które
dla systemu *jest* sprzętem: wirtualna mysz. Karabiner-Elements 16.3.0 jest zainstalowany,
sterownik `Karabiner-DriverKit-VirtualHIDDevice` i demon działają.
- Klient wysyła raporty wskaźnika (przycisk + względny ruch) przez gniazdo demona
  (`/Library/Application Support/org.pqrs/tmp/rootonly/`) → **wymaga roota** (sudo albo pomocnik w tle).
- Kursor najpierw ustawiamy `CGWarpMouseCursorPosition`, potem przycisk w dół, ruch małymi krokami
  z korektą (system nakłada przyspieszenie na ruch względny), przycisk w górę.
- Biblioteka klienta: pqrs `Karabiner-DriverKit-VirtualHIDDevice` (C++, header-only).
- Koszt: średni/duży + uprawnienia roota. Zysk, jeśli zadziała: przeciąganie w Mission Control.

### P2 ❌ Edycja `com.apple.spaces` + restart Docka
Wynik (T22, T23): Dock po restarcie odtwarza kolejność ze stanu WindowServera, plik ignoruje
(przynajmniej w trakcie sesji; przy logowaniu może być inaczej, niesprawdzone).
Kopia zapasowa: `~/Library/Application Support/spaces-layout/spaces-backup-*.plist`.

Zapisać pożądaną kolejność do `SpacesDisplayConfiguration` i zrestartować Dock (`killall -9 Dock`,
żeby nie nadpisał pliku przy wyjściu). Dock odtwarza biurka z tego pliku przy starcie.
- Niewiadome: czy przestrzenie pełnoekranowe też idą wg pliku, czy wg stanu WindowServera.
- Ryzyko: ~2 s mignięcia Docka, możliwe pomieszanie pliku. **Najpierw kopia zapasowa, i tylko za zgodą.**
- Kopia: `defaults export com.apple.spaces ~/spaces-backup.plist`, przywrócenie:
  `defaults import com.apple.spaces ~/spaces-backup.plist && killall Dock`.

### P3 ⏳ Przestawiać zawartość zamiast przestrzeni
Stałe N zwykłych biurek na monitor + okna powiększone na cały ekran (zamiast natywnego pełnego ekranu).
Restore tylko rozkłada okna na właściwe biurka, kolejność biurek się nie zmienia.
- Biurka: dodawanie przez AX `mc.spaces.add`, usuwanie przez `AXRemoveDesktop`.
- Przenoszenie cudzych okien: bez SIP w praktyce tylko przeciąganiem w Mission Control → zależy od P1.
  Ewentualnie sprawdzić `SLSMoveWindowsToManagedSpace` / trik z compat ID na cudzym oknie.
- Minus: zmiana sposobu pracy (widać pasek menu i Dock, chyba że autoukrywanie).

### P4 ⏳ Przyspieszenie obecnej metody (pewny zapas)
- Skok do konkretnej przestrzeni przez Mission Control + `AXPress` zamiast przewijania Ctrl+strzałka
  (drugie okno Brave: ~3,4 s → ~1 s).
- Kolejność zdejmowania z pełnego ekranu tak, żeby skakać jak najmniej.
- Pomiar z „Ogranicz ruch” (Ustawienia → Dostępność → Monitor).
- Natychmiastowe przełączanie przestrzeni sposobem noswoosh (gest z IOHID payload).

### P5 ⏳ Uchwyty AX do okien z innych przestrzeni
AltTab zdobywa elementy AX okien z innych przestrzeni przez `_AXUIElementCreateWithRemoteToken`.
Sprawdzić, czy na takim elemencie da się ustawić `AXFullScreen` bez przechodzenia na przestrzeń.
Mogłoby skrócić pierwszy etap restore.

### P6 ⏳ Test z drugim monitorem
Przeniesienie okna na zewnętrzny monitor przed wejściem w pełny ekran (kod jest w `restore`, niesprawdzony)
oraz `goto` na drugim ekranie (Ctrl+strzałka działa na ekranie pod kursorem).

### P7 ✅ Kiedy zapisywać układ — DECYZJA (2026-11-16)
**W apce jest ustawienie „Tryb zapisu” z dwiema wzajemnie wykluczającymi się opcjami:**
- **Ręcznie:** układ zapisuje się tylko po kliknięciu „Zapisz układ”.
- **Automatycznie:** apka sama zapisuje zmiany kolejności, z zabezpieczeniami z opcji B poniżej
  (pauza ~10 s po zmianie monitorów i po własnym restore, zapis dopiero po ~5 s stabilnej kolejności).

Bez trybu mieszanego (opcja C odrzucona). W obu trybach zapis jest per zestaw monitorów.

Analiza, z której wyszła decyzja:
Układ jest już zapisywany **osobno dla każdego zestawu monitorów** (klucz = posortowane UUID
podłączonych ekranów). Zapis „laptop + monitor” nie nadpisuje zapisu „sam laptop”, więc po odłączeniu
wraca ostatni zapis dla samego laptopa.

Opcje:
- **A. Ręcznie:** przycisk „Zapisz układ” w apce (dziś komenda `save`). Przewidywalne, zero ryzyka.
- **B. Automatycznie:** apka co ~1 s czyta kolejność z SkyLight (tani odczyt) i zapisuje zmianę.
  Pułapka: po podłączeniu / odłączeniu monitora macOS sam miesza przestrzenie i automat zapisałby
  ten bałagan jako „nowy układ”. Wymagane zabezpieczenia:
  - nie zapisywać przez ~10 s po zmianie monitorów ani w trakcie / po własnym `restore`,
  - zapisywać dopiero, gdy kolejność stoi bez zmian przez ~5 s (nie łapać przeciągania w połowie),
  - przy zmianie monitorów najpierw `restore`, dopiero potem włączyć automat z powrotem.
- **C. Hybryda (rekomendacja):** A jako podstawa + B jako opcja do włączenia w menu, z zabezpieczeniami powyżej.
  Do tego „Cofnij ostatni automatyczny zapis” (trzymać poprzednią wersję), gdyby automat złapał bałagan.

### P8 🔬 Szybkie układanie bez Karabinera (2026-11-18)
Cel: tryb szybki bez sterownika Karabinera i bez roota. Wnioski:
- **Własna wirtualna mysz: niemożliwa bez konta Apple** (T41). DriverKit i CoreHID wymagają
  uprawnienia wydawanego przez Apple; `CGEventPost` Mission Control odrzuca (T21); yabai wymaga
  wyłączenia SIP. Każda metoda przeciągania w Mission Control odpada.
- **Zostaje pełny ekran, ale szybszy.** Dzisiejszy `restore` traci czas na przewijanie Ctrl+strzałka
  do każdej przestrzeni (T34: 18,6 s, dwa razy nie trafił). Plan:
  1. T43: wyjście z pełnego ekranu przez `axWindow` **bez przechodzenia** na przestrzeń (T42 mówi,
     że atrybut jest ustawialny). Jeśli działa: etap 1 bez `goTo`, potem T44: kilka okien naraz.
  2. Wejście w pełny ekran w docelowej kolejności (nowa przestrzeń zawsze na końcu paska), okno
     najpierw przesunięte na właściwy monitor (to już działa).
  3. T45: pomiar z „Ogranicz ruch” (Ustawienia → Dostępność → Monitor): przejścia stają się
     przenikaniem, krótsze niż przesuwanie.
  4. T46: biurka bez myszy: AX w Mission Control (`AXRemoveDesktop`, `mc.spaces.add`) to nie
     zdarzenia myszy, więc nie powinny być filtrowane. Puste biurko „przestawia się” przez usuń +
     dodaj na końcu. Biurko z oknami odpada (okna przeszłyby na sąsiednie biurko).
- **T43 ✅:** cykl off/on 0,85 s bez przechodzenia na przestrzeń. Następny krok: `restore` v5
  (etap 1 przez `axWindow`, bez `goTo`) i T44 na prawdziwym pomieszaniu.
- Szacunek sprzed T43: ~0,7–1 s na przestawianą przestrzeń zamiast ~1,5 s + przewijanie.
  Przeciąganie Karabinerem: 1,2 s na start + ~1,2 s na ruch, czyli porównywalnie przy kilku ruchach.
- Minus metody: okna na chwilę wychodzą z pełnego ekranu (widać mignięcie), Split View się rozpada.

### P9 ✅ WMBridge: przestawianie przestrzeni operacją SkyLight (2026-11-18)
Z researchu (`reports/Przestawianie Spaces bez Karabinera.md`): macOS 26+ ma ~90 klas
`SLSBridged*Operation`, które zwykły proces z załadowanym AppKitem wysyła do menedżera okien,
z włączonym SIP. `SLSBridgedMoveManagedSpaceToDisplayIndexOperation`
(`-initWithSpaceID:displayIdentifier:index:`, indeks = końcowa pozycja od 0, z biurkami) ustawia
przestrzeń na miejscu i może ją przenieść na inny monitor. Kod: `bridgedMoveSpace` w
`Sources/DragRestore.swift`, test `spmove <ID> <monitor|.> <indeks> [fb]`, sprawdzenie `mcorder`.
Wyniki T45–T48: działa na 27.0.1 dla przestrzeni pełnoekranowych i biurek, ~80 ms na ruch,
Mission Control zgodny, przetrwa restart Docka. T49: przeniesienie na inny monitor też działa
(~100 ms). Następny krok: `restore` oparty na tej operacji zamiast przeciągania.

### Odrzucone
- **yabai ze skryptem w Docku:** wymaga częściowego wyłączenia SIP.
- **AeroSpace / własne wirtualne biurka:** rezygnacja z przestrzeni macOS i pełnego ekranu.
- **Akcja AX „przesuń”:** nie istnieje (T18).

---

## Źródła
- noswoosh (walidacja IOHID payload na 27): https://github.com/mmathys/noswoosh
- MouseDragFix `DockSwipe.swift` (`IOHIDEventCreate` + `SLEventSetIOHIDEvent`): https://github.com/channelramble/MouseDragFix
- Mac Mouse Fix #1876, #2026, PR #2023: https://github.com/noah-nuebling/mac-mouse-fix/issues/1876
- PaperWM.spoon #173 i PR #174 (drag na 27.0): https://github.com/mogenson/PaperWM.spoon/pull/174
- Hammerspoon #3897 (MC ignoruje sztuczne kliknięcia): https://github.com/Hammerspoon/hammerspoon/issues/3897
- SpaceKeeper (brak API do przestawiania): https://github.com/shuistyle/SpaceKeeper
- Moom FAQ (brak przenoszenia między przestrzeniami): https://www.manytricks.com/osticket/kb/faq.php?id=52
- par-term `macos_space.rs` (trik z compat ID): https://docs.rs/crate/par-term/0.32.1/source/src/macos_space.rs
- Mosaico (jak yabai bez SIP przenosi okna): https://mautoblog.com/en/posts/mosaico-tiling-window-manager-macos-yabai-no-sip-2026/
- gist o edycji `com.apple.spaces.plist`: https://gist.github.com/0xdevalias/8bc497546d5f036cbaeae5d0e389aa35
- Zgłoszenia o mieszaniu przestrzeni przy monitorach: discussions.apple.com/thread/253718328 (uśpienie),
  discussions.apple.com/thread/255037510 (zamiana laptop/monitor), discuss.binaryage.com/t/3052
  (dwa zewnętrzne zamienione), discuss.binaryage.com/t/1343 (restart), discuss.binaryage.com/t/2405
  (pierwsza przestrzeń znika), r/MacOS 1ju82l5 (regres od 15.4).
