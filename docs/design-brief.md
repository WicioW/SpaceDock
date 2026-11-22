# SpaceDock: brief do zakładki Design (motyw „wnętrze statku”)

Dołącz razem z tym plikiem: `docs/design-research.md` (elementy, palety, zasady, źródła),
`assets/icon/AppIcon.svg` (wahadłowiec), zdjęcia wzorcowe (kokpit wahadłowca, panele z anime).

## Cel

Ukryty, alternatywny wygląd całej apki SpaceDock (odblokowany easter eggiem: 10 szybkich kliknięć w
wahadłowiec w wierszu tytułu). Ma wyglądać jak neonowy panel sterowania z anime lat 80./90. i jak
wnętrze statku kosmicznego: gęsto, futurystycznie, z wykresami, wskaźnikami i odczytami. Nie
uproszczony panel, nie „stara fabryka”. Układ może być zupełnie inny niż w obecnej apce.

## Co to za apka (treść, którą każdy projekt musi pokazać)

SpaceDock (macOS, pasek menu + okno) zapamiętuje kolejność przestrzeni (Spaces: apki na pełnym
ekranie i biurka) osobno dla każdego zestawu monitorów i przywraca ją po podłączeniu/odłączeniu kabla.

- **Zestawy monitorów:** np. „Sam laptop”, „Laptop + DELL G3223Q”, „Laptop + DELL + PL2779Q”;
  jeden jest podłączony teraz, jeden wybrany do podglądu.
- **Status zestawu:** zgodny z zapisem / inny niż zapis / brak zapisu / niepodłączony.
- **Monitory zestawu** (1–3, ułożone jak na biurku), na każdym przestrzenie w kolejności:
  numer, ikona apki, nazwa apki, tytuł okna (np. karta w Brave), numer okna.
- **Różnice z zapisem:** przestrzeń „nie zapisana” (jest na pasku, nie ma jej w zapisie, np.
  Docker) i „nie otwarta” / „nie na pełnym ekranie” (jest w zapisie, nie ma jej teraz).
- **Akcje:** „Zapisz obecny układ” (nadpisanie pyta o potwierdzenie), „Przywróć”.
- **Ustawienia:** przywracanie Ręcznie/Automatycznie, zapis Ręcznie/Automatycznie, metoda
  Przeciąganie / Pełny ekran / Bezpośrednio (Przeciąganie niedostępne bez Karabinera), język
  (PL/EN/ES/ZH), uruchamiaj przy logowaniu, stan „automat pilnuje monitorów” / „brak uprawnienia”.
- **Odczyty:** czas ostatniego ułożenia (np. 0,29 s), liczba ruchów, postęp w trakcie przywracania.
- **Wiersz tytułu macOS:** 3 kółka okna po lewej, „SpaceDock”, na środku mały wahadłowiec z ikony
  (widok z góry, otwarty luk, 3 miniaturki okien przed nosem).

Przykładowe dane: Sam laptop = Biurko, Claude, Brave („Raport.pdf”), Brave („Status”),
Fork, IntelliJ IDEA, Bitwarden + Docker niezapisany.

## Trzy kierunki (szczegóły w design-research.md)

- **A. Neonowa konsola (lata 80.):** rząd ekranów CRT u góry (jeden na monitor, boczne pochylone,
  cyjanowe okręgi wektorowe, magentowe linie konstrukcyjne, białe przekątne); pod nimi pulpit z
  matrycą płaskich, kolorowych bloków-klawiszy (żółty, zielony, czerwony, niebieski) na zestawy,
  ustawienia i akcje; lampki kontrolne, cyfry siedmiosegmentowe. Matowy brąz/czerń, świeci tylko
  to, co aktywne.
- **B. Centrum dowodzenia (lata 90.):** czarna próżnia, pomarańcz/czerwień, czerwony pionowy pas
  z kwadratowymi przyciskami zestawów, ogromne konturowe cyfry, lista kontrolna z „OK”, stos faz
  przywracania, dwie splecione fale (zapis vs stan teraz) z przestrzeniami jako węzłami,
  celowniki „+”, pieczątka statusu, taśma ostrzegawcza tylko przy przywracaniu.
- **C. Radar dokowania:** okrągły radar (pierścienie, skala namiaru, wiązka skanu z poświatą);
  zestaw monitorów to stacja w środku, monitory to porty, przestrzenie to statki w kolejce do
  portów (apka = trójkąt, biurko = kwadrat, „nie zapisany” = żółty romb poza kolejką, „nie
  otwarty” = przerywany kontur); kasety zestawów na dole, suwaki ustawień z prawej, lista
  kontrolna z lewej, „zapisz” pod odchylaną osłoną.

## Ograniczenia

- **Oryginalny design:** bez nazw, logo, postaci, symboli i napisów z Akiry, Evangeliona (NERV,
  MAGI, SEELE, EVA…) ani innych serii. Styl gatunku tak, kopie nie.
- **Okno macOS:** min. 780 × 420 pt, typowo ok. 1100 × 700; wiersz tytułu 30 pt; ciemny motyw.
- **Do wdrożenia w SwiftUI:** grafika 2D (kształty, linie, tekst, gradienty, poświata), bez 3D;
  animacje proste (skan, miganie, przesuw), z wersją dla „Ogranicz ruch”.
- **Czytelność:** status zawsze też słowem lub kształtem, nie tylko kolorem; tekst min. 11 pt;
  etykiety po polsku (opcjonalnie japońskie obok, np. 保存 / 復元).

## Co ma powstać

Dla każdego kierunku (A, B, C):
1. Całe okno, zestaw „Sam laptop”, stan „inny niż zapis” (Docker niezapisany, IntelliJ nieotwarty).
2. To samo dla zestawu z 2 i 3 monitorami.
3. Stan w trakcie przywracania (postęp, kroki).
4. Arkusz elementów: przyciski, przełączniki, wybór metody, statusy, kafelek przestrzeni we
   wszystkich stanach.

Potem wybieramy jeden kierunek i przekazujemy go do Claude Code do wdrożenia w apce.
