# Narzędzia OpenEE

Narzędzia deweloperskie w Pythonie i powłoce. Zwykłe uruchomienie OpenEE (launcher, sceny, testy Godota) nie wymaga
żadnego z nich ani lokalnego Riverlands_MCP. Wszystkie czytają instalację gry tylko do odczytu. Wyniki zapisują
w ignorowanych przez git katalogach `wyniki/`, `cache/` i `audyt/`.

Porządek od etapu 13.5:
- `narzedzia/` – biblioteka formatów i narzędzia używane regularnie;
- `narzedzia/eksperymenty/` – jednorazowe analizy, które zostają, bo pozwalają odtworzyć pomiary opisane
  w dokumentacji. Przy każdym pliku podano dokument, który z niego korzysta.

## `narzedzia/` – używane regularnie

| Plik | Do czego | Kto wywołuje |
|---|---|---|
| `eeformaty/` | czytniki formatów EE/AoC w Pythonie: SSA, DCL (+ `dcl_szybki.c`), SST, CEM, DB, SCN, gracze, epoki | narzędzia poniżej; **Riverlands_MCP** (`ee_diag._eeformaty` dodaje `narzedzia/` do ścieżki) – nie przenosić |
| `przygotuj_dane_lokalne.sh` | generuje lokalne dane porównawcze dla pełnego zestawu testów Godota | użytkownik (README) |
| `audyt_instalacji.py`, `porownaj_instalacje.py`, `weryfikuj_gog_hashdb.py`, `manifest_archiwow.py` | inwentarz, porównanie instalacji, weryfikacja GOG, manifest archiwów | `przygotuj_dane_lokalne.sh` |
| `klasyfikuj_warstwy.py` (etap 1) → `klasyfikuj_warstwy_v2.py` (etap 2) | manifest warstw (vanilla / aoc / lokalizacja / NeoEE…); v2 korzysta z manifestu v1 | ręcznie; wynik `audyt/manifest_zasobow.json` czytają testy E2 |
| `lokalizacja_pl.py` | manifest polskiej lokalizacji | `przygotuj_dane_lokalne.sh` |
| `eksport_testu_graficznego.py` | próbka zasobów do testów grafiki | `przygotuj_dane_lokalne.sh`, `test_teren.gd` |
| `analiza_animacji.py` | sekwencje animacji (dbgraphics) – dane porównawcze testów E4 | `przygotuj_dane_lokalne.sh` |
| `test_cem13.py`, `test_ciaglosci_tekstur.py`, `test_db.py`, `test_gracze.py`, `test_orientacji_modeli.py`, `test_scenariuszy_ee.py` | wzorce Pythona, z którymi porównują się testy Godota | `przygotuj_dane_lokalne.sh` |
| `test_wizualny_051.sh`, `metryki_zrzutu.py`, `porownaj_renderery.sh` | test wizualny modeli i porównanie rendererów (**GPU**) | ręcznie (README: „Testy”) |
| `baner_launchera.py` | własna grafika nagłówka launchera | ręcznie (`dane/launcher/grafika/ZRODLO.md`) |

## `narzedzia/eksperymenty/` – pomiary do odtworzenia

| Plik | Etap | Dokument |
|---|---|---|
| `analiza_modelu.py` (+ `kierunek_billboardow.py`, `statystyka_alfa.py`, `uv_modelu.py`, `wspolplaszczyznowe.py` – importują `analiza_modelu`) | 5.1 | `RAPORT_DIAGNOSTYKA_MODELI_051.md`, `docs/FORMATY_DIAGNOSTYKA_051.md` |
| `izolowane_ee.sh`, `izolowane_ee_sesja.py` | 5 | izolowana sesja gry pod Xvfb (`RAPORT_ETAP_5.md`); zastąpiona w praktyce przez Riverlands_MCP, zachowana do odtwarzania pomiarów bez MCP |
| `warianty_epok.py` | 8 | `docs/WARIANTY_EPOK.md` |
| `scenariusz_testowy_ruchu.py` | 9 | `docs/MECHANIKA_RUCHU_EE.md` – mapa Riverlands z grupami jednostek |
| `analiza_ruchu_ee.py` | 9 | trajektorie z MCP → tabela (`RAPORT_RUCH_GRUPOWY_EE.md`) |
| `audyt_ee_aoc.py` | 11 | `docs/FORMATY_DB_EE_VS_AOC.md`, `docs/WARIANTY_GRY.md` |
| `scenariusz_testowy_kolizji.py` | 13 | `docs/KOLIZJE_JEDNOSTEK_EE.md`, `docs/MECHANIKA_PREDKOSCI_EE.md` |
| `sonda_scn.py`, `test_formatow.py`, `test_dcl_c.py` | 1–2 | sondy czytników: scenariusze z kampanii, wszystkie formaty na archiwach, DCL w C a w Pythonie. Nie są używane w żadnym dokumencie ani skrypcie; zostawione jako szybkie sprawdzenie czytników po zmianach w `eeformaty` |

Skrypty z tego katalogu dodają do ścieżki importu `narzedzia/` (biblioteka `eeformaty`) oraz własny katalog.

## Narzędzia w GDScripcie (`godot/narzedzia/`)

Uruchamiane z wiersza poleceń przez `godot --headless --path godot --script res://narzedzia/<plik>.gd`:

| Plik | Do czego |
|---|---|
| `obiekty_scenariusza.gd` | lista obiektów scenariusza z położeniami (diagnostyka czytnika SCN) |
| `porownanie_ruchu_ee.gd` | porównanie trajektorii OpenEE z pomiarem EE (`docs/MECHANIKA_RUCHU_EE.md`) |
| `statystyka_geometrii.gd` | statystyka ścian współpłaszczyznowych modeli (`DiagnostykaModelu`) |
