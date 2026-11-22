# TODO: pomysły

Pomysły na później. Plan wydania jest w [docs/distribution.md](docs/distribution.md).

## Easter egg: wahadłowiec zjada przestrzenie (2026-11-18)

**Stan (2026-11-19):** ✅ scenka w wierszu tytułu i wywołanie (`Sources/ShuttleEgg.swift`): klik =
kolor na 0,6 s, 10 kliknięć (≤ 0,4 s odstępu) = lot 2 s i okna w luku, po 1,5 s powrót na start;
„Ogranicz ruch” = bez lotu. ✅ (2026-11-21) nowy wygląd „panel” (`Sources/Panel.swift`, `docs/design-handoff.md`): odblokowany lotem, motyw 1–3 w ustawieniach.

**Gdzie:** w wierszu tytułu okna, na środku (2026-11-19; wcześniej obok napisu „SpaceDock”).

**Wygląd w spoczynku:** mała, mało szczegółowa, bezbarwna (jednokolorowa jak glif w pasku menu)
scenka w poziomie:
- wahadłowiec z naszej ikony, ustawiony poziomo, nosem w prawo;
- za nim ogień z silników;
- przed nim 3 ikonki przestrzeni, czyli 3 miniaturki okien jak w Mission Control.

**Klik w wahadłowiec:** wahadłowiec i ogień na chwilę dostają kolory (jak w ikonie apki), potem
kolory gasną i scenka wraca do bezbarwnej.

**10 szybkich kliknięć z rzędu:**
1. Wahadłowiec rusza do przodu i po kolei „zjada” 3 miniaturki okien.
2. Po każdym zjedzonym oknie w środku wahadłowca (w luku) przybywa jedna miniaturka, tak jak na
   ikonie apki: 1, potem 2, potem 3.
3. Po zjedzeniu wszystkich trzech odblokowuje się **zupełnie nowy wygląd apki**.

**Nowy wygląd (odblokowany):** zamiast standardowego wyglądu apki na macOS, motyw nawiązujący do
kosmosu i dokowania: przestrzenie / okienka „dokują” jak statki do stacji. Dotyczy całego okna
(lista zestawów, monitory, kafelki przestrzeni, ustawienia).

**Najpierw szkice**, dopiero potem kod:
- scenka w wierszu tytułu: stan bezbarwny, błysk koloru po kliknięciu, klatki animacji zjadania;
- 2–3 kierunki nowego wyglądu apki do wyboru.

**Do ustalenia:**
- Co liczy się jako „szybko”: np. 10 kliknięć, każde najwyżej 0,4 s po poprzednim?
- Czy nowy wygląd zostaje na stałe po odblokowaniu, czy tylko do zamknięcia apki? Jak wrócić do
  zwykłego wyglądu (przełącznik w ustawieniach, kolejne 10 kliknięć)?
- Gdy w systemie jest włączone „Ogranicz ruch”: krótsza animacja albo samo przejście bez lotu.
- Jasny i ciemny tryb dla obu wyglądów.
