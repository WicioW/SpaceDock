# README SpaceDock: research przed przepisaniem

Cel: README, które w kilka sekund pokazuje, co SpaceDock robi i po co (zadanie z `TODO.md`,
sekcja „README na GitHubie”). Ten plik to tylko research i propozycja, README jeszcze się nie zmienia.

## Źródła (czytane 2026-11-26)

README (surowe, przez `gh api repos/…/readme`):
- [rxhanson/Rectangle](https://github.com/rxhanson/Rectangle) (259 linii, ~21 KB)
- [jordanbaird/Ice](https://github.com/jordanbaird/Ice) (112)
- [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos) (7: sam baner SVG z linkiem na stronę)
- [exelban/stats](https://github.com/exelban/stats) (163)
- [MonitorControl/MonitorControl](https://github.com/MonitorControl/MonitorControl) (142)
- [Hammerspoon/hammerspoon](https://github.com/Hammerspoon/hammerspoon) (53)
- [dwarvesf/hidden](https://github.com/dwarvesf/hidden), dziś `consolelabs/hidden` (97)
- [p0deje/Maccy](https://github.com/p0deje/Maccy) (172)
- [ianyh/Amethyst](https://github.com/ianyh/Amethyst) (235)
- [koekeishiya/yabai](https://github.com/koekeishiya/yabai), dziś `asmvik/yabai` (96)
- [sindresorhus/Gifski](https://github.com/sindresorhus/Gifski) (167)

Poradniki i fakty:
- [makeareadme.com](https://www.makeareadme.com/), [matiassingers/awesome-readme](https://github.com/matiassingers/awesome-readme)
- GitHub Docs: [About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes),
  [Attaching files](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files),
  [Basic formatting (relative paths, `<picture>`)](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)
- GitHub Blog: [obrazki dla dark/light mode](https://github.blog/developer-skills/github/how-to-make-your-images-in-markdown-on-github-adjust-for-dark-mode-and-light-mode/)
- Podobne apki: [Display Maid](https://apps.apple.com/us/app/display-maid/id450063525), [Stay](https://apps.apple.com/us/app/stay/id435410196),
  [SnapState (post autora)](https://www.hackingwithswift.com/forums/app-announcements/snapstate-2-7-2-puts-mac-windows-spaces-and-browser-tabs-back-after-sleep-or-a-dock-reconnect/31182),
  [Spencer (MacRumors)](https://forums.macrumors.com/threads/spencer-one-click-to-save-and-restore-window-layouts.2456003/),
  nasz `research_notes/Przestawianie Spaces bez Karabinera/fullscreen_speed.md` (AeroSpace, FlashSpace, yabai).
- Narzędzia: [Gifski](https://github.com/sindresorhus/Gifski), [Kap](https://github.com/wulkano/Kap).

## Co robią najlepsze README

**Góra strony (pierwszy ekran)**
- Ikona apki 120–200 px, wyśrodkowana, pod nią nazwa i jedno zdanie: Ice, Gifski, Hidden, Stats, MonitorControl
  (ikona z lewej, `align="left"`, obok opis i przycisk pobierania).
- Tagline to jedno krótkie zdanie „co robi”, bez marketingu: Gifski, yabai, Stats, Amethyst.
- Odznaki shields.io, zwykle 3–6: pobrania, wersja, licencja, platforma, wymagany macOS (Ice, MonitorControl,
  Hidden, Maccy). Hammerspoon ma też CI i coverage, czyli odznaki dla deweloperów, nie dla użytkownika.
- Obraz od razu pod nagłówkiem: Rectangle (zrzut okna), Ice (baner), Stats (dwa zrzuty menu), MonitorControl
  (duży zrzut), Amethyst (zrzut kafelków + link do wideo na YouTube). AltTab robi z całego README baner SVG
  i odsyła na stronę.
- Link do tłumaczenia README w drugiej linii („English | 简体中文”): Rectangle, Maccy.
- Ostrzeżenia na samej górze tylko w szczególnych przypadkach: Maccy i Hidden o fałszywych stronach,
  Hammerspoon o braku opieki, Ice o wczesnej wersji (`> [!NOTE]`).

**Jak pokazują działanie**
- Przeważają statyczne zrzuty PNG, nie GIF-y. Ice ma „Gallery” z podpisanym zrzutem dla każdej funkcji,
  MonitorControl siatkę 4 zrzutów ustawień, Hidden 2 zrzuty obok siebie (`width="400"`).
- Obrazki często hostowane jako `github.com/user-attachments/assets/…` (Ice, Rectangle), czyli wrzucone
  przeciąganiem, poza repo. Inni trzymają je w repo (`.github/`, `img/`, `docs/images/`) albo na własnym CDN (Stats).
- Wideo: Amethyst linkuje film z YouTube zamiast osadzać. Żadne z czytanych README nie używa `<picture>`
  z wariantem jasnym i ciemnym, mimo że GitHub to obsługuje.
- Amethyst pokazuje zrzut okna uprawnienia Dostępność i ustawienia Mission Control, które trzeba zmienić.

**Kolejność sekcji (typowa)**
Nagłówek, obraz, Install (Download / Homebrew), Requirements, Features lub Usage, FAQ / Known issues /
Troubleshooting, Translations, Build / Contributing, Credits, License. Instalacja prawie zawsze jest
w pierwszej trójce sekcji.

**Instalacja**
- Zawsze dwie drogi: DMG z Releases + `brew install --cask …` w bloku kodu (wszyscy).
- Stats i Rectangle dodają linki do starszych wersji dla starszych macOS; Hidden tłumaczy, czemu wymaga macOS 13.
- Hidden pisze wprost, że apka jest notaryzowana; MonitorControl i Amethyst opisują krok z uprawnieniem
  Dostępność (MonitorControl: kiedy można go pominąć).
- Stats i Rectangle mają osobną sekcję Uninstall.

**FAQ / znane problemy**
- Stats: FAQ w formie „problem, przyczyna, **Solution:** jedna linia z dokładną ścieżką w Ustawieniach”.
- Rectangle: „Common Known Issues” + „Troubleshooting” (reset uprawnień Dostępność, logi debug).
- yabai: dwie tabele „Requirements” i „Caveats” (uprawnienia, ustawienia Mission Control, SIP).
- Maccy: FAQ z pytaniami jako nagłówkami (linkowalne kotwice), ręczny spis treści na górze.
- Ice: jedno FAQ jako nagłówek („Why only macOS 14+?”).

**Porównanie z alternatywami**
- Rectangle: „Differences with Spectacle” (lista różnic z poprzednikiem).
- MonitorControl: jedno zdanie z linkiem do płatnej BetterDisplay dla bardziej zaawansowanych.
- Maccy: „Motivation” (czemu kolejna apka). Nikt nie robi dużej tabeli porównawczej.

**Sponsoring, społeczność, zasady**
- Ice: odznaka Sponsor + duży przycisk Buy Me a Coffee; Amethyst: sekcja Donating; AltTab: baner sponsora.
- Stats: sekcja „Open source, but not open contribution” (PR-y bez wcześniejszego issue mogą być zamknięte,
  tłumaczenia mile widziane).
- Tłumaczenia apki: Maccy (Weblate + widget statusu), Stats (lista języków), Rectangle (jak dodać).

**Długość:** od 7 linii (AltTab, wszystko na stronie www) do 259 (Rectangle, pół dokumentacji w README).
Środek to 100–170 linii. Długie opcje (Rectangle: ukryte ustawienia, URL actions) lepiej trzymać w `docs/`.

**Ogólne zasady z poradników:** co robi, dlaczego się przydaje, jak zacząć, gdzie szukać pomocy, licencja
(GitHub Docs); makeareadme radzi wymienić wyróżniki, gdy są alternatywy, i pokazać wizualnie, co robi projekt;
awesome-readme chwali demo GIF/wideo, logo, krótką instalację. GitHub sam generuje spis treści (ikona Outline),
ucina README powyżej 500 KiB i zaleca ścieżki względne do obrazków z repo.

## Co bierzemy dla SpaceDock

Proponowana kolejność nowego README (cel: ~150–180 linii, długie rzeczy w `<details>` albo w `docs/`):

1. **Nagłówek** (wyśrodkowany): ikona 128 px (`<picture>`: `assets/icon/AppIcon-1024.png` /
   `AppIcon-dark-1024.png`), `# SpaceDock`, tagline, np. *Keeps your Spaces in order when monitors come and go.*
2. **Odznaki (4):** najnowsze wydanie, pobrania, `macOS 15+`, licencja PolyForm NC. Bez CI (repo nie ma `.github/`).
3. **Hero GIF** (niżej scenariusz) + jedno zdanie problemu: macOS miesza Spaces po (od)łączeniu monitora,
   SpaceDock zapamiętuje kolejność dla każdego zestawu monitorów i ją przywraca.
4. **Features**: obecna lista punktów, każdy punkt z krótkim zrzutem albo bez, ale z galerią poniżej.
5. **Install**: bez zmian w treści (DMG + Homebrew, „Open Anyway”, `xattr`), dodać mały zrzut okna
   Privacy & Security z przyciskiem Open Anyway albo przełącznikiem Dostępność (jak Amethyst).
6. **Quick start**: 3–4 kroki (uprawnienie, ułóż Spaces, Save Current Layout, nazwij; powtórz dla zestawu).
7. **Gallery** (jak Ice, podpis nad każdym obrazem):
   - okno z zapisanymi układami, monitor po monitorze (sam laptop / laptop + 1 / laptop + 2);
   - przełączanie „Work” → „Evening” skrótem ⌃⌥1–9 z banerem na ekranie (drugi krótki GIF);
   - menu w pasku menu z listą układów;
   - podgląd układu z kolorami różnic;
   - opcja ukrywania apek spoza układu (przed / po), jeśli zmieści się w GIF-ie z przełączaniem.
8. **Keyboard shortcuts**: mała tabela (skrót, działanie), w stylu `<kbd>` jak Maccy.
9. **Restore methods**: obecna tabela, w `<details>` (dla większości ludzi wystarczy Direct).
10. **FAQ** (pytania jako nagłówki `###`, odpowiedź 1–3 zdania, format Stats „przyczyna + co kliknąć”):
    - Why does SpaceDock need Accessibility? (czyta i przesuwa okna; nic nie wysyła)
    - Why does macOS block the first launch? (brak notaryzacji, czemu: brak płatnego konta deweloperskiego?
      do potwierdzenia; aktualizacje przez Sparkle są podpisane i nie wymagają ponownie Open Anyway)
    - Does it use private APIs? Is it safe? (SkyLight do odczytu i przesuwania Spaces; aktualizacja macOS może
      je zepsuć, wtedy fallback; nie wymaga wyłączania SIP, w odróżnieniu od dodatku skryptowego yabai)
    - Does it quit or close my apps? (nie; ukrywanie = minimalizacja)
    - Two windows of the same app? (rozpoznaje po oknie i tytule)
    - Should I turn off „Automatically rearrange Spaces based on most recent use”? (odpowiedź do ustalenia)
    - It didn't restore / restored wrong: how do I report a bug? (log `~/Library/Logs/SpaceDock.log`,
      bez tytułów okien, link do formularza issue)
    - How do I uninstall? (usunąć apkę, `~/Library/Application Support/SpaceDock`, log, oraz
      `tccutil reset Accessibility io.github.wiciow.spacedock`)
    - Can I use it at work? (licencja: użytek niekomercyjny; komercyjny po zgodzie autora)
11. **Similar apps** (krótko, 4–5 punktów, uczciwie, bez tabeli ocen): Display Maid i Stay przywracają pozycje
    okien po zmianie monitorów, ale nie kolejność Spaces (Stay nie zapisuje Space okna); Moom zapisuje
    układy okien; SnapState (płatny) wraca apki do zapisanego Space i pełnego ekranu; yabai potrafi przesuwać
    Spaces, ale część funkcji wymaga częściowego wyłączenia SIP; AeroSpace i FlashSpace zastępują natywne
    Spaces wirtualnymi. Nasz research nie znalazł narzędzia, które przywraca kolejność Spaces z apkami
    na pełnym ekranie. Każde zdanie sprawdzić przed publikacją.
12. **Privacy**: obecny tekst (dobry, konkretny).
13. **Build from source**: obecny tekst, w `<details>`.
14. **License**: obecny tekst + jedno zdanie, że to *source-available*, nie OSI open source.

Drobne zasady: ścieżki względne do obrazków z repo; każdy obraz z `alt` i `width`; bez ręcznego spisu treści
(GitHub ma Outline), chyba że README przekroczy ~200 linii.

## Co odrzucamy i dlaczego

- **Odznaki CI / coverage / „reviewed by”** (Hammerspoon, Amethyst): nie mamy CI, a użytkownika to nie obchodzi.
- **Baner SVG zamiast README** (AltTab): wymaga strony www i projektu graficznego; cała treść ucieka z GitHuba.
- **Roadmapa z checkboxami w README** (Ice): `TODO.md` jest po polsku i wewnętrzny; roadmapa szybko się starzeje.
- **Dokumentacja wszystkich opcji w README** (Rectangle, 21 KB): utrudnia znalezienie instalacji; szczegóły
  zostają w `docs/app.md`.
- **Duże przyciski Buy Me a Coffee / baner sponsora**: tylko jeśli właściciel chce (pytanie niżej).
- **Avatary kontrybutorów, Discord, Google Group**: jeden autor, issues wystarczą.
- **Pełne pokazanie Neon**: to easter egg; najwyżej jedno zdanie-podpowiedź albo mały kadr.
- **Osobne README po polsku / hiszpańsku / chińsku teraz**: 4 wersje do utrzymania przy każdej zmianie;
  wrócić, gdy treść się ustabilizuje (pytanie niżej).
- **Osadzony YouTube** (Amethyst): GitHub nie osadza YouTube, pokazuje tylko link albo miniaturę.

## Nagrania

**Fakty GitHuba**
- Obrazki i GIF-y wrzucane przez przeglądarkę: do 10 MB. Wideo (`.mp4`, `.mov`, `.webm`, najlepiej H.264):
  do 10 MB w repo na darmowym planie (100 MB na płatnym).
- Wideo w README działa tylko jako plik wrzucony przeciąganiem (adres `github.com/user-attachments/assets/…`
  w osobnej linii); ścieżka do pliku `.mp4` w repo się nie odtworzy. Praktyczny sposób: przeciągnąć plik
  do komentarza w szkicu issue albo do edytora README na github.com i skopiować wygenerowany adres.
- Wideo nie odtwarza się samo (trzeba kliknąć), GIF tak. Dźwięk niepotrzebny (`-an`).
- Jasny i ciemny motyw: `<picture><source media="(prefers-color-scheme: dark)" srcset="…dark.png">`
  `<img src="…light.png" alt="…" width="…"></picture>`. Aplikacja mobilna GitHuba zawsze zgłasza jasny motyw.

**Format**
- Hero: **GIF** (gra od razu, w pętli), 6–12 s, szerokość 800–960 px, 10–15 fps, cel ≤ 3–5 MB.
- Dłuższe demo (np. cały przepływ: zapis, odłączenie, przywrócenie, przełączenie układu): **mp4** H.264,
  1280 px, ≤ 10 MB, pod galerią albo w sekcji „See it in action”.
- Zrzuty: PNG z ekranu Retina (2x), w README `width` ok. połowy, zoptymalizowane (`pngquant`/`oxipng`).
  Zrzut okna: ⌘⇧4, spacja, klik (z ⌥: bez cienia).
- Motywy: zrzuty statyczne w obu wariantach przez `<picture>` (tani koszt). GIF-y w jednym motywie
  (podwójne GIF-y to podwójna praca przy każdej zmianie UI).

**Narzędzia**
- Nagrywanie: wbudowane ⌘⇧5 („Record Selected Portion”, opcja „Show Mouse Clicks”) daje `.mov`, wystarczy.
- Konwersja do GIF: **Gifski** (sindresorhus, App Store, aktywnie rozwijany, dobre palety) albo ffmpeg:
  ```bash
  ffmpeg -i in.mov -vf "fps=12,scale=960:-1:flags=lanczos,palettegen=stats_mode=diff" pal.png
  ffmpeg -i in.mov -i pal.png -lavfi "fps=12,scale=960:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" out.gif
  gifsicle -O3 --lossy=60 out.gif -o out-small.gif   # gdy za duży
  ```
- mp4: `ffmpeg -i in.mov -vf "scale=1280:-2" -c:v libx264 -crf 26 -preset slow -pix_fmt yuv420p -movflags +faststart -an out.mp4`
- **Kap**: wygodny, ale ostatnie wydanie v3.6.0 z października 2022; nie polegać na nim na macOS 26+.
- Jak zmniejszyć GIF: krótsza pętla, niższy fps, mniejszy kadr (tylko pasek Spaces w Mission Control zamiast
  całego ekranu), jednolita tapeta, brak animowanych elementów w tle, przycięcie martwych klatek.

**Scenariusz hero GIF-a** (podłączenia kabla nie widać na nagraniu ekranu, więc cięcia z podpisami):
Mission Control z poprawną kolejnością, cięcie „monitor unplugged / plugged back”, Mission Control
z pomieszaną kolejnością, baner SpaceDock o przywróceniu, Mission Control znów w porządku. Alternatywa bez
kabla: pomieszać ręcznie i kliknąć **Restore**.

**Prywatność na nagraniach**
- Osobne konto użytkownika macOS do nagrań albo świeży zestaw okien; domyślna tapeta, ukryte ikony biurka.
- Neutralne okna z neutralnymi tytułami (TextEdit „Notes”, Kalendarz, Muzyka, Terminal z prostym promptem);
  przeglądarka tylko z publiczną stroną. Podgląd układu i plik `layout-sets.json` zawierają tytuły okien.
- Pasek menu: tylko SpaceDock i zegar; włączone „Nie przeszkadzać” (bez powiadomień).
- Bez nazwy konta, awatara, Wi-Fi; obejrzeć każdą klatkę przed wrzuceniem. Nazwy monitorów: pytanie 11.
- Nazwy układów przykładowe: „Work”, „Evening”, zestawy „Laptop only”, „Laptop + Display”.

## Pytania do właściciela

1. Hero: GIF (gra sam, słabsza jakość) czy mp4 (lepsza jakość, trzeba kliknąć)? Propozycja: GIF + mp4 niżej.
2. Gdzie trzymać media: w repo (`docs/readme/`, wersjonowane, ale każdy GIF zostaje w historii publicznego
   repo na zawsze) czy `user-attachments` (repo lekkie, ale trudniej podmienić i nie ma ich w klonie)?
   Propozycja: PNG w repo, GIF/mp4 jako `user-attachments`.
3. Czy pokazać Neon w README (jedno zdanie, mały kadr, nic)?
4. Czy sekcja „Similar apps” z nazwami innych apek? Jeśli tak, kto sprawdzi każde zdanie na aktualnych wersjach?
5. Czemu SpaceDock nie jest notaryzowany: czy README ma podać powód (np. brak płatnego Apple Developer Program)?
6. Co odpowiedzieć na „Automatically rearrange Spaces based on most recent use”: zalecić wyłączenie czy bez znaczenia?
7. Sponsoring: GitHub Sponsors / Buy Me a Coffee, czy nic?
8. Zasady wkładu: przyjmować PR-y, czy jak Stats „najpierw issue, tłumaczenia mile widziane”?
9. Kontakt w sprawie użytku komercyjnego: issue (jak teraz) czy e-mail?
10. Tłumaczenia README (pl / es / zh) teraz, później czy wcale? Kto utrzyma zh i es?
11. Prawdziwe nazwy monitorów na zrzutach czy zamazane / zmienione?
12. Czy kiedyś strona www (jak AltTab, Maccy), czy README zostaje jedyną „stroną” projektu?

## Decyzje (2026-11-27)

1. Hero: do ustalenia, czym nagrywamy (pytanie, czy da się wygenerować GIF / wideo bez nagrywania ekranu).
2. Zrzuty PNG i GIF w repo (`docs/readme/`); załącznik `user-attachments` z niezapisanego issue
   dawał 404 bez logowania (2026-11-27). mp4 poza repo (`dist/`).
3. O wyglądzie Neon ani słowa. Zamiast tego jedno zdanie: *For fans of Neon Genesis Evangelion and
   Akira, there's an easter egg.*
4. „Similar apps”: tak, 4–5 punktów; każde zdanie sprawdzone na stronie danej apki przed publikacją.
5. Brak notaryzacji: powód w jednym zdaniu (płatne konto Apple Developer, apka darmowa).
6. FAQ: zalecić wyłączenie „Automatically rearrange Spaces based on most recent use”.
7. Sponsoring: na razie nic w README; pomysł w `docs/improvements.md`.
8. Wkład: najpierw issue, potem PR, tłumaczenia mile widziane; kontakt komercyjny przez issue.
9. Tłumaczenia README: później, zadanie w `TODO.md`.
10. Prawdziwe nazwy monitorów na zrzutach zostają; tytuły okien zawsze wymyślone.
11. Bez strony www, README jest stroną projektu.
