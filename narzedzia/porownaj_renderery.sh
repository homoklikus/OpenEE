#!/bin/bash
# OpenEE 0.5.1 – porównanie rendererów dla tej samej sceny diagnostycznej i tej samej kamery.
# Użycie: narzedzia/porownaj_renderery.sh <katalog_wyników> [argumenty sceny diag_modelu, np. --model="Stable - Copper"]
# Renderery: opengl3 (Compatibility), vulkan (Forward+). W środowisku bez GPU OpenGL działa na llvmpipe (programowo),
# a Vulkan – na lavapipe, jeśli ustawiono VK_ICD_FILENAMES (np. sterownik rozpakowany do katalogu użytkownika, bez
# instalacji w systemie). Na komputerze z kartą graficzną ten sam skrypt porównuje sterowniki sprzętowe.
# SCENA=res://sceny/diag_modelu.tscn (domyślnie); ROZ=1280x900. Wyniki: <kat>/opengl3.png, vulkan.png, roznica.json
set -u
cd "$(dirname "$0")/.." || exit 1
OUT="$1"; shift; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
G="${GODOT:?ustaw GODOT=ścieżka do Godot 4.7}"
SCENA="${SCENA:-res://sceny/diag_modelu.tscn}"; ROZ="${ROZ:-1280x900}"
X=""; [ -z "${DISPLAY:-}" ] && X="xvfb-run -a -s -screen\ 0\ 1600x1200x24"
uruchom() {   # $1 = nazwa, reszta: argumenty Godota przed sceną
  local n="$1"; shift
  if [ -z "${DISPLAY:-}" ]; then
    timeout 170 xvfb-run -a -s "-screen 0 1600x1200x24" "$G" --path godot "$@" --resolution "$ROZ" "$SCENA" -- "${ARGS[@]}" "--zrzut=$OUT/$n.png" > "$OUT/$n.log" 2>&1
  else
    timeout 170 "$G" --path godot "$@" --resolution "$ROZ" "$SCENA" -- "${ARGS[@]}" "--zrzut=$OUT/$n.png" > "$OUT/$n.log" 2>&1
  fi
  grep -m1 -E "OpenGL API|Vulkan [0-9]" "$OUT/$n.log" | cut -c1-160
}
ARGS=("$@")
uruchom opengl3 --rendering-driver opengl3
uruchom vulkan --rendering-method forward_plus --rendering-driver vulkan
python3 - "$OUT" <<'PY'
import sys, json
from PIL import Image, ImageChops
o = sys.argv[1]
try:
    a = Image.open(f"{o}/opengl3.png").convert("RGB"); b = Image.open(f"{o}/vulkan.png").convert("RGB")
except Exception as e:
    print("brak zrzutu:", e); sys.exit(0)
d = ImageChops.difference(a, b).convert("L")
h = d.histogram(); n = sum(h)
wyn = {"piksele": n, "rozne_>16": sum(h[17:]) / n, "rozne_>64": sum(h[65:]) / n}
w = Image.new("RGB", (a.width * 2, a.height)); w.paste(a, (0, 0)); w.paste(b, (a.width, 0)); w.save(f"{o}/obok.png")
json.dump(wyn, open(f"{o}/roznica.json", "w"), indent=1); print(wyn)
PY
