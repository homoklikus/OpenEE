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
