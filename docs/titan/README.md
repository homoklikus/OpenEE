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

Wpisy atlasu: `zegar_symulacji.md` (etap 14), `przydzial_taktow.md` (etap 15), `rozkazy_gracza.md` (etap 16), `grupy_ruchu.md` (etap 17), `cele_jednostek.md` (etap 18), `przydzial_bliski.md` (etap 19), `przydzial_specjalny.md` (etap 20), `kolejka_rozkazow.md` (etap 21), `nawigacja_wejscie.md` (etap 22), `architektura_nawigacji.md` (etap 23), `astar_pola.md` i `astar_wyniki.md` (etap 24), `ruch_jednostki.md` i `ruch_trasa_przeszkody.md` (etap 25), `fizyka_terenu.md`, `kolizje_objazdy.md` i `skrypty_stanow.md` (etap 26), `precyzja_numeryczna.md`, `walidacja_kolizji.md`, `testy_referencyjne_ruchu.md` i `specyfikacja_ruchu_godot.md` (etap 27). Od etapu 28 ustalenia atlasu są implementowane w natywnym rdzeniu C++ – `docs/cpp/ARCHITEKTURA_CORE.md`. Mapa systemów, które jeszcze nie są rozpoznane, i plan prac: `docs/PLAN_REKONSTRUKCJI_TITAN.md` (etap 29). Etap 30: `walka.md` (podstawy walki), `import_mapy.md` (EEMap/EETile i import SCN do Core), `struktury_titan.md` (tabela generowana ze wspólnego opisu struktur `dane/titan/struktury_titan.json`). Etap 31: `walka.md` § 8–14 (wybór celu, podejście, łuk/obrót, przeładowanie AoC, obrażenia klas, cykl w Core). Etap 32: `walka.md` § 15–19 (zakończenie i przycięcie obrotu, cfg wysokości, tablice AoC, mgła, permutacja kandydatów). Etap 33: `walka.md` § 20–24 (morale z budynków w TakeDamage, obrót AoC, remisy, eksperymenty). Etap 34: `walka.md` § 25 (pełne reguły morale z budynków, efekty obszarowe), `rozkazy_gracza.md` § 7 (wybór obiektu pod kursorem). Etap 35: `rozkazy_gracza.md` § 8 (warunki rozkazu ataku gracza), `dziennik_eksperymentow.md` (dziennik eksperymentów z oryginałem).
Rejestr błędów oryginału (odtwarzanych wiernie, zasada w `CLAUDE.md`): `BLEDY_ORYGINALU.md`. Mapa postępu całej rekonstrukcji (podsystemy, oceny rozpoznania / implementacji / zgodności, pozostałe prace – od etapu 49): `POSTEP_REKONSTRUKCJI.md`. Pozostałe miejsca są opisane w innych dokumentach i przy następnej
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
| Walka: DealDamage, obszar, wysokość, tablica trafień, TakeDamage (vt+0x70), SetHP, upgrader HP, regeneracja, EEUGAttackUnit (konstruktor, vt+0x40, vt+0x64), UnitInWeaponRange, przeładowanie losowe AoC | 0x61DE61, 0x61DAE6, 0x61E500, 0x4D5F2C, 0x6172BC, 0x616F30, 0x638CBF, 0x625B47, 0x60AD45 / 0x60B26F / 0x60B5CB, 0x5F0CE8, – | –, –, –, –, –, –, 0x64F18D, –, – / 0x61D8DC / –, –, 0x5FEA22 | `docs/titan/walka.md` |
| Walka (etap 31): CanISeeEnemy, szukanie celu, przegląd stref, filtr i ocena kandydata, mgła, PrepareToMove → punkt podejścia (przechwycenie, sloty), zasięg punktowy, łuk/obrót, tryb fizyki 1, wejścia 2013/2021 | 0x61BFF4, 0x61AC11, 0x63969A, 0x639993 / 0x6399CA, 0x631B64, 0x6222A8 → 0x60AF05 (0x62C963, 0x62CF6A / 0x63234D, 0x60B9D8), 0x631935 / 0x631501, 0x61FC51 / 0x61FCAF, 0x54DA82, 0x61ADD7 / 0x61AF33 | wysokość 0x631918, wagi [0x8E60C0], przeładowanie [0x92FCA8]; reszta [N] | `docs/titan/walka.md` § 8–11 |
| Walka/ruch (etap 32): CompletedUnitFacing, przycięcie kroku obrotu, tryb 4 (obrót przy hamowaniu), tryb 3, modyfikator wysokości (cfg), mgła (kafel, licznik widoczności), permutacja listy kandydatów | 0x6153A3 → 0x614F52, 0x548477–0x5484B5, 0x54DE35 → 0x548920, 0x5488D1, 0x61E500 ([0x917BB8]), 0x631B64 → 0x40DD00 / 0x44E46E, 0x63969A → 0x40CFC7 | 0x631880 ([0x92FCA8]); tablice 0x8E870C / 0x8E8708 / 0x8E8710; reszta [N] | `docs/titan/walka.md` § 15–18 |
| Walka (etap 33): DealDamage (pełna ścieżka), TakeDamage, lista modyfikatorów, EEAEMoraleFromBuildings (test/zastosowanie, poziom), liczniki +0x2C4/+0x2C8, wybór najlepszego kandydata z osiągalnością | 0x61DE61, 0x6172BC, 0x664EA1, 0x6640BA / 0x6648CC / 0x664202 (vtable 0x835CA8), 0x5EDCA4, 0x639D1B–0x639D6B | obrót: 0x554738 (kody 3/4: 0x554980 / 0x5548D6), decyzja 0x554F56 | `docs/titan/walka.md` § 20–23 |
| Efekty obszarowe i morale (etap 34): fabryka, konstruktor EEAEMoraleFromBuildings, zliczanie domów, test odbiorcy, relacja, zestaw jednostek, usuwanie nadmiarowych, menedżer co 2000 ms, przeliczenie gracza; wybór obiektu pod kursorem (EEAMouseClick, 0x50EC37) | 0x663A73, 0x6641CA, 0x664214, 0x664B52, 0x664A89, 0x52BFA4, 0x664E0B, 0x663DBD (0x547742), 0x55C00E; 0x403CF1, 0x50EC37 | 0x67B911, 0x67B95B, 0x67C651, 0x67B634 (0x553C59); kamera 0x928D78, mysz [0x931924] | `docs/titan/walka.md` § 25, `docs/titan/rozkazy_gracza.md` § 7 |
| Mapa: EEMap (komórki, brzegi, szerokość), EETile, rejestracja nazw stanów / zdarzeń `.tai` | +0x1816D4…, 0x4039AC, 0x618E11 / 0x617C34 | +0x1955F0…, –, 0x62BAE6 / 0x62A81D | `docs/titan/import_mapy.md`, `docs/titan/walka.md` § 2 |

## Narzędzia

- Analiza statyczna: pefile + capstone w środowisku sesji, albo serwer `rea` (Cutter/rizin).
- Etap 30 – `narzedzia/titan/`: `indeks_pe.py` (indeks dostępów do pól, kandydaci funkcji), `struktury.py` (wspólny
  opis struktur: walidacja, mapa dostępu, spójność EE/AoC w parach funkcji, tabela atlasu), `rtti_titan.py` (vtable ↔
  klasa), `switch_titan.py` (przypadek instrukcji switch dla wartości), `eksport_mapy.py`, `pomiar_core.py`.
- Pomiary w grze: Riverlands_MCP:
  - odczyt pamięci, zegar gry (`ee_czas`), trajektorie (`ruch_czas`), kolizje (`ruch_analiza`);
  - start bez intra (`start_testowy`);
  - scenariusze testowe (`narzedzia/eksperymenty/scenariusz_testowy_*.py`).
