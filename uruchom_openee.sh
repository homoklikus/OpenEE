#!/bin/bash
# OpenEE – uruchomienie projektu Godot.
#   ./uruchom_openee.sh            launcher OpenEE (ekran główny)
#   ./uruchom_openee.sh diag       ekran diagnostyki (etap 1)
#   ./uruchom_openee.sh scenariusz scenariusz testowy etapu 2 (Soldiers for Rome)
#   ./uruchom_openee.sh test       test graficzny etapu 1 (teren + model)
#   ./uruchom_openee.sh testy      testy automatyczne bez okna (bez instalacji EE część testów jest pomijana)
# Godot 4.7: zmienna GODOT, polecenie godot4/godot w PATH albo plik Godot_v4*_linux.x86_64 obok projektu.
cd "$(dirname "$(readlink -f "$0")")"
for g in "$GODOT" "$(command -v godot4)" "$(command -v godot)" ./Godot_v4*_linux.x86_64 ../Godot_v4*_linux.x86_64; do
  [ -n "$g" ] && [ -x "$g" ] && GODOT="$g" && break
done
[ -x "$GODOT" ] || { echo "Nie znaleziono Godota 4.7 – ustaw zmienną GODOT"; exit 1; }
[ -d godot/.godot ] || "$GODOT" --headless --path godot --import >/dev/null 2>&1
case "$1" in
  test)  exec "$GODOT" --path godot res://sceny/test_teren.tscn ;;
  diag)  exec "$GODOT" --path godot res://sceny/diagnostyka.tscn ;;
  scenariusz) exec "$GODOT" --path godot res://sceny/test_scenariusz.tscn ;;
  testy) exec "$GODOT" --headless --path godot --script res://testy/uruchom_testy.gd ;;
  *)     exec "$GODOT" --path godot res://launcher/launcher.tscn ;;
esac
