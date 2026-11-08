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

Wpisy atlasu: `zegar_symulacji.md` (etap 14), `przydzial_taktow.md` (etap 15), `rozkazy_gracza.md` (etap 16), `grupy_ruchu.md` (etap 17), `cele_jednostek.md` (etap 18), `przydzial_bliski.md` (etap 19), `przydzial_specjalny.md` (etap 20), `kolejka_rozkazow.md` (etap 21), `nawigacja_wejscie.md` (etap 22), `architektura_nawigacji.md` (etap 23), `astar_pola.md` i `astar_wyniki.md` (etap 24), `ruch_jednostki.md` i `ruch_trasa_przeszkody.md` (etap 25), `fizyka_terenu.md`, `kolizje_objazdy.md` i `skrypty_stanow.md` (etap 26), `precyzja_numeryczna.md`, `walidacja_kolizji.md`, `testy_referencyjne_ruchu.md` i `specyfikacja_ruchu_godot.md` (etap 27). Od etapu 28 ustalenia atlasu są implementowane w natywnym rdzeniu C++ – `docs/cpp/ARCHITEKTURA_CORE.md`.
Rejestr błędów oryginału (odtwarzanych wiernie, zasada w `CLAUDE.md`): `BLEDY_ORYGINALU.md`. Pozostałe miejsca są opisane w innych dokumentach i przy następnej
analizie zostaną przeniesione do atlasu:

| Funkcja | EE | AoC | Dokument |
|---|---|---|---|
| Intro startowe (lista `Movies\*.bik`, pętla odtwarzania) | 0x538867 (wywołanie 0x535EE5) | 0x5439B5 (wywołanie 0x5410BA) | `Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 17 |
| Parsowanie wiersza poleceń (`hostgame`, `joinbyip`) | – | 0x52D9E5 | jw. |
| Tryb przezroczystości budynków (F5) | – | opis w raporcie | `raporty/archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md` |
| Zegar symulacji: wątek, takt `EEPhysics`, komunikat taktów, ustawienie n, krok, reset | 0x5532FB, 0x546C63, 0x5470B0, 0x553663, 0x5476C1, 0x54650E | 0x56140C, 0x553082, 0x55355C, 0x561774, 0x553BD8, 0x552909 | `docs/titan/zegar_symulacji.md` |
| Przydział taktów: serwer lockstep (DLL `Send`, `SendCommunicationsTick`, `TuneForSlowCPU`), komunikat 0x26 → 0x28 w EXE | DLL 0x10055D2E, 0x10054AB8, 0x10055099; EXE 0x4C3839 | DLL 0x10049D13, 0x10048A9D, 0x1004907E; EXE 0x4CBC77 | `docs/titan/przydzial_taktow.md` |
| Rozkaz ruchu: `EEAMouseClick` +0x0C / +4, `EEMPathTo` (Export/Execute), `EEServer` +0x60, wykonanie poleceń w `EEPhysics` | 0x403CF1, 0x403AA1, 0x4BA0A0, 0x4B9D7B, 0x4C3D90, 0x547263 | 0x403350, 0x403009, 0x4C2B41, 0x4C281C, 0x4CC1F9, pętla w 0x55355C | `docs/titan/rozkazy_gracza.md` |
| Grupy ruchu: wypełnienie, warunek przebiegu, cel `EEUGLocation`, ustawienie celu, maszyna stanów grupy, flagi środowiska typu | 0x5DD18B, 0x5DD2D8, 0x614D47, 0x5DD436, 0x5DD463, 0x61CCEC | 0x5ED9D4, 0x5EDB21, 0x627742, 0x5EDC93, 0x5EDCC0, 0x62FD1C | `docs/titan/grupy_ruchu.md` |
| Cele jednostek: obsługa stanu 8000, układ szyku liniowego, `EEFormation` vtable +4 | 0x5DB641, 0x4D79D9, 0x4D7E0B | 0x5EBF85, 0x4DD9A3, 0x4DDDD5 | `docs/titan/cele_jednostek.md` |
| Przydział bliski: ścieżka bliska stanu 8000, kąt względem osi +y, sortowanie i porównanie jednostek | 0x5DC364, 0x62D460, 0x5DFBB9, 0x5E0641 | 0x5ECCA1, 0x642345, 0x5F0627, 0x5F109A | `docs/titan/przydzial_bliski.md` |
| Gałąź specjalna przydziału: warunek +0xB6 / kolizja / +0x70, parametry ruchu grupy, `EEUICCommandUnits` (naciśnięcie, ruch, zwolnienie PPM) | 0x5DBE35, 0x5DCE49, 0x641C7F, 0x64198C, 0x641B53 | 0x5EC790, 0x5ED692, 0x65829C, 0x657FA9, 0x658170 | `docs/titan/przydzial_specjalny.md` |
| Kolejka celów jednostki: dopisanie (Shift), zdjęcie z aktywacją następnego, wyczyszczenie, ustawienie, wejście w stan „Idle”, `EEUGLocation` aktywacja | 0x4412D4, 0x5EAE25, 0x5E9664, 0x5F05BD, 0x61AD41, 0x61529E | 0x43D416, 0x5F88FE, 0x5F6FBC, 0x5FE863, 0x62DB0F, 0x627C99 | `docs/titan/kolejka_rozkazow.md` |
| Wejście do nawigacji: prośba grupy o trasę, `EEPathManager`, zastosowanie trasy, punkty +0x32, „PrepareToMove” jednostki | 0x5DB4B8, 0x5F670A, 0x4A15E7, 0x5F6809, 0x5EDF6B, 0x6222A8, 0x4A1AFF | 0x5EBDFC, 0x606581, 0x4A6948, 0x606680, 0x5FC0A8, 0x63674B, 0x4A6E88 | `docs/titan/nawigacja_wejscie.md` |
| Architektura tras: `EEPathManager` (uruchomienie maszyny, wybór maszyny grafu, zakończenie, prośba po polach, takt i kolejki), `EEAIContinentManager`, maszyny A* (graf, pola, `Bounded`), budżety | 0x4A1681, 0x4A1351, 0x4A26E3, 0x4A13EE, 0x4A396B, 0x917BC8, 0x4A5428, 0x4A0CE8, 0x4A0E2F | 0x4A69E2, 0x4A6687, 0x4A7B03, 0x4A6724, 0x4A8DB8, –, 0x4AA98D, 0x4A6010, 0x4A6157 | `docs/titan/architektura_nawigacji.md` |
| A* po polach: pętla, dodanie sąsiada, koszt, test celu, lista otwarta (wstaw, zdejmij), koniec trasy, odtworzenie trasy, przekazanie (łączenie, zapis), `Bounded` | 0x4A5428, 0x4A5E13, 0x41CFFF, 0x41CCA8, 0x41F876, 0x420030, 0x4A5D16, 0x41CE5F, 0x4A2B29, 0x5EE4E6, 0x4A24E1 | 0x4AA98D, 0x4AB504, 0x40EE51, 0x4191D1, 0x41BAAE, 0x41C268, 0x4AB407, 0x419388, 0x4A7F4A, 0x5FC61B, 0x4A78C1 | `docs/titan/astar_pola.md`, `docs/titan/astar_wyniki.md` |
| Ruch jednostki: krok jednostki, maszyna stanów (krok, przejście, wejście w stan, zdarzenia), switch trybu ruchu, tryb 0 / 4 / 5, obrót, prędkość (wartość, decyzja), gettery z grupą, kolizje i odpychanie, punkt trasy (odczyt, pozostała długość, zdjęcie), test osiągnięcia, 9016 | 0x547E0E, 0x5F0F7E, 0x618CCB, 0x61AD41, 0x61B677, 0x549F82, 0x54D7AE, 0x54DE35, 0x54E0F1, 0x548266, 0x54858E, 0x548645, 0x5DD355, 0x549E61, 0x5EC69D, 0x5EC655, 0x5EDCF4, 0x6213D8, 0x5F0844 | 0x5540DC, 0x5FF2E8, 0x62B9A0, 0x62DB0F, 0x62E47A, 0x556897, 0x55A0DB, 0x55A791, 0x55AA64, 0x554738, 0x554BDE, 0x554CB2, 0x5EDC93 (grupa), 0x556710, 0x5FA229, 0x5FA1E1, 0x5FBDD1, 0x6353BB, 0x5FEB61 | `docs/titan/ruch_jednostki.md`, `docs/titan/ruch_trasa_przeszkody.md` |
| Teren i kolizje: wysokość (GetMeshZ, DLL), nachylenie / przechył, test kroku, przycięcie do brzegu, zapis pozycji i komórki, kontakty, odpychanie małe / duże / zastosowanie, ObstacleDetected (RNG), objazd, parser i ocena `.tai`, grupa, parametry ruchu (init, SetSpeed) | 0x4C0201 (DLL 0x1003B6AC), 0x51216A / 0x512257, 0x54E275, 0x549FF3, 0x5F043B / 0x616F9D, 0x5E8F0E, 0x549179 / 0x548A3C / 0x549A08, 0x61BD3F (DLL 0x10002117), 0x6225E7 / 0x4A1E11, 0x619B9D / 0x618ED9 / 0x619FF5, 0x5DCE49, 0x627942 / 0x628051 | 0x4C0894 (DLL 0x1002A185), 0x51C75A / 0x51C847, 0x55ABE8, 0x556908, 0x5FE611 / 0x629AC3, 0x5F6817, 0x555984 / 0x555247 / 0x556213, 0x62EC75 (DLL 0x1000DDE9), 0x636B69 / 0x4A71C9, 0x62C8BD / 0x62BBAE / 0x62CD8B, 0x5ED692, 0x63C005 | `docs/titan/fizyka_terenu.md`, `docs/titan/kolizje_objazdy.md`, `docs/titan/skrypty_stanow.md` |
| Struktury pamięci (kamera, gra, gracze, jednostki, ekrany) | `ee_warianty.KOMPILACJE` | `ee_warianty.KOMPILACJE` | `Riverlands_MCP/riverlands_mcp/ee_warianty.py` |

## Narzędzia

- Analiza statyczna: pefile + capstone w środowisku sesji, albo serwer `rea` (Cutter/rizin).
- Pomiary w grze: Riverlands_MCP:
  - odczyt pamięci, zegar gry (`ee_czas`), trajektorie (`ruch_czas`), kolizje (`ruch_analiza`);
  - start bez intra (`start_testowy`);
  - scenariusze testowe (`narzedzia/eksperymenty/scenariusz_testowy_*.py`).
