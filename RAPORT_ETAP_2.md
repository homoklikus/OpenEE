# OpenEE – raport etapu 2
Czysta instalacja referencyjna, separacja modów, polska lokalizacja, poprawa renderowania.

## Wyniki w skrócie
| Zadanie | Wynik |
|---|---|
| 1. Instalacja referencyjna | GOG build 58180155540805121, gra + AoC; **602/602 MD5 zgodne z hashdb GOG**; brak dodatków (sprawdzone na treści) |
| 2. Porównanie | 522 identyczne, 61 zmienionych, 33 tylko GOG, 1714 tylko społ.; w `data.ssa` EE zmienione **wyłącznie** 462 głosy; 252 luźne zamienniki (0 równych oryginałowi) |
| 3. Wybór instalacji | `[instalacje]` + `[zrodlo] gra=` (domyślnie referencyjna), warstwy niezależne od ścieżki, mieszane archiwa obsłużone |
| 4. Importery | CEM 1.3 (11/11 co do bajta), tabele db wg schematu (39/39 AoC), kolor gracza, obiekty scenariusza (18/18 AoC), mozaika wariantów tekstur, billboardy |
| 5. Test graficzny | scenariusz kampanii Rzym z GOG: teren, tekstury, woda, 685 obiektów, budynki, jednostki, kolory graczy, kamera |
| Lokalizacja PL | warstwa `localization/pl`: 542 głosy, 1517 nagrań narracji, 55 scenariuszy, teksty; osobny wybór języka tekstów/głosów/kampanii; 8 braków → EN |
| 6. Testy | Godot **33/33**, testy Pythona (DCL C 173/173, db, CEM, gracze, formaty), kontrola nienaruszenia 0 zmian |

## Dokumenty
* `audyt/porownanie/RAPORT_POROWNANIA_INSTALACJI.md` – porównanie instalacji (+ `porownanie_instalacji.json`)
* `audyt/RAPORT_SEPARACJI_WARSTW.md` (v2), `audyt/manifest_zasobow.json/.csv` (v2), `audyt/manifest_referencyjny.json`
* `docs/FORMATY_ETAP2.md` – CEM 1.3, db, warianty terenu, kolor gracza, obiekty, hashdb, Language.dll
* `docs/LOKALIZACJA.md`, `dane/lokalizacja/pl/manifest.json` – lokalizacja i prawa
* `wyniki/RAPORT_ZGODNOSCI_RENDEROWANIA.md` + `wyniki/test_graficzny_etap2/`
* Wyniki testów: `wyniki/testy_godot.json`, `wyniki/test_*.json`, `wyniki/kontrola_nienaruszenia_etap2.json`, `wyniki/hashdb_po_etapie2.json`

## Zmiany w kodzie (architektura zachowana)
* `konfiguracja.gd` – wiele instalacji, profil, języki; zgodność wstecz z `[instalacja] sciezki`.
* `zasoby.gd` – kolejność: nakładka lokalizacji → EN z referencji (gdy baza społ. i głosy EN) → nakładka HD → źródła bazowe.
* Nowe importery: `baza_db.gd`, `scenariusz.gd`, `teksty_dll.gd`, `importer_dzwiekow.gd`; `importer_modeli.gd` – CEM 1.3, materiały.
* Nowa scena `test_scenariusz` + `kamera_rts.gd`; narzędzia Pythona: weryfikacja hashdb, porównanie, klasyfikacja v2, lokalizacja, DCL w C.
* Kopia stanu sprzed etapu: `kopie/etap1_przed_etapem2/`.

## Ograniczenia i otwarte kwestie
* Mieszanie tekstur terenu i klify – nierozpoznane; kolor gracza i kąt obrotu – hipotezy (`RAPORT_ZGODNOSCI_RENDEROWANIA.md`).
* Scenariusze EE (starszy format obiektów) i tabele EE `dbobjects`/`dbcivilization` – nieobsłużone.
* Autorstwo: łatki DLL, `Empire Earth.bik`, pakiety HD – nieustalone.
* Schemat tabel db pochodzi z EE DB Editor (GPLv3) → kod OpenEE korzystający z niego musi mieć licencję zgodną z GPL (jak OpenMW).
* Dane gry (w tym polskie nagrania) czytane w miejscu; `cache/` i dane użytkownika nie mogą trafić do publicznego pakietu.
* Serwer MCP Godota niedostępny – testy headless + zrzuty przez xvfb.

## Bezpieczeństwo
Żadna instalacja EE, plik EXE/DLL, Riverlands ani `EmpireEarth test` nie zostały zmienione (kontrola SHA-256 przed/po:
0 zmian; hashdb GOG po etapie 602/602). Gra nie była uruchamiana. Brak Gita i Dockera.
