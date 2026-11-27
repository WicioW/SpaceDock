# Potencjalne ulepszenia

Pomysły bez decyzji, że je robimy (w odróżnieniu od TODO.md). Każdy z datą i skąd się wziął.

## Automatyczne przełączanie układów (2026-11-24, z ustaleń „kilka układów na zestaw”)

Na start układy przełącza się tylko ręcznie. Możliwe automaty:
- **Pora dnia / dzień tygodnia:** np. „Praca” w dni robocze 9–17, „Wieczór” poza tym.
- **Uruchomione apki:** np. otwarcie IDE wybiera układ „Kod”, otwarcie Logic „Muzyka”.

## Okna przeglądarek po adresach kart (2026-11-24, research przed „kilka układów”)

Dziś okno przeglądarki rozpoznajemy po apce i tytule (tytuł = aktywna karta), a otwarta apka
przywraca okna sama. Pomysł: zapisywać adresy kart każdego okna (AppleScript) i po starcie
przeglądarki dokładać tylko brakujące okna (porównanie po adresach, nie po tytule).
Koszt: uprawnienie Automatyzacja osobno dla każdej przeglądarki; Firefox bez AppleScript (nie da
się); profile Chrome/Brave tylko przy starcie (`--profile-directory`, zawsze nowe okno); ryzyko
duplikatów z „kontynuuj tam, gdzie skończyłeś”.

## Komunikat o wyniku przywrócenia (2026-11-26, z ustaleń o komunikacie „Zmieniono układ”)

Dziś komunikat mówi tylko, co SpaceDock robi („Zmieniono układ na …”), nie czy się udało. Pomysł:
gdy po zakończeniu ekran dalej różni się od układu, komunikat zmienia się na „Nie wszystko się
ułożyło” (pomarańczowy, dłużej, np. 2 s). Ryzyko fałszywego alarmu: różnica bywa chwilowa (apka
jeszcze się otwiera, wraca na pełny ekran).

## Wsparcie finansowe (2026-11-27, z researchu README)

GitHub Sponsors albo Buy Me a Coffee: przycisk w README / `FUNDING.yml`. Wymaga założenia konta;
na razie bez decyzji i bez wzmianki w README. Research: [readme-research.md](readme-research.md).
