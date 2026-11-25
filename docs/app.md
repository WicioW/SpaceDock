# Apka: decyzje i plan

Cel: kolejność przestrzeni (Spaces) i ich przypisanie do monitorów zapisane osobno dla każdego
zestawu monitorów i przywracane automatycznie po podłączeniu / odłączeniu kabla.
Ustalenia techniczne i testy: [experiments.md](experiments.md).

## Decyzje (2026-11-16)

1. **Apka z oknem + ikonka w pasku menu.** Okno do przeglądania i edycji. Ikonka przy zegarze trzyma
   program w tle (pilnuje zmian monitorów) także po zamknięciu okna. Bez ikony w Docku.
2. **Okno:**
   - po lewej lista zestawów monitorów („Sam laptop”, „Laptop + Dell”…), aktualny zaznaczony,
     z możliwością zmiany nazwy;
   - po prawej monitory zestawu narysowane tak, jak stoją na biurku, na każdym przestrzenie
     w kolejności, z ikonami apek;
   - przyciski „Zapisz obecny układ” i „Przywróć”, data ostatniego zapisu.
3. **Edycja przeciąganiem:** kolejność i przypisanie do monitora zmienia się, przeciągając ikony
   przestrzeni w oknie (także między monitorami). Edytuje to *zapisany* układ, nie rusza prawdziwych
   przestrzeni, dopóki nie klikniesz „Przywróć” (albo nie zadziała automat).
4. **Tryb zapisu:** ustawienie „Ręcznie” albo „Automatycznie” (szczegóły: experiments.md, P7).
5. **Zapis per zestaw monitorów:** klucz = posortowane UUID podłączonych ekranów.
6. **Przywracanie:** `restore-drag` (przeciąganie w Mission Control wirtualną myszą Karabinera,
   ~3,6 s), a gdy Karabiner niedostępny, zapasowo `restore` (pełny ekran, ~1,5 s na przestrzeń).

## Automat: `watch`

```bash
./.build/release/spaces-layout watch               # przywraca po zmianie monitorów, zapis ręczny (save)
./.build/release/spaces-layout watch --auto-save   # + automatyczny zapis zmian kolejności
```
Uruchamiać w iTerm (uprawnienie Dostępność). Co 1 s sprawdza listę ekranów; po zmianie czeka 3 s od ostatniej zmiany
i 2 s nieruchomego paska przestrzeni, potem `restore-drag` (jeden monitor) albo `restore`
(kilka monitorów albo brak wirtualnej myszy). `--auto-save`: zapis po 5 s stabilnej kolejności,
nigdy w ciągu 10 s od zmiany monitorów ani od własnego restore.
Brak ekranów (uśpienie, zgaszone ekrany) nie jest zestawem: nic nie przestawia, a wybudzenie liczy się
jako zmiana. Gdy monitory zmienią się w trakcie układania, układanie się przerywa i rusza od nowa
dla nowego zestawu.

### Wirtualna mysz bez hasła
`watch` nie może pytać o hasło, więc pomocnik wirtualnej myszy potrzebuje reguły `sudoers`.
**Reguła musi wskazywać kopię należącą do roota**, nie plik z `.build/` (ten może podmienić każdy
program działający jako Ty, i dostałby roota). Reguła pozwala uruchomić bez hasła tylko
`/usr/local/libexec/spaces-layout vhid-serve`, z dokładnie tym argumentem.

```bash
sudo install -d -o root -g wheel -m 755 /usr/local/libexec
sudo install -o root -g wheel -m 755 .build/release/spaces-layout /usr/local/libexec/spaces-layout
echo "$USER ALL=(root) NOPASSWD: /usr/local/libexec/spaces-layout vhid-serve" | sudo tee /etc/sudoers.d/spaces-layout
sudo chmod 440 /etc/sudoers.d/spaces-layout && sudo visudo -cf /etc/sudoers.d/spaces-layout
```
Po każdej przebudowie, która zmienia kod wirtualnej myszy, trzeba ponowić drugą komendę (`install`).
Usunięcie: `sudo rm /etc/sudoers.d/spaces-layout /usr/local/libexec/spaces-layout`.

## Apka

```bash
tools/make-app.sh && open ~/Applications/SpaceDock.app
```
Apka nazywa się **SpaceDock**. Instaluje `~/Applications/SpaceDock.app` (identyfikator `io.github.wiciow.spacedock`; do 2026-11-18 był `local.spaces-layout`: ustawienia apka przenosi sama przy pierwszym starcie, zgodę Dostępność i start przy logowaniu trzeba nadać od nowa). W apce działa automat (to samo co `watch`, więc `watch`
w iTerm trzeba wyłączyć). Ustawienia są w osobnym oknie (⌘, albo koło zębate pod zestawami; w
pasku zostaje tylko stan automatu): **Ogólne** = przywracanie Automatycznie (po zmianie monitorów) /
Ręcznie (przycisk „Przywróć”), zapis Ręcznie / Automatycznie, metoda; **Skróty** = globalne skróty zapisu, przywracania i przywracania z otwieraniem zamkniętych apek
(`Sources/Hotkeys.swift`, domyślnie brak); **Apka** = język, wygląd, start
przy logowaniu, aktualizacje. Kafelek obecnego zestawu: klik zaznacza go pierścieniem, dwuklik przenosi na
tę przestrzeń (podniesienie okna przez SkyLight + AX, `goTo`), ↗ na czerwonym kafelku otwiera zamkniętą apkę.
„Przywróć z brakującymi” najpierw otwiera zamknięte apki z zapisu i zostaje na nich (bez powrotu). Apka startuje jak po zwykłym uruchomieniu: stanu sprzed zamknięcia (np. kart przeglądarki) SpaceDock nie przywraca. Podczas układania na
każdym ekranie jest czerwony komunikat „Układam przestrzenie… nie ruszaj myszy”. Log:
`~/Library/Logs/SpaceDock.log` (menu: „Pokaż log”), bez tytułów okien (tylko numery), więc można go dołączyć do zgłoszenia. Zapisy: `~/Library/Application Support/SpaceDock/layout-sets.json` (od 2026-11-25: lista układów i wybrany dla każdego zestawu; przy pierwszym starcie budowany z `layouts.json`, który zostaje nietknięty dla starszych wersji apki), folder `~/Library/Application Support/SpaceDock/` (do 2026-11-21 folder `spaces-layout` i log `spaces-layout.log`; apka przenosi je sama przy pierwszym starcie).
Zapis obejmuje też biurka (wpis `desktop`), więc ich miejsce na pasku wraca razem z resztą; zapis
sprzed tej zmiany nie ma biurek i wtedy biurka idą na początek paska (trzeba zapisać jeszcze raz).
Dwa okna tej samej apki (np. dwa Brave) rozróżnia numer okna zapisany przy przestrzeni: nie zmienia
się przy odłączaniu kabla ani wyjściu z pełnego ekranu, ginie po zamknięciu apki. Dopasowanie idzie
od najpewniejszego: to samo okno, ta sama apka z tym samym tytułem, ta sama apka na tym samym
monitorze, ta sama apka gdziekolwiek. Zapis bez numerów okien (sprzed tej zmiany) działa jak dawniej.
Po restarcie Maca apki wracają jako zwykłe okna: przed ułożeniem apka sama wstawia na pełny ekran
okna z zapisu, których przestrzeni brakuje (szuka ich na wszystkich biurkach, także
zminimalizowanych), okno po oknie (~1 s każde), potem układa wszystko naraz. Numery okien po
restarcie są nadawane od nowa, więc liczą się tylko w obrębie tej samej apki.
Po ułożeniu apka wraca na przestrzenie, które były widoczne wcześniej, i do apki, która była na wierzchu.
Ustawienie **Metoda**: „Przeciąganie” (Mission Control + wirtualna mysz Karabinera, przestawia też
biurka; gdy się nie uda, zapasowo zwykły pełny ekran) albo „Pełny ekran” (bez Karabinera i roota:
okna wychodzą z pełnego ekranu bez przechodzenia na ich przestrzenie i wracają w kolejności zapisu;
biurek nie przestawia; CLI `restore-fast`, experiments.md P8) albo „Bezpośrednio” (**domyślna**; gdy zawiedzie, apka próbuje przeciąganiem, potem pełnym ekranem; prywatna operacja
SkyLight z macOS 26+, każda przestrzeń od razu na swoim miejscu i monitorze, ~0,1 s na ruch, bez
myszy i Karabinera; CLI `restore-bridge`, experiments.md P9).
Testy z uprawnieniem apki: `tools/run-in-app.sh <komenda>` (np. `restore-drag`, `mcbars`, `mcmove`).
Języki: polski (tekst w kodzie jest kluczem), angielski, hiszpański, chiński uproszczony, w
`Localization/<język>.lproj` (`Localizable.strings` + `.stringsdict` z odmianą „N przestrzeni”).
Apka idzie za językiem systemu; inny tylko dla niej: Ustawienia → Ogólne → Język i region → Aplikacje.
Nowy napis w UI = nowy klucz we wszystkich trzech `Localizable.strings`. Log zostaje po polsku.

### Lokalny certyfikat (raz)
Uprawnienie Dostępność jest przypięte do podpisu apki. Przy podpisie ad-hoc każda przebudowa je
kasuje, a z własnym certyfikatem zostaje.
1. Otwórz Pęk kluczy: `open "/System/Library/CoreServices/Applications/Keychain Access.app"`.
2. Menu Pęk kluczy → Asystent certyfikatów → Utwórz certyfikat…
3. Nazwa `SpaceDock` (do 2026-11-19 był `Spaces Layout Dev`), typ tożsamości „Główny samopodpisany”, typ certyfikatu
   „Podpisywanie kodu”, Utwórz.
4. `tools/make-app.sh`. Przy pierwszym podpisie macOS pyta o dostęp `codesign` do klucza: „Zawsze pozwalaj”.
5. W apce „Nadaj uprawnienie…” i włącz SpaceDock na liście, która się otworzy. Ręcznie:
   `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`.
   Jeśli przełącznik jest włączony, a apka dalej nie ma zgody (stary wpis po innym podpisie):
   `tccutil reset Accessibility io.github.wiciow.spacedock`, potem znowu „Nadaj uprawnienie…”.
6. Kopia zapasowa (raz): Moje certyfikaty → prawy klik `SpaceDock` → Eksportuj → `.p12` z hasłem,
   do menedżera haseł. Tym certyfikatem są podpisane wydania: bez kopii utrata Maca = nowy
   certyfikat = każdy użytkownik nadaje zgodę od nowa.

**Stary certyfikat `Spaces Layout Dev`** (sprzed 2026-11-19) nic już nie podpisuje. Usunąć go
dopiero, gdy apka podpisana `SpaceDock` działa i ma zgodę Dostępność (usunięcie jest
nieodwracalne, chyba że wcześniej go wyeksportujesz):
1. Pęk kluczy → Moje certyfikaty → prawy klik `Spaces Layout Dev` → Usuń (usuwa certyfikat
   razem z kluczem prywatnym).
2. Stare wpisy na liście Dostępność (SpaceShips / Spaces Layout, identyfikator sprzed zmiany):
   zaznaczyć wpis i kliknąć „−” pod listą. `tccutil reset Accessibility local.spaces-layout`
   nie działa, gdy apki z tym identyfikatorem już nie ma (błąd -10814).

Uprawnienie dostaje każdy program z identyfikatorem `io.github.wiciow.spacedock` podpisany tym
certyfikatem, więc klucz prywatny certyfikatu zostaje tylko w Twoim pęku kluczy.

### Aktualizacje (Sparkle)

Apka raz dziennie (i z menu „Sprawdź aktualizacje…”) czyta
`https://github.com/WicioW/SpaceDock/releases/latest/download/appcast.xml`, czyli `appcast.xml`
z najnowszego wydania. Wyższy `sparkle:version` niż własny `CFBundleVersion` = okno „Dostępna jest
nowa wersja”. Sparkle sprawdza podpis EdDSA pliku i podpis kodu, podmienia apkę i uruchamia ją
od nowa; zgoda Dostępność zostaje (ten sam certyfikat), Gatekeeper nie pyta (brak kwarantanny).
Sprawdzone lokalnie 2026-11-22: 0.1.0 → 0.1.1 z `localhost`.

- **Klucz EdDSA** (raz, 2026-11-22): narzędzia Sparkle 2.10.1 w `.build/sparkle-tools`
  (`Sparkle-2.10.1.tar.xz` z wydania sparkle-project/Sparkle, rozpakowany).
  `generate_keys --account spacedock` zapisuje klucz prywatny w pęku kluczy, publiczny idzie do
  `assets/sparkle-public-key.txt` (w repo, `make-app.sh` wpisuje go jako `SUPublicEDKey`).
  Kopia: `generate_keys --account spacedock -x <plik>` do menedżera haseł. Utrata klucza =
  użytkownicy nie dostaną już żadnej aktualizacji (muszą pobrać nową wersję ręcznie).
- **DMG:** `tools/make-dmg.sh` (wołany przez `release.sh`): tło z wahadłowcem i instrukcją
  pierwszego otwarcia (`dmg-background`, `Sources/DMGBackground.swift`), układ okna zapisuje
  Finder przez AppleScript (raz zgoda: Prywatność i ochrona → Automatyzacja → Terminal → Finder).
  Kto ma włączone pokazywanie ukrytych plików, widzi folder `.background` poza oknem i pasek
  przewijania; zwykły użytkownik nie.
- **Wydanie:** `tools/release.sh <wersja> [--publish]`. Wersja zawsze wyższa niż poprzednia i
  nigdy użyta drugi raz. Skrypt podpisuje zip (`sign_update`) i pisze `dist/appcast.xml` z jedną
  pozycją (najnowszą); `--publish` dołącza go do wydania i aktualizuje cask w tapie Homebrew
  (`tools/update-cask.sh`, suma SHA-256 brana z opublikowanego wydania). Kroki: docs/release.md.
- **Test lokalny:** zainstalować starszą wersję z kanałem na `localhost`, zbudować nowszą z
  adresami na `localhost` i podać `dist/` serwerem:
  ```bash
  SPACEDOCK_VERSION=0.1.0 SPACEDOCK_FEED=http://localhost:8765/appcast.xml tools/make-app.sh
  SPACEDOCK_FEED=http://localhost:8765/appcast.xml SPACEDOCK_DOWNLOADS=http://localhost:8765 tools/release.sh 0.1.1
  python3 -m http.server 8765 --bind 127.0.0.1 --directory dist
  ```
  Potem w apce „Sprawdź aktualizacje…”. Na koniec `tools/make-app.sh` (prawdziwy adres).

## Plan budowy

1. ✅ **Automat w CLI (`watch`)**, przetestowany z kablem (T33): wykrycie zmiany monitorów (lista ekranów sprawdzana co 1 s, T32),
   odczekanie, aż macOS skończy mieszać, `restore-drag` / zapasowo `restore`; tryb automatycznego zapisu
   z zabezpieczeniami. Wirtualna mysz bez hasła: na start reguła `sudoers` dla jednego programu.
2. 🔬 **Drugi monitor (P6):** profile z wieloma monitorami działają. Mission Control przyjmuje mysz
   tylko na monitorze, z którego go otwarto (T35), więc przestrzeń na złym monitorze idzie pełnym
   ekranem, a kolejność przeciąganiem w osobnej sesji Mission Control na każdy monitor. Czeka na
   test z kablem.
3. 🔬 **Apka SwiftUI:** okno + ikonka w pasku menu, logika z kroków 1–2 bez zmian, własne uprawnienie
   Dostępność (podpisana apka, stała tożsamość). Pierwsza wersja (`tools/make-app.sh`, `Sources/App.swift`):
   lista zestawów, monitory od lewej do prawej z ikonami przestrzeni, „Zapisz obecny układ”,
   „Przywróć” (tylko z uprawnieniem Dostępność), „Usuń zapis” w menu kontekstowym, ikonka w pasku menu.
   Nazwy i pozycje monitorów pamiętane w `screens.json`. Automat, tryb zapisu, log i start przy
   logowaniu w apce; podpis lokalnym certyfikatem. Czeka na test z kablem.
4. **Edycja przeciąganiem w oknie** (zapisany układ), zmiana nazw zestawów.
5. **Pomocnik systemowy** zamiast `sudoers` (SMAppService / LaunchDaemon) dla wirtualnej myszy.
6. **Drobne:** Split View w `list`/`restore`.
