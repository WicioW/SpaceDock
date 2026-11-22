# SpaceDock: ukryty wygląd „R" — specyfikacja do wdrożenia

Wybrany kierunek po kilkunastu iteracjach na płótnie. Kontekst i wcześniejsze założenia:
`docs/design-brief.md`, `docs/design-research.md`.

## Źródło prawdy

- `docs/design/R-panel.dc.html` — pełny, działający prototyp panelu (HTML + inline CSS + logika
  w klasie `Component` na dole pliku). Wymiary, kolory, geometria wstęgi i reguły stanów są tam
  dokładne. Czytaj go jak specyfikację, nie jak kod do przeniesienia 1:1.
- Płótno z renderem (prywatne, właściciel ma dostęp):
  https://claude.ai/artifact/HijQ8vWRWEvwQM1QqY5ALy — rząd „R", artboardy R1, R2 i dwa motywy.
- Prototyp ma rozmiar stały 1100 × 700. Zachowanie przy innych rozmiarach okna **nie jest
  zaprojektowane** (patrz „Otwarte kwestie").

## Jak się włącza

- Wygląd jest ukryty. Odblokowuje go istniejący easter egg: 10 szybkich kliknięć w wahadłowiec
  w wierszu tytułu (`Sources/ShuttleEgg.swift`, użyty w `Sources/App.swift`).
- Zwykły wygląd apki zostaje bez zmian i ma dalej działać.
- **Motyw kolorów (1–3) wybiera się w ustawieniach apki, nie na panelu.** Na panelu nie ma
  żadnej kontrolki motywu.

## Układ (1100 × 700)

Wiersz tytułu 30 px: trzy kółka okna, „SPACEDOCK", na środku wahadłowiec (kontur 1 px).

Pod nim, z marginesem 12/14 px, dwie kolumny: główna 794 px i szyna 264 px, odstęp 14 px.

Kolumna główna, od góry:

1. **Nagłówek, 96 px.**
   - Numer wybranego zestawu, konturowy, 76 px; pod nim pas ukośny 12 px.
   - Blok 配置: znak, pionowy pas ukośny, trzy wiersze mono (`ZESTAW`, `MONITORY`, `接続中`),
     pod spodem nazwa zestawu (do dwóch wierszy; 15 px, a powyżej 22 znaków 13 px).
   - Status: pasek „UWAGA" z liczbą różnic, pod nim zamknięta ramka z polem znaku (相違 / 一致 /
     復元) i słowem (RÓŻNICA / ZGODNY / PRZYWRACANIE) z podpisem.
   - Plaster zestawów: heksy 40 × 32 px, pięć w rzędzie, do 10 zestawów w dwóch rzędach.
     W heksie tylko numer.
2. **Strefa monitora, 320 px.**
   - Zakładki monitorów zestawu, 26 px. Jedna na monitor: nazwa, liczba przestrzeni, stan.
   - Pasek szczegółów, 22 px: numer, pełna nazwa aplikacji, tytuł okna, numer okna, stan.
   - Kafelki przestrzeni wybranego monitora: siatka, min. 124 px szerokości, wysokość 40 px,
     belka pochylona o 5°. Przy większej liczbie strefa przewija się w pionie.
   - Pole połączeń (min. 66 px, zajmuje resztę): rząd „ZAPIS 保存", rząd „TERAZ", linie między
     nimi, po prawej dwa słupki z liczbami.
3. **Baner różnicy, 18 px.** Przewijany tekst, po bokach pasy ukośne jadące w przeciwne strony.
4. **Wstęga, reszta wysokości.** Nagłówek „一致率 WSPÓŁCZYNNIK ZGODNOŚCI n/m · p%", wykres
   138 px, pod nim skala pozycji.

Szyna, od góry: lista zestawów (wiersz 19 px: numer, pełna nazwa, liczba przestrzeni),
ustawienia, pasek odchylenia (ZGODNY / NADMIAR / BRAKI), dziennik (3 wiersze), „Zapisz obecny
układ" pod osłoną, „Przywróć".

## Zasada: jeden monitor naraz

- Wybierasz zestaw (plaster albo lista w szynie), potem monitor (zakładka).
- Kafelki, pole połączeń i wstęga pokazują **tylko wybrany monitor**.
- Status, współczynnik zgodności, baner i pasek odchylenia dotyczą **całego zestawu**.
- Domyślnie wybrany jest pierwszy monitor z różnicą; gdy wszystko zgodne, pierwszy.
- W trakcie przywracania widok przechodzi na monitor, na którym trwa ruch.

## Znaczenie kolorów

Pięć ról, takie same we wszystkich motywach:

| Rola | Gdzie |
|---|---|
| Ramki i „zapis" | obramowania, numer zestawu, wiązka zapisu, komórki „zapis" |
| Zgodne i „teraz" | kafelki zgodne, wiązka stanu, wybrane pozycje, „Przywróć" |
| Opisy | tekst etykiet i danych |
| Nadmiar | przestrzeń nie zapisana (jest na pasku, brak w zapisie) |
| Błąd | przestrzeń nie otwarta albo nie na pełnym ekranie |

Tym samym kolorem malują się: blok statusu, baner, zakładka monitora, kafelek, etykieta na
wstędze, pasek odchylenia. Gdy w zestawie są i braki, i nadmiar, status bierze kolor błędu.

Stan zawsze ma też słowo i kształt, nie tylko kolor:

| Stan | Kafelek | Węzeł na wstędze |
|---|---|---|
| aplikacja zgodna | pełna belka | pełny kwadrat |
| biurko zgodne | belka z samym konturem | pusty kwadrat |
| nie zapisana | belka w kolorze nadmiaru, numer „+" | romb |
| nie otwarta | kontur 1,5 px + ruchome ukośne paski | pusty kwadrat w kolorze błędu |
| nie na pełnym ekranie | kontur 2 px + ruchome ukośne paski | pusty kwadrat w kolorze błędu |
| w ruchu (przywracanie) | belka w kolorze opisów | pełny kwadrat w kolorze opisów |

## Trzy motywy

Tło wszędzie `#000000`. Tekst na wypełnionych polach wszędzie `#000000`.

| Motyw | Ramki / zapis | Zgodne / teraz | Opisy | Błąd | Nadmiar |
|---|---|---|---|---|---|
| 1 (domyślny) | `#9B6CFF` | `#B4FF39` | `#D9C9FF` | `#FF3B30` | `#FFD60A` |
| 2 | `#FF3FB4` | `#3FF0FF` | `#D6F7FF` | `#FF4A1C` | `#FFD60A` |
| 3 | `#FF2A2A` | `#5CF0B0` | `#FF8A1E` | `#FFFFFF` | `#4DA6FF` |

Paski na kafelkach z błędem: kolor błędu z przezroczystością ok. 30%.

## Wstęga

- Dwie wiązki po 9 linii: „zapis" i „teraz", w przeciwfazie. Przecinają się w węzłach.
- Jeden węzeł na przestrzeń wybranego monitora, rozłożone równo na całej szerokości.
- Przy różnicy wiązka omija węzeł: nie zapisana odgina wiązkę zapisu, brak odgina wiązkę stanu.
- Gdy węzłów jest mało, fala robi między nimi dodatkowe przecięcia (pół okresu ok. 80 px).
- Etykiety na zmianę nad i pod wstęgą. Powyżej 10 węzłów zgodne mają sam numer; różnice mają
  numer, nazwę i krótkie słowo (NOWA / BRAK / OKNO).
- Krzyżyki „+" stoją nad lub pod węzłem po stronie przeciwnej niż jego numer, na wysokości
  numerów. Przy węźle sąsiadującym z różnicą krzyżyka nie ma.
- Dokładna matematyka: funkcje `line`, `bundle` i budowa `nodes` w prototypie.

## Pole połączeń

- Górny rząd: przestrzenie w kolejności zapisu. Dolny rząd: przestrzenie obecne teraz.
- Linia łączy tę samą przestrzeń w obu rzędach.
- Brak w „teraz": krótka urwana linia od góry w kolorze błędu.
- Nadmiar: krótka urwana linia od dołu w kolorze nadmiaru.
- Słupki po prawej: liczba w zapisie i liczba teraz, skalowane do większej z dwóch.

## Zachowania

- **Plaster i lista zestawów:** klik wybiera zestaw do podglądu. Podłączony zestaw jest
  wyróżniony; jego heks miga.
- **Zakładki monitorów:** klik wybiera monitor.
- **Pasek szczegółów:** po najechaniu na kafelek pokazuje jego pełne dane. Bez najechania
  pokazuje pierwszą różnicę na monitorze.
- **Zapisz obecny układ:** pod osłoną. Pierwszy klik podnosi osłonę, drugi zapisuje. Zapis
  nadpisuje poprzedni.
- **Przywróć:** wypełniony, gdy jest różnica; sam kontur, gdy układ zgodny; w trakcie pokazuje
  „PRZYWRACANIE" i numer ruchu.
- **Ustawienia w szynie** (te same co w zwykłym wyglądzie): przywracanie ręcznie/auto, zapis
  ręcznie/auto, metoda (przeciąganie / pełny ekran / bezpośrednio; przeciąganie przekreślone
  i nieaktywne bez Karabinera), język PL/EN/ES/ZH, uruchamiaj przy logowaniu, stan automatu
  i uprawnienia.

## Ruch

Wszystko jest proste i skokowe, bez sprężyn. Przy systemowym „Ogranicz ruch" cały ruch staje.

| Element | Ruch |
|---|---|
| Strefy okna | odsłaniają się po kolei przy otwarciu, 0,6 s, 8 kroków |
| Wstęga | amplituda „oddycha" (0,72–1,0), krok co ok. 140 ms; węzły stoją |
| Wstęga | jasny impuls biegnie po linii środkowej, 3,2 s |
| Wstęga | pionowy skaner przejeżdża przez wykres, 7 s |
| Pole połączeń | linie płyną (przesuw kreski), słupki drgają |
| Pasy ukośne | przesuw; pod numerem, obok 配置 i w banerze tylko przy różnicy lub przywracaniu |
| Osłona zapisu, kafelki z błędem | pasy przesuwają się stale |
| Status | pasek „UWAGA" i pole znaku migają twardo co 1,2 s; ramka nie miga |
| Heks podłączonego zestawu | miga jak status |
| Baner | tekst przewija się w lewo, 26 s na pętlę |
| Dziennik | tekst pisze się znak po znaku |

## Dane w prototypie, które są przykładowe

- Sześć pierwszych zestawów to prawdziwe zestawy użytkownika; siódmy (z U2720Q) jest zmyślony,
  żeby pokazać 4 monitory.
- 20 przestrzeni na DELL-u, ich nazwy, tytuły i numery okien są zmyślone.
- Czas „0,29 s", „5 ruchów" i wiersze dziennika to przykłady. W apce mają pochodzić
  z prawdziwego ostatniego ułożenia.
- Blok „OŚ PORTU" i radar z wcześniejszych kierunków **nie wchodzą** do R.

## Otwarte kwestie

- ✅ **Rozmiar okna.** Poniżej 1100 × 700 cały panel skaluje się proporcjonalnie (do 780 × 420);
  większe okno daje miejsce strefie monitorów.
- ✅ **Więcej niż 7 zestawów.** Lista w szynie przewija się od 8. zestawu; plaster w nagłówku
  pokazuje 10 pierwszych.
- ✅ **Znaki japońskie.** 設定 (ustawienia), 方式 (metoda), 言語 (język), 偏差 (odchylenie),
  一致率 (współczynnik zgodności), 起動 (uruchamianie), 監視 (nadzór) to zwykłe japońskie słowa
  w tym znaczeniu (sprawdził Claude, nie rodzimy użytkownik języka).
- ✅ **Motyw 3:** nadmiar niebieski `#4DA6FF` zamiast żółtego, który zlewał się z pomarańczowymi
  opisami.
- **Samoczynne przewijanie długich nazw w kafelku** nie jest zrobione; pełną nazwę pokazuje
  pasek szczegółów.
