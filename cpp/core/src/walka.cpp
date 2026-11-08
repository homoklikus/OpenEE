#include "openee/walka.hpp"

#include <algorithm>
#include <cfenv>
#include <cmath>

#include "openee/f32.hpp"

namespace openee {

std::optional<int> wybor_tablicy_trafien(bool atak_czl, bool cel_czl, int trudnosc) {
    if (trudnosc != 0) return std::nullopt;
    if (atak_czl && !cel_czl) return 2;   // 0x8D2010
    if (!atak_czl && cel_czl) return 0;   // 0x8D2008
    return std::nullopt;                  // np. komputer ↔ komputer (0x8D200C?) – [N]
}

WynikObrazen oblicz_obrazenia(const ParametryWalki& a, const ParametryWalki& c, double m, double w, double r, bool ten_sam) {
    WynikObrazen o;
    o.m = m;
    o.w = w;
    double d = f32(f32(w) * f32(m));      // fld w; call → fmul: iloczyn w rejestrze, potem zapis f32 przy fstp [ebp+0xc]
    if (!(d > 0.0)) {
        o.zerowy_mnoznik = true;
        o.obrazenia = 0;
        return o;
    }
    const int ra = std::clamp(a.rodzaj_ataku, 0, 5);
    d = f32(d * double(a.atak) - double(c.pancerz[std::size_t(ra)]));
    if (r != 1.0) {
        if (r > 1.0) {
            const double t = f32(r * d);
            d = t < d + 1.0 ? f32(d + 1.0) : t;
        } else {
            const double t = f32(r * d);
            d = t > d - 1.0 ? f32(d - 1.0) : t;
        }
    }
    if (ten_sam) d = f32(double(c.ogien_bratobojczy) * d);
    o.przed_zaokragleniem = d;
    int v = int(std::nearbyint(d));       // fistp – tryb zaokrąglania FPU domyślny (do najbliższej, remis do parzystej)
    o.obrazenia = v < 1 ? 1 : v;
    return o;
}

WagiCelu WagiCelu::z_rekordu(const std::vector<int>& r) {
    WagiCelu w;
    auto v = [&r](std::size_t i) { return i < r.size() ? r[i] : 0; };
    w.atakuje_mnie = v(0);
    w.w_zasiegu = v(2);
    w.mniejsze_ac = v(3);
    w.slabszy_atak = v(4);
    w.typ_specjalny = v(5);
    w.waga_trafienia = v(6);
    w.waga_odleglosci = v(7);
    w.ac_zero = v(8);
    w.prog = v(9);
    return w;
}

int ocena_celu(const ParametryWalki& ja, const ParametryWalki& kand, double zasieg_f, double d2, double m,
               bool atakuje_mnie, const WagiCelu& w, bool& specjalny) {
    // 0x639C18…0x639D19 (EE). Wszystkie porównania na f32 z funktora (+0x38 = (zasięg·f)², +0x58 = int(atak)).
    specjalny = kand.typ_bazy == w.typ_specjalny;
    if (specjalny) return 0;
    int e = atakuje_mnie ? w.atakuje_mnie : 0;
    const double z2 = f32(f32(zasieg_f) * f32(zasieg_f));
    if (d2 <= z2) e += w.w_zasiegu;
    const int atak_int = int(std::nearbyint(double(ja.atak)));   // fistp (funktor +0x58)
    if (double(atak_int) > double(kand.atak)) e += w.slabszy_atak;
    if (kand.pole_ac < ja.pole_ac) e += w.mniejsze_ac;
    if (kand.pole_ac == 0.0f) e += w.ac_zero;
    const double t1 = f32(double(w.waga_odleglosci) / d2);
    const double t2 = f32(double(w.waga_trafienia) * f32(m));
    e += int(std::nearbyint(t1)) + int(std::nearbyint(t2));
    return e;
}

bool w_zasiegu_punktowy(double d2, double s_ja, double s_cel) {
    // x87: fld 1,42f; fmul 0,05f; fadd s_ja; fadd s_cel; fmul 1,42f  →  R (rozszerzona precyzja); R·R > 4·d²
    const long double k = static_cast<long double>(f32(1.42));
    long double R = k * static_cast<long double>(f32(0.05));
    R += static_cast<long double>(f32(s_ja));
    R += static_cast<long double>(f32(s_cel));
    R *= k;
    const long double d4 = static_cast<long double>(f32(d2)) * 4.0L;
    return R * R > d4;
}

int przeladowanie_aoc(double r, double lo, double hi, int bazowe) {
    // 0x5612B9: (hi − lo)·r + lo w rejestrze; 0x5FEA22: fimul bazowe, fstp f32, fistp
    const long double v = (static_cast<long double>(f32(hi)) - static_cast<long double>(f32(lo))) *
                              static_cast<long double>(r) + static_cast<long double>(f32(lo));
    const double z = f32(static_cast<double>(v * static_cast<long double>(bazowe)));
    return int(std::nearbyint(z));
}

double modyfikator_wysokosci(const ModyfikatorWysokosci& m, int ta, int tc, double za, double zc, double premia_gracza) {
    if (!m.wlaczony) return 1.0;
    const bool a = ta == 5 || ta == 6;
    const bool c = tc == 5 || tc == 2 || tc == 6 || tc == 13 || tc == 19 || tc == 15 || tc == 23 || tc == 16 || tc == 29 ||
                   tc == 24 || tc == 25;
    if (!a || !c) return 1.0;
    const double k = f32(0.408248276);   // 0x832088
    const double dz = za - zc;           // fld z_atak; fld z_cel; fsubp (rozszerzona precyzja)
    if (dz >= double(m.prog_gora) * k) return double(f32(double(premia_gracza) + double(m.premia)));
    if (dz <= -(double(m.prog_dol) * k)) return double(m.kara);
    return 1.0;
}

bool przyjmij_obrazenia(StanWalki& cel, int obrazenia) {
    if (cel.hp <= 0) return false;
    cel.hp -= obrazenia;
    if (cel.hp < 0) cel.hp = 0;
    return cel.hp == 0;
}

void PojedynekTitan::takt(int ms) {
    ++takt_;
    // kolejność jednostek w takcie: jak lista gracza (tu: 0, potem 1) – dla dwóch graczy kolejność list [N]
    for (int i = 0; i < 2; ++i) {
        UczestnikPojedynku& u = u_[std::size_t(i)];
        UczestnikPojedynku& v = u_[std::size_t(1 - i)];
        if (u.s.hp <= 0) {
            // martwa jednostka: licznik +0x2A0 nadal maleje (pomiar 564: 1048 w takcie śmierci, 0 po ok. 1 s) [P]
            u.s.przeladowanie_ms = std::max(0, u.s.przeladowanie_ms - ms);
            continue;
        }
        switch (u.stan) {
            case 2012:   // FaceEnemyUnit: Reloaded i cel w łuku → AttackEnemyUnit
                if (u.takty_do_pierwszego_ataku > 0) {
                    --u.takty_do_pierwszego_ataku;
                    break;
                }
                if (u.s.przeladowanie_ms == 0 && v.s.hp > 0) {
                    u.stan = 2001;
                    u.s.przeladowanie_ms = u.p.przeladowanie_ms;   // wejście 0x60B26F (+0x2A0 := upgrade+0x138)
                    u.s.trafienie_w_cyklu = false;
                    zd_.push_back({takt_, i, "atak", u.s.przeladowanie_ms});
                }
                break;
            case 2001:   // AttackEnemyUnit: AlwaysTrue → WaitForReload
                u.stan = 2021;
                break;
            case 2021:   // WaitForReload: Reloaded → FaceEnemyUnit
                if (u.s.przeladowanie_ms == 0) u.stan = 2012;
                break;
            default:
                break;
        }
        // licznik przeładowania: −ms taktu, nie poniżej 0 (pomiar: 1966 w takcie wejścia, 0 po 59 taktach) [P]
        u.s.przeladowanie_ms = std::max(0, u.s.przeladowanie_ms - ms);
        // trafienie: moment z animacji ataku (opoznienie_trafienia_ms od wejścia w 2001) [P dla gwardii: 878 ms
        // do końca przeładowania; mechanizm zdarzenia animacji – N]
        if (!u.s.trafienie_w_cyklu && u.p.opoznienie_trafienia_ms >= 0 && (u.stan == 2021 || u.stan == 2001) &&
            u.p.przeladowanie_ms - u.s.przeladowanie_ms >= u.p.opoznienie_trafienia_ms && v.s.hp > 0) {
            u.s.trafienie_w_cyklu = true;
            const auto o = oblicz_obrazenia(u.p, v.p, u.m, u.w);
            zd_.push_back({takt_, 1 - i, "trafienie", o.obrazenia});
            if (przyjmij_obrazenia(v.s, o.obrazenia)) {
                ++u.s.zabicia;
                v.stan = 6000;   // Dying (Generic Death.tai)
                zd_.push_back({takt_, 1 - i, "smierc", 0});
            }
        }
    }
}

}  // namespace openee
