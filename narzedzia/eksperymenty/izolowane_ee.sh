#!/bin/bash
# OpenEE – odizolowane środowisko oryginalnego Empire Earth do porównań wizualnych (etap 5).
#
# Zasady: osobny serwer X (Xvfb, bez dostępu do pulpitu i fizycznej myszy/klawiatury), osobny WINEPREFIX,
# KOPIA gry w katalogu roboczym (oryginalna instalacja tylko czytana), żadnych zmian w Lutris ani w działających
# procesach Wine użytkownika, brak sudo i pakietów systemowych, całość usuwalna jednym poleceniem.
#
# Użycie:
#   IZ=<katalog roboczy> WINE_DIR=<przenośne Wine> narzedzia/eksperymenty/izolowane_ee.sh przygotuj <instalacja_EE>
#   IZ=… narzedzia/eksperymenty/izolowane_ee.sh uruchom --zgoda [ee|aoc]     # pierwsze uruchomienie gry wymaga zgody użytkownika
#   IZ=… narzedzia/eksperymenty/izolowane_ee.sh zrzut <plik.png>
#   IZ=… narzedzia/eksperymenty/izolowane_ee.sh klik <x> <y> | klawisz <nazwa>   # wejście wyłącznie do Xvfb (python-xlib, XTEST)
#   IZ=… narzedzia/eksperymenty/izolowane_ee.sh sesja <ee|aoc> <plik_kroków> <katalog_zrzutów> --zgoda   # jeden przebieg (zalecane)
#   IZ=… narzedzia/eksperymenty/izolowane_ee.sh zatrzymaj | usun
# Zmienne: EKRAN (domyślnie :77), ROZDZ (domyślnie 1024x768x24).
set -e
IZ="${IZ:?ustaw IZ – katalog roboczy}"
EKRAN="${EKRAN:-:77}"
ROZDZ="${ROZDZ:-1024x768x24}"
WINE_DIR="${WINE_DIR:-$IZ/wine}"
export WINEPREFIX="$IZ/prefiks"
export WINEARCH=win64
export WINEDEBUG=-all
# bez skrótów na pulpicie, bez instalatorów Mono/Gecko
export WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree=;mshtml="
export DISPLAY="$EKRAN"
WINE="$WINE_DIR/bin/wine"

xvfb() {
  if ! [ -e "/tmp/.X11-unix/X${EKRAN#:}" ]; then
    Xvfb "$EKRAN" -screen 0 "$ROZDZ" -nolisten tcp -noreset >"$IZ/xvfb.log" 2>&1 &
    echo $! > "$IZ/xvfb.pid"; sleep 1
  fi
}

case "$1" in
  przygotuj)
    SRC="${2:?podaj katalog instalacji EE}"
    mkdir -p "$IZ"
    [ -x "$WINE" ] || { echo "Brak Wine w $WINE_DIR"; exit 1; }
    if [ ! -d "$IZ/gra" ]; then
      echo "Kopiowanie gry (oryginał tylko do odczytu) → $IZ/gra"
      cp -a "$SRC" "$IZ/gra"
      chmod -R u+w "$IZ/gra"
    fi
    xvfb
    "$WINE_DIR/bin/wineboot" -i >"$IZ/wineboot.log" 2>&1 || true
    "$WINE_DIR/bin/wineserver" -w
    echo "Gotowe: prefiks $WINEPREFIX, kopia gry $IZ/gra, ekran $EKRAN (gra NIE została uruchomiona)"
    ;;
  uruchom)
    [ "$2" = "--zgoda" ] || { echo "Uruchomienie oryginalnej gry wymaga zgody użytkownika (--zgoda)"; exit 2; }
    xvfb
    gra="${3:-aoc}"
    if [ "$gra" = "ee" ]; then d="$IZ/gra/Empire Earth"; exe="Empire Earth.exe"; else d="$IZ/gra/Empire Earth - The Art of Conquest"; exe="EE-AOC.exe"; fi
    cd "$d"
    nohup "$WINE" "$exe" >"$IZ/gra.log" 2>&1 &
    echo $! > "$IZ/gra.pid"; echo "Uruchomiono $exe na $EKRAN (pid $(cat "$IZ/gra.pid"))"
    ;;
  zrzut)
    import -display "$EKRAN" -window root "${2:?plik.png}" && echo "zrzut: $2"
    ;;
  klik|klawisz|ruch)
    python3 - "$@" <<'PY'
import sys, os, time
from Xlib import display, X, XK
from Xlib.ext import xtest
d = display.Display(os.environ["DISPLAY"])
cmd = sys.argv[1]
if cmd in ("klik", "ruch"):
    x, y = int(sys.argv[2]), int(sys.argv[3])
    xtest.fake_input(d, X.MotionNotify, x=x, y=y); d.sync(); time.sleep(0.15)
    if cmd == "klik":
        b = int(sys.argv[4]) if len(sys.argv) > 4 else 1
        xtest.fake_input(d, X.ButtonPress, b); d.sync(); time.sleep(0.08)
        xtest.fake_input(d, X.ButtonRelease, b); d.sync()
else:
    k = d.keysym_to_keycode(XK.string_to_keysym(sys.argv[2]))
    xtest.fake_input(d, X.KeyPress, k); d.sync(); time.sleep(0.08)
    xtest.fake_input(d, X.KeyRelease, k); d.sync()
PY
    ;;
  sesja)
    # cała sesja w jednym przebiegu: Xvfb + gra + kroki + sprzątanie (izolowane_ee_sesja.py)
    [ "$5" = "--zgoda" ] || { echo "Uruchomienie oryginalnej gry wymaga zgody użytkownika (--zgoda)"; exit 2; }
    python3 "$(dirname "$0")/izolowane_ee_sesja.py" "$IZ" "$WINE_DIR" "${2:?ee|aoc}" "${3:?plik kroków}" "${4:?katalog zrzutów}" --zgoda
    ;;
  zatrzymaj)
    "$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
    [ -f "$IZ/xvfb.pid" ] && kill "$(cat "$IZ/xvfb.pid")" 2>/dev/null || true
    rm -f "$IZ/xvfb.pid" "$IZ/gra.pid"; echo "zatrzymano (tylko procesy tego prefiksu i tego ekranu)"
    ;;
  usun)
    "$0" zatrzymaj || true
    rm -rf "$IZ/prefiks" "$IZ/gra" "$IZ"/*.log; echo "usunięto prefiks i kopię gry z $IZ"
    ;;
  *) sed -n 2,16p "$0"; exit 1 ;;
esac
