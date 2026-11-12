#include "openee/ulepszenia.hpp"

#include "openee/f32.hpp"

namespace openee {

double wartosc_z_premia(double wartosc, double baza, const PremiaAtrybutu& p, double minimum) {
    double krok = f32(baza * (p.procent == 0.0 ? 0.1 : p.procent));   // 0x626FB0
    if (krok < minimum) krok = minimum;                                 // 0x627030: max(krok, minimum)
    double w = wartosc;
    for (int i = 0; i < p.poziomy; ++i) w = f32(krok + w);
    return w;
}

ParametryRuchu z_premia_predkosci(const ParametryRuchu& baza, const PremiaAtrybutu& p) {
    if (p.poziomy <= 0) return baza;
    ParametryRuchu r = baza;
    const double v0 = f32(baza.vmax);
    const double v1 = wartosc_z_premia(v0, v0, p, double(f32(0.05)));   // przypadek 0xE, minimum 0x825508
    const double k = f32(v1 / v0);                                         // 0x628051
    r.vmax = v1;
    r.a = f32(f32(baza.a) * k);
    r.alfa = f32(f32(baza.alfa) * k);
    r.wmax = f32(f32(baza.wmax) * k);
    r.c4 = f32(1.0 / r.a);
    r.c8 = f32(1.0 / r.alfa);
    return r;
}

}  // namespace openee
