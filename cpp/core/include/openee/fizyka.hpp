// OpenEE Core – fizyka jednostki lądowej EEPMLand: tryby 0/3/4/5 (etap 28).
// docs/titan/ruch_jednostki.md § 5–8, docs/titan/precyzja_numeryczna.md § 5–6, fizyka_terenu.md § 2–3.
// Port modelu v4 (etap 27) – kolejność operacji i punkty zapisu f32 jak w oryginale.
#pragma once

#include "openee/jednostka.hpp"
#include "openee/teren.hpp"

namespace openee {

struct KontekstFizyki {
    const MatematykaTitan& mat;
    const TerenSiatka& teren;
    double dt;   // f32(1,5/44) s czasu gry
    double tps;  // 1/dt (rejestr)
};

/// Wynik obrotu: nowy kurs (f32) i ω (f32).
struct WynikObrotu {
    double yaw, omega;
};

class FizykaLadowa {
public:
    /// Rdzeń obrotu z decyzją zależną od wariantu (EE 0x54880E/0x548266, AoC 0x554F56/0x554738).
    static WynikObrotu obrot(const KontekstFizyki& k, const Jednostka& u, double cur, double diff);

    /// Jeden takt fizyki według trybu jednostki. Zwraca false, gdy tryb 0 nie ma punktu (brak ruchu).
    static bool takt(const KontekstFizyki& k, Jednostka& u);

    /// Ustawia orientację i z po zmianie kursu (SetOrientationYPR, pochylenie przy typ+0x5F3).
    static void ustaw_kurs(const KontekstFizyki& k, Jednostka& u, double yaw);

private:
    static bool tryb_jazda(const KontekstFizyki& k, Jednostka& u);
    static void tryb_hamowanie(const KontekstFizyki& k, Jednostka& u);
    static void tryb_obrot_w_miejscu(const KontekstFizyki& k, Jednostka& u);
};

}  // namespace openee
