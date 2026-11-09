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

## `narzedzia/titan/` – warsztat reverse engineeringu Titan (etap 30)

Binarki gry są czytane tylko do odczytu; wyniki dotyczące binarek (indeks, mapy dostępu) trafiają do
`~/.cache/openee_re` albo do `Testy_MCP` – nie do repozytorium.

| Plik | Do czego |
|---|---|
| `indeks_pe.py` | indeks instrukcji z operandem `[rej + przesunięcie]` (capstone), rodzaj dostępu O/Z/OZ, kandydaci początków funkcji (cele `call` i wskaźniki vtable) |
| `struktury.py` | wspólny opis struktur `dane/titan/struktury_titan.json`: `waliduj` (schemat i dostęp w funkcjach z pól `odczyt`/`zapis`), `dostep STRUKTURA POLE` (kandydaci odczytu i zapisu w EE i AoC), `przesuniecie`, `porownaj` (spójność EE/AoC w parach funkcji), `markdown` (tabela atlasu `docs/titan/struktury_titan.md`) |
| `rtti_titan.py` | nazwa klasy dla vtable i vtable dla klasy (RTTI MSVC), lista klas z filtrem |
| `switch_titan.py` | adres przypadku instrukcji switch MSVC (drzewo porównań + tablice skoków) dla konkretnych wartości – dispatchery stanów i zdarzeń |
| `eksport_mapy.py` | SCN → neutralny plik dla Core (tylko dekodowanie; interpretacja w `MapaTitan`); opcjonalnie zrzut EEMap z Riverlands_MCP, tablica terenu typu, próbki wysokości |
| `pomiar_core.py` | pomiar Riverlands_MCP → walidacja → seria `openee_seria_v1` → `cpp/tools/openee_porownaj` → raport (pierwszy rozbieżny takt); `walka` (etap 31): okno walki z zapisu `obs_rejestruj` + tablice/wagi z gry → `openee_walka_v1` dla `core_walka_swiat` (wejścia w atak ze stanem RNG przed/po – sprawdzenie przeładowania AoC); etap 32: w próbkach także kurs, ω i tryb ruchu, w parametrach rodzaj jednostki (typ +0x4B4); etap 33: `--morale id=poziom,…` (poziomy EEAEMoraleFromBuildings z `walka_modyfikatory`) |
| (etap 35) | scenariusz kontrolny `e35_a`: `python3 narzedzia/eksperymenty/scenariusz_testowy_kolizji.py zbuduj <Wojna trojańska.scn> e35_a.scn dane/testy_walki/e35_a.uklad_wej.json` (plik SCN lokalnie); opis w `docs/titan/dziennik_eksperymentow.md` |
| `efekty_obszaru.py` | etap 34: szablony `dbareaeffect` w układzie pamięci gry, zestawy jednostek `dbunitset` rozwiązane algorytmem EE 0x52BFA4, „Alter max morale” wariantów (`dbgamevariant`) i budynki z efektami/domy z kawałka 5 SCN → `openee_efekty_v1` (dane wejściowe efektów obszarowych Core, np. `dane/testy_walki/efekty_e31_a_ee.json`) |
| `test_titan_narzedzia.py` | testy bez danych gry (walidacja pomiaru, schemat) |

Przykłady: `python3 narzedzia/titan/struktury.py dostep EEUnit hp --exe-ee …`; `python3 narzedzia/titan/pomiar_core.py
porownaj POMIAR.json --instalacja KATALOG_GRY --mapa MAPA.json --jednostki 0x100018c`.

## `narzedzia/eksperymenty/` – pomiary do odtworzenia

| Plik | Etap | Dokument |
|---|---|---|
| `analiza_modelu.py` (+ `kierunek_billboardow.py`, `statystyka_alfa.py`, `uv_modelu.py`, `wspolplaszczyznowe.py` – importują `analiza_modelu`) | 5.1 | `raporty/archiwum/RAPORT_DIAGNOSTYKA_MODELI_051.md`, `docs/FORMATY_DIAGNOSTYKA_051.md` |
| `izolowane_ee.sh`, `izolowane_ee_sesja.py` | 5 | izolowana sesja gry pod Xvfb (`raporty/archiwum/RAPORT_ETAP_5.md`); zastąpiona w praktyce przez Riverlands_MCP, zachowana do odtwarzania pomiarów bez MCP |
| `warianty_epok.py` | 8 | `docs/WARIANTY_EPOK.md` |
| `scenariusz_testowy_ruchu.py` | 9 | `docs/MECHANIKA_RUCHU_EE.md` – mapa Riverlands z grupami jednostek |
| `analiza_ruchu_ee.py` | 9 | trajektorie z MCP → tabela (`raporty/archiwum/RAPORT_RUCH_GRUPOWY_EE.md`) |
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
