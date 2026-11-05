#!/usr/bin/env python3
"""OpenEE – jedna sesja oryginalnego Empire Earth w izolowanym Xvfb (etap 5; wywoływane z izolowane_ee.sh sesja).

Uruchamia własny Xvfb, grę z kopii w katalogu roboczym (osobny WINEPREFIX), wykonuje kroki i na końcu zamyka WYŁĄCZNIE
swoje procesy (wineserver -k dla tego prefiksu, Xvfb tego ekranu). Wejście trafia tylko do Xvfb (XTEST) – brak dostępu do
pulpitu i fizycznych urządzeń.

Kroki (plik tekstowy, po jednym w wierszu; # komentarz):
  czekaj <s>            zrzut <nazwa>          klawisz <keysym>      tekst <napis>
  abs <x> <y>           rel <dx> <dy>          klik [przycisk]       przytrzymaj <keysym> <s>
Użycie: izolowane_ee_sesja.py <IZ> <WINE_DIR> <ee|aoc> <plik_kroków> <katalog_zrzutów> [--zgoda]
"""
import os, sys, time, subprocess, signal


def main():
    iz, wine_dir, gra, kroki_plik, out = sys.argv[1:6]
    if "--zgoda" not in sys.argv:
        sys.exit("Uruchomienie oryginalnej gry wymaga zgody użytkownika (--zgoda)")
    os.makedirs(out, exist_ok=True)
    ekran = os.environ.get("EKRAN", ":77")
    env = dict(os.environ, DISPLAY=ekran, WINEPREFIX=os.path.join(iz, "prefiks"), WINEDEBUG="-all",
               WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree=;mshtml=")
    xv = subprocess.Popen(["Xvfb", ekran, "-screen", "0", os.environ.get("ROZDZ", "1024x768x24"), "-nolisten", "tcp"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.5)
    if gra == "ee":
        kat, exe = os.path.join(iz, "gra", "Empire Earth"), "Empire Earth.exe"
    else:
        kat, exe = os.path.join(iz, "gra", "Empire Earth - The Art of Conquest"), "EE-AOC.exe"
    log = open(os.path.join(out, "gra.log"), "w")
    g = subprocess.Popen([os.path.join(wine_dir, "bin", "wine"), exe], cwd=kat, env=env, stdout=log, stderr=log)
    from Xlib import display, X, XK
    from Xlib.ext import xtest
    d = None
    for _ in range(20):
        try:
            d = display.Display(ekran); break
        except Exception:
            time.sleep(0.5)
    t0 = time.time()
    try:
        for wiersz in open(kroki_plik, encoding="utf-8"):
            w = wiersz.split("#")[0].split()
            if not w:
                continue
            k, a = w[0], w[1:]
            if k == "czekaj":
                time.sleep(float(a[0]))
            elif k == "zrzut":
                p = os.path.join(out, a[0] + ".png")
                subprocess.run(["import", "-display", ekran, "-window", "root", p], env=env, timeout=30)
                print(f"{time.time() - t0:6.1f}s zrzut {p}", flush=True)
            elif k == "abs":
                xtest.fake_input(d, X.MotionNotify, x=int(a[0]), y=int(a[1])); d.sync()
            elif k == "rel":
                xtest.fake_input(d, X.MotionNotify, detail=1, x=int(a[0]), y=int(a[1])); d.sync()
            elif k == "klik":
                b = int(a[0]) if a else 1
                xtest.fake_input(d, X.ButtonPress, b); d.sync(); time.sleep(0.1)
                xtest.fake_input(d, X.ButtonRelease, b); d.sync()
            elif k in ("klawisz", "przytrzymaj"):
                kc = d.keysym_to_keycode(XK.string_to_keysym(a[0]))
                xtest.fake_input(d, X.KeyPress, kc); d.sync()
                time.sleep(float(a[1]) if k == "przytrzymaj" else 0.08)
                xtest.fake_input(d, X.KeyRelease, kc); d.sync()
            elif k == "tekst":
                for ch in " ".join(a):
                    kc = d.keysym_to_keycode(XK.string_to_keysym(ch))
                    xtest.fake_input(d, X.KeyPress, kc); d.sync(); xtest.fake_input(d, X.KeyRelease, kc); d.sync()
            print(f"{time.time() - t0:6.1f}s {k} {' '.join(a)}", flush=True)
    finally:
        subprocess.run([os.path.join(wine_dir, "bin", "wineserver"), "-k"], env=env, timeout=30)
        for p in (g, xv):
            try:
                p.send_signal(signal.SIGTERM); p.wait(5)
            except Exception:
                p.kill()
        print("sesja zakończona – procesy gry i Xvfb zamknięte", flush=True)


if __name__ == "__main__":
    main()
