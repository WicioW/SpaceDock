# SpaceDock: kilka układów na zestaw monitorów — specyfikacja wyglądu

Decyzje użytkownika z 2026-11-25: zwykły wygląd = **LA** (drzewko w pasku bocznym), panel =
**QA** (drzewko w szynie pod wybranym zestawem), dziennik w szynie skrócony do 1 wiersza.
Zachowanie (co robi Zapisz, Przywróć, podgląd, skróty): `TODO.md`, sekcja „Kilka układów na jeden
zestaw monitorów”. Ten plik opisuje tylko wygląd.

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

Panel: napisy wielkimi literami w języku apki; znaki japońskie (現, 閲覧, 新規, 初回, 削除, 改名,
外, 残, 隠) zostają we wszystkich językach poza chińskim, gdzie panel pokazuje angielskie
oznaczenia zamiast japońskich (jak dotąd).

## Otwarte kwestie

- Więcej niż 9 układów: pozycje 10+ nie mają skrótu; wiersz pokazuje sam numer.
- Strzałki ←/→ i ↑/↓ w oknie apki (osobny punkt w `TODO.md`): w LA układy są w drzewku, gdzie
  ←/→ systemowo zwija i rozwija. Do ustalenia, czy ←/→ ma zmieniać układ, czy zostać przy
  zwijaniu.
- Panel przy oknie mniejszym niż 1100 × 700: blok układów skaluje się razem z całą szyną;
  nie było to osobno rysowane.
