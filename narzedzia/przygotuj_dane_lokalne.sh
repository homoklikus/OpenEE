#!/bin/bash
# OpenEE – przygotowanie LOKALNYCH danych pomocniczych z legalnej instalacji Empire Earth.
# Wyniki (wyniki/, audyt/, cache/, dane/lokalizacja/) są wyłącznie lokalne i nie są publikowane (.gitignore).
#
# Użycie: narzedzia/przygotuj_dane_lokalne.sh <instalacja_EE> [<instalacja_z_polską_wersją>]
#   <instalacja_EE> – katalog z „Empire Earth” i „Empire Earth - The Art of Conquest” (np. GOG Empire Earth Gold)
# Wymagania: Python 3.8+, Pillow, numpy (część testów porównawczych).
set -e
cd "$(dirname "$(readlink -f "$0")")/.."
REF="$1"; SPOL="$2"
[ -d "$REF/Empire Earth" ] || { echo "Nie znaleziono '$REF/Empire Earth'"; exit 1; }
mkdir -p wyniki audyt cache
krok() { echo; echo "== $*"; }
if ls "$REF"/goggame-*.hashdb >/dev/null 2>&1; then
  krok "weryfikacja instalacji GOG (sumy kontrolne dystrybucji)"
  python3 narzedzia/weryfikuj_gog_hashdb.py "$REF" wyniki/hashdb.json
fi
krok "tabele db (wzorzec dla testów GDScript)";   python3 narzedzia/test_db.py "$REF" wyniki/test_db_referencyjna.json
krok "modele CEM 1.3";                             python3 narzedzia/test_cem13.py "$REF/Empire Earth/Data/data.ssa" wyniki/test_cem13.json
krok "scenariusze AoC (gracze/obiekty)";           python3 narzedzia/test_gracze.py "$REF" wyniki/test_gracze.json
krok "scenariusze EE i AoC (wzorzec 52 plików)";   python3 narzedzia/test_scenariuszy_ee.py "$REF"
krok "orientacja modeli (mury)";                   python3 narzedzia/test_orientacji_modeli.py "$REF"
krok "ciągłość wariantów tekstur";                 python3 narzedzia/test_ciaglosci_tekstur.py "$REF" >/dev/null
krok "animacje CEM i sekwencje dbgraphics (etap 4)"; python3 narzedzia/analiza_animacji.py "$REF" wyniki/analiza_animacji.json >/dev/null
if [ -n "$SPOL" ]; then
  [ -d "$SPOL/Empire Earth" ] || { echo "Nie znaleziono '$SPOL/Empire Earth'"; exit 1; }
  krok "manifest archiwów (instalacja 2)";        python3 narzedzia/manifest_archiwow.py "$SPOL" audyt/manifest_archiwow.json
  krok "eksport testu graficznego etapu 1";       python3 narzedzia/eksport_testu_graficznego.py "$SPOL" cache/test_graficzny
  krok "inwentarze instalacji";                   python3 narzedzia/audyt_instalacji.py "$REF" audyt/inwentarz_ref.json
                                                  python3 narzedzia/audyt_instalacji.py "$SPOL" audyt/inwentarz_spol.json
  krok "porównanie instalacji (kilka minut)";     python3 narzedzia/porownaj_instalacje.py "$REF" audyt/inwentarz_ref.json "$SPOL" audyt/inwentarz_spol.json audyt/porownanie.json
  krok "manifest lokalizacji PL (odniesienia)";   python3 narzedzia/lokalizacja_pl.py "$REF" "$SPOL" audyt/porownanie.json dane/lokalizacja/pl
fi
echo; echo "Gotowe. Testy: ./uruchom_openee.sh testy"
