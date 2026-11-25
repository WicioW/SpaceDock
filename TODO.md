# TODO: pomysły

Pomysły na później. Plan wydania jest w [docs/distribution.md](docs/distribution.md). Luźne pomysły bez decyzji: [docs/improvements.md](docs/improvements.md).

## Easter egg: wahadłowiec zjada przestrzenie (2026-11-18)

**Stan (2026-11-19):** ✅ scenka w wierszu tytułu i wywołanie (`Sources/ShuttleEgg.swift`): wciśnięcie =
kolor, póki trzymasz (od 2026-11-24), 10 kliknięć (≤ 0,4 s odstępu) = lot 2 s i okna w luku, po 1,5 s powrót na start;
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
przywracanie bez zapisu albo bez zgody = sygnał dźwiękowy. Panel: wiersz „Skróty” z przyciskiem „Ustaw” (otwiera tę zakładkę ustawień).

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
przywracanie. Osobna akcja „Przywróć z brakującymi” (do 2026-11-24 „Przywróć i otwórz apki”) (przycisk w nagłówku, menu w pasku menu,
własny skrót); zwykłe „Przywróć” tylko przestawia, automat po zmianie monitorów nigdy nie otwiera.
Po otwarciu czeka, aż pasek stoi 2 s (apki same wracające na pełny ekran). Czerwony kafelek
apki ma przycisk „otwórz” (tylko ta apka, potem cały układ). ✅ (2026-11-24) to samo w panelu (segment ↗ na pasku).

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

**Stan (2026-11-25):** ustalenia gotowe (niżej, sesja pytań + research w sieci). Designy wybrane:
zwykły wygląd **LA** (drzewko w pasku bocznym: zestaw rozwija się w swoje układy, „+ Zapisz jako
nowy…” na końcu), panel **QA** (to samo drzewko w szynie pod wybranym zestawem; krawędzie heksu
zestawu = liczba układów, do 6; dziennik w szynie skrócony do 1 wiersza). Specyfikacja:
[docs/design-handoff-layouts.md](docs/design-handoff-layouts.md) (prototypy w `docs/design/layouts/`). Dalej: kod. Odrzucone i odłożone pomysły:
[docs/improvements.md](docs/improvements.md).

**Pojęcia:**
- **Zestaw monitorów:** podłączone ekrany; nie wybiera się go, wynika z kabli.
- **Układ** (w rozmowie „zestaw aplikacji”): pełny zapis kolejności przestrzeni na wszystkich
  monitorach zestawu, jak dzisiejszy zapis. Zestaw ma listę układów.
- **Wybrany układ:** ostatnio przywrócony albo utworzony; pamiętany po restarcie apki.
- **Podgląd:** klik w inny układ w oknie tylko go pokazuje (kafelki z różnicami), nic nie przestawia.

**Lista układów:**
- Nazwę wpisuje użytkownik (niepusta, unikalna w zestawie); żadnych domyślnych „Układ 1”.
- Kolejność przeciąganiem; numery ciągłe 1, 2, 3… (usunięcie nr 4 przesuwa nr 5 na 4).
- Usuwanie z potwierdzeniem; po usunięciu ostatniego zestaw jest bez zapisu.
- Pierwszy zapis na nowym zestawie pyta o nazwę („Zapisz” nieaktywny przy pustym polu).
- Migracja: dzisiejszy zapis zestawu staje się układem bez nazwy, wiersz ma pole „Nadaj nazwę”,
  nic nie blokuje. `layouts.json`: klucz = zestaw monitorów, wartość = lista układów
  (nazwa + zapis) i wybrany.
- Układy innych zestawów: podgląd tak, przywrócenie nie.

**Akcje:**
- „Przywróć” / „Przywróć z brakującymi” (dwa przyciski jak dziś): na wybranym naprawiają
  rozjechanie; w podglądzie ładują oglądany układ, który od tej chwili jest wybrany.
- „Zapisz”: nadpisuje wybrany; w podglądzie niedostępny.
- „Zapisz jako nowy…”: pyta o nazwę, tworzy układ z obecnego ekranu i od razu go wybiera.
- „Zapisuj automatycznie”: zawsze do wybranego (nigdy do podglądanego).
- Po zmianie monitorów („Przywracaj automatycznie”): ostatnio wybrany układ tego zestawu
  (po aktualizacji: jedyny istniejący). Bez układu domyślnego.
- Otwieranie apek nie przywraca ich stanu (np. kart przeglądarki); przeglądarki dalej po bundle
  + tytule.

**Apki spoza układu** (globalne ustawienie, dwie wartości):
- **Zostaw** (domyślnie): zostają na końcu jako „Nie zapisane”.
- **Schowaj:** każde przywrócenie (ręczne, skrót, automat) wyprowadza z pełnego ekranu i
  minimalizuje przestrzenie pełnoekranowe spoza układu. Zwykłych okien na biurkach nie rusza.
  W opisie ustawienia: automat schowa też świeżo otwartą, niezapisaną apkę pełnoekranową.
- Apek nie zamykamy nigdy (niezapisana praca).

**Skróty:**
- Jeden modyfikator w ustawieniach (np. ⌃⌥), numer pozycji na liście dochodzi sam: ⌃⌥1 =
  pierwszy układ obecnego zestawu, pozycje 1–9. Przypięte do pozycji, nie do nazwy; przy każdym
  układzie na liście widać jego skrót. Numer poza końcem listy = sygnał dźwiękowy.
- Przy modyfikatorze: czy skróty układów przywracają tylko przestawiając, czy z brakującymi.
- Ostrzeżenie przy skrócie z samym ⌘ (⌘1–9 to karty w przeglądarkach, okna w IntelliJ).
- Dzisiejsze globalne „Zapisz”, „Przywróć”, „Przywróć z brakującymi”: na wybrany układ.

**Menu w pasku menu:** lista układów obecnego zestawu, ptaszek przy wybranym; klik = przywróć
(jak skrót).

**Poza zakresem:** automatyczne przełączanie układów, karty przeglądarek
([docs/improvements.md](docs/improvements.md)); składanie układu z osobnych monitorów.

## Strzałki w oknie apki: zestawy monitorów i układy (2026-11-24)

**Dopiero po** „Kilka układów na jeden zestaw monitorów” (wyżej): bez kilku układów strzałki
w lewo/prawo nie mają czego przełączać.

Gdy okno SpaceDock jest na wierzchu (nie globalnie):
- **↑ / ↓**: poprzedni / następny zestaw monitorów,
- **← / →**: poprzedni / następny układ apek w wybranym zestawie.

**Do ustalenia:**
- ✅ (2026-11-24, z ustaleń „kilka układów”) ← / → zmieniają podgląd, nie przywracają.
- Wybrany design LA (drzewko): w drzewku ← / → systemowo zwija i rozwija, a ↑ / ↓ i tak chodzi
  po zestawach i ich układach. Czy osobne ← / → dla układów jest jeszcze potrzebne?
- Kolizja z zaznaczaniem kafelka (klik = zaznaczenie): czy strzałki mają też przesuwać zaznaczenie.
- Na końcu listy: zatrzymać się czy zawijać.
- To samo w panelu (easter egg).
