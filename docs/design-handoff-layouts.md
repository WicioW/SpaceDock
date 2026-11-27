# SpaceDock: kilka układów na zestaw monitorów — specyfikacja wyglądu

Decyzje użytkownika z 2026-11-25: zwykły wygląd = **LA** (drzewko w pasku bocznym), panel =
**QA** (drzewko w szynie pod wybranym zestawem), dziennik w szynie skrócony do 1 wiersza.
Zachowanie (co robi Zapisz, Przywróć, podgląd, skróty): sekcja „Zachowanie” na końcu pliku
(do 2026-11-27 w `TODO.md`). Reszta pliku opisuje wygląd.

## Źródło prawdy

Prototypy w `docs/design/layouts/` (kopie z płótna
https://claude.ai/artifact/HijQ8vWRWEvwQM1QqY5ALy, rzędy „L”, „RL”, „RQ”):

| Plik | Co pokazuje |
|---|---|
| `LA1.dc.html` | zwykły wygląd, wybrany układ na ekranie |
| `LA2.dc.html` | zwykły wygląd, podgląd innego układu |
| `LA3.dc.html` | zwykły wygląd, układ bez nazwy (po aktualizacji) |
| `LD.dc.html` | zwykły wygląd, okna: nowy układ, pierwszy zapis, usuwanie, menu, zmiana nazwy |
| `LS.dc.html` | okno Ustawień: Ogólne i Skróty |
| `LM.dc.html` | menu w pasku menu |
| `RQA1.dc.html` | panel, wybrany układ na ekranie |
| `RQA2.dc.html` | panel, podgląd innego układu |
| `RQA3.dc.html` | panel, układ bez nazwy |
| `RLD.dc.html` | panel, okna: nowy układ, pierwszy zapis, usuwanie, menu, zmiana nazwy |
| `RVA.dc.html` | panel, komunikat przy przywracaniu: blok stanu (polecany) |
| `RVB.dc.html` | panel, komunikat przy przywracaniu: taśma |
| `RVC.dc.html` | panel, komunikat przy przywracaniu: wiersz konsoli |
| `RUA1.dc.html` | panel, szyna bez ustawień, przycisk w górnym pasku (polecany) |
| `RUB1.dc.html` | panel, szyna bez ustawień, wiersz ustawień nad akcjami |
| `RUC1.dc.html` | panel, szyna bez ustawień, przycisk w nagłówku „ZESTAWY” |
| `RUW1.dc.html` | panel, okno ustawień otwarte, wszystko w porządku |
| `RUW2.dc.html` | panel, okno ustawień otwarte, brak uprawnienia i Karabinera |

Pliki `L*.dc.html` i `RLD.dc.html` to statyczny HTML (wymiary i kolory w `<style>` i w atrybutach
`style`). Pliki `RQA*.dc.html` to pełny prototyp panelu z logiką w klasie `Component`; nowe rzeczy
znajdziesz po `lay.`, `k.open`, `css2`, `EDGE`, `sv.`, `pv`. Makiety zwykłego wyglądu są w ciemnym
wyglądzie systemu; kolory to systemowe akcent / zielony / pomarańczowy / czerwony, więc jasny
wygląd wynika z nich sam.

## Pojęcia i trzy stany wiersza układu

- **Oglądany:** układ, którego kafelki widać w oknie. Zawsze dokładnie jeden.
- **Na ekranie (wybrany):** układ ostatnio przywrócony albo utworzony. Najwyżej jeden na zestaw.
- **Zwykły:** pozostałe.

„Oglądany” i „na ekranie” to osobne znaki, bo mogą dotyczyć dwóch różnych wierszy naraz
(podgląd) albo tego samego (zwykła praca).

## Zwykły wygląd (LA)

### Pasek boczny

- Zestaw monitorów jest wierszem z trójkątem rozwijania (▶ / ▼, 9 pt, kolor drugorzędny) przed
  ikoną. Podpis pod nazwą: „3 układy · 7 przestrzeni”. Znaczki „TERAZ” i trójkąt ostrzegawczy
  zostają jak dziś.
- Rozwinięty zestaw pokazuje pod sobą wiersze układów, wcięte o 30 pt względem wiersza zestawu.
  Podłączony zestaw jest rozwinięty domyślnie; pozostałe zwinięte.
- Wiersz układu, wysokość min. 28 pt, promień 6 pt, od lewej:
  - numer pozycji (cyfry tabelaryczne, kolor drugorzędny, szerokość 14 pt, do prawej),
  - nazwa (ucinana wielokropkiem),
  - zielone kółko z białym ptaszkiem 14 pt, tylko przy układzie na ekranie,
  - skrót, np. `⌃⌥1` (11 pt, kolor trzeciorzędny). Tylko przy układach podłączonego zestawu
    i tylko dla pozycji 1–9; układy innych zestawów nie mają skrótu.
- Oglądany: zwykłe zaznaczenie listy (tło akcentu, biały tekst). Zielony ptaszek jest niezależny
  od zaznaczenia.
- Ostatni wiersz pod układami: „+ Zapisz jako nowy…” (kolor drugorzędny). To jedyne miejsce tej
  akcji w oknie; w nagłówku nie ma czwartego przycisku.
- Bez nazwy (po aktualizacji): w miejscu nazwy pole tekstowe z podpowiedzią „Nadaj nazwę”;
  numer, ptaszek i skrót bez zmian. Nic nie jest zablokowane.
- Zmiana kolejności: przeciąganie wierszy w obrębie zestawu. Numery i skróty przeliczają się od
  razu.

### Część szczegółów

- Tytuł (title2 bold) = nazwa oglądanego układu; „Bez nazwy” kolorem drugorzędnym, gdy jej nie ma.
- Kapsułka obok tytułu: zielona „NA EKRANIE” (jak „TERAZ”: 10 pt bold, biały tekst) albo
  „PODGLĄD” (11 pt bold, tekst i obwódka 1 pt w kolorze akcentu, bez wypełnienia).
- Pod tytułem: status jak dziś (pomarańczowy trójkąt + „Obecny układ jest inny niż zapis”
  albo szare „Układ zgodny z zapisem”); w podglądzie nazwa zestawu kolorem drugorzędnym.
- Przyciski po prawej: „Zapisz” · „Przywróć” · „Przywróć z brakującymi”.

### Podgląd

- Pod nagłówkiem baner: ikona oka, tekst „Oglądasz zapisany układ **„Wieczór”**. Na ekranie jest
  **„Praca”**. Kolory pokazują, czym różni się od ekranu.”, po prawej link „Wróć do „Praca””.
  Tło: akcent 18%, obwódka 1 pt: akcent 55%, promień 8 pt, odstępy 8/12 pt.
- „Zapisz” wyszarzony (krycie 0,35); podpowiedź: zapis działa tylko na układ na ekranie.
- „Przywróć” dostaje styl przycisku głównego (wypełnienie akcentu).
- Układ innego, niepodłączonego zestawu: baner ten sam, oba „Przywróć” wyszarzone.
- Kafelki bez zmian: czerwony brak, żółty przestawione, niebieski nie zapisane.

### Okna (`LD.dc.html`)

- **Zapisz jako nowy:** tytuł „Zapisz obecny układ jako nowy”, pole nazwy z podpowiedzią
  „np. Praca”, [Anuluj] [Zapisz]. „Zapisz” nieaktywny przy pustym polu i przy zajętej nazwie.
  Zajęta nazwa: czerwony podpis „Ten zestaw ma już układ „Praca”.”
- **Pierwszy zapis na nowym zestawie:** to samo okno, tytuł „Nazwij pierwszy układ tego zestawu”,
  wiersz „<zestaw> nie ma jeszcze żadnego układu.”
- **Usuwanie:** „Usunąć układ „Wieczór”?”, „Tego nie da się cofnąć. „Prezentacja” przejdzie
  z pozycji 3 na 2 i dostanie skrót ⌃⌥2.”, [Anuluj] [Usuń] (czerwony). Zdanie o przesunięciu tylko
  wtedy, gdy za usuwanym są inne układy.
- **Menu pod prawym przyciskiem na układzie:** Przywróć · Przywróć z brakującymi · — ·
  Zmień nazwę… · Usuń układ… (czerwony).
- **Zmiana nazwy:** w miejscu, w wierszu listy. Enter zatwierdza, Esc anuluje. Pusta albo zajęta
  nazwa: pole w czerwonej ramce, Enter nie działa.

### Ustawienia (`LS.dc.html`)

- **Ogólne**, nowy wiersz „Apki spoza układu”: przełącznik [Zostaw | Schowaj], pod nim opis:
  „Schowaj: przy każdym przywróceniu apki pełnoekranowe spoza układu wychodzą z pełnego ekranu
  i są minimalizowane. Automat schowa też świeżo otwartą, niezapisaną apkę. Apek nigdy nie
  zamykamy.”
- **Skróty**, nowa sekcja „Układy” pod trzema istniejącymi skrótami:
  - „Skróty układów”: pole nagrywania samego modyfikatora (np. `⌃⌥`) i tekst „+ numer 1–9”,
  - „Skrót układu”: dwa przyciski radiowe „tylko przestawia przestrzenie” / „przywraca
    z brakującymi apkami”,
  - objaśnienie: „Numer to pozycja układu na liście obecnego zestawu: ⌃⌥1 pierwszy, ⌃⌥2 drugi.
    Numer bez układu daje sygnał dźwiękowy.”
- **Samo ⌘:** pomarańczowy trójkąt i tekst „⌘1–9 przełącza karty w przeglądarkach i okna
  w IntelliJ. SpaceDock przejmie te skróty we wszystkich apkach. Dodaj ⌃ albo ⌥.” Ostrzega,
  nie blokuje.

### Menu w pasku menu (`LM.dc.html`)

Po wierszu „Teraz: …”: nagłówek „Układy”, wiersze układów obecnego zestawu (ptaszek przy układzie
na ekranie, skrót po prawej; klik = przywróć jak skrót). Niżej: Pokaż okno · Przywróć ·
Przywróć z brakującymi · Zapisz „Praca” (z nazwą nadpisywanego układu) · Zapisz jako nowy… ·
reszta jak dziś. Zestaw bez układów: zamiast listy tylko „Zapisz jako nowy…”.

## Panel (QA)

Role kolorów jak w `docs/design-handoff.md`: `th.s` ramki i zapis, `th.k` zgodne i teraz,
`th.t` opisy, `th.e` błąd. Układ to zapis, więc jego zaznaczenie jest w `th.s`; „na ekranie”
to „teraz”, więc jest w `th.k`.

### Szyna: drzewko pod wybranym zestawem

- Pod wierszem wybranego zestawu w liście ZESTAWY stoi blok układów: margines 2 / 0 / 3 / 9 pt,
  wcięcie treści 9 pt, z lewej pionowa kreska 1,5 pt `th.s`. Wiersze co 2 pt.
- Wiersz układu: wysokość 19 pt, odstępy wewnętrzne 0 / 6 pt, elementy co 6 pt:
  - numer `01` (Orbitron 700, 10 pt),
  - nazwa (Chakra Petch 700, 11 pt, odstęp liter 0,03 em, ucinana wielokropkiem),
  - znaczek 現: kwadrat 14 × 14 pt, ramka 1 pt w kolorze tekstu, znak 10 pt (Hiragino Mincho
    900), mruga twardo co 1,2 s jak heks podłączonego zestawu. Tylko przy układzie na ekranie,
  - skrót `⌃⌥1` (JetBrains Mono 500, 10 pt).
- Kolory wiersza:

  | Stan | Ramka 1 pt | Tło | Tekst |
  |---|---|---|---|
  | oglądany | `th.s` | `th.s` | `#000000` |
  | na ekranie, nie oglądany | `th.k` | `#000000` | `th.k` |
  | zwykły | `th.s` | `#000000` | `th.t` |

  Układ oglądany i jednocześnie na ekranie jest wypełniony `th.s` i ma znaczek 現.
- Ostatni wiersz bloku: „+ 新規 ZAPISZ JAKO NOWY”, 19 pt, ramka przerywana 1 pt `th.s`,
  tekst `th.s`.
- Bez nazwy: w miejscu nazwy pole 15 pt wysokości z ramką przerywaną 1 pt w kolorze tekstu,
  napis „NADAJ NAZWĘ” i mrugający kursor ▮ (1 s, jak w dzienniku).
- Najechanie na wiersz: pełna inwersja jak w reszcie panelu.
- Zmiana kolejności: przeciąganie wierszy w pionie.

### Szyna: miejsce

- Lista ZESTAWY (zestawy razem z blokiem układów) ma stałą wysokość ok. 149 pt i przewija się
  w pionie; wybrany zestaw i jego układy są zawsze przewinięte do widoku. Przy 3 układach widać
  wybrany zestaw, jego blok i 2 kolejne zestawy; przy 1 układzie 4 kolejne. (W prototypie
  odpowiada temu `railSets: sets.slice(0, n)`.)
- Dziennik: 1 wiersz zamiast 3 (ostatni wpis, np. „> OSTATNIO: 5 RUCHÓW W 0,29 S”), dalej pisany
  znak po znaku z kursorem.
- Nowy wiersz ustawień po „ZAPIS 保存”, wysokość 28 pt: etykieta „INNE APKI 外”, przełącznik
  [ZOSTAW 残] [SCHOWAJ 隠] w stylu sąsiednich wierszy (wysokość 20 pt, 12 pt, ramka 1 pt `th.k`,
  wybrany wypełniony `th.k`). Dłuższa etykieta nie mieści się w szynie.
- Skróty układów nie mają kontrolek na panelu: zostają w oknie Ustawień (zakładka Skróty),
  wspólnym dla obu wyglądów.

### Plaster: krawędzie heksu jako licznik układów

- Heks zestawu 40 × 32 pt, wierzchołki: (10,0) (30,0) (40,16) (30,32) (10,32) (0,16).
  Krawędzie liczone od górnej, zgodnie z ruchem wskazówek zegara.
- n układów = pierwsze n krawędzi pogrubione **do środka**: ok. 4 pt zamiast 1,5 pt, kolor `th.s`.
  Przy n ≥ 6 cały obwód jest gruby i dalej się nie zmienia. 0 układów: zwykły heks.
- W prototypie: ta sama ścieżka co obrys, kreska 8 pt wyśrodkowana na krawędzi i przycięta
  kształtem heksu, więc widać tylko wewnętrzne 4 pt.
- Na heksie podłączonego zestawu (wypełnienie `th.k`, mruga) grube krawędzie zostają w `th.s`
  i nie mrugają.
- To tylko oznaczenie: bez własnego klikania. Do opisu dostępności heksu dopisz liczbę układów.

### Nagłówek

- Blok 配置, pierwszy wiersz mono: zamiast „ZESTAW: 01” jest „UKŁAD 1/3 現” (oglądany układ jest
  na ekranie) albo „UKŁAD 2/3 閲覧” (podgląd). Format: pozycja / liczba układów, bez dwukropka
  (z dwukropkiem wiersz się nie mieści). Pozostałe dwa wiersze bez zmian.

### Podgląd

- Blok statusu: kolor `th.s`, pasek „PODGLĄD” z liczbą różnic po prawej, pole znaku „閲覧”,
  słowo = nazwa oglądanego układu (np. „WIECZÓR”), pod nim zamiast podpisu przycisk w ramce 1 pt
  `th.s` (odstępy 0 / 5 pt): „↩ WRÓĆ DO „PRACA””. Blok nie mruga.
- Baner: „PODGLĄD · WIECZÓR · NA EKRANIE: PRACA · 閲覧 ·” w kolorze `th.s`.
- Kafelki, pole połączeń i wstęga dalej pokazują różnice względem ekranu, zwykłymi kolorami.
- „ZAPISZ OBECNY UKŁAD”: ramka przerywana, napis przekreślony z kryciem 0,4, podpis
  „保存 · TYLKO WYBRANY UKŁAD”, osłona z napisem „OSŁONA · ZABLOKOWANA” i nie podnosi się.
- Poza podglądem podpis pod zapisem mówi, co zostanie nadpisane: „保存 · NADPISUJE „PRACA””.
- „PRZYWRÓĆ”: wypełniony `th.k`, podpis „復元 · WCZYTAJ „WIECZÓR””.

### Okna w stylu panelu (`RLD.dc.html`)

- Rama jak blok statusu: zewnętrzna 2 pt, promień 10 pt, poświata w kolorze ramy; wewnętrzna
  1 pt, promień 6 pt; pasek tytułu 22 pt wypełniony kolorem ramy, tekst czarny, odstęp liter
  0,14 em. Szerokość 300 pt, tło `#000000`.
- **Nowy układ:** rama `th.s`, tytuł „新規 NOWY UKŁAD”, wiersz mono „NAZWA UKŁADU · INNA NIŻ
  POZOSTAŁE”, pole 26 pt z ramką 1 pt `th.t` i kursorem ▮ (podpowiedź „NP. PRACA” z kryciem
  0,4), przyciski 24 pt: [ANULUJ] (ramka `th.t`) i [ZAPISZ 保存] (wypełniony `th.k`).
  Nieaktywny zapis: ramka przerywana, napis przekreślony, krycie 0,4.
  Zajęta nazwa: ramka pola `th.e` i wiersz „✕ TEN ZESTAW MA JUŻ UKŁAD „PRACA”” w `th.e`.
- **Pierwszy zapis:** to samo okno, tytuł „初回 PIERWSZY UKŁAD”, opis „<ZESTAW> NIE MA JESZCZE
  UKŁADU. / NADAJ NAZWĘ PIERWSZEMU.”
- **Usuwanie:** rama `th.e`, tytuł „削除 USUNĄĆ UKŁAD?”, „02 WIECZÓR” (16 pt, `th.e`), mono
  „TEGO NIE DA SIĘ COFNĄĆ.” i „03 PREZENTACJA › POZ. 02 · SKRÓT ⌃⌥2” (tylko gdy coś się
  przesuwa), [ANULUJ] [USUŃ 削除] (wypełniony `th.e`).
- **Menu pod prawym przyciskiem:** lista w ramce 1 pt `th.s`, wiersze 22 pt: PRZYWRÓĆ 復元 ·
  PRZYWRÓĆ Z BRAKUJĄCYMI 起動 · ZMIEŃ NAZWĘ 改名 · USUŃ UKŁAD 削除 (`th.e`, nad nim kreska).
  Wiersz pod kursorem wypełniony `th.k`.
- **Zmiana nazwy:** w miejscu, w wierszu układu: pole z ramką przerywaną i kursorem. Enter
  zatwierdza, Esc anuluje; pusta lub zajęta nazwa = ramka pola w `th.e`.
  (Na planszy pole jest narysowane w pochylonej zakładce z wcześniejszego wariantu; w QA to
  zwykły wiersz szyny.)

## Komunikat przy przywracaniu, styl panelu (RV)

Stan (2026-11-26): **wybrany RV-C** (wiersz konsoli), wdrożony jako `PanelRestoreBanner`
(Sources/Panel.swift); kursor miga co 1,2 s, pasek ostrzeżenia przewija się co 9 s, przy
„Ogranicz ruch” oba stoją. Opisy RV-A i RV-B zostają jako odrzucone warianty. Płótno: rząd „RV”.

Dotyczy tylko sytuacji, gdy włączony jest panel. W zwykłym wyglądzie komunikat robi sesja
implementacyjna (neutralny, ciemny, półprzezroczysty). Okienko, położenie i czasy są te same
w obu wyglądach: 440 × 76 pt, na dole pośrodku każdego ekranu, 90 pt nad dolną krawędzią,
kliknięcia przechodzą, widoczny przez czas zmiany i co najmniej 0,3 s, gaśnie 0,2 s.

### Wspólne dla wszystkich wariantów

- Tło to pełna czerń `#000000`, bez przezroczystości i bez zaokrągleń: komunikat leży na
  dowolnej apce, także jasnej. Bez cienia systemowego.
- Role kolorów: informacja `th.k`, ostrzeżenie `th.e`, tekst pomocniczy `th.t`, drobny podpis
  `th.s`. Kolory z aktualnego motywu panelu.
- Wejście natychmiast (bez animacji startu panelu: przy 0,3 s zjadłaby cały czas widoczności).
  Zgaśnięcie: przezroczystość do 0 w 0,2 s.
- Ruch ma tylko ostrzeżenie (taśma albo przewijany pasek). Przy „Ogranicz ruch” stoi.
- Napisy wielkimi literami. Nazwa układu obcinana wielokropkiem na końcu.
- Trzy rodzaje informacji i jedno ostrzeżenie:

| Sytuacja | Znak | Etykieta | Duży wiersz | Wiersz dolny |
|---|---|---|---|---|
| zmiana na inny układ | 切替 | ZMIENIONO UKŁAD NA | nazwa układu | brak |
| przywrócenie tego samego układu | 復元 | PRZYWRÓCONO UKŁAD | nazwa układu | brak |
| któraś z powyższych + otwieranie apek | jak wyżej | jak wyżej | nazwa układu | 起動 · OTWIERAM BRAKUJĄCE APKI |
| wolna metoda (ostrzeżenie) | 配置中 | UKŁADAM PRZESTRZENIE… „nazwa” | NIE RUSZAJ MYSZY ANI KLAWIATURY | 操作禁止 · POTRWA KILKA SEKUND |

  Układ bez nazwy: w dużym wierszu „BEZ NAZWY”, w ostrzeżeniu etykieta bez cudzysłowu i nazwy.

### RV-A: blok stanu (polecany, `RVA.dc.html`)

Ten sam układ co blok stanu w panelu: pole w kolorze roli ze znakiem, obok słowa.

- Ramka wewnętrzna 1,5 pt w kolorze roli (`th.k` albo `th.e`) na całym obwodzie.
- **Pole znaku:** lewe 76 × 76 pt, wypełnione kolorem roli z poziomymi liniami skanowania
  (czarny 22 % krycia, 1 pt co 3 pt, jak wypełnienie przycisków pod kursorem). Znak czarny,
  Hiragino Mincho ProN 600, wyśrodkowany: 28 pt dla dwóch znaków, 22 pt dla 配置中.
- **Słowa:** kolumna wyśrodkowana w pionie, odstęp między wierszami 3 pt, margines lewy 14 pt,
  prawy 16 pt.
  - Etykieta: JetBrains Mono 400, 11 pt, odstęp liter 0,04 em; `th.t` w informacji, `th.e`
    w ostrzeżeniu.
  - Duży wiersz: Chakra Petch 700, odstęp liter 0,04 em, kolor roli; 24 pt w informacji
    (nazwa układu), 17 pt w ostrzeżeniu.
  - Wiersz dolny: JetBrains Mono 400, 11 pt; `th.t` w informacji, `th.e` w ostrzeżeniu.
    Znaki japońskie krojem Mincho.
- **Taśma (tylko ostrzeżenie):** pas 5 pt przy dolnej krawędzi, od pola znaku do prawej ramki,
  ukośne pasy 45° `th.e` / czarny po 7 pt, przesuw w lewo, pełny cykl 0,7 s. Treść ma wtedy
  5 pt dolnego marginesu.

Dlaczego ten: nazwa układu jest największym elementem, więc da się ją przeczytać w 0,3 s;
informacja i ostrzeżenie różnią się kolorem, ruchem i treścią dużego wiersza naraz; forma jest
już w panelu, więc nie dochodzi nowy kształt.

### RV-B: taśma (`RVB.dc.html`)

Pas pochylony o 12° (treść prosta), szerokość 424 pt w obrysie 440 pt, czarny cień 6 × 6 pt
bez rozmycia. Informacja: wypełnienie `th.k` z liniami skanowania, cały tekst czarny.
Ostrzeżenie: całe tło to ruchoma taśma `th.e` / czarny, tekst `th.e` na czarnych tabliczkach
(dopełnienie 1 × 6 pt), duży wiersz 15 pt. Najgłośniejszy; informacja pojawiająca się przy
każdym skrócie może przez to męczyć.

### RV-C: wiersz konsoli (`RVC.dc.html`)

Czarne pole bez ramki, w czterech rogach narożniki 12 × 12 pt, linia 2 pt w kolorze roli.
U góry podpis „SPACEDOCK // 切替” (JetBrains Mono 10 pt, `th.s`). Niżej jeden wiersz
„> ZMIENIONO UKŁAD NA „WIECZÓR”” (Chakra Petch 700, 16 pt, `th.k`) z migającym kursorem
8 × 15 pt, pod nim opcjonalnie „> 起動 OTWIERAM BRAKUJĄCE APKI…” (Mono 11 pt, `th.t`).
Ostrzeżenie: wiersz „> UKŁADAM PRZESTRZENIE… „PRACA”” 15 pt w `th.e` i pod nim pasek 18 pt
wypełniony `th.e` z przewijanym czarnym napisem „操作禁止 · NIE RUSZAJ MYSZY ANI KLAWIATURY ·
POTRWA KILKA SEKUND ·” (pełny obrót 9 s). Najcichszy; nazwa układu nie jest wyróżniona,
a zakaz ruszania myszy jest drobny i w ruchu, czyli najtrudniejszy do przeczytania.

## Ustawienia panelu w osobnym oknie (RU)

Stan (2026-11-26): **wybrany RU-B** (wiersz „設定 USTAWIENIA” nad akcjami), wdrożony jako
`PanelSettingsWindow` i `PanelRail.settingsButton` (Sources/Panel.swift). Płótno: rząd
„RU”. Pliki `RU*.dc.html` to pełne kopie prototypu QA; zmiany znajdziesz po `aria-label="Ustawienia"`
i `role="dialog"`.

Zastępuje z sekcji „Panel (QA)”: blok USTAWIENIA w szynie, stałą wysokość listy ZESTAWY
(≈149 pt) i dziennik w jednym wierszu.

### Szyna bez ustawień (wszystkie warianty)

Kolejność od góry, odstęp między blokami 10 pt:

1. **ZESTAWY 配置** z drzewkiem układów: bierze całą wolną wysokość (`flex: 1`, minimum 0)
   i przewija się w pionie, gdy się nie mieści. Wiersze bez zmian (19 pt, odstęp 2 pt).
2. **ODCHYLENIE 偏差**: bez zmian, stała wysokość.
3. **Dziennik:** wraca do 3 wierszy (15 pt każdy).
4. **Akcje**, stała wysokość, zawsze widoczne: Zapisz (70 pt), Przywróć (56 pt), Przywróć
   z brakującymi (30 pt), odstęp 8 pt.

Przy oknie 1100 × 700 i 7 zestawach z 3 układami zostaje około 90 pt wolnego miejsca w liście.
Kurczy się tylko lista: górny pasek i akcje nigdy nie znikają.

### Przycisk ustawień: trzy miejsca

- **RU-A, górny pasek (polecany, `RUA1.dc.html`).** Na prawym końcu paska „SPACEDOCK”,
  12 pt od krawędzi: wysokość 20 pt, dopełnienie 0 × 8 pt, ramka 1 pt `th.s`, tło czarne,
  napis „設定 USTAWIENIA” Chakra Petch 700, 11 pt, odstęp liter 0,1 em, kolor `th.s`.
  Pod kursorem i przy otwartym oknie: wypełniony `th.s`, napis czarny.
  Nie zabiera szynie ani punktu i leży tam, gdzie w zwykłym wyglądzie są sprawy całej apki.
- **RU-B, wiersz nad akcjami (`RUB1.dc.html`).** Wiersz 24 pt na całą szerokość szyny, nad
  przyciskiem Zapisz: z lewej „設定 USTAWIENIA”, z prawej skrót stanu mono 10 pt w `th.t`
  („AUTO · BEZPOŚR. ▸”). Widać tryb bez otwierania okna, ale kosztuje 32 pt szyny i dokłada
  czwarty przycisk do grupy akcji.
- **RU-C, nagłówek listy (`RUC1.dc.html`).** Mały przycisk „設定 UST.” (17 pt, 10 pt) po
  prawej w nagłówku „ZESTAWY 配置”. Nic nie kosztuje, ale jest mały, skrócony i wygląda jak
  ustawienie samej listy zestawów.

**Stan błędu (każdy wariant):** gdy brakuje uprawnienia Dostępność, przycisk ma ramkę i napis
w `th.e` oraz migający „!” przed znakiem (1,2 s, jak plakietka 現). Samo „Brak Karabinera”
nie zmienia przycisku. Plansza `RUW2.dc.html`.

### Okno ustawień (`RUW1.dc.html`, `RUW2.dc.html`)

- **Rama** jak okna RLD: zewnętrzna 2 pt `th.s`, promień 10 pt, poświata; wewnętrzna 1 pt,
  promień 6 pt; tło `#000000`. Szerokość 560 pt, wysokość z treści (około 470 pt). Wyśrodkowane
  w poziomie w oknie apki, góra 92 pt od góry okna. Panel pod spodem nie jest przyciemniany.
- **Pasek tytułu** 22 pt wypełniony `th.s`: „設定 USTAWIENIA” (czarny, 700, odstęp 0,14 em),
  po prawej przycisk „✕” 26 × 22 pt oddzielony czarną kreską 1,5 pt.
- **Zamykanie:** Esc, „✕”, przycisk [ZAMKNIJ], kliknięcie poza oknem, ponowne kliknięcie
  przycisku ustawień. Zmiany działają od razu, bez „Zapisz”.
- **Treść:** dopełnienie 2 / 14 / 10 pt. Trzy grupy; nagłówek grupy 20 pt, mono 11 pt, `th.s`,
  kreska 1 pt pod spodem, 8 pt odstępu nad nim.
- **Wiersz:** 32 pt, etykieta z lewej (Chakra Petch 600, 13 pt, `th.t`), przełącznik z prawej.
  Segment przełącznika 22 pt, dopełnienie 0 × 9 pt, 12 pt: wybrany wypełniony `th.k` z czarnym
  napisem (700), pozostałe ramka 1 pt `th.k` i napis `th.k` (600), niedostępny ramka przerywana
  `th.t` i napis przekreślony.

| Grupa | Wiersz | Sterowanie |
|---|---|---|
| 自動 AUTOMAT I PRZYWRACANIE | PRZYWRACANIE 復元 | [RĘCZNIE 手動] [AUTO 自動] |
| | ZAPIS 保存 | [RĘCZNIE 手動] [AUTO 自動] |
| | APKI SPOZA UKŁADU 外 | [ZOSTAW 残] [SCHOWAJ 隠] |
| | (opis, mono 11 pt, `th.t`, zawsze widoczny) | SCHOWAJ: PRZY PRZYWRÓCENIU APKI PEŁNOEKRANOWE SPOZA UKŁADU WYCHODZĄ Z PEŁNEGO EKRANU I SĄ MINIMALIZOWANE. APEK NIGDY NIE ZAMYKAMY. |
| | METODA 方式 | [PRZECIĄGANIE] [PEŁNY EKRAN] [BEZPOŚREDNIO] |
| | (tylko bez Karabinera, mono 11 pt) | PRZECIĄGANIE WYMAGA KARABINER-ELEMENTS · BRAK KARABINERA |
| 鍵 SKRÓTY | jeden wiersz 36 pt | plakietki nazwa + skrót, po prawej [USTAW ↗] |
| 系 SYSTEM | JĘZYK 言語 | [PL] [EN] [ES] [ZH], segmenty 38 pt |
| | URUCHAMIAJ PRZY LOGOWANIU 起動 | [WYŁ] [WŁ], segmenty 44 pt |
| | AUTOMAT PILNUJE MONITORÓW 監視 (26 pt) | „OK” w `th.k` albo „--” w `th.e` |
| | UPRAWNIENIE DOSTĘPNOŚĆ (26 pt) | „OK” w `th.k` albo „BRAK” + [NADAJ ↗] wypełniony `th.e`, migający |

- **Plakietka skrótu:** 20 pt, ramka 1 pt `th.s`; nazwa (600, 11 pt, `th.t`) i pole skrótu
  wypełnione `th.s` (mono 11 pt, czarny). Cztery: ZAPIS, PRZYWRÓĆ, Z BRAKUJĄCYMI, UKŁADY
  (modyfikator + „1–9”). Skróty na planszy są przykładowe; skrót nieustawiony pokazuje „--”.
  [USTAW ↗] otwiera systemowe okno Ustawień na karcie Skróty, jak dziś.
- **Stopka:** z lewej mono 11 pt `th.s` „ESC · ZAMYKA · ZMIANY DZIAŁAJĄ OD RAZU”, z prawej
  [ZAMKNIJ] 24 pt, ramka 1 pt `th.t`.
- W szynie etykieta brzmiała „INNE APKI 外”, bo pełna się nie mieściła. W oknie jest pełna:
  „APKI SPOZA UKŁADU 外”.

## Teksty

Polskie są z prototypów. Angielskie, hiszpańskie i chińskie to propozycje Claude'a, nie
sprawdzone przez rodzimych użytkowników języka.

| PL | EN | ES | ZH |
|---|---|---|---|
| Układy | Layouts | Diseños | 布局 |
| 3 układy · 7 przestrzeni | 3 layouts · 7 spaces | 3 diseños · 7 espacios | 3 个布局 · 7 个空间 |
| Zapisz jako nowy… | Save as new… | Guardar como nuevo… | 另存为新布局… |
| Nadaj nazwę | Name it | Ponle nombre | 命名 |
| Bez nazwy | Untitled | Sin nombre | 未命名 |
| NA EKRANIE | ON SCREEN | EN PANTALLA | 当前 |
| PODGLĄD | PREVIEW | VISTA PREVIA | 预览 |
| Oglądasz zapisany układ „%@”. Na ekranie jest „%@”. Kolory pokazują, czym różni się od ekranu. | You are viewing the saved layout “%@”. “%@” is on screen. Colors show how it differs from the screen. | Estás viendo el diseño guardado «%@». En pantalla está «%@». Los colores muestran en qué se diferencia de la pantalla. | 正在查看已保存的布局“%@”。屏幕上是“%@”。颜色表示它与屏幕的差异。 |
| Wróć do „%@” | Back to “%@” | Volver a «%@» | 返回“%@” |
| Zapisz obecny układ jako nowy | Save the current layout as new | Guardar el diseño actual como nuevo | 将当前布局另存为新布局 |
| np. Praca | e.g. Work | p. ej. Trabajo | 例如：工作 |
| Ten zestaw ma już układ „%@”. | This set already has a layout “%@”. | Este conjunto ya tiene un diseño «%@». | 此组合已有布局“%@”。 |
| Nazwij pierwszy układ tego zestawu | Name this set's first layout | Pon nombre al primer diseño de este conjunto | 为此组合的第一个布局命名 |
| %@ nie ma jeszcze żadnego układu. | %@ has no layouts yet. | %@ aún no tiene diseños. | %@ 还没有布局。 |
| Usunąć układ „%@”? | Delete layout “%@”? | ¿Eliminar el diseño «%@»? | 删除布局“%@”？ |
| Tego nie da się cofnąć. | This cannot be undone. | Esto no se puede deshacer. | 此操作无法撤销。 |
| „%@” przejdzie z pozycji %d na %d i dostanie skrót %@. | “%@” will move from position %d to %d and get the shortcut %@. | «%@» pasará de la posición %d a la %d y tendrá el atajo %@. | “%@”将从位置 %d 移到 %d，快捷键变为 %@。 |
| Zmień nazwę… | Rename… | Renombrar… | 重命名… |
| Usuń układ… | Delete layout… | Eliminar diseño… | 删除布局… |
| Apki spoza układu | Apps outside the layout | Apps fuera del diseño | 布局之外的应用 |
| Zostaw / Schowaj | Leave / Hide | Dejar / Ocultar | 保留 / 隐藏 |
| Skróty układów | Layout shortcuts | Atajos de diseños | 布局快捷键 |
| + numer 1–9 | + number 1–9 | + número 1–9 | + 数字 1–9 |
| tylko przestawia przestrzenie | only rearranges spaces | solo reordena los espacios | 仅重新排列空间 |
| przywraca z brakującymi apkami | restores with missing apps | restaura con las apps que faltan | 连同缺少的应用一起恢复 |
| Zapisz „%@” | Save “%@” | Guardar «%@» | 保存“%@” |
| Zmieniono układ na „%@” | Switched to layout “%@” | Se cambió al diseño «%@» | 已切换到布局“%@” |
| Przywrócono układ „%@” | Restored layout “%@” | Se restauró el diseño «%@» | 已恢复布局“%@” |
| otwieram brakujące apki | opening missing apps | abriendo las apps que faltan | 正在打开缺少的应用 |
| Układam przestrzenie… „%@” | Arranging spaces… “%@” | Organizando espacios… «%@» | 正在排列空间…“%@” |
| Nie ruszaj myszy ani klawiatury | Don't touch the mouse or keyboard | No toques el ratón ni el teclado | 请勿操作鼠标或键盘 |
| potrwa kilka sekund | this takes a few seconds | tardará unos segundos | 需要几秒钟 |
| Automat i przywracanie | Automation and restore | Automatización y restauración | 自动与恢复 |
| System | System | Sistema | 系统 |
| Zamknij | Close | Cerrar | 关闭 |
| Esc zamyka · zmiany działają od razu | Esc closes · changes apply immediately | Esc cierra · los cambios se aplican al instante | 按 Esc 关闭 · 更改立即生效 |
| Brak | Missing | Falta | 缺少 |

Panel: napisy wielkimi literami w języku apki; znaki japońskie (現, 閲覧, 新規, 初回, 削除, 改名,
外, 残, 隠, 切替, 復元, 起動, 配置中, 操作禁止, 鍵, 系) zostają we wszystkich językach poza chińskim, gdzie panel pokazuje angielskie
oznaczenia zamiast japońskich (jak dotąd).

## Otwarte kwestie

- Więcej niż 9 układów: pozycje 10+ nie mają skrótu; wiersz pokazuje sam numer.
- Strzałki ←/→ i ↑/↓ w oknie apki (osobny punkt w `TODO.md`): w LA układy są w drzewku, gdzie
  ←/→ systemowo zwija i rozwija. Do ustalenia, czy ←/→ ma zmieniać układ, czy zostać przy
  zwijaniu.
- Panel przy oknie mniejszym niż 1100 × 700: blok układów skaluje się razem z całą szyną;
  nie było to osobno rysowane.

## Zachowanie (ustalenia z 2026-11-25, przeniesione z TODO.md 2026-11-27)

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
([improvements.md](improvements.md)); składanie układu z osobnych monitorów.
