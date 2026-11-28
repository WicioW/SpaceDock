# TODO: pomysły

Otwarte sprawy. Plan wydania jest w [docs/distribution.md](docs/distribution.md). Luźne pomysły bez decyzji: [docs/improvements.md](docs/improvements.md).

## Tłumaczenia README (2026-11-27)

README po polsku, hiszpańsku i chińsku (`README.pl.md` itd., linki między nimi na górze).
Do ustalenia: kto utrzyma es i zh, czy tłumaczyć całość czy tylko górę + instalację.

## Automatyczne przełączanie układów (2026-11-27) — pomysł

Na razie tylko pomysł, bez decyzji o kształcie; szczegóły w
[docs/improvements.md](docs/improvements.md). Wrócić po pewnym czasie z ręcznym przełączaniem i
skrótami, jeśli go brakuje: pora dnia / dzień tygodnia albo uruchomione apki wybierają układ.

## Promocja: SEO, strona, katalogi, kontakty (2026-11-28)

Powtórzyć to, co zrobiliśmy w InvertedCursor. Na razie tylko plan: nic nie publikować ani nie
wysyłać bez decyzji. Research (pisany pod InvertedCursor, poza gitem):
`~/IdeaProjects/inverted-cursor/research/` — `1-reddit-and-forums.md`,
`2-launch-sites-and-directories.md`, `3-youtube-and-creators.md` (ok. 100 twórców z publicznymi
kontaktami), `4-seo.md`, `5-writing-venues-and-hacker-news.md`. Listy miejsc, reguł i kontaktów są
wspólne dla darmowych apek na Maca; słowa kluczowe, konkurencję i wątki zbadać osobno dla
SpaceDock. Reguł Reddita nikt nie otworzył u źródła: przed każdym postem sprawdzić je ręcznie.

**Stan (2026-11-28):** opis repo jest („Saves the order of macOS Spaces per monitor set…”), brak
tematów i strony (`homepageUrl` pusty), 0 gwiazdek, repo od 2026-11-22. Ikona w pasku menu ma
`accessibilityLabel("SpaceDock")` (App.swift, `MenuBarExtra`); Ko-fi i `FUNDING.yml` są.

**Zadania** (w kolejności opłacalności):
- ✅ (a) (2026-11-28: opis 298 znaków, 20 tematów, adres strony) GitHub „About”: opis do 350 znaków z frazami, których ludzie szukają, + do 20 tematów
  (`gh repo edit --description … --add-topic …`). Wyszukiwarka GitHuba szuka tylko po nazwie,
  opisie i tematach.
- ✅ (b) (2026-11-28, `research/1-seo.md`, poza gitem) Research dla SpaceDock jak `4-seo.md`: słowa kluczowe (słowa użytkowników z wątków, nie
  nasze), konkurencja, istniejące wątki z pytaniami.
- ✅ (c) (2026-11-28: pierwszy akapit, FAQ jako zapytania, alt, title i meta strony; tabela porównania czeka na decyzję) README pod te frazy: tabela „Compared with other tools” (narzędzie, co robi, czy robi to co
  SpaceDock; wcześniej odpuszczone „Similar apps” — wrócić po researchu), pytania FAQ jak zapytania
  („How do I … on a Mac?”), alt obrazków ze słowami kluczowymi.
- ✅ (d) (2026-11-28) `tools/release.sh`: opis wydania z instrukcją instalacji (`--notes` + `--generate-notes`)
  zamiast samego „Full Changelog”; w każdym wydaniu dodatkowo `SpaceDock.dmg` o stałej nazwie,
  czyli stały link `…/releases/latest/download/SpaceDock.dmg` do README, strony i postów.
- ✅ (e) (2026-11-28, zrobione inaczej: `site/` + GitHub Actions, nie folder `docs/`; opis w
  docs/app.md, „Strona”; og:image = social.png z (f)) Strona GitHub Pages z `docs/` (`index.html`, `404.html`, `.nojekyll`, ikona): title, meta
  description, og:image, canonical, JSON-LD SoftwareApplication (bez wymyślonych ocen), FAQ w
  zwykłym HTML, tabela porównania, przycisk Download na stały link. Włączenie:
  `gh api -X POST repos/WicioW/SpaceDock/pages -f "source[branch]=main" -f "source[path]=/docs"`,
  potem `gh repo edit --homepage <adres>`. Wzór: `inverted-cursor/docs/index.html`. Uwaga:
  `docs/` ma już dokumentację po polsku — sprawdzić, czy strona nie wystawi jej publicznie (np.
  osobny folder albo wykluczenia). Dark Reader przebarwia tła z CSS: `<meta name="darkreader-lock">`.
- ✅ (f) (2026-11-28: `docs/readme/social.png` z `tools/readme/social.swift`, w `shots.sh`; og:image strony; do GitHuba wgrać ręcznie) Obrazek podglądu linków 1280×640 (`docs/readme/social.png`), wgrywany ręcznie: repo →
  Settings → General → Social preview (brak API).
- ✅ (g) (2026-11-28: etykiety przycisków z samą ikoną w obu wyglądach, kafelek = jeden element z akcją „przejdź”, komunikaty na ekranie czytane przez VoiceOver; opis w docs/app.md) VoiceOver: etykieta ikony paska jest; sprawdzić toolTip i czy VoiceOver czyta menu.
- (h) PR do list bez wymogu OSI: jaywcjlove/awesome-mac (jedna apka na PR, alfabetycznie, wpis w
  README i wersjach zh/ja/ko, ikona Freeware, nie OSS), iCHAIT/awesome-macOS (freeware),
  open-saas-directory/awesome-native-macosx-apps (szablon issue „App Suggestion”).
- (i) Katalogi: AlternativeTo (kolejka miesiące; nie zaznaczać Open Source), MacUpdate (bezpośredni
  URL do DMG), macmenubar.com (min. 3 prawdziwe zrzuty paska menu), thriftmac, formac.app,
  macapps.org.
- (j) [szkice: `research/2-listings-and-outreach.md`, poza gitem, też dla (h), (i), (k)] Lista maili do twórców i redakcji z plików 2 i 3 (kontakty trzymać poza repo).
- (k) Plan postów: r/macapps, forum MacRumors (Mac Apps), Show HN, polskie kanały.

**Zasady z researchu:**
- Licencja PolyForm Noncommercial: zawsze „source-available”, nigdy „open source”. Odpadają
  r/opensource, Lobsters, listy z „open source” w nazwie, OpenAlternative.
- Brak notaryzacji i prywatne API (SkyLight) w pierwszym akapicie każdego posta. Link Ko-fi tylko
  w README, nie w postach.
- Instrukcja pierwszego uruchomienia: „Open Anyway” w System Settings → Privacy & Security, nie
  „right-click → Open” (nie działa na obecnym macOS).
- Homebrew: SpaceDock ma własny tap (`wiciow/spacedock`). Oficjalne repo casków wymaga notaryzacji,
  225 gwiazdek i repo starszego niż 30 dni; sprawdzić, czy wyłączanie casków bez notaryzacji
  (Homebrew 6.0.0) dotyczy też własnych tapów.
- Hacker News: Show HN ograniczone dla kont bez historii; tekst posta i komentarzy pisze
  człowiek (zakaz tekstu generowanego) — agent daje tylko konspekt. Tytuł „Show HN: SpaceDock –
  … for macOS”, pierwszy komentarz: po co, jak działa, ograniczenia, pytanie do czytelników.
- r/macapps: limit postów dewelopera (30 dni albo 3 miesiące, źródła się różnią), ujawnić
  autorstwo. MacRumors: jeden wątek na apkę, podpisać się jako deweloper. Swift Forums Community
  Showcase: tylko tekst techniczny. Lemmy (apple_enthusiast): tylko w przypiętym wątku miesięcznym.
- Redakcje: TidBITS (temat „PITCH: SpaceDock – …”, wersja, macOS, cena, konkurencja, udział AI w
  kodzie), 9to5Mac Indie App Spotlight, MacStories, Michael Tsai, iOS Dev Weekly (tylko artykuł
  techniczny), Changelog News. Polska: iMagazine, forum MyApple (Programy użytkowe), unknowNews,
  Wykop, kanał Michał Grodecki Tech.
- Twórcy: największa szansa w małych i średnich kanałach (np. Mostly Mac, A Better Computer,
  Fensy, Lewis Lovelock, podcast Mac Geek Gab). Mail krótko: dlaczego właśnie oni, 10–30 s
  nagrania albo GIF, link do strony.
- FAQPage nie daje już wyników rozszerzonych w Google; SoftwareApplication wymaga ocen — nie liczyć
  na to. Wyszukiwarki AI cytują głównie Reddit, Wikipedię, YouTube: najtańsze kroki to opis About,
  jasny pierwszy akapit README, FAQ jako pytania, wzmianki w katalogach.
