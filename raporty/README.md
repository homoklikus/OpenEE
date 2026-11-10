# Raporty OpenEE

## Aktualny raport

[`RAPORT_ETAP_42.md`](../RAPORT_ETAP_42.md) – etap 42: siatka regionów 0x4240D3 odtworzona (39 480/39 480 pól), reguła przekątnej floodu podsektorów wyjaśniona rodzajem regionu (1857/1857), graf Core z wejścia mapy (619/620 jak gra); czysta mapa EE (oczyszczona kopia 231) z rozkazem ataku MCP potwierdzonym w grze i generator wariantów.
Leży w katalogu głównym repozytorium.

Bieżący stan projektu bez czytania raportów: [`docs/ARCHITEKTURA_OPENEE.md`](../docs/ARCHITEKTURA_OPENEE.md).

## Zasada przechowywania raportów

W katalogu głównym OpenEE leży **tylko jeden raport – najnowszy**. Przy kończeniu kolejnego etapu:

1. Utwórz nowy raport `RAPORT_*.md` w katalogu głównym.
2. Przenieś dotychczasowy aktualny raport do `raporty/archiwum/` (`git mv`, żeby Git widział przeniesienie).
3. Popraw odwołania do przeniesionego raportu (README, `docs/`, ten indeks, komentarze w kodzie i narzędziach).
4. Dopisz przeniesiony raport do listy poniżej i zaktualizuj sekcję „Aktualny raport”.
5. Zaktualizuj aktualności launchera `dane/launcher/aktualnosci.json`: nowy wpis na początku (raport w katalogu
   głównym), ścieżkę poprzedniego raportu zmień na `raporty/archiwum/…`.

Raportów nie tworzy się bezpośrednio w archiwum, chyba że chodzi o odzyskanie dokumentacji historycznej. Treści
zarchiwizowanych raportów nie zmienia się, poza poprawkami odnośników potrzebnymi do nawigacji; obalone wnioski
oznacza się adnotacją „[Etap … – zastąpione]”, bez usuwania pierwotnych obserwacji.

## Archiwum (`raporty/archiwum/`)

| Raport | Etap / wersja | Zakres |
|---|---|---|
| [`RAPORT_ETAP_1.md`](archiwum/RAPORT_ETAP_1.md) | 0.1 – etap 1 | audyt instalacji i warstw, czytniki SSA, DCL, SST, CEM 2.0, teren SCN, szkielet projektu Godot |
| [`RAPORT_ETAP_2.md`](archiwum/RAPORT_ETAP_2.md) | 0.2 – etap 2 | instalacja referencyjna GOG, CEM 1.3, tabele db, obiekty i kolory graczy, lokalizacja PL |
| [`RAPORT_LAUNCHER_UI.md`](archiwum/RAPORT_LAUNCHER_UI.md) | 0.2 – launcher | launcher PL/EN: instalacje, profile, język, nakładki, sceny podglądu |
| [`RAPORT_ETAP_3.md`](archiwum/RAPORT_ETAP_3.md) | 0.3 – etap 3 | teren według reguł EE, scenariusze EE 1.x, obrót obiektów z macierzy, MultiMesh |
| [`RAPORT_PUBLIKACJI_GITHUB.md`](archiwum/RAPORT_PUBLIKACJI_GITHUB.md) | 0.3.0-dev | pierwsza publikacja na GitHubie (GPLv3), testy bez danych komercyjnych |
| [`RAPORT_ETAP_4.md`](archiwum/RAPORT_ETAP_4.md) | 0.4.0-dev – etap 4 | animacje CEM, sekwencje dbgraphics, hierarchia części, animowana woda |
| [`RAPORT_ETAP_5.md`](archiwum/RAPORT_ETAP_5.md) | 0.5.0-dev – etap 5 | symulacja jednostek, nawigacja, A*, zaznaczanie i ruch myszą |
| [`RAPORT_NAPRAWA_GRAFIKI.md`](archiwum/RAPORT_NAPRAWA_GRAFIKI.md) | 0.5.1-dev | modele wielomateriałowe, wybór obrazu SST, kolor gracza |
| [`RAPORT_DIAGNOSTYKA_MODELI_051.md`](archiwum/RAPORT_DIAGNOSTYKA_MODELI_051.md) | 0.5.2-dev | tryb diagnostyczny modeli, porównanie rendererów, alfa, odrzucanie ścian, billboardy |
| [`RAPORT_KAMERA_EE_OPENEE.md`](archiwum/RAPORT_KAMERA_EE_OPENEE.md) | etap 6 | pierwsze pomiary kamery oryginału (Riverlands_MCP) |
| [`RAPORT_UKLAD_WSPOLRZEDNYCH_OPENEE.md`](archiwum/RAPORT_UKLAD_WSPOLRZEDNYCH_OPENEE.md) | etap 7 | przyczyna odbicia lustrzanego świata i naprawa (`UkladEE`) |
| [`RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md`](archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md) | etap 8 | grafika zależna od epoki, przezroczystość budynków (F5) |
| [`RAPORT_RUCH_GRUPOWY_EE.md`](archiwum/RAPORT_RUCH_GRUPOWY_EE.md) | etap 9 | zaznaczanie, szyk grupy, trasy, prędkość, porównanie trajektorii |
| [`RAPORT_KAMERA_OPENEE.md`](archiwum/RAPORT_KAMERA_OPENEE.md) | etap 10 | kamera wierna EE (pomiary AoC, kamera produkcyjna OpenEE) |
| [`RAPORT_EE_AOC_FORMATY.md`](archiwum/RAPORT_EE_AOC_FORMATY.md) | etap 11 | Empire Earth i The Art of Conquest na jednym silniku, formaty baz EE 1.0/AoC |
| [`RAPORT_ETAP_12_EE_AOC.md`](archiwum/RAPORT_ETAP_12_EE_AOC.md) | etap 12 | mechaniki podstawowego EE a AoC (kamera, zaznaczanie, ruch, grafika) |
| [`RAPORT_ETAP_13.md`](archiwum/RAPORT_ETAP_13.md) | etap 13 | start oryginałów bez intra, zegar gry, prędkość jednostek, kolizje grup |
| [`RAPORT_PORZADKI_ETAP_13_5.md`](archiwum/RAPORT_PORZADKI_ETAP_13_5.md) | etap 13.5 | porządki: audyt, martwy kod, dokument architektury, zasady atlasu Titan, kolejka zadań MCP |
| [`RAPORT_ETAP_14.md`](archiwum/RAPORT_ETAP_14.md) | etap 14 | zegar symulacji Titan: `EEPhysics`, krok 1000·G/n, pauza; EE ↔ AoC |
| [`RAPORT_ETAP_15.md`](archiwum/RAPORT_ETAP_15.md) | etap 15 | przydział taktów: serwer lockstep, 15 taktów co 350 ms, tempo 1,461, n = 44 (przepełnienie bajtu) |
| [`RAPORT_ETAP_16.md`](archiwum/RAPORT_ETAP_16.md) | etap 16 | droga rozkazu ruchu: `EEMPathTo`, kolejka serwera, takt komunikacji, wykonanie w `EEPhysics`; rejestr błędów oryginału |
| [`RAPORT_ETAP_17.md`](archiwum/RAPORT_ETAP_17.md) | etap 17 | grupy ruchu: podział zaznaczenia według środowiska, cel `EEUGLocation`, Shift jako flaga grupy, stan 8000 |
| [`RAPORT_ETAP_18.md`](archiwum/RAPORT_ETAP_18.md) | etap 18 | cele jednostek: szyk `EEFShortLine`, przydział daleki sortowaniem według klucza poprzecznego, `EEUGLocation` na jednostkę, BO-2 |
| [`RAPORT_ETAP_19.md`](archiwum/RAPORT_ETAP_19.md) | etap 19 | przydział bliski: jednostki po kolei biorą najbliższą wolną pozycję (prędkość, „Size of collider”, numer w grupie), BO-3 |
| [`RAPORT_ETAP_20.md`](archiwum/RAPORT_ETAP_20.md) | etap 20 | gałąź specjalna przydziału: ruch w szyku po przeciągnięciu PPM, kolejność grupy zamiast przydziału bliskiego/dalekiego |
| [`RAPORT_ETAP_21.md`](archiwum/RAPORT_ETAP_21.md) | etap 21 | kolejka celów jednostki: dopisywanie z Shift, zastępowanie zwykłym rozkazem, przejście do następnego celu w stanie „Idle”, BO-4 |
| [`RAPORT_ETAP_22.md`](archiwum/RAPORT_ETAP_22.md) | etap 22 | wejście do nawigacji: prośby o trasę grupy i jednostki, `EEPathManager`, punkty pośrednie +0x32, znaczniki celu +0x34 |
| [`RAPORT_ETAP_23.md`](archiwum/RAPORT_ETAP_23.md) | etap 23 | architektura tras: `EEPathManager`, `EEAIContinentManager`, sektory, podsektory, obszary, maszyny A*, budżety, kolejki odroczeń |
| [`RAPORT_ETAP_24.md`](archiwum/RAPORT_ETAP_24.md) | etap 24 | A* po polach: koszt 10/14, heurystyka 10·Manhattan, kolejność sąsiadów i reguła narożników, lista otwarta z kubełkami, koniec trasy w najbliższym dostępnym węźle, kolejka +0x7C jednostki, `Bounded`; model zgodny z pomiarami; BO-5, BO-6 |
| [`RAPORT_ETAP_25.md`](archiwum/RAPORT_ETAP_25.md) | etap 25 | ruch jednostki: maszyna stanów, takt, prędkość (±a·dt, dyskretna droga hamowania), obrót trapezowy, zaliczanie punktów, przeszkody, Shift, punkty +0x32, niezależny model; BO-7 |
| [`RAPORT_ETAP_26.md`](archiwum/RAPORT_ETAP_26.md) | etap 26 | etap 26: fizyka terenu (wysokość, nachylenie, prędkość na stoku), test kroku, kolizje i objazdy, skrypty stanów `.tai`, parametry szyku, weryfikacja BO-6 i BO-7, model ruchu całego przebiegu (EE i AoC) |
| [`RAPORT_ETAP_27.md`](archiwum/RAPORT_ETAP_27.md) | etap 27 | etap 27: UMArcTan2 i tablice trygonometryczne z DLL, precyzja x87 i zapisy f32, przyczyna rozbieżności AoC 505 (obrót AoC), walidacja odpychania, RNG i determinizm, BO-8/BO-9′, k = 2,0, model v4, testy referencyjne i specyfikacja ruchu dla Godota |
| [`RAPORT_ETAP_28.md`](archiwum/RAPORT_ETAP_28.md) | etap 28 | etap 28: natywny rdzeń OpenEE Core w C++20 (matematyka Titan z tablicami DLL, generator, teren, fizyka EE/AoC, maszyna stanów, odpychanie), GDExtension (godot-cpp 10.0.0, API 4.7), testy S1–S7 bitowo w Debug i Release, scena diagnostyczna |
| [`RAPORT_ETAP_29.md`](archiwum/RAPORT_ETAP_29.md) | etap 29 | etap 29: A* po polach, test kroku, kolizje w takcie i kolejka celów w OpenEE Core (C++), porównanie Core z pomiarami EE/AoC, rejestracja wielu jednostek w Riverlands_MCP, mapa systemów Titan i prognoza rekonstrukcji |
| [`RAPORT_ETAP_30.md`](archiwum/RAPORT_ETAP_30.md) | etap 30 | etap 30: import rzeczywistych map SCN do OpenEE Core, schemat struktur Titan i narzędzia statyki, narzędzie pomiar → Core, kamera i kolejka celów w Riverlands_MCP, początek rekonstrukcji walki (pojedynek wręcz EE odtworzony bez różnic), aktualizacja prognozy |
| [`RAPORT_ETAP_31.md`](archiwum/RAPORT_ETAP_31.md) | etap 31 | etap 31: pełny cykl ataku w OpenEE Core (wybór celu z wagami z gry, podejście i pościg, zasięg, łuk i obrót, atak, przeładowanie, śmierć), przeładowanie AoC 0x5FEA22, obrażenia klas, walka zintegrowana ze `Swiat`, API walki w GDExtension, porównanie Core z grą, aktualizacja prognozy |
| [`RAPORT_ETAP_40.md`](archiwum/RAPORT_ETAP_40.md) | etap 40 | etap 40: graf podsektorów odczytany z gry, A* grafu i punkty pośrednie, osiągalność 0x62D696, obie gwardie zgodne co takt w 616/619/620 |
| [`RAPORT_ETAP_41.md`](archiwum/RAPORT_ETAP_41.md) | etap 41 | etap 41: kroki budowy grafu podsektorów z kodu, sąsiedzi 0x4246E8 i punkty 0x42C2D5 w Core (1857/1857, 1851/1857), 619/620 z przydziałem pól z gry |
| [`RAPORT_ETAP_39.md`](archiwum/RAPORT_ETAP_39.md) | etap 39 | etap 39: zajętość miejsc podejścia (0x63234D) w Core, 578 G3 bliżej gry, pośrednie EEUGLocation jako etap grafu podsektorów, potwierdzanie rozkazów MCP stanem gry, scenariusz e39_a |
| [`RAPORT_ETAP_38.md`](archiwum/RAPORT_ETAP_38.md) | etap 38 | etap 38: pełne odtworzenie e35_a z bohaterem, regeneracja HP (0x625B47), obrót trybu 1 do EEUGLocation, gwardia zgodna co takt w całych 616/619/620/622, eksperyment B1 |
| [`RAPORT_ETAP_37.md`](archiwum/RAPORT_ETAP_37.md) | etap 37 | etap 37: przyczyna rozbieżności stanu 9006 (tryb 5 i 9014 zależne od rodzaju celu, kurs końcowy PPM = kąt szyku), ponowny wybór nieosiągalnego celu (licznik ≤ 25, mapa celów nieosiągalnych na 30 s); Core zgodny co takt z 616/619/620 znacznie dłużej |
| [`RAPORT_ETAP_36.md`](archiwum/RAPORT_ETAP_36.md) | etap 36 | etap 36: pierwsza grywalna potyczka w Godocie (ruch i walka wręcz w OpenEE Core, sterowanie EE, wynik, restart), pomiary 619–620, rozkaz ataku gracza zgodny z grą co takt, poprawiona interpretacja 616 |
| [`RAPORT_ETAP_35.md`](archiwum/RAPORT_ETAP_35.md) | etap 35 | etap 35: nowa metodologia eksperymentów (scenariusz `e35_a`, dziennik 602–618), przyczyny niepowodzeń PPM (mgła, zwłoki, błędny rzut MCP), działający rozkaz ataku gracza przez MCP, warunki EEMAttackUnit w `EEAMouseClick`, lista braków do potyczki |
| [`RAPORT_ETAP_34.md`](archiwum/RAPORT_ETAP_34.md) | etap 34 | etap 34: pełne reguły morale z budynków liczone w Core (5/5 okien zgodnych z grą), mechanizm wyboru obiektu pod kursorem, próby rozkazu ataku MCP, śmierć celu i kolejka, mapa statyczna pocisków |
| [`RAPORT_ETAP_33.md`](archiwum/RAPORT_ETAP_33.md) | etap 33 | etap 33: współczynnik obrażeń 0,8 wyjaśniony (morale z budynków, EEAEMoraleFromBuildings w TakeDamage), obrót AoC z kodu 0x554738 (AoC 505: pierwszy rozbieżny takt 224 → 803), próby rozkazu ataku przez MCP, wycofanie w trakcie walki i pościg AI, remisy i osiągalność w wyborze celu |
| [`RAPORT_ETAP_32.md`](archiwum/RAPORT_ETAP_32.md) | etap 32 | etap 32: pomiary odporne na wygaszacz ekranu, pierwsza rozbieżność walki EE wyjaśniona kodem Titan (zakończenie i przycięcie obrotu, obrót w trybie 4), 578 G1 zgodny w każdym takcie, cfg wysokości i tablice obrażeń AoC, statyka mgły i kolejności kandydatów |
