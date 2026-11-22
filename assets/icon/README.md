# Ikona aplikacji

Wahadłowiec z otwartym lukiem, w którym leżą miniatury okien (wariant „R” z projektu ikony).

| Plik | Do czego |
|---|---|
| `AppIcon.svg`, `AppIcon-1024.png` | ikona domyślna, źródło |
| `AppIcon-dark.svg`, `AppIcon-dark-1024.png` | wariant do trybu ciemnego |
| `AppIcon-clear.svg`, `AppIcon-clear-1024.png` | wariant przezroczysty (Clear) |
| `AppIcon-tinted.svg`, `AppIcon-tinted-1024.png` | wariant zabarwiony (Tinted) |
| `AppIcon.iconset/` | wszystkie rozmiary 16–1024 dla `iconutil` |
| `AppIcon.icns` | gotowa ikona do `Contents/Resources` bundla |
| `MenuBarIconTemplate.svg`, `MenuBarIconTemplate.png`, `MenuBarIconTemplate@2x.png` | jednokolorowy glif do paska menu (18 / 36 px), obraz szablonu: czarny na przezroczystym, system sam odwraca kolor |

Odtworzenie `.icns` po zmianie PNG:

```sh
iconutil -c icns AppIcon.iconset -o AppIcon.icns
```
