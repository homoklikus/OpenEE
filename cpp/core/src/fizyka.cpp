#include "openee/fizyka.hpp"

#include <algorithm>
#include <cmath>

namespace openee {

namespace {
constexpr double PROG_DOJAZDU = 0.05;      // 0x825508
constexpr double PROG_V_ZERO = 0.005;      // 0x82C65C
constexpr double PROG_S_ZERO = 1e-4;       // 0x827AC0
constexpr double PROG_KURSU_KONC = 0.0174533;  // 1° – zatrzymanie obrotu końcowego [W, model v4]
inline double pi_4() { return f32(3.14159265358979323846 / 4.0); }
}  // namespace

WynikObrotu FizykaLadowa::obrot(const KontekstFizyki& k, const Jednostka& u, double cur, double diff) {
    const double al = u.param.alfa, wmax = u.param.wmax, dt = k.dt, w = u.omega;
    const double ad = al * dt;
    double w2 = w;
    if (u.wariant.obrot == RegulaObrotu::aoc) {  // 0x554F56 (decyzja) + 0x554738 (hamowanie)
        int kod;
        if (w != 0 && ((w > 0) != (diff > 0)) && diff != 0) {
            kod = 4;
        } else if (diff == 0) {
            kod = (w == 0) ? 2 : 4;
        } else {
            const double w1 = f32(ad + std::fabs(w));
            const double rem = f32(std::fabs(diff) - dt * w1);
            if (rem < 0) {
                kod = 4;
            } else {
                const std::int64_t m = std::int64_t(std::ceil(f32(u.param.c8 * k.tps * w1))) - 1;
                // m*(m+1)//2 w Pythonie: dzielenie całkowite z zaokrągleniem w dół (m ≥ −1, iloczyn ≥ 0)
                const std::int64_t tri = (m * (m + 1)) / 2;
                const double S = al * double(tri + 1) * dt * dt;
                kod = (f32(double(m) * dt * w1) - S < rem) ? 3 : 4;
            }
        }
        const int s = diff > 0 ? 1 : -1;
        if (kod == 3) {
            w2 = w + double(s) * ad;
            w2 = std::max(-wmax, std::min(wmax, w2));
        } else if (kod == 4) {
            if (diff == 0) {
                w2 = std::fabs(w) < 0.001 ? 0.0 : (w > 0 ? w - ad : w + ad);
            } else if (w * double(s) > 0) {
                w2 = w - double(s) * ad;
                if (std::fabs(w2) < ad || w2 * double(s) < 0) w2 = double(s) * ad;
            } else {
                w2 = (w != 0) ? w - double(w > 0 ? 1 : -1) * ad : 0.0;
            }
        }
    } else {  // EE 0x54880E + 0x548266
        const double n = f32(u.param.c8 * k.tps * std::fabs(w));
        const double S_rot = ((n + 1) * n * 0.5) * (al * dt * dt);
        if (S_rot < std::fabs(diff)) {
            w2 = w + (diff > 0 ? ad : -ad);
            if (w2 > wmax) w2 = wmax;
            if (w2 < -wmax) w2 = -wmax;
        } else if (w > 0) {
            w2 = w - ad;
            if (w2 < 0) w2 = 0.0;
        } else if (w < 0) {
            w2 = w + ad;
            if (w2 > 0) w2 = 0.0;
        } else {
            w2 = 0.0;
        }
    }
    const double krok_r = w2 * dt;
    const double krok = (std::fabs(krok_r) > std::fabs(diff) && krok_r * diff >= 0) ? diff : f32(krok_r);
    return {f32(krok + cur), f32(w2)};
}

void FizykaLadowa::ustaw_kurs(const KontekstFizyki& k, Jednostka& u, double yaw) {
    u.orientacja = k.mat.set_orientation_ypr(yaw);
}

bool FizykaLadowa::tryb_jazda(const KontekstFizyki& k, Jednostka& u) {
    const std::size_t licz = u.pozostalo_punktow();
    if (licz == 0) return false;  // trasa pusta: brak ruchu, v i ω bez zmian
    const double dt = k.dt, tps = k.tps;
    const double a = f32(u.param.a), vmax = f32(u.param.vmax);
    const Punkt2 W = u.trasa[u.zdjete_punkty];
    const double dxr = W.x - u.x, dyr = W.y - u.y;
    const double dreg = std::sqrt(dxr * dxr + dyr * dyr);
    double d = f32(dreg);
    if (dreg < PROG_DOJAZDU) d = 0.0;  // porównanie na wartości z rejestru
    const double cur = f32(k.mat.kurs_z_macierzy(u.orientacja));
    const double des = f32(k.mat.kat_do_celu(u.x, u.y, W.x, W.y));
    const double diff = MatematykaTitan::normalizuj_roznice(des - cur);
    const WynikObrotu ob = obrot(k, u, cur, diff);
    u.omega = ob.omega;
    // --- decyzja prędkości 0x548645 ---
    const double v = u.v;
    const double kk = f32(u.param.c4 * tps * v / 1.0);
    double S = f32(((kk + 1) * kk * 0.5) * dt * dt * 1.0 * a);
    if (S < PROG_S_ZERO) S = 0.0;
    int tryb;
    if (-pi_4() <= diff && diff <= pi_4()) {
        tryb = 3;
    } else {
        const double X = std::fabs(u.omega * std::min(d, 0.5) * 0.5 * dt);
        tryb = (v * dt >= X) ? 4 : (((v + a * dt) * dt >= X) ? 2 : 3);
    }
    const double R = licz > 1 ? f32(u.dl_po.back() - u.dl_przed[u.zdjete_punkty]) : d;
    if (R <= S) tryb = 4;
    if (u.param.t488 < 1.0) {  // reguła stoku, nachylenie z macierzy sprzed ruchu
        const double pt = k.teren.nachylenie(k.mat, u.x, u.y, u.orientacja.m01(), u.orientacja.m11());
        double s = f32(pt * f32(1.9098593));
        s = s < 0 ? 0.0 : (s > 1 ? 1.0 : s);
        if (v > vmax * (1.0 - s * u.param.t488)) tryb = 4;
    }
    if (tryb == 3) {
        double v1 = dt * a + v;
        if (v1 > vmax) {
            v1 = vmax;
        } else if (licz == 1 && v1 > d) {
            v1 = d;  // BO-7: docisk ostatniego kroku
        }
        u.v = f32(v1);
    } else if (tryb == 4) {
        const double v1 = v - dt * a;
        u.v = v1 < PROG_V_ZERO ? 0.0 : f32(v1);
    }
    // --- ruch po macierzy NOWEGO kursu (yaw) ---
    const Macierz3 n = k.mat.set_orientation_ypr(ob.yaw);
    const double step = f32(u.v * dt);
    const double x0 = u.x, y0 = u.y;
    u.x = f32(u.x + f32(step * n.m01()));
    u.y = f32(u.y + f32(step * n.m11()));
    test_kroku(k, u, x0, y0);  // fizyka_terenu.md § 4 – wynik w trybie 0 ignorowany (ta sama orientacja)
    u.z = k.teren.get_mesh_z(u.x, u.y);
    if (u.param.pochyla) {
        const double pt2 = k.teren.nachylenie(k.mat, u.x, u.y, n.m01(), n.m11());
        u.orientacja = k.mat.set_orientation_ypr(ob.yaw, pt2);
    } else {
        u.orientacja = n;
    }
    // --- osiągnięcie punktu (0x6213D8), d sprzed ruchu ---
    if (licz > 1) {
        u.osiagnieto_punkt = d <= u.param.rozmiar && std::floor(x0) == std::floor(W.x) && std::floor(y0) == std::floor(W.y);
    } else {
        u.osiagnieto_punkt = dreg < PROG_DOJAZDU;
    }
    return true;
}

WynikKroku FizykaLadowa::test_kroku(const KontekstFizyki& k, Jednostka& u, double x0, double y0) {
    const double x1 = u.x, y1 = u.y;
    if (!k.teren.komorka_istnieje(podloga(u.x), podloga(u.y))) {  // brak komórki: P −= krok
        u.x = x0;
        u.y = y0;
        ++u.kroki_cofniete;
        return WynikKroku::poza_mapa;
    }
    int proba = 0;
    WynikKroku w = WynikKroku::ok;
    for (;;) {
        const std::int64_t ix = podloga(u.x), iy = podloga(u.y);
        if (ix == u.komorka_x && iy == u.komorka_y) break;  // pozostanie na tym samym polu – zawsze dozwolone
        bool ok = k.teren.pole_przejezdne(ix, iy);
        const IdJednostki blok = k.srodek_w_polu ? k.srodek_w_polu(ix, iy, u.id) : 0;
        if (blok) ok = false;
        if (ok && ix != u.komorka_x && iy != u.komorka_y)  // przekątna: jedna z komórek bocznych przejezdna
            ok = k.teren.pole_przejezdne(u.komorka_x, iy) || k.teren.pole_przejezdne(ix, u.komorka_y);
        if (ok) break;
        if (blok) {  // środek obiektu w tej komórce: zapamiętaj blokującego, +0x330 = 2, cofnij krok
            u.blokujacy = blok;
            u.flaga_330 = 2;
            u.x = x0;
            u.y = y0;
            ++u.kroki_cofniete;
            return WynikKroku::zablokowany_przez_jednostke;
        }
        ++proba;
        if (proba == 1) {         // cofnij x → ślizg wzdłuż y
            u.x = x0;
            u.y = y1;
            w = WynikKroku::slizg_wzdluz_y;
        } else if (proba == 2) {  // przywróć x, cofnij y → ślizg wzdłuż x
            u.x = x1;
            u.y = y0;
            w = WynikKroku::slizg_wzdluz_x;
        } else {                  // cofnij x – krok odrzucony
            u.x = x0;
            u.y = y0;
            ++u.kroki_cofniete;
            u.licznik_blokady_ms += k.ms_taktu;
            return WynikKroku::cofniety;
        }
    }
    // przycięcie do brzegu mapy (0x549FF3, ±0,001) [W]
    const double xmax = double(k.teren.szerokosc() - 1) - 0.001, ymax = double(k.teren.wysokosc() - 1) - 0.001;
    if (u.x < 0.001) u.x = f32(0.001);
    if (u.y < 0.001) u.y = f32(0.001);
    if (u.x > xmax) u.x = f32(xmax);
    if (u.y > ymax) u.y = f32(ymax);
    if (w != WynikKroku::ok) {
        u.licznik_blokady_ms += k.ms_taktu;
        ++u.kroki_slizg;
    }
    return w;
}

void FizykaLadowa::tryb_hamowanie(const KontekstFizyki& k, Jednostka& u) {
    // tryb 4: v' = max(0, v − a·dt), ω hamowane o α·dt, ruch naprzód po dotychczasowym kursie
    const double v1 = u.v - k.dt * f32(u.param.a);
    u.v = v1 < PROG_V_ZERO ? 0.0 : f32(v1);
    if (u.omega > 0) u.omega = f32(std::max(0.0, u.omega - u.param.alfa * k.dt));
    else if (u.omega < 0) u.omega = f32(std::min(0.0, u.omega + u.param.alfa * k.dt));
    const double step = f32(u.v * k.dt);
    u.x = f32(u.x + f32(step * u.orientacja.m01()));
    u.y = f32(u.y + f32(step * u.orientacja.m11()));
    u.z = k.teren.get_mesh_z(u.x, u.y);
}

void FizykaLadowa::tryb_obrot_w_miejscu(const KontekstFizyki& k, Jednostka& u) {
    // tryb 5: przy v ≠ 0 jak tryb 4; inaczej obrót do kursu końcowego celu (cel+0x2C)
    if (u.v != 0.0) {
        tryb_hamowanie(k, u);
        return;
    }
    if (u.kurs_koncowy) {
        const double cur = f32(k.mat.kurs_z_macierzy(u.orientacja));
        const double diff = MatematykaTitan::normalizuj_roznice(f32(*u.kurs_koncowy) - cur);
        const WynikObrotu ob = obrot(k, u, cur, diff);
        u.omega = ob.omega;
        u.orientacja = k.mat.set_orientation_ypr(ob.yaw);
        if (std::fabs(diff) < PROG_KURSU_KONC) u.omega = 0.0;
    } else {
        u.omega = 0.0;
    }
}

bool FizykaLadowa::takt(const KontekstFizyki& k, Jednostka& u) {
    switch (u.tryb) {
        case TrybRuchu::jazda:
            return tryb_jazda(k, u);
        case TrybRuchu::hamowanie:
            tryb_hamowanie(k, u);
            return true;
        case TrybRuchu::obrot_w_miejscu:
            tryb_obrot_w_miejscu(k, u);
            return true;
        case TrybRuchu::spoczynek:
            if (u.v != 0.0 || u.omega != 0.0) tryb_hamowanie(k, u);
            return true;
    }
    return true;
}

}  // namespace openee
