# Schemat tabel db*.dat – pochodzenie

Pliki `AOC/*.dats`, `README.txt`, `LICENSE` pochodzą z projektu społeczności **EE DB Editor** (autor: Forlini91),
licencja **GNU GPL v3** (plik `LICENSE`). Skopiowane bez zmian z `EmpireEarth test/analysis/external_schema_eedbeditor`
(gdzie trafiły w ramach wcześniejszej analizy laboratorium).

OpenEE używa schematu wyłącznie jako opisu układu pól (nazwy, rozmiary, typy). Dekoder jest własny
(`narzedzia/eeformaty/db.py`, `godot/silnik/importery/baza_db.gd`) i jest weryfikowany przez zużycie co do bajta
każdej tabeli. **Licencja:** OpenEE jest udostępniany na GPLv3 (decyzja autora projektu, 2026-11-05), co pozwala dystrybuować ten
schemat razem z projektem. Plik `AOC/language.txt` z pakietu EE DB Editor (teksty gry) nie jest publikowany (.gitignore).
