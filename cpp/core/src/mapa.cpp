#include <algorithm>
#include "openee/mapa.hpp"

#include <bit>
#include <cmath>
#include <limits>
#include <stdexcept>

namespace openee {

std::vector<ZakresWiersza> wiersze_rombu(int n, int lo, int hi, int gorna, int postoj) {
    std::vector<ZakresWiersza> out;
    bool dl = true, dh = true;
    int sl = 0, sh = 0;
    for (int i = 0; i < n; ++i) {
        out.push_back({lo, hi});
        if (dl) {
            if (lo == 0) {
                if (++sl == postoj) dl = false;
            } else {
                --lo;
            }
        } else {
            ++lo;
        }
        if (dh) {
            if (hi == gorna) {
                if (++sh == postoj) dh = false;
            } else {
                ++hi;
            }
        } else {
            --hi;
        }
    }
    return out;
}

int MapaTitan::teren_z_pola(std::uint8_t tekstura, std::uint8_t flagi, float f10,
                            const std::array<std::int16_t, 256>& rodzina) {
    // [W: zgodność 39 344 / 39 480 pól z pamięcią gry, EE, „Wojna trojańska” – zad. 550/552]
    // bit 0 flag = pole pod wodą; f10 < −0,3 → woda głęboka (1); płytkie: ≥ 3 z bitów 1–4 → rodzina tekstury,
    // inaczej woda płytka (10). Pole lądowe → rodzina tekstury (dbterrain „Terrain family”).
    if (flagi & 1u) {
        if (f10 < -0.3f) return 1;
        if (std::popcount(unsigned((flagi >> 1) & 0xFu)) < 3) return 10;
    }
    return rodzina[tekstura];
}

MapaTitan MapaTitan::z_scn(const DaneTerenuScn& d, const std::array<std::int16_t, 256>& rodzina) {
    if (d.A <= 0 || d.B <= 0) throw std::invalid_argument("MapaTitan: A, B ≤ 0");
    const int N = d.A + d.B;
    const std::size_t T = std::size_t(2 * d.A * d.B + d.A + d.B), V = std::size_t(2 * d.A * d.B + 3 * d.A + 3 * d.B + 1);
    if (d.tekstura.size() != T || d.flagi.size() != T || d.f10.size() != T || d.wysokosc.size() != V)
        throw std::invalid_argument("MapaTitan: rozmiary tablic ≠ geometria rombu");
    MapaTitan m;
    m.n_ = N;
    m.teren_.assign(std::size_t(N) * N, -1);
    m.pewnosc_.assign(std::size_t(N) * N, PewnoscPola::brak);
    m.z_.assign(std::size_t(N + 1) * (N + 1), std::numeric_limits<float>::quiet_NaN());
    m.tekstura_.assign(std::size_t(N) * N, 0);
    m.f10_.assign(std::size_t(N) * N, 0.0f);
    m.rodzina_ = rodzina;
    const auto rp = wiersze_rombu(N, d.B - 1, d.B, N - 1, 1);
    const auto rv = wiersze_rombu(N + 1, d.B - 1, d.B + 1, N, 2);
    std::size_t i = 0;
    m.s1_ = std::numeric_limits<int>::max();
    m.s2_ = std::numeric_limits<int>::min();
    m.d_ = 0;
    for (int y = 0; y < N; ++y)
        for (int x = rp[std::size_t(y)].od; x <= rp[std::size_t(y)].do_; ++x, ++i) {
            const std::size_t k = std::size_t(y) * N + std::size_t(x);
            int t = teren_z_pola(d.tekstura[i], d.flagi[i], d.f10[i], rodzina);
            m.tekstura_[k] = d.tekstura[i];
            m.f10_[k] = d.f10[i];
            m.teren_[k] = std::int8_t(t);
            m.pewnosc_[k] = t < 0 ? PewnoscPola::niepewne : PewnoscPola::regula;
            m.s1_ = std::min(m.s1_, x + y);
            m.s2_ = std::max(m.s2_, x + y);
            m.d_ = std::max(m.d_, std::abs(y - x));
        }
    if (i != T) throw std::logic_error("MapaTitan: liczba pól ≠ T");
    // klify: rodzina 9 rozstrzygana inaczej niż reguła (0,3 % pól) – pole i jego sąsiedzi niepewni [N]
    for (int y = 0; y < N; ++y)
        for (int x = 0; x < N; ++x) {
            const std::size_t k = std::size_t(y) * N + std::size_t(x);
            if (m.teren_[k] != 9) continue;
            for (int dy = -1; dy <= 1; ++dy)
                for (int dx = -1; dx <= 1; ++dx)
                    if (m.komorka_istnieje(x + dx, y + dy))
                        m.pewnosc_[std::size_t(y + dy) * N + std::size_t(x + dx)] = PewnoscPola::niepewne;
        }
    i = 0;
    for (int y = 0; y <= N; ++y)
        for (int x = rv[std::size_t(y)].od; x <= rv[std::size_t(y)].do_; ++x, ++i)
            m.z_[std::size_t(y) * (N + 1) + std::size_t(x)] = d.wysokosc[i];
    if (i != V) throw std::logic_error("MapaTitan: liczba punktów ≠ V");
    return m;
}

std::vector<int> MapaTitan::rodzaj_pol_titan(double g, int rodzina_domyslna) const {
    // Etap 44 [W: 0x51241D / 0x512FB0, P: e35_a]. Ładowanie mapy:
    //  1) 0x51241D: każde pole → Tile::SetKind(rodzina tekstury); tekstura rodziny 9 (klif) zastępowana terenem
    //     domyślnym mapy (+0x181734, 0x513941) → SetKind(rodzina terenu domyślnego);
    //  2) 0x512FB0 przebieg 1: pole, którego najwyższy narożnik ≥ H (= map+0x1816D8) i rozpiętość narożników
    //     ≥ 1,5·H − 0,0001 → SetKind(9) (i malowanie tekstur klifu na polach (x−1..x, y−1..y));
    //  3) 0x512FB0 przebieg 2: pole o rodzaju ≠ 9, gdy ≥ 3 z pól {(x, y), (x−1, y), (x, y−1), (x−1, y−1)} ma
    //     teksturę klifu (lub nie istnieje) → SetKind(9).
    // Tile::SetKind 0x516E8C: f10 ≥ 0 → argument; f10 < −0,75·G → 1; inaczej < 3 narożniki ≥ 0 → 10, reszta → argument.
    const int N = n_;
    if (rodzina_domyslna < 0) {
        // teren domyślny map+0x181734: pole ogona kawałka 4 (e35_a: 0 – brak terenu 0) → [0x8D1FD0] = ID pierwszego
        // ważnego rekordu dbterrain (0x4D5662: rekord +0x0C > 0, +0x50 ≠ −1) – EE: ID 2, rodzina 0 [W; P e35_a]
        rodzina_domyslna = 0;
        for (int id = 0; id < 256; ++id)
            if (rodzina_[std::size_t(id)] >= 0) { rodzina_domyslna = rodzina_[std::size_t(id)]; break; }
    }
    std::vector<int> w(std::size_t(N) * N, -1);
    std::vector<int> k_yx(std::size_t(N) * N, -1);
    const float prog = float(-(float(g) * 0.75f));
    const float H = float(g);
    const float prog_klifu = float(H * 1.5f) - 9.999999747378752e-05f;
    auto z = [&](int x, int y) { return z_[std::size_t(y) * (N + 1) + std::size_t(x)]; };
    auto istnieje = [&](int x, int y) { return x >= 0 && y >= 0 && x < N && y < N && teren_[std::size_t(y) * N + std::size_t(x)] >= 0; };
    auto ustaw = [&](int x, int y, int arg) {
        const std::size_t k = std::size_t(y) * N + std::size_t(x);
        int r = arg;
        const float f = f10_[k];
        if (!(f >= 0.0f)) {
            if (f < prog) r = 1;
            else {
                int n = 0;
                const int c[4][2] = {{x, y}, {x + 1, y}, {x, y + 1}, {x + 1, y + 1}};
                for (const auto& q : c) {
                    const float h = z(q[0], q[1]);
                    if (h == h && h >= 0.0f) ++n;
                }
                if (n < 3) r = 10;
            }
        }
        k_yx[k] = r;
    };
    auto klif_tekstura = [&](int x, int y) { return !istnieje(x, y) || rodzina_[tekstura_[std::size_t(y) * N + std::size_t(x)]] == 9; };
    for (int y = 0; y < N; ++y)
        for (int x = 0; x < N; ++x) {
            if (!istnieje(x, y)) continue;
            const int rodz = rodzina_[tekstura_[std::size_t(y) * N + std::size_t(x)]];
            ustaw(x, y, rodz == 9 ? rodzina_domyslna : rodz);
        }
    for (int x = 0; x < N; ++x)            // przebieg 1 (pętla zewnętrzna po x jak 0x512FB0; kolejność bez znaczenia)
        for (int y = 0; y < N; ++y) {
            if (!istnieje(x, y)) continue;
            float mn = z(x, y), mx = mn;
            const float c[3] = {z(x, y + 1), z(x + 1, y), z(x + 1, y + 1)};
            for (float h : c) { if (h < mn) mn = h; if (h > mx) mx = h; }
            if (!(mx >= H)) continue;
            if (!(mx - mn >= prog_klifu)) continue;
            ustaw(x, y, 9);
        }
    for (int x = 0; x < N; ++x)            // przebieg 2
        for (int y = 0; y < N; ++y) {
            if (!istnieje(x, y) || k_yx[std::size_t(y) * N + std::size_t(x)] == 9) continue;
            const int n = int(klif_tekstura(x, y)) + int(klif_tekstura(x - 1, y)) + int(klif_tekstura(x, y - 1)) +
                          int(klif_tekstura(x - 1, y - 1));
            if (n >= 3) ustaw(x, y, 9);
        }
    for (int y = 0; y < N; ++y)
        for (int x = 0; x < N; ++x) w[std::size_t(x) * N + std::size_t(y)] = k_yx[std::size_t(y) * N + std::size_t(x)];
    return w;
}

std::vector<int> MapaTitan::bajt14_wody(const std::vector<int>& r) const {
    const int N = n_;
    std::vector<int> h(std::size_t(N) * N, 0);
    std::vector<std::uint8_t> s(std::size_t(N) * N, 0);   // 1 = S1 (+0x1C), 2 = S2 (+0x2C)
    auto rd = [&](int x, int y) { return (x < 0 || y < 0 || x >= N || y >= N) ? -1 : r[std::size_t(x) * N + std::size_t(y)]; };
    const int s8[8][2] = {{-1, 0}, {-1, 1}, {-1, -1}, {1, 0}, {1, 1}, {1, -1}, {0, -1}, {0, 1}};   // kolejność 0x4282B8
    for (int x = 0; x < N; ++x)
        for (int y = 0; y < N; ++y) {
            const int k = rd(x, y);
            if (k != 1 && k != 10) continue;
            bool lad = false, k9 = false;
            for (const auto& d : s8) {
                const int q = rd(x + d[0], y + d[1]);
                if (q < 0) continue;
                if (q != 1 && q != 10 && q != 9) { lad = true; break; }
                if (q == 9) k9 = true;
            }
            s[std::size_t(x) * N + std::size_t(y)] = lad ? 1 : (k9 ? 2 : 0);
        }
    for (int x = 0; x < N; ++x)
        for (int y = 0; y < N; ++y) {
            const int k = rd(x, y);
            if (k != 1 && k != 10) continue;
            int v = 0;
            for (const auto& d : s8) {
                const int a = x + d[0], b = y + d[1];
                if (a < 0 || b < 0 || a >= N || b >= N) continue;
                if (s[std::size_t(a) * N + std::size_t(b)]) v += 10;
            }
            if (s[std::size_t(x) * N + std::size_t(y)] == 1) v = -10 - v;
            h[std::size_t(x) * N + std::size_t(y)] = std::clamp(v, -120, 120);
        }
    return h;
}

bool MapaTitan::komorka_istnieje(int x, int y) const {
    return x >= 0 && y >= 0 && x < n_ && y < n_ && teren_[std::size_t(y) * n_ + std::size_t(x)] >= 0;
}
int MapaTitan::teren(int x, int y) const {
    return (x >= 0 && y >= 0 && x < n_ && y < n_) ? teren_[std::size_t(y) * n_ + std::size_t(x)] : -1;
}
PewnoscPola MapaTitan::pewnosc(int x, int y) const {
    return komorka_istnieje(x, y) ? pewnosc_[std::size_t(y) * n_ + std::size_t(x)] : PewnoscPola::brak;
}
bool MapaTitan::punkt_istnieje(int x, int y) const {
    return x >= 0 && y >= 0 && x <= n_ && y <= n_ && !std::isnan(z_[std::size_t(y) * (n_ + 1) + std::size_t(x)]);
}
double MapaTitan::wysokosc_punktu(int x, int y) const {
    return punkt_istnieje(x, y) ? double(z_[std::size_t(y) * (n_ + 1) + std::size_t(x)]) : 0.0;
}

void MapaTitan::ustaw_teren_z_pamieci(int x, int y, int t) {
    if (!komorka_istnieje(x, y)) return;
    const std::size_t k = std::size_t(y) * n_ + std::size_t(x);
    teren_[k] = std::int8_t(t);
    pewnosc_[k] = PewnoscPola::pamiec_gry;
}

StatystykaTerenu MapaTitan::porownaj_teren(const std::vector<std::array<int, 3>>& pamiec) const {
    StatystykaTerenu s;
    for (const auto& [x, y, t] : pamiec) {
        ++s.komorek;
        if (!komorka_istnieje(x, y)) { ++s.brakujacych; continue; }
        if (teren(x, y) == t) ++s.zgodnych;
        else {
            ++s.roznych;
            if (pewnosc(x, y) == PewnoscPola::niepewne) ++s.niepewnych_roznych;
        }
    }
    return s;
}

TerenSiatka MapaTitan::siatka(const std::array<std::uint8_t, 16>& dozw, bool z_obiektami) const {
    const int n1 = n_ + 1;
    std::vector<float> z(std::size_t(n1) * n1, 0.0f);
    std::vector<std::uint8_t> ist(std::size_t(n1) * n1, 0);
    for (std::size_t k = 0; k < z.size(); ++k)
        if (!std::isnan(z_[k])) { z[k] = z_[k]; ist[k] = 1; }
    TerenSiatka s(n1, n1, std::move(z));
    s.ustaw_istnienie(std::move(ist));
    s.ustaw_romb(s1_, s2_, d_);
    for (int y = 0; y < n_; ++y)
        for (int x = 0; x < n_; ++x) {
            const int t = teren(x, y);
            if (t < 0) continue;
            s.ustaw_przejezdnosc(x, y, t < 16 && dozw[std::size_t(t)] != 0);
        }
    if (z_obiektami)
        for (const auto& o : obiekty_) {
            if (!o.blokuje || !o.zywy) continue;
            for (int dy = 0; dy < o.kwadrat; ++dy)
                for (int dx = 0; dx < o.kwadrat; ++dx) s.dodaj_blokade(o.pole_x + dx, o.pole_y + dy);   // etap 47: licznik
        }
    return s;
}

std::uint64_t MapaTitan::skrot() const {
    std::uint64_t h = 1469598103934665603ULL;
    auto mix = [&](const void* p, std::size_t n) {
        const auto* b = static_cast<const unsigned char*>(p);
        for (std::size_t i = 0; i < n; ++i) { h ^= b[i]; h *= 1099511628211ULL; }
    };
    mix(teren_.data(), teren_.size());
    for (float v : z_) { const float w = std::isnan(v) ? -1e30f : v; mix(&w, sizeof w); }
    for (const auto& o : obiekty_) { mix(&o.id, 4); mix(&o.pole_x, 4); mix(&o.pole_y, 4); mix(&o.kwadrat, 4); const char b = o.blokuje; mix(&b, 1); }
    return h;
}

}  // namespace openee
