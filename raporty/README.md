# Raporty OpenEE

## Aktualny raport

[`RAPORT_PORZADKI_ETAP_13_5.md`](../RAPORT_PORZADKI_ETAP_13_5.md) – etap 13.5: porządkowanie projektu przed dalszą
rekonstrukcją silnika Titan. Leży w katalogu głównym repozytorium.

Bieżący stan projektu bez czytania raportów: [`docs/ARCHITEKTURA_OPENEE.md`](../docs/ARCHITEKTURA_OPENEE.md).

## Zasada przechowywania raportów

W katalogu głównym OpenEE leży **tylko jeden raport – najnowszy**. Przy kończeniu kolejnego etapu:

1. Utwórz nowy raport `RAPORT_*.md` w katalogu głównym.
2. Przenieś dotychczasowy aktualny raport do `raporty/archiwum/` (`git mv`, żeby Git widział przeniesienie).
3. Popraw odwołania do przeniesionego raportu (README, `docs/`, ten indeks, komentarze w kodzie i narzędziach).
4. Dopisz przeniesiony raport do listy poniżej i zaktualizuj sekcję „Aktualny raport”.

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
