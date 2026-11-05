#!/bin/bash
# OpenEE – uruchomienie projektu Godot.
#   ./uruchom_openee.sh            launcher OpenEE (ekran główny)
#   ./uruchom_openee.sh diag       ekran diagnostyki (etap 1)
#   ./uruchom_openee.sh scenariusz scenariusz testowy etapu 2 (Soldiers for Rome)
#   ./uruchom_openee.sh test       test graficzny etapu 1 (teren + model)
#   ./uruchom_openee.sh testy      testy automatyczne bez okna (bez instalacji EE część testów jest pomijana)
#   ./uruchom_openee.sh rts [opcje]       scena RTS (etap 5): Troja, zaznaczanie LPM, ruch PPM
#   ./uruchom_openee.sh animacje [opcje]  scena diagnostyczna animacji CEM (etap 4), np. --model=Phalanx --sekwencja=atak
# Godot 4.7: zmienna GODOT, polecenie godot4/godot w PATH albo plik Godot_v4*_linux.x86_64 obok projektu.
cd "$(dirname "$(readlink -f "$0")")"
for g in "$GODOT" "$(command -v godot4)" "$(command -v godot)" ./Godot_v4*_linux.x86_64 ../Godot_v4*_linux.x86_64; do
  [ -n "$g" ] && [ -x "$g" ] && GODOT="$g" && break
done
[ -x "$GODOT" ] || { echo "Nie znaleziono Godota 4.7 – ustaw zmienną GODOT"; exit 1; }
# import przy pierwszym uruchomieniu i po dodaniu/zmianie skryptów (nowe klasy class_name muszą trafić do pamięci podręcznej)
if [ ! -f godot/.godot/global_script_class_cache.cfg ] || [ -n "$(find godot -name '*.gd' -newer godot/.godot/global_script_class_cache.cfg 2>/dev/null | head -1)" ]; then
  "$GODOT" --headless --path godot --import >/dev/null 2>&1
fi
case "$1" in
  test)  exec "$GODOT" --path godot res://sceny/test_teren.tscn ;;
  diag)  exec "$GODOT" --path godot res://sceny/diagnostyka.tscn ;;
  scenariusz) exec "$GODOT" --path godot res://sceny/test_scenariusz.tscn ;;
  testy) exec "$GODOT" --headless --path godot --script res://testy/uruchom_testy.gd ;;
  animacje) shift; exec "$GODOT" --path godot res://sceny/diag_animacji.tscn -- "$@" ;;
  rts) shift; exec "$GODOT" --path godot res://sceny/rts_test.tscn -- --kampania=EETheGreeks.ssa "--scenariusz=trojan war" --kamera=blisko "$@" ;;
  *)     exec "$GODOT" --path godot res://launcher/launcher.tscn ;;
esac
