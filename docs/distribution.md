# Wydanie SpaceDock dla innych: plan

Założenia (2026-11-18): **bez konta Apple Developer**, hosting na **GitHubie**, instalacja też
przez **Homebrew**, aktualizacje automatyczne, możliwie mało zależności od Karabinera.

## Co to oznacza w skrócie

| Temat | Bez konta Apple | Skutek dla użytkownika |
|---|---|---|
| Podpis | własny certyfikat „SpaceDock Release” (samopodpisany, jeden na zawsze) | zgoda Dostępność zostaje po aktualizacjach |
| Notaryzacja | niemożliwa | przy **pierwszym** uruchomieniu: Ustawienia → Prywatność i ochrona → „Otwórz mimo to” |
| Mac App Store | niemożliwy (prywatne API, Dostępność, brak sandboxa) | — |
| Oficjalny `homebrew/cask` | odpada: od 5.0 Homebrew wycina caski, które nie przechodzą Gatekeepera | własny tap |
| Własna wirtualna mysz | niemożliwa (uprawnienie od Apple) | opcjonalny sterownik Karabinera tylko dla trybu szybkiego |

## 1. Repo publiczne bez danych osobowych

Audyt historii (18 commitów):
- autor: `wiktor w <…@users.noreply.github.com>`, czyli adres zastępczy GitHuba, nie prywatny e-mail;
- w historii nie ma: prywatnego e-maila, ścieżek `/Users/…`, UUID monitorów, tytułów okien, logów;
- nigdy nie usunięto żadnego pliku (nic nie „wisi” w historii);
- są: nazwy monitorów (DELL, PL) i apek (Bitwarden, Brave) w `docs/experiments.md`.

Plan:
1. **Nowe publiczne repo z jednym commitem** (najprostsze i najpewniejsze: zero historii).
   Obecne repo zostaje prywatne, lokalnie, z pełną historią.
   ```bash
   git checkout --orphan public && git commit -m "SpaceDock 0.1"
   ```
   Autor: login GitHuba zamiast imienia (`git -c user.name=<login> commit …`).
   Alternatywa z zachowaniem historii: `git filter-repo --mailmap` (podmiana autora we wszystkich commitach).
2. Przed pierwszym `push`: skan sekretów (`gitleaks detect`), przejrzenie `docs/experiments.md`.
3. Zmiany w kodzie przed publikacją:
   - ✅ identyfikator `local.spaces-layout` → `io.github.wiciow.spacedock` (ustawienia przenoszone same; zgoda Dostępność do nadania od nowa);
   - ✅ nazwa certyfikatu w `make-app.sh` jako zmienna (`SPACEDOCK_SIGN_IDENTITY`);
   - ✅ `tools/hs-drag-test.lua` (eksperyment) usunięty;
   - `LICENSE` (PolyForm Noncommercial 1.0.0 od 2026-11-22, wcześniej MIT; nikt nie pobrał wersji na MIT), `README.md` po angielsku: co robi, instalacja, „Otwórz mimo to”, uprawnienia.

## 2. Wirtualna mysz: ile da się uniezależnić od Karabinera

> **Aktualizacja (2026-11-18, P9):** domyślna metoda „Bezpośrednio” (operacja SkyLight) nie
> potrzebuje myszy, Karabinera, roota ani `sudoers`. Poniższe dotyczy już tylko opcjonalnej
> metody „Przeciąganie”; w wydaniu wystarczy, że bez pomocnika apka przechodzi na pełny ekran
> (tak działa dziś). Pomocnik roota (SMAppService) przestaje być potrzebny.

Mission Control na macOS 27 ignoruje zdarzenia z `CGEventPost` (T21); działa tylko prawdziwe
urządzenie HID. Własne wirtualne urządzenie HID wymaga uprawnienia, które wydaje Apple:
- DriverKit: `com.apple.developer.driverkit.family.hid.virtual.device`,
- CoreHID (`HIDVirtualDevice`, macOS 15+): `com.apple.developer.hid.virtual.device`.

Oba wymagają konta Apple i profilu, więc **bez konta własnej myszy nie da się zrobić**.

Da się za to ograniczyć zależność do minimum:
1. **Tryb podstawowy bez niczego:** przywracanie pełnym ekranem (`restore`), ~1,5 s na przestrzeń.
   Działa od razu, tylko z uprawnieniem Dostępność.
2. **Tryb szybki (opcjonalny):** sam sterownik `Karabiner-DriverKit-VirtualHIDDevice`
   (osobny `.pkg`, bez Karabiner-Elements, domena publiczna, podpisany i notaryzowany przez
   pqrs.org, więc instaluje się bez ostrzeżeń). Apka wykrywa go i w ustawieniach pokazuje
   „Tryb szybki: włączony / zainstaluj sterownik”.
3. **Pomocnik roota zamiast `sudoers`:** sterownik przyjmuje polecenia tylko od roota.
   - najpierw spróbować `SMAppService.daemon` (LaunchDaemon w bundlu, użytkownik zatwierdza
     przełącznikiem w Rzeczach otwieranych podczas logowania);
   - jeśli nie działa z samopodpisanym certyfikatem: instalacja LaunchDaemona przez
     `osascript … with administrator privileges` (jedno hasło administratora);
   - pomocnik przyjmuje tylko ruch/klik myszy i sprawdza podpis klienta (certyfikat SpaceDock).

## 3. Podpis bez konta Apple

- Jeden certyfikat „SpaceDock Release” (samopodpisany, Podpisywanie kodu), klucz prywatny tylko
  u Ciebie + kopia w menedżerze haseł. **Nigdy w repo.**
- Każde wydanie podpisane nim. Wymaganie podpisu (`codesign -d -r-`) przypina certyfikat, więc
  macOS uznaje każdą wersję za tę samą apkę: zgoda Dostępność i start przy logowaniu zostają.
- Utrata klucza = nowy certyfikat = każdy użytkownik nadaje zgodę od nowa. Stąd kopia.

## 4. Hosting i instalacja

1. **GitHub Releases:** `SpaceDock-<wersja>.zip` (albo `.dmg`) + suma SHA-256.
   Skrypt `tools/release.sh`: build uniwersalny (`--arch arm64 --arch x86_64`), podpis,
   zip, appcast (punkt 5), `gh release create`. Na start lokalnie, potem GitHub Actions
   (certyfikat `.p12` w sekretach repo).
2. **Własny tap Homebrew:** repo `<login>/homebrew-tap`, plik `Casks/spacedock.rb`
   (`url` do zipa z Releases, `sha256`, `auto_updates true`). Instalacja:
   `brew install --cask <login>/tap/spacedock`. Tap może aktualizować skrypt wydania.
3. **Pierwsze uruchomienie:** README pokazuje „Otwórz mimo to” (od macOS 15 prawy klik → Otwórz
   już nie omija Gatekeepera) i alternatywę w Terminalu:
   `xattr -dr com.apple.quarantine /Applications/SpaceDock.app`.

## 5. Aktualizacje: Sparkle 2

- Sparkle nie wymaga konta Apple: aktualizacje podpisuje własny klucz EdDSA
  (`generate_keys`, klucz prywatny w pęku kluczy, publiczny w `Info.plist` jako `SUPublicEDKey`).
- `appcast.xml` na GitHub Pages (albo w repo); `generate_appcast` w skrypcie wydania.
- Kod: zależność SwiftPM `sparkle-project/Sparkle`, w `make-app.sh` kopiowanie
  `Sparkle.framework` do `Contents/Frameworks` i podpis frameworka przed apką; w menu
  „Sprawdź aktualizacje…”, w ustawieniach „Sprawdzaj automatycznie”.
- Nowa wersja podpisana tym samym certyfikatem, więc zgody zostają (do sprawdzenia w teście 6.3).

## 6. Jak sprawdzić instalację u innych

1. **Drugie konto użytkownika** na tym Macu: czysty TCC, brak certyfikatu w pęku kluczy.
   Pobranie zipa przeglądarką (flaga kwarantanny jak u prawdziwego użytkownika).
2. **Maszyna wirtualna** (Tart albo UTM) z czystym macOS 15 i najnowszym: instalacja z zipa
   i z `brew`, „Otwórz mimo to”, zgoda Dostępność, start przy logowaniu, zmiana języka.
   Mission Control i kilku monitorów w VM się nie przetestuje.
3. **Aktualizacja:** zainstalować wersję N, wydać N+1, Sparkle aktualizuje, zgoda zostaje.
4. **Komendy:** `codesign --verify --deep --strict -vv SpaceDock.app`,
   `codesign -d -r- SpaceDock.app` (wymaganie z certyfikatem), `spctl -a -vv SpaceDock.app`
   (oczekiwane „rejected”: brak notaryzacji, to znany stan).
5. **Prawdziwe monitory:** tylko na fizycznym Macu (Twój + ktoś z innym zestawem).

## 7. Pierwsze uruchomienie w apce (onboarding)

Okno startowe w 3 krokach: zgoda Dostępność → (opcjonalnie) tryb szybki: sterownik + pomocnik →
„Zapisz obecny układ”. Bez tego nowy użytkownik nie wie, co kliknąć.

## Kolejność

| Krok | Co | Zależy od |
|---|---|---|
| M1 | ✅ (2026-11-22) Repo publiczne [WicioW/SpaceDock](https://github.com/WicioW/SpaceDock): jeden commit bez historii (gałąź `main`); prywatna historia tylko lokalnie na gałęzi `history`, **nigdy jej nie wysyłać**; tytuły okien w docs podmienione | — |
| M2 | ✅ certyfikat „SpaceDock” + `tools/release.sh` (uniwersalny build, podpis, zip, SHA-256; `--publish` = wydanie przez gh); ✅ [Release 0.1.0](https://github.com/WicioW/SpaceDock/releases/tag/v0.1.0) (DMG, zip, appcast) | M1 |
| M3 | Własny tap Homebrew | M2 |
| ~~M4~~ | ~~pomocnik roota~~: zbędne po P9; zamiast tego: „Przeciąganie” w ustawieniach tylko, gdy jest Karabiner + pomocnik | M1 |
| M5 | ✅ Sparkle 2.10.1 (aktualizacje w apce, appcast w każdym wydaniu, test lokalny 0.1.0 → 0.1.1; docs/app.md) | M2 |
| M6 | Onboarding: zgoda Dostępność → pierwszy zapis | M1 |
| M6b | ✅ Log bez tytułów okien (prywatność: tytuły kart, adresy e-mail) albo opcja „szczegółowy log” | — |
| M7 | Testy z punktu 6 przed ogłoszeniem; potem GitHub Actions do wydań | M2–M6 |
