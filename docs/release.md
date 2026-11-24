# Wydanie nowej wersji

Nowa wersja trafia do użytkowników dwiema drogami, i jedno polecenie robi obie:

1. **Apka (GitHub Releases + Sparkle).** Wydanie `v<wersja>` w `WicioW/SpaceDock` z
   `SpaceDock-<wersja>.zip`, `.dmg`, sumami `.sha256` i `appcast.xml`. Zainstalowane apki czytają
   `releases/latest/download/appcast.xml` i same proponują aktualizację (zip podpisany EdDSA).
   Nowi użytkownicy pobierają `.dmg`.
2. **Homebrew (cask).** Plik `Casks/spacedock.rb` w osobnym repo `WicioW/homebrew-spacedock`
   (wersja + SHA-256 `.dmg` pobrana z opublikowanego wydania). Instalacja:
   `brew install --cask wiciow/spacedock/spacedock`.

## Kroki

1. Wszystko scommitowane i wypchnięte (`git push origin main`): `gh release create` tworzy tag
   z HEAD domyślnej gałęzi na GitHubie, nie z lokalnej.
2. Wersja: ostatnia to `git describe --tags --abbrev=0`. Nowa zawsze wyższa, nigdy użyta drugi
   raz (Sparkle porównuje numery). Nowe funkcje: druga liczba (0.1.2 → 0.2.0), same poprawki:
   trzecia (0.2.0 → 0.2.1).
3. Wydanie (publiczne, uruchamia właściciel):
   ```bash
   tools/release.sh 0.2.0 --publish
   ```
   - Buduje uniwersalną apkę (arm64 + x86_64) podpisaną certyfikatem `SpaceDock`, zip, DMG
     (`tools/make-dmg.sh`), sumy i `dist/appcast.xml`, potem `gh release create` z notatkami z
     commitów (droga 1), na końcu `tools/update-cask.sh <wersja> --publish` (droga 2).
   - Zaczyna od `rm -rf dist`: poprzednie pliki z `dist/` znikają (są w poprzednim wydaniu).
   - Bez `--publish` tylko buduje do `dist/`, nic nie wysyła.
4. Lokalny tag: `git fetch --tags`.

Sam cask (np. gdy krok Homebrew się nie udał, a wydanie już jest):
```bash
tools/update-cask.sh 0.2.0 --publish
```
Bez `--publish` pisze tylko `dist/spacedock.rb`.

## Wymagania (raz, opisane w docs/app.md)

- Certyfikat `SpaceDock` w pęku kluczy (ten sam przy każdym wydaniu, inaczej użytkownicy tracą
  zgodę Dostępność); skrypt odmawia podpisu ad-hoc.
- Klucz Sparkle: prywatny w pęku kluczy (`--account spacedock`), publiczny w
  `assets/sparkle-public-key.txt`, narzędzie `.build/sparkle-tools/bin/sign_update`.
- `gh` zalogowany z dostępem do obu repo.
- Zgoda Automatyzacja Terminal → Finder (układ okna DMG).

Test aktualizacji bez publikowania: docs/app.md, „Aktualizacje (Sparkle)”, test lokalny.
