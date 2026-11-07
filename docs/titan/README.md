# Atlas funkcji silnika Titan (Empire Earth / The Art of Conquest)

Ten katalog będzie zbierał wyniki analizy kodu oryginalnych plików wykonywalnych: co robi dana funkcja, jak i gdzie
ma odpowiednik w OpenEE. Na razie zawiera tylko zasady. Nowy dokument powstaje dopiero wtedy, gdy podsystem jest
rzeczywiście badany; pustych plików na zapas nie zakładamy.

## Zasady

- Analiza dotyczy wyłącznie legalnie posiadanych plików użytkownika. Do repozytorium nie trafiają pliki exe,
  zdekompilowany kod w całości, zrzuty pamięci ani zasoby gry. Dokument opisuje zachowanie własnymi słowami i
  podaje krótkie fragmenty (adresy, kilka instrukcji, sygnatury bajtów) tylko tam, gdzie są potrzebne do weryfikacji.
- Każde ustalenie ma poziom pewności:
  - **[P]** – potwierdzone pomiarem w działającej grze albo testem;
  - **[W]** – wniosek z kodu, sprawdzony częściowo;
  - **[H]** – hipoteza z kodu, niesprawdzona;
  - **[N]** – nieustalone.
- Analiza statyczna (kod) i pomiar w grze (Riverlands_MCP) się uzupełniają. Algorytm wpisany do OpenEE wymaga
  przynajmniej jednego pomiaru w grze albo testu porównawczego.

## Warianty plików wykonywalnych

Adresy są ważne tylko dla danej kompilacji. Każdy dokument podaje, której dotyczy.

| Gra | Plik | SHA-256 | Uwagi |
|---|---|---|---|
| Empire Earth | `Empire Earth.exe` | `e352d7ae5ebc91f8d2f9c4363e41e990d7be8b063b1ee9e686a0d2a5f9bea2b5` | GOG + NeoEE (instalacja społecznościowa), baza obrazu 0x400000 |
| The Art of Conquest | `EE-AOC.exe` | `db8fc5ceb85dbb9bb7e47804e15f1a025373efe995948cddc5b3d05605797f52` | GOG + NeoEE, baza obrazu 0x400000 |

Kopie testowe bez filmów startowych mają inne sumy, ale ten sam układ kodu poza 6 bajtami
(`Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 17).

## Szablon wpisu

Jeden plik na podsystem, np. `docs/titan/ruch_jednostek.md`. W pliku jedna sekcja na funkcję:

```markdown
### <nazwa robocza funkcji>

| | EE (`Empire Earth.exe`, e352d7ae…) | AoC (`EE-AOC.exe`, db8fc5ce…) |
|---|---|---|
| adres funkcji | 0x… | 0x… |
| wywołania (skąd) | 0x… (opis) | 0x… |

- **Przeznaczenie:** jedno–dwa zdania.
- **Wejścia:** argumenty, rejestry, pola struktur czytane przez funkcję.
- **Wyjścia:** wartość zwracana, zapisywane pola, efekty uboczne.
- **Struktury:** używane obiekty i przesunięcia pól (np. `A_GRA+0xD0` – ms czasu gry); odsyłacz do opisu struktury.
- **Zależności:** wywoływane funkcje, dane z tabel `db*.dat`, stałe.
- **Algorytm:** opis kroków własnymi słowami, z pseudokodem tylko tam, gdzie jest potrzebny.
- **Pewność:** [P]/[W]/[H]/[N] dla każdego istotnego twierdzenia.
- **Weryfikacja:** jak sprawdzono – zadanie MCP (`Testy_MCP/ee_zadania/<nr>`), test Godota, porównanie trajektorii,
  pułapka w kodzie (breakpoint).
- **Odpowiednik w OpenEE:** plik i funkcja (np. `godot/silnik/symulacja/sciezki.gd: Sciezki.znajdz`) albo „brak”.
```

## Już ustalone miejsca w kodzie

Opisane w innych dokumentach, przy następnej analizie do przeniesienia tutaj:

| Funkcja | EE | AoC | Dokument |
|---|---|---|---|
| Intro startowe (lista `Movies\*.bik`, pętla odtwarzania) | 0x538867 (wywołanie 0x535EE5) | 0x5439B5 (wywołanie 0x5410BA) | `Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 17 |
| Parsowanie wiersza poleceń (`hostgame`, `joinbyip`) | – | 0x52D9E5 | jw. |
| Tryb przezroczystości budynków (F5) | – | opis w raporcie | `raporty/archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md` |
| Struktury pamięci (kamera, gra, gracze, jednostki, ekrany) | `ee_warianty.KOMPILACJE` | `ee_warianty.KOMPILACJE` | `Riverlands_MCP/riverlands_mcp/ee_warianty.py` |

## Narzędzia

- Analiza statyczna: pefile + capstone w środowisku sesji, albo serwer `rea` (Cutter/rizin).
- Pomiary w grze: Riverlands_MCP:
  - odczyt pamięci, zegar gry (`ee_czas`), trajektorie (`ruch_czas`), kolizje (`ruch_analiza`);
  - start bez intra (`start_testowy`);
  - scenariusze testowe (`narzedzia/eksperymenty/scenariusz_testowy_*.py`).
