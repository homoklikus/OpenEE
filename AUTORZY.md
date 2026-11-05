# Autorzy i elementy zewnętrzne

## OpenEE
Projekt: homoklikus (2026), z pomocą asystenta AI Claude (Anthropic). Licencja: GPLv3 (`LICENSE`).

## Elementy zewnętrzne zawarte w repozytorium
| Element | Pochodzenie | Licencja | Wykorzystanie |
|---|---|---|---|
| `dane/schemat_db_eedbeditor/AOC/*.dats`, `README.txt`, `LICENSE` | **EE DB Editor**, autor: Forlini91 (projekt społeczności Empire Earth) | GNU GPL v3 | opis pól tabel `db*.dat` (nazwy, rozmiary, typy) – pliki bez zmian |
| `dane/uklad_db.json` | wygenerowany z powyższego schematu przez `narzedzia/eeformaty/db.py` | GNU GPL v3 (utwór zależny) | układ pól dla dekodera GDScript |

Kod dekoderów (`narzedzia/eeformaty/db.py`, `godot/silnik/importery/baza_db.gd`) jest własny – nie zawiera kodu EE DB Editor.
Z pakietu schematu pominięto plik `language.txt` (zawiera teksty gry).

## Narzędzia (niezawarte)
* **Godot Engine** (MIT) – silnik; nie jest dołączany do repozytorium.
* Analiza formatów: Ghidra (Apache 2.0) – używana lokalnie, jej wyniki nie są publikowane; publikowane są wyłącznie opisy.

## Dokumentacja formatów
Część ustaleń o formatach pochodzi z lokalnego laboratorium projektu (analiza plików i zachowania gry); wszystkie opisy
w `docs/` zostały napisane od nowa. Nazwy struktur modeli CEM są zgodne z publiczną dokumentacją crate `cem` (Rust).

## Znaki towarowe
„Empire Earth” jest znakiem towarowym jego właścicieli. OpenEE nie jest z nimi powiązany.
