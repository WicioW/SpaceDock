# SpaceDock: research wizualny do trzech koncepcji

Notatki do szkiców. Cel: gęste, neonowe, „filmowe” panele sterowania, a nie uproszczony panel ustawień. Każdy element ma krótki opis wyglądu i dane SpaceDock, które pokazuje. Źródła podane są przy tekście. Tam, gdzie opis pochodzi z ogólnej znajomości gatunku, a nie z konkretnego źródła, jest dopisek *(konwencja gatunku)*.

## 0. Dane, które musi pokazać każda koncepcja

| Dane | Uwagi do szkicu |
|---|---|
| Lista zestawów monitorów („Sam laptop”, „Laptop + DELL”, „3 monitory”) | bieżący zestaw oznaczony jako *podłączony* |
| Na każdy monitor: Spaces w zapisanej kolejności | Space = aplikacja albo biurko; nazwa aplikacji i tytuł okna |
| Znaczniki „nie zapisany” i „nie otwarty” | „nie zapisany” = dodatkowy Space jest teraz na pasku, „nie otwarty” = zapisany, ale go brak |
| Ustawienia | przywracanie Ręczne/Automatyczne, zapis Ręczny/Automatyczny, metoda Drag / Full screen / Direct, język, start przy logowaniu |
| Status | zgodny z zapisem / różni się / brak zapisu / niepodłączony |
| Przyciski | Zapisz bieżący układ, Przywróć |
| Ostatnie przywrócenie | np. 0,29 s, 5 ruchów |
| Easter egg | mały prom kosmiczny na pasku tytułu |

### Słowniczek japońskich etykiet (opcjonalny, tylko poprawne słowa)

Fanowski przewodnik ostrzega przed japońskim tekstem używanym tylko jako ozdoba ([ckorhonen/evangelion-design](https://skills.sh/ckorhonen/claude-skills/evangelion-design)). Jeśli w ogóle dajemy japońskie podpisy, to krótkie, prawdziwe i zawsze obok etykiety po polsku albo angielsku:

保存 (zapis) · 復元 (przywrócenie) · 自動 / 手動 (auto / ręcznie) · 接続中 (podłączony) · 未接続 (niepodłączony) · 一致 (zgodny) · 相違 (różnica) · 画面 (ekran) · 配置 (układ) · 未保存 (nie zapisany) · 未起動 (nie uruchomiony).

---

## A. „Neonowa konsola” (sterownie z anime lat 80.)

### Co wiadomo o źródłach

- Ekrany komputerów w filmach anime z lat 80. robiono analogowo, efektami optycznymi przy zdjęciach komórkowych. Tylko jedna sekwencja w *Patlabor 1* była CGI ([animetudes, Patlabor: The Movie](https://animetudes.com/2022/04/15/mobile-police-patlabor-the-movie/)). Stąd świecenie bez gradientów, płaskie kolory, cienkie linie świetlne i lekkie rozmycie światła.
- Technika „światła przechodzącego” (transmitted light, jap. 透過光) polega na fotografowaniu światła przez maski w komórce, co daje izolowane, świecące plamy koloru ([Wikipedia: Cinematography of *Royal Space Force*](https://en.wikipedia.org/wiki/Cinematography_of_Royal_Space_Force:_The_Wings_of_Honn%C3%AAamise)). Podświetlane folie i „underlighting” były w tej dekadzie standardem ([TV Tropes: Underlighting](https://tvtropes.org/pmwiki/pmwiki.php/Main/Underlighting)).
- Pulpity w OVA z tej epoki to „małe, płaskie elementy rozsiane po dużej konsoli”, symbole i nieregularne kształty zamiast zwykłej klawiatury. Fonty są niskiej rozdzielczości, retro, a animacja prosta ([HUDS+GUIS: Cyber City Oedo 808](https://www.hudsandguis.com/home/2025/cyber-city-odeo-808)).
- Lata 70. i 80. w sci-fi to „piękna i prosta” estetyka ekranów: rozdzielczość ok. 320×240, wypukłość kineskopu, równe linie skanowania i migotanie (dot crawl) ([Mark Paterson, Archer S10](https://markpaterson.tv/projects/fx_networks_archer_season_10_mv_seamus_interface)). Na look CRT składają się linie skanowania, krzywizna, bloom, rozlanie koloru, winieta i szum ([Maxon: Analog](https://help.maxon.net/uni/en-us/Content/html/analog.html)).

### Paleta (propozycja)

Tło `#0B0705` (prawie czarne, ciepłe). Panele `#22170F` i `#33231A` (ciemny brąz, matowy). Bloki: żółty `#F2C230`, zielony `#3DAA48`, czerwony `#D7372A`, niebieski `#2F6FD0`, biały kremowy `#E9E4D4`. Fosfor CRT: cyjan `#3FF0FF`. Linie konstrukcyjne: magenta `#FF3FB4`. Diagonale: biel `#F4F1E8`, 0,5 px, przezroczystość 60%.

### Elementy

| # | Element | Wygląd | Dane SpaceDock |
|---|---|---|---|
| A1 | Rząd ekranów CRT u góry | 3 do 5 ekranów w grubych brązowych ramkach z zaokrąglonymi rogami „kineskopu”. Boczne ekrany są pochylone do środka (trapez, perspektywa ok. 15°). Wewnątrz czerń z lekką winietą *(konwencja gatunku)* | jeden ekran na każdy monitor bieżącego zestawu, środkowy (szerszy) to monitor główny |
| A2 | Wektorowe okręgi cyjan | koncentryczne okręgi 1 px w kolorze `#3FF0FF` z bloomem (dwie warstwy: ostra linia i rozmyta kopia 4–6 px przy 40%), łuki niedomknięte, krótkie znaczniki co 30° | na każdym ekranie CRT: Spaces tego monitora jako punkty na okręgu w zapisanej kolejności (zgodnie z ruchem wskazówek, od godz. 12) |
| A3 | Magentowe linie konstrukcyjne | cienkie proste i łuki `#FF3FB4`, wychodzące poza okręgi jak linie pomocnicze kreślarza, z małymi krzyżykami w punktach przecięcia | łączą punkt Space z etykietą (nazwa aplikacji i tytuł okna) poza okręgiem |
| A4 | Białe diagonale | pojedyncze linie 0,5 px pod kątem ok. 30°, które przecinają cały panel, częściowo pod ekranami | czysta dekoracja, która daje „głębię” *(konwencja gatunku)* |
| A5 | Mozaika płaskich bloków-przycisków | prostokąty różnych szerokości (1×, 2×, 3× moduł), płaski kolor bez gradientu, 1 px ciemniejsza krawędź dolna, krótka etykieta w czarnym foncie na żółtym i białym tle, w białym na czerwonym i niebieskim | rzędy ustawień: przywracanie RĘCZNE/AUTO (dwa bloki, aktywny jasny, nieaktywny przygaszony do 35%), zapis RĘCZNY/AUTO, metoda DRAG / FULL / DIRECT, język, start przy logowaniu |
| A6 | Duże klawisze akcji | dwa największe bloki: żółty „ZAPISZ UKŁAD” i zielony „PRZYWRÓĆ”. Pod spodem cienka czerwona osłona w paski jak osłona przełącznika | Zapisz bieżący układ, Przywróć |
| A7 | Matryca klawiszy (biurko) | siatka małych kwadratów 8×4 na szerokim pulpicie w perspektywie od dołu, część kolorowych, część brązowych „pustych” | każdy kwadrat to jeden Space. Kolumny to monitory, kolor to typ (aplikacja = niebieski, biurko = biały, „nie zapisany” = żółty, „nie otwarty” = czerwony obrys bez wypełnienia) |
| A8 | Lampki kontrolne (annunciatory) | małe kwadratowe okienka 2×1 z podświetlonym napisem, zgaszone są ciemnobrązowe, zapalone pełnym kolorem z poświatą | status: ZGODNY (zielony) / RÓŻNICA (żółty) / BRAK ZAPISU (biały) / NIEPODŁĄCZONY (czerwony). Zawsze zapalona tylko jedna |
| A9 | Odczyt siedmiosegmentowy | cyfry LED w czerwieni lub bursztynie na czarnym okienku, zgaszone segmenty widoczne jako ciemny „duch” (np. `#1A0A00`) | ostatnie przywrócenie: `0.29` s i `05` ruchów |
| A10 | Pasek tekstu fosforowego | 1 linia tekstu monospace w kolorze zielonego lub cyjanowego fosforu z linią skanowania, tekst pisany znak po znaku | log: „PRZYWRÓCONO 5 RUCHÓW W 0,29 S” |
| A11 | Selektor zestawów jako przełącznik obrotowy | okrągła gałka z białą kreską i 3–4 pozycjami opisanymi małym drukiem, przy aktualnej pozycji zielona dioda | lista zestawów monitorów, dioda przy zestawie podłączonym |
| A12 | Krzyż celownika na ekranie | cienki krzyż cyjan z przerwą w środku i narożnikami-nawiasami | zaznaczony Space, którego dotyczy podgląd |
| A13 | Siatka perspektywiczna | linie cyjan lub zielone o 20% jasności, zbiegające się do horyzontu, na dolnej połowie jednego ekranu *(konwencja gatunku, grafika wektorowa)* | podłoże pod ikonami Spaces na ekranie głównego monitora |
| A14 | Linie skanowania i bloom | poziome linie co 2 px przy 6–8%, lekka aberracja RGB 0,5 px tylko na ekranach CRT, nigdy na pulpicie | efekt, nie dane |
| A15 | Tabliczki z nitami | małe metalowe plakietki z wytłoczonym kodem panelu (np. „SD-02 / PANEL B”) w rogach | identyfikator zestawu i wersja aplikacji |
| A16 | Prom na pasku tytułu | sylwetka wektorowa 1 px biała. Po kliknięciu zapala się cyjanowym konturem z poświatą | easter egg |

### Zasady kompozycji

- Układ to „scena”: u góry rząd ekranów (boczne pochylone), poniżej szeroki pulpit ze skrótem perspektywicznym. Około 60% powierzchni to matowy brąz i czerń, światło jest tylko na ekranach i zapalonych blokach.
- Świeci tylko to, co aktywne. Bloki nieaktywne są płaskie i przygaszone, a aktywne dostają poświatę 4–8 px. Tak działało podświetlanie przez komórkę.
- Kolory płaskie, „kryjące”, jak farba na komórce: żadnych gradientów na przyciskach. Jeden poziom cienia (twarda ciemniejsza krawędź).
- Ekrany pokazują grafikę wektorową złożoną z kilku prostych figur (okręgi, krzyże, siatka), a nie dashboard z wykresami.
- Typografia: szeroki, geometryczny bezszeryfowy krój w duchu Eurostile Extended albo Microgramma na etykiety bloków (pisownia wersalikami), monospace o niskiej rozdzielczości (bitmapowy, np. w stylu 5×7) na ekranach, cyfry siedmiosegmentowe *(konwencja gatunku)*.

### Czego unikać

- Wygładzonych gradientów, szklanych efektów (glassmorphism), cieni „material”, zaokrąglonych przycisków w stylu iOS.
- Krojów z XXI wieku i dalekowschodniego cyberpunku z lat 2010 (fioletowo-różowe synthwave, palmy i siatki zachodzącego słońca).
- Wszystkiego, co świeci naraz: bloom tylko na ekranach i zapalonych lampkach.
- Bezpośrednich cytatów: czerwonego motocykla, kapsułki z pigułką, napisów i logotypów z konkretnych filmów, kanji z plakatów.

---

## B. „Centrum dowodzenia” (anime HQ lat 90.)

### Źródła

- Biblioteka [NERV-UI](https://mdrbx.github.io/nerv-ui/) ([repozytorium mdrbx/nerv-ui](https://github.com/mdrbx/nerv-ui)), czytana bezpośrednio z kodu komponentów, oraz pliki [`docs/DESIGN_TOKENS.md`](https://github.com/mdrbx/nerv-ui/blob/master/docs/DESIGN_TOKENS.md), [`DESIGN-REFERENCES.md`](https://github.com/mdrbx/nerv-ui/blob/master/DESIGN-REFERENCES.md) i strona [Visual Grammar](https://mdrbx.github.io/nerv-ui/docs/getting-started/visual-grammar/).
  Gotowe ekrany zbudowane z tych komponentów (19 przykładów: centrum dowodzenia, monitoring, terminal, logowanie, błąd 404 „signal lost”, pusty stan): [NERV-UI Examples](https://mdrbx.github.io/nerv-ui/examples/).
- [ckorhonen/evangelion-design](https://skills.sh/ckorhonen/claude-skills/evangelion-design), w tym [`style-guide.md`](https://github.com/ckorhonen/claude-skills/blob/main/skills/evangelion-design/references/style-guide.md) i [`source-signals.md`](https://github.com/ckorhonen/claude-skills/blob/main/skills/evangelion-design/references/source-signals.md). Ten drugi powołuje się na [Pedro Fleming](https://www.pedrofleming.com/neongenesisevangelion) i [Astromono](https://astromono.wordpress.com/2015/06/04/ui-design-of-evangelion/).
- [trimad: NERV Theme Generative Guidelines](https://trimad.github.io/prompts/2026-04-23-generative-guidelines-for-nerv-theme/).
- Typografia: [Fonts In Use](https://www.fontsinuse.com/uses/28760/neon-genesis-evangelion) i [Fontworks](https://en.fontworks.co.jp/products/evamatisse/). Na planszach tytułowych użyto ciężkiego kroju Ming (Matisse EB) mechanicznie ściśniętego, w parze z wersalikami Helvetiki, i ta para przeszła do interfejsów HUD w serialu.

### Paleta

- Wariant z NERV-UI (ostry, czysty RGB): tło `#000000`, panel `#0A0A0A`/`#1A1A1A`, linie `#333333`, pomarańcz (tekst główny) `#FF9900`, czerwień (alarm) `#FF0000`, zieleń (stan OK, siatki) `#00FF00`, cyjan (dane) `#00FFFF`, magenta (fala B) `#FF00FF`, zieleń LCD `#39FF14`, biel tekstu `#E0E0E0` ([DESIGN_TOKENS](https://github.com/mdrbx/nerv-ui/blob/master/docs/DESIGN_TOKENS.md)).
- Wariant „filmowy” z ckorhonen (przygaszony, bardziej jak celuloid): tło `#0B090B`, panel `#140E0F`, alarm `#8F1507`, ostrzeżenie (cyfry) `#F19E1F`, zieleń sygnałowa `#549F58`, cyjan synchronizacji `#65E6D1`, magenta `#C45484`. Reguły: min. 70% ekranu ciemne, jedna „gorąca” rodzina kolorów na ekran, zieleń i cyjan tylko jako znaczenie, a nie ozdoba ([style-guide](https://github.com/ckorhonen/claude-skills/blob/main/skills/evangelion-design/references/style-guide.md)).
- Moja rekomendacja: wariant filmowy na płaszczyzny, a czyste `#FF9900`/`#00FF00` tylko na cienkie linie i cyfry. Wtedy całość nie wygląda jak strona z 2010 roku.

### Elementy

| # | Element | Wygląd (geometria i kolory) | Dane SpaceDock |
|---|---|---|---|
| B1 | Czerwony pionowy pas z kwadratowymi przyciskami | pas 28–36 px w kolorze `#8F1507` lub `#FF0000` przy lewej krawędzi. Kwadraty 24×24 z czarną cyfrą lub skrótem, aktywny jest czarny z czerwoną ramką. trimad zaleca „cienki czerwony pasek statusu” na krawędzi ([trimad](https://trimad.github.io/prompts/2026-04-23-generative-guidelines-for-nerv-theme/)) | wybór zestawu monitorów: 01 SAM LAPTOP, 02 LAPTOP+DELL, 03 3 MONITORY. Przy podłączonym zestawie mały zielony znacznik „ONLINE” |
| B2 | Nagłówek z ogromną cyfrą konturową | cyfra 120–200 px, tylko kontur 1–1,5 px pomarańczowy, ściśnięta w poziomie (scaleX 0,6–0,7), obok mała etykieta wersalikami z rozstrzeleniem 0,2 em ([DESIGN_TOKENS](https://github.com/mdrbx/nerv-ui/blob/master/docs/DESIGN_TOKENS.md): tytuły z `letter-spacing: -0.04em`, `line-height: 0.85`) | liczba monitorów w bieżącym zestawie (np. „3”) albo numer zestawu |
| B3 | Taśma ostrzegawcza (hazard stripes) | `repeating-linear-gradient(-45deg)`, czerwone i czarne pasy, w NERV-UI przesuwa się co 0,5 s. Wg trimad tylko na małe akcenty i separatory | ramka wokół przycisku „PRZYWRÓĆ” i pasek, gdy status = RÓŻNICA. Ruch wyłącznie podczas przywracania |
| B4 | Kolumna checklisty OK/CHECK | wiersze 9–10 px mono, etykieta po lewej, po prawej blok statusu. W `PhaseStatusStack` siatka `64px / 1fr / 48px`, pasek wysokości 12 px z pomarańczową kreską środkową i podziałką co 7 px (`repeating-linear-gradient(90deg … 6px, rgba(0,0,0,.38) 7px)`). Wypełnienie: ok 100% zielone, warning 68% pomarańcz, danger 48% czerwień, inactive 24% szarość ([PhaseStatusStack.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/PhaseStatusStack/PhaseStatusStack.tsx)) | ustawienia jako lista kontrolna: PRZYWRACANIE AUTO, ZAPIS RĘCZNY, METODA DIRECT, JĘZYK PL, START PRZY LOGOWANIU (włączone = zielony blok „OK”, wyłączone = szary „OFF”) |
| B5 | Stos faz (phase status stack) | jak wyżej, ale wiersze to kolejne kroki | kroki przywracania: WYKRYCIE ZESTAWU, ODCZYT ZAPISU, PORÓWNANIE, RUCHY 1–5, WERYFIKACJA. Każdy wiersz zapala się na zielono po kolei |
| B6 | Splecione fale (sync ratio) | dwie sinusoidy 1,5 px: fala A cyjan `#00FFFF`, fala B magenta `#FF00FF`, każda z `drop-shadow(0 0 3px)` przy 50%. Siatka co 20 px w zieleni przy 12% opacity, oś środkowa 0,6 px przy 25%, opisy osi „+1.0 / 0.0 / −1.0” 8 px ([SyncRatioChart.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/SyncRatioChart/SyncRatioChart.tsx)) | fala A = zapisany układ, fala B = stan bieżący. Gdy się pokrywają, status ZGODNY, a rozjazd fazy wizualizuje RÓŻNICĘ. Spaces jako węzły (kwadraty 6 px) w punktach przecięcia fal |
| B7 | Węzły z etykietami-callout | mały kwadrat lub romb na fali, od niego cienka linia łamana do etykiety w ramce 1 px: nazwa aplikacji wersalikami, pod spodem tytuł okna w mono | każdy Space danego monitora w zapisanej kolejności (oś X = pozycja w kolejności) |
| B8 | Znaczniki „nie zapisany” / „nie otwarty” | węzeł „nie zapisany” to pusty pomarańczowy romb z etykietą „EXTRA”. Węzeł „nie otwarty” to czerwony przekreślony kwadrat z przerywaną linią callout | znaczniki z danych |
| B9 | Pieczątka statusu (status stamp) | wielkie wersaliki krojem wąskim, obrót −12°, ramka podwójna, tło w kolorze przy 7% opacity, np. `#00FF00` z poświatą `rgba(0,255,0,.16)` ([StatusStamp.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/StatusStamp/StatusStamp.tsx)) | ZGODNY / RÓŻNICA / BRAK ZAPISU / NIEPODŁĄCZONY. Pojawia się na ok. 1 s po zapisie lub przywróceniu |
| B10 | Odczyt siedmiosegmentowy | segmenty jako ścieżki SVG z grubością kreski, zgaszone w „ciemnym” odcieniu tego samego koloru (pomarańcz `#FF9900` / duch `#1A1200`), okienko z gradientem `#0A0A0A→#050505`, poświata `0 0 20px` ([SegmentDisplay.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/SegmentDisplay/SegmentDisplay.tsx)) | czas ostatniego przywrócenia `0.29` s |
| B11 | Pasek bloków LCD (sync progress bar) | 20 bloków, progi kolorów: 0–50% cyjan, 50–80% zieleń, 80–95% pomarańcz, 95%+ czerwień migająca ([COMPONENTS.md](https://github.com/mdrbx/nerv-ui/blob/master/docs/COMPONENTS.md)) | postęp przywracania (ruch 3 z 5 = 60%). Po zakończeniu liczba ruchów jako bloki |
| B12 | Pasek strefowy (gradient status bar) | poziomy pasek ze strefami kolorów, podziałką co 7 px i znacznikiem wartości | „odchylenie od zapisu”: 0 = zgodny, strefa żółta = drobne różnice (kolejność), czerwona = brakujące Spaces |
| B13 | Krzyż celowniczy i narożniki | `TargetingContainer`: narożniki w kształcie L, 24 px, cienki krzyż w środku. `TargetingReticle`: okrąg przerywany `8 4`, 36 podziałek, romb w środku, po zablokowaniu czerwień ([TargetingReticle.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/TargetingReticle/TargetingReticle.tsx)) | ramka wokół aktualnie zaznaczonego monitora. „Lock” = monitor gotowy do przywrócenia |
| B14 | Tło heksagonalne | plaster miodu z wielokątów, kreska 0,5 px, `#FF9900` przy opacity 0,08, rozmiar 30 px, pulsuje 4 s ([HexGridBackground.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/HexGridBackground/HexGridBackground.tsx)). Uwaga: ckorhonen odradza heksy jako „tapetę bez funkcji” | tylko pod panelem zestawów albo podczas stanu NIEPODŁĄCZONY, nie na całym oknie |
| B15 | Tryptyk monitorów (surveillance grid) | siatka „kamer”: każda komórka z ID w rogu, znacznikiem czasu, linią skanowania i stanem active/inactive/alert ([SurveillanceGrid.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/SurveillanceGrid/SurveillanceGrid.tsx)) | miniatury monitorów zestawu: ID „MON-01”, nazwa wyświetlacza, liczba Spaces |
| B16 | Baner alarmowy | pełna szerokość, tło czerwone `#FF0000` z czarnym tekstem (lub pomarańczowe dla ostrzeżenia, cyjan dla informacji), pasy ostrzegawcze po bokach, migotanie tekstu ([EmergencyBanner](https://github.com/mdrbx/nerv-ui/blob/master/docs/COMPONENTS.md)) | NIEPODŁĄCZONY / BRAK ZAPISU dla bieżącego zestawu |
| B17 | Terminal | mono, zielony lub pomarańczowy, numery linii, migający kursor blokowy | log przywrócenia: „MOVE 3/5 SAFARI → MON-02 … OK” |
| B18 | Wireframe loader | obracający się ośmiościan (romb z romb wewnątrz i krawędziami głębi) ([WireframeLoader.tsx](https://github.com/mdrbx/nerv-ui/blob/master/src/components/WireframeLoader/WireframeLoader.tsx)) | trwa przywracanie (metoda Drag/Full screen, czyli wolniejsza) |
| B19 | Prom na pasku tytułu | sylwetka w konturze pomarańczowym 1 px. Po kliknięciu wypełnia się, a pod nim pojawia się mała pieczątka „LAUNCH” | easter egg |

### Zasady kompozycji

- Najpierw konstrukcja, potem tekstura. Ramki, linijki, okręgi, paski, maski i krzyże celownicze powinny czytać się zanim pojawi się blask ([ckorhonen](https://skills.sh/ckorhonen/claude-skills/evangelion-design)).
- Jeden moduł jest bohaterem (tu: splecione fale ze Spaces), reszta go wspiera. Duży kontrast skali: ogromna cyfra lub wykres obok etykiet 8–10 px.
- Linie cienkie (0,5–1,5 px), zagnieżdżone ramki, etykiety „przyklejone” do ramki, częste wewnętrzne separatory, mało pustego paddingu ([DESIGN-REFERENCES.md](https://github.com/mdrbx/nerv-ui/blob/master/DESIGN-REFERENCES.md)). Jednocześnie zostawić 1–2 duże puste czarne pola, bo pustka buduje napięcie ([source-signals](https://github.com/ckorhonen/claude-skills/blob/main/skills/evangelion-design/references/source-signals.md)).
- Zero zaokrągleń w podwoziu (`border-radius: 0`). Zaokrąglone mogą być tylko „plakietki” przypięte do obrazu z kamery ([Visual Grammar](https://mdrbx.github.io/nerv-ui/docs/getting-started/visual-grammar/)).
- Typografia: wąski grotesk wersalikami (NERV-UI: Oswald / Barlow Condensed; ckorhonen: IBM Plex Sans Condensed, Archivo Narrow, League Gothic) z rozstrzeleniem 0,2 em, mono na dane (Fira Code / JetBrains Mono / IBM Plex Mono), cyfry tabelaryczne. Szeryf tylko na rzadkich „planszach tytułowych”, nigdy w panelu.
- Ruch mechaniczny: liniowy albo `steps()`, bez sprężyn. Rysowanie linii 80–160 ms, skanowanie 180–320 ms, licznik 40–70 ms na krok, krok drabinki 60–120 ms ([style-guide](https://github.com/ckorhonen/claude-skills/blob/main/skills/evangelion-design/references/style-guide.md)).

### Konwencja gatunku a elementy specyficzne dla franczyzy

- Ogólne (można używać): czarne pole, pomarańcz, czerwień i zieleń jako sygnały, wąskie wersaliki, mono, pasy ostrzegawcze, sinusoidy, krzyże celownicze, siatki, segmentowe LCD, pieczątki statusu, drabinki i kapsuły, wielka cyfra.
- Specyficzne (nie używać): logo z liściem figowym i półliściem, trójkąt z siedmioma oczami, nazwy „MAGI / MELCHIOR / BALTHASAR / CASPER”, trzy-sekcyjny panel głosowania w kolejności znanej z serialu, słowa „PATTERN BLUE”, „ANGEL”, „EVA”, „SYNC RATE”, „A.T. FIELD”, „Entry plug”, „Third Impact”, napisy „REFUSED”, krój Matisse EB lub jego bezpośrednia imitacja w układzie L-kształtnym, monolity z numerami „SOUND ONLY”, czcionki z tytułu serialu. W NERV-UI to są komponenty `MagiSystemPanel`, `SeeleMonolith`, `PatternAlert`, `PilotCard` (pomijamy je w całości).
- Nasze nazwy zamiast tych z serialu: „WSPÓŁCZYNNIK ZGODNOŚCI” zamiast „sync ratio”, „FAZA” zamiast „pattern”, „DOK” zamiast „cage”.

### Czego unikać

- Fioletowych gradientów, glassmorphizmu, miękkich rozmyć, sprężystego ruchu ([ckorhonen](https://skills.sh/ckorhonen/claude-skills/evangelion-design)).
- Wszystkiego, co świeci naraz, a także „zwykłego neonowego cyberpunka” (tęczowe gradienty, fiolet z cyjanem).
- Pastelowych i beżowych palet, pigułkowych przycisków, dużych gładkich gradientów, „kół i bokeh” ([trimad](https://trimad.github.io/prompts/2026-04-23-generative-guidelines-for-nerv-theme/)).
- Gładkich „analitycznych” wykresów kołowych i wskaźników jak z SaaS, kart z dużą ilością powietrza, ściętych narożników użytych wszędzie jako trik, grubych ramek bez wewnętrznej struktury ([DESIGN-REFERENCES.md](https://github.com/mdrbx/nerv-ui/blob/master/DESIGN-REFERENCES.md)).
- Koloru jako jedynego nośnika statusu. Zawsze dodać słowo albo kształt (np. „OK” / „DIFF”).

---

## C. „Radar dokowania”

### Źródła

- Radar PPI (plan position indicator): koncentryczne pierścienie zasięgu w stałych odstępach zależnych od skali, namiar odczytywany od linii odniesienia u góry ekranu, długa poświata luminoforu, która trzyma obraz między obrotami anteny ([EngineerFix: PPI](https://engineerfix.com/how-a-plan-position-indicator-works/), [NEETS Module 18](https://rfcafe.com/references/electrical/neets-modules/NEETS-Module-18-3-1-3-10.htm)). Luminofor P7 to klasyczny długopoświatowy luminofor radarowy (niebiesko-biały błysk z żółto-zielonym powidokiem).
- Symulator dokowania Crew Dragon: odczyty przechyłu, pochylenia, odchylenia i odległości. Zielone liczby to potrzebne korekty, niebieskie to prędkości. Prędkość zbliżania w prawym dolnym rogu, dokowanie udane, gdy wszystkie korekty spadną poniżej 0,2 ([space.com](https://www.space.com/spacex-crew-dragon-docking-simulator-online.html), [iss-sim.spacex.com](https://iss-sim.spacex.com/)).
- RPOP (Space Shuttle): laptopowy program pokazujący graficznie ruch względny „ścigającego” i celu, z trajektorią przeszłą, bieżącą i przewidywaną nałożonymi na jeden wykres. Część koncepcji RPOP stała się minimalnym standardem dla wyświetlaczy nadzoru zbliżenia ([NTRS 20110012267](https://ntrs.nasa.gov/citations/20110012267), [NTRS 20130003242](https://ntrs.nasa.gov/citations/20130003242)).
- Kurs / TORU: pomiar odległości, prędkości i orientacji. Na ISS format „Rendezvous” pokazuje prędkość kątową, odległość, prędkość zbliżania, tryb sterowania orientacją i status systemu Kurs ([Wikipedia: Kurs](https://en.wikipedia.org/wiki/Kurs_(docking_navigation_system)), [orbiter-forum](https://www.orbiter-forum.com/threads/kurs-docking-system-video-display.28092/)).
- Space Shuttle MEDS: szklany kokpit, w formatach ostrzeżeń czerwień = warning, żółć = caution, cyjan = brak danych. Formaty skopiowano 1:1 ze starych wyświetlaczy z lat 70. ([NASA CAU / MEDS](https://ntrs.nasa.gov/api/citations/20030053052/downloads/20030053052.pdf), [Aviation Week](https://aviationweek.com/space/archives-space-shuttles-new-glass-cockpit)). Osłony przełączników stosuje się tam, gdzie przypadkowe przełączenie byłoby nieodwracalne ([NTRS 19850021661](https://ntrs.nasa.gov/api/citations/19850021661/downloads/19850021661.pdf)).
- FUI: Territory Studio przy *The Martian* (ok. 400 ekranów, konsultacje z NASA i ESA) wyszło od zasady „każdy ekran ma jasny cel”, z jasnym niebiesko-zielono-białym na czerni i wyraźną siatką ([Territory: The Martian](https://territorystudio.com/project/the-martian/), [VFX World](https://d1xfgk3mh635yx.cloudfront.net/vfxworld/interfacing-mars-territory-studio-and-martian)). GMUNK przy *Oblivion*: wszystkie elementy zawieszone na siatce punktów, czerwień tylko dla alarmów ([HUDS+GUIS: Oblivion](https://www.hudsandguis.com/2013/05/02/oblivion-interface-design/), [Fuzzy Math](https://fuzzymath.com/blog/evaluating-interface-design-of-oblivion), [gmunk.com](https://gmunk.com/OBLIVION-GFX)).

### Paleta (propozycja)

Tło `#03080A` (czarny z odcieniem morskim), siatka `#0E3A3A` przy 40%. Turkus (dane, pierścienie, statki) `#19F0D0`, magenta (cel, porty, trajektoria przewidywana) `#FF2FA0`, żółć (ostrzeżenia, aktywny wybór) `#FFD23A`. Semantyka w duchu MEDS: czerwień `#FF3B30` = alarm, żółć = ostrzeżenie, cyjan/turkus = brak danych (przerywana linia).

### Elementy

| # | Element | Wygląd | Dane SpaceDock |
|---|---|---|---|
| C1 | Tarcza radaru | okrąg główny 1,5 px turkus, 4–5 pierścieni zasięgu 0,5 px przy 35%, opisane małymi cyframi przy osi pionowej, pierścień namiarowy na zewnątrz z kreskami co 5° i cyframi co 30° | cały bieżący zestaw monitorów |
| C2 | Stacja w środku | wektorowa sylwetka stacji złożona z prostokątnych modułów, jeden moduł na monitor, proporcje jak rozdzielczość monitora | zestaw monitorów; podpis pod spodem „LAPTOP + DELL / PODŁĄCZONY” |
| C3 | Porty dokujące | na końcu każdego modułu prostokątny port z magentowymi nawiasami i numerem (P1, P2, P3) | jeden port na monitor |
| C4 | Statki w kolejce (kolejka podejścia) | małe trójkątne lub „pociskowe” znaczniki turkusowe ustawione w linii na promieniu prowadzącym do portu. Najbliżej portu jest Space nr 1 | Spaces danego monitora w zapisanej kolejności. Etykieta: nazwa aplikacji wersalikami, pod nią tytuł okna mono 9 px |
| C5 | Typy statków | aplikacja = wypełniony trójkąt, biurko = pusty kwadrat (ten sam rozmiar) | rodzaj Space |
| C6 | Znacznik „nie zapisany” | żółty romb poza kolejką, z migającą kropką i etykietą „NIEZNANY / NIE ZAPISANY” | dodatkowy Space, który jest teraz na pasku |
| C7 | Znacznik „nie otwarty” | turkusowy przerywany kontur statku w jego miejscu w kolejce, bez wypełnienia, z napisem „BRAK SYGNAŁU” (konwencja MEDS: cyjan = brak danych) | Space zapisany, ale go nie ma |
| C8 | Wiązka skanująca | klin z gradientem kątowym od 0% do 25% turkusu, linia czołowa 1 px. Za nią statki „gasną” z długą poświatą jak P7 | animacja podczas porównywania zapisu z bieżącym stanem |
| C9 | Trajektoria podejścia | linia ciągła = przebyta droga, punktowana magenta = przewidywana (jak w RPOP: przeszła, bieżąca i przewidywana na jednym wykresie) | podczas przywracania: droga każdego ruchu Space do docelowego portu |
| C10 | Odczyt odległości i prędkości zbliżania | kolumna liczb mono w rogach tarczy: zielona korekta, niebieska prędkość, jak w symulatorze Dragona | „RÓŻNICE: 2”, „RUCHY: 5”, „CZAS: 0,29 S” |
| C11 | Kasety zestawów na dole | rząd 3–4 prostokątnych „kartridży” z etykietą jak na taśmie, wycięciem u góry i diodą. Włożony (aktywny) jest wsunięty niżej i podświetlony | lista zestawów monitorów. Podłączony zestaw ma zieloną diodę, pozostałe zgaszoną |
| C12 | Suwaki pionowe po prawej | 4–5 wąskich torów z podziałką, gałka prostokątna z kreską. Suwak trójpozycyjny ma zapadki opisane z boku | przywracanie RĘCZNE/AUTO, zapis RĘCZNY/AUTO, metoda DRAG / FULL / DIRECT (3 pozycje), język |
| C13 | Checklista po lewej | lista wierszy z kwadracikiem stanu po lewej: ✓ zielony, — szary, ! żółty | „ZESTAW WYKRYTY”, „ZAPIS ISTNIEJE”, „KOLEJNOŚĆ ZGODNA”, „WSZYSTKIE SPACES OBECNE”, „START PRZY LOGOWANIU” |
| C14 | Panel lampek (annunciator) | siatka 2×2 prostokątnych lampek z napisem, zgaszone ciemnoszare, zapalone pełnym kolorem (czerwień = warning, żółć = caution, jak w MEDS) | status: ZGODNY / RÓŻNICA / BRAK ZAPISU / NIEPODŁĄCZONY |
| C15 | Przyciski z osłoną | „ZAPISZ UKŁAD” i „PRZYWRÓĆ” pod przezroczystą, odchylaną osłoną z pasami ostrzegawczymi (osłony stosuje się dla akcji trudno odwracalnych) | zapis nadpisuje poprzedni układ, więc osłona ma sens. „Przywróć” bez osłony albo z jasną |
| C16 | Celownik dokowania (widok z portu) | mały kwadratowy podgląd: krzyż w środku, okrąg tolerancji, wskaźnik odchyłki | po wybraniu monitora: czy pierwsza pozycja w kolejce jest „w osi” (zgodna z zapisem) |
| C17 | Siatka punktów w tle | punkty co 8 px przy 15%, na niej zawieszone wszystkie moduły (zasada siatki z *Oblivion*) | struktura, nie dane |
| C18 | Prom na pasku tytułu | mały prom wektorowy, po kliknięciu wylatuje na tarczę i dokuje w porcie P1 | easter egg |

### Zasady kompozycji

- Tarcza radaru jest bohaterem i zajmuje 50–60% okna. Lewy pas = checklista, prawy pas = suwaki, dolny pas = kasety zestawów. Pasy są wąskie i gęste, a tarcza ma dużo czarnego powietrza wokół pierścieni.
- Trzy kolory, trzy role: turkus = to, co jest (stan bieżący i Spaces), magenta = to, co ma być (porty, zapis, trajektoria przewidywana), żółć = to, co wymaga uwagi. Czerwień tylko do alarmu.
- Każdy ekran ma jasny cel, a dane są realistyczne. FUI ze studiów filmowych bierze wiarygodność z prawdziwych źródeł NASA, a nie z ozdobników.
- Ruch: wiązka skanu z długą poświatą, statki przesuwają się skokowo po promieniu, odczyty liczą w dół. Bez sprężyn.
- Typografia: monospace o technicznym charakterze (np. JetBrains Mono, IBM Plex Mono) na odczyty, wąski grotesk (DIN Condensed, Barlow Condensed) wersalikami na etykiety, cyfry tabelaryczne.

### Czego unikać

- Tarczy jako dekoracji bez danych (obracający się „radar” z losowymi kropkami). Każdy znacznik to prawdziwy Space.
- Wielokolorowych tęczowych neonów i hologramów 3D w stylu kina superbohaterskiego.
- Fotorealistycznych statków, zdjęć ISS, emblematów NASA, SpaceX czy logo misji, a także krojów i układów z prawdziwych kokpitów 1:1 (bierzemy zasady, nie grafikę).
- Gwiezdnego tła z mgławicą. Czerń z siatką wystarczy.

---

## Wspólne wnioski

1. Wszystkie trzy koncepcje stoją na tym samym: czarne lub ciemne pole, cienkie linie, wersaliki w wąskim kroju i mono, cyfry tabelaryczne, świeci tylko to, co aktywne.
2. Różnią się materiałem: A to płaski kolor jak farba na celuloidzie i grafika wektorowa CRT, B to precyzyjne linie i pieczątki statusu na czerni, C to luminofor radaru i sprzęt kokpitu (osłony, lampki, kasety).
3. Status zawsze zdublowany słowem albo kształtem, nie tylko kolorem. Ruch wyłączany przy `prefers-reduced-motion`.
4. Żadnych logotypów, postaci, nazw ani dosłownych napisów z franczyz. Wszystkie etykiety piszemy sami, na podstawie danych SpaceDock.
