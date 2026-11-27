# TODO: pomysły

Otwarte sprawy. Plan wydania jest w [docs/distribution.md](docs/distribution.md). Luźne pomysły bez decyzji: [docs/improvements.md](docs/improvements.md).

## Strzałki w oknie apki: zestawy monitorów i układy (2026-11-24)

Gdy okno SpaceDock jest na wierzchu (nie globalnie):
- **↑ / ↓**: poprzedni / następny zestaw monitorów,
- **← / →**: poprzedni / następny układ apek w wybranym zestawie.

**Do ustalenia:**
- ✅ (2026-11-24, z ustaleń „kilka układów”) ← / → zmieniają podgląd, nie przywracają.
- Wybrany design LA (drzewko): w drzewku ← / → systemowo zwija i rozwija, a ↑ / ↓ i tak chodzi
  po zestawach i ich układach. Czy osobne ← / → dla układów jest jeszcze potrzebne?
- Kolizja z zaznaczaniem kafelka (klik = zaznaczenie): czy strzałki mają też przesuwać zaznaczenie.
- Na końcu listy: zatrzymać się czy zawijać.
- To samo w panelu (easter egg).

## Tłumaczenia README (2026-11-27)

README po polsku, hiszpańsku i chińsku (`README.pl.md` itd., linki między nimi na górze).
Do ustalenia: kto utrzyma es i zh, czy tłumaczyć całość czy tylko górę + instalację.

## Automatyczne przełączanie układów (2026-11-27) — pomysł

Na razie tylko pomysł, bez decyzji o kształcie; szczegóły w
[docs/improvements.md](docs/improvements.md). Wrócić po pewnym czasie z ręcznym przełączaniem i
skrótami, jeśli go brakuje: pora dnia / dzień tygodnia albo uruchomione apki wybierają układ.
