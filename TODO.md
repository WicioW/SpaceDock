# TODO: pomysły

Pomysły na później. Plan wydania jest w [docs/distribution.md](docs/distribution.md).

## Easter egg: wahadłowiec zjada przestrzenie (2026-11-18)

**Stan (2026-11-19):** ✅ scenka w wierszu tytułu i wywołanie (`Sources/ShuttleEgg.swift`): klik =
kolor na 0,6 s, 10 kliknięć (≤ 0,4 s odstępu) = lot 2 s i okna w luku, po 1,5 s powrót na start;
„Ogranicz ruch” = bez lotu. ✅ (2026-11-21) nowy wygląd „panel” (`Sources/Panel.swift`, `docs/design-handoff.md`): odblokowany lotem, motyw 1–3 w ustawieniach.

**Gdzie:** w wierszu tytułu okna, na środku (2026-11-19; wcześniej obok napisu „SpaceDock”).

**Wygląd w spoczynku:** mała, mało szczegółowa, bezbarwna (jednokolorowa jak glif w pasku menu)
scenka w poziomie:
- wahadłowiec z naszej ikony, ustawiony poziomo, nosem w prawo;
- za nim ogień z silników;
- przed nim 3 ikonki przestrzeni, czyli 3 miniaturki okien jak w Mission Control.

**Klik w wahadłowiec:** wahadłowiec i ogień na chwilę dostają kolory (jak w ikonie apki), potem
kolory gasną i scenka wraca do bezbarwnej.

**10 szybkich kliknięć z rzędu:**
1. Wahadłowiec rusza do przodu i po kolei „zjada” 3 miniaturki okien.
2. Po każdym zjedzonym oknie w środku wahadłowca (w luku) przybywa jedna miniaturka, tak jak na
   ikonie apki: 1, potem 2, potem 3.
3. Po zjedzeniu wszystkich trzech odblokowuje się **zupełnie nowy wygląd apki**.

**Nowy wygląd (odblokowany):** zamiast standardowego wyglądu apki na macOS, motyw nawiązujący do
kosmosu i dokowania: przestrzenie / okienka „dokują” jak statki do stacji. Dotyczy całego okna
(lista zestawów, monitory, kafelki przestrzeni, ustawienia).

**Najpierw szkice**, dopiero potem kod:
- scenka w wierszu tytułu: stan bezbarwny, błysk koloru po kliknięciu, klatki animacji zjadania;
- 2–3 kierunki nowego wyglądu apki do wyboru.

**Do ustalenia:**
- Co liczy się jako „szybko”: np. 10 kliknięć, każde najwyżej 0,4 s po poprzednim?
- Czy nowy wygląd zostaje na stałe po odblokowaniu, czy tylko do zamknięcia apki? Jak wrócić do
  zwykłego wyglądu (przełącznik w ustawieniach, kolejne 10 kliknięć)?
- Gdy w systemie jest włączone „Ogranicz ruch”: krótsza animacja albo samo przejście bez lotu.
- Jasny i ciemny tryb dla obu wyglądów.

## Skróty klawiszowe: zapis i przywracanie (2026-11-22)

**Stan (2026-11-22):** ✅ `Sources/Hotkeys.swift`: dwa pola w ustawieniach zwykłego wyglądu
(„Skrót: zapis”, „Skrót: przywróć”), domyślnie bez skrótu, Delete usuwa, Esc anuluje; skrót
zajęty przez inną apkę = napis przy polu. Zapis skrótem pyta przed nadpisaniem (jak przycisk),
przywracanie bez zapisu albo bez zgody = sygnał dźwiękowy. Brak jeszcze w ustawieniach panelu.

Dziś zapis i przywracanie są tylko pod przyciskami (okno, menu w pasku menu). Pomysł:
- **Tylko globalne**, działają z każdej apki, nie tylko gdy SpaceDock jest na wierzchu. Bez
  osobnych skrótów w oknie.
- **Skrót ustawia użytkownik** w ustawieniach: pole „naciśnij skrót” osobno dla zapisu i dla
  przywracania, z możliwością wyczyszczenia (= skrót wyłączony). Domyślnie oba puste, żeby nie
  gryźć się z systemem ani innymi apkami.
- **Jak:** `RegisterEventHotKey` z Carbon, bez nowej zależności i bez dodatkowej zgody (Dostępność
  już mamy, ale ten mechanizm jej nie wymaga). Gdy skrót jest zajęty przez inną apkę, rejestracja
  się nie uda: pokazać to przy polu.
- **Do ustalenia:** potwierdzenie przed zapisem, bo nadpisuje poprzedni układ (dźwięk /
  powiadomienie / krótki błysk ikony w pasku menu zamiast okna?); co gdy przywracanie już trwa.

## Zwykły wygląd: kolory rozjechania między zapisem a ekranami (2026-11-22)

**Stan (2026-11-22):** ✅ zwykły wygląd bierze stany z `PanelData` (jedno liczenie dla obu
wyglądów): czerwony = nie otwarte / brak biurka / nie na pełnym ekranie, żółty = „Przestawione › N”, każda apka na innym miejscu wśród zapisanych niż w zapisie (zamiana = obie)
(w jasnym trybie ciemniejszy żółty), niebieski = nie zapisane. Zawsze kolor plus napis.

W zwykłym wyglądzie (nie „panel” za easter eggiem) kafelek, który różni się od zapisu, ma dziś
zawsze tę samą pomarańczową ramkę i napis (`SpaceTile` w `Sources/App.swift`), a przestawionych
przestrzeni nie oznacza wcale. Pomysł: na monitorach pokazać konkretne apki w dwóch kolorach:
- **czerwony:** zamknięta / brak, czyli „Nie otwarte”, „Brak biurka”, „Nie na pełnym ekranie”;
- **żółty:** na złym miejscu, „Przestawione › N” (N = gdzie jest teraz na pasku).

Panel już to liczy (`SpaceState` w `Sources/Panel.swift`: `moved`, `missing`, `noFullScreen`,
`unsaved`): przenieść to liczenie w jedno wspólne miejsce i użyć w obu wyglądach, zamiast liczyć
drugi raz.

**Do ustalenia:** kolor dla „Nie zapisane” (nowa przestrzeń spoza zapisu; dziś pomarańczowy, może
niebieski jak w panelu); kolor plus napis, nie sam kolor (daltoniści); czy żółty jest czytelny
w jasnym trybie.

## Otwieranie zamkniętych apek z zapisu (2026-11-22)

**Stan (2026-11-23):** ✅ `launchMissingApps` (DragRestore.swift) przed każdą metodą przywracania:
uruchamia apki z zapisu bez okna i bez pełnego ekranu, czeka do 20 s na okno, resztę robi zwykłe
przywracanie. Osobna akcja „Przywróć i otwórz apki” (przycisk w nagłówku, menu w pasku menu,
własny skrót); zwykłe „Przywróć” tylko przestawia, automat po zmianie monitorów nigdy nie otwiera.
Po otwarciu czeka, aż pasek stoi 2 s (apki same wracające na pełny ekran). Czerwony kafelek
apki ma przycisk „otwórz” (tylko ta apka, potem cały układ). Brak jeszcze w panelu.

1. **Jedna apka:** kafelek na czerwono („Nie otwarte”) dostaje akcję (klik / przycisk „Otwórz”):
   SpaceDock uruchamia apkę, czeka na jej okno, włącza pełny ekran i stawia przestrzeń na miejscu
   z zapisu.
2. **Wszystkie naraz:** to samo dla wszystkich czerwonych apek z obecnego zapisu. Raczej bez nowego
   skrótu: w ramach przywracania (przycisk i skrót „przywróć”), np. jako opcja w ustawieniach
   „Przywracanie otwiera zamknięte apki”.

**Punkt startu:** `enterMissingFullScreen` w `Sources/DragRestore.swift` już włącza pełny ekran
oknom z zapisu, które nie są na pełnym ekranie; dziś pomija apki bez okna („brak okna, apka nie
działa”). Brakuje: uruchomienia apki (`NSWorkspace.openApplication`) i czekania na okno.

**Do ustalenia:** apki, które po starcie nie otwierają okna same (np. pokazują tylko ikonę w pasku
menu); które okno, gdy zapis ma tytuł, a apka otwiera inne (np. przeglądarka bez przywracania
kart); limit czasu na start apki; czy automatyczne przywracanie po zmianie monitorów też ma
otwierać apki (raczej nie, tylko ręczne).

## Kilka układów na jeden zestaw monitorów (2026-11-22) — duże

Dziś jest jeden zapis na zestaw monitorów. Pomysł: kilka nazwanych układów na ten sam zestaw
(np. „Praca”, „Wieczór”) i wybór, który przywrócić.

**Najpierw designy**, dla zwykłego wyglądu i dla panelu (easter egg), dopiero potem kod.

**Do ustalenia:**
- Który układ przywraca automat po zmianie monitorów (ostatnio użyty? oznaczony jako domyślny?).
- Gdzie wybór układu: lista w pasku pod zestawem, przełącznik w nagłówku, menu w pasku menu.
- Zapis: nadpisuje wybrany układ czy tworzy nowy; nazywanie, zmiana nazwy, usuwanie.
- Skróty: „przywróć” przywraca wybrany układ? osobne skróty per układ?
- Format `layouts.json` (dziś klucz = zestaw monitorów, wartość = jeden układ): migracja starych
  zapisów do układu „Domyślny”.
