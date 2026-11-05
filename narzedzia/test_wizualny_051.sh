#!/bin/bash
# OpenEE 0.5.1 – test wizualny artefaktów modeli (uzupełnienie testów odczytu – te nie zastępują oceny obrazu).
# Renderuje fragment scenariusza „The Trojan War” ze stajnią (Stable - Copper, gracz 5, pole 157×230) z tej samej
# kamery w OpenGL i – jeśli dostępny – w Vulkanie, i liczy metryki kadru: udział czarnych pikseli (czarna bryła
# pomocnicza) i stosunek gradientów pionowych do poziomych (poziome pasy z-fightingu).
# Użycie: GODOT=… narzedzia/test_wizualny_051.sh <katalog_wyników> [katalog_projektu_porównawczego]
# Vulkan w środowisku bez GPU: VK_ICD_FILENAMES na sterownik programowy (lavapipe) – wynik NIE jest weryfikacją na GPU.
set -u
cd "$(dirname "$0")/.." || exit 1
OUT="$1"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
G="${GODOT:?ustaw GODOT}"
A=(--kampania=EETheGreeks.ssa "--scenariusz=trojan war" --okno=218,145,24 --kamera=blisko)
render() {  # $1 katalog projektu, $2 nazwa, reszta – sterownik
  local P="$1" n="$2"; shift 2
  local X=(); [ -z "${DISPLAY:-}" ] && X=(xvfb-run -a -s "-screen 0 1400x1000x24")
  (cd "$P" && timeout 170 "${X[@]}" "$G" --path godot "$@" --resolution 1274x898 res://sceny/test_scenariusz.tscn -- "${A[@]}" "--zrzut=$OUT/$n.png" >"$OUT/$n.log" 2>&1)
}
render "$PWD" po_opengl --rendering-driver opengl3
render "$PWD" po_vulkan --rendering-method forward_plus --rendering-driver vulkan
if [ $# -ge 2 ]; then
  render "$2" przed_opengl --rendering-driver opengl3
  render "$2" przed_vulkan --rendering-method forward_plus --rendering-driver vulkan
fi
python3 narzedzia/metryki_zrzutu.py "$OUT" 300 150 1000 630 "$OUT"/*.png
