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
                for (int dx = 0; dx < o.kwadrat; ++dx) s.ustaw_przejezdnosc(o.pole_x + dx, o.pole_y + dy, false);
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
