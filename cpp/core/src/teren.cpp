#include "openee/teren.hpp"

#include <stdexcept>

namespace openee {

TerenSiatka::TerenSiatka(int szer, int wys, std::vector<float> z) : szer_(szer), wys_(wys), z_(std::move(z)) {
    if (szer < 2 || wys < 2 || z_.size() != std::size_t(szer) * std::size_t(wys))
        throw std::invalid_argument("TerenSiatka: nieprawidłowy rozmiar siatki");
}

TerenSiatka TerenSiatka::syntetyczny_etap27() {
    const int n = 61;
    std::vector<float> z(std::size_t(n) * n);
    for (int iy = 0; iy < n; ++iy)
        for (int ix = 0; ix < n; ++ix) {
            const double v = iy < 20 ? 0.0 : (iy <= 40 ? 0.15 * double(iy - 20) : 3.0);
            z[std::size_t(iy) * n + ix] = float(v);
        }
    return TerenSiatka(n, n, std::move(z));
}

void TerenSiatka::ustaw_przejezdnosc(std::int64_t ix, std::int64_t iy, bool p) {
    if (!komorka_istnieje(ix, iy)) return;
    if (przejezdne_.empty()) przejezdne_.assign(std::size_t(szer_) * std::size_t(wys_), 1);
    przejezdne_[std::size_t(iy) * std::size_t(szer_) + std::size_t(ix)] = p ? 1 : 0;
}

bool TerenSiatka::pole_przejezdne(std::int64_t ix, std::int64_t iy) const {
    if (!komorka_istnieje(ix, iy) || na_brzegu_rombu(ix, iy)) return false;
    const std::size_t i = std::size_t(iy) * std::size_t(szer_) + std::size_t(ix);
    if (!blokady_.empty() && blokady_[i] != 0) return false;
    return przejezdne_.empty() || przejezdne_[i] != 0;
}

void TerenSiatka::dodaj_blokade(std::int64_t ix, std::int64_t iy) {
    if (!komorka_istnieje(ix, iy)) return;
    if (blokady_.empty()) blokady_.assign(std::size_t(szer_) * std::size_t(wys_), 0);
    ++blokady_[std::size_t(iy) * std::size_t(szer_) + std::size_t(ix)];
}

bool TerenSiatka::zdejmij_blokade(std::int64_t ix, std::int64_t iy) {
    if (!komorka_istnieje(ix, iy) || blokady_.empty()) return false;
    auto& b = blokady_[std::size_t(iy) * std::size_t(szer_) + std::size_t(ix)];
    if (b == 0) return false;
    --b;
    return true;
}

int TerenSiatka::blokady(std::int64_t ix, std::int64_t iy) const {
    if (!komorka_istnieje(ix, iy) || blokady_.empty()) return 0;
    return blokady_[std::size_t(iy) * std::size_t(szer_) + std::size_t(ix)];
}

double TerenSiatka::h(std::int64_t ix, std::int64_t iy) const {
    if (!wierzcholek_istnieje(ix, iy)) {
        ++poza_mapa_;
        return 0.0;
    }
    return double(z_[std::size_t(iy) * std::size_t(szer_) + std::size_t(ix)]);
}

double TerenSiatka::get_mesh_z(double x, double y) const {
    x = f32(x);
    y = f32(y);
    const std::int64_t ix = podloga(x), iy = podloga(y);
    if (!istnieje_.empty() && !komorka_istnieje(ix, iy)) return 0.0;
    const double fx = x - double(ix), fy = y - double(iy);  // rejestr
    const double a = f32(1.0 - fx);                         // zapis f32
    const double h00 = h(ix, iy), h10 = h(ix + 1, iy), h01 = h(ix, iy + 1), h11 = h(ix + 1, iy + 1);
    const double A0 = h00 * a, mA0 = f32(A0);
    const double B1 = h11 * fx, mB1 = f32(B1);
    const double D = f32(B1 + A0);  // punkt na przekątnej
    if (fy >= fx) {                 // trójkąt (h00, h01, h11)
        const double t = (fy - fx) / a;
        return f32(t * (h01 * a + mB1) + (1.0 - t) * D);
    }
    if (fx == 0.0) return f32(D);
    const double t = fy / fx;  // trójkąt (h00, h10, h11)
    return f32((1.0 - t) * (h10 * fx + mA0) + t * D);
}

double TerenSiatka::nachylenie(const MatematykaTitan& mat, double px, double py, double m01, double m11) const {
    const double zA = get_mesh_z(px + f32(0.65 * m01), py + f32(0.65 * m11));
    const double zB = get_mesh_z(px - f32(0.65 * m01), py - f32(0.65 * m11));
    return f32(mat.um_arccos(f32((zA - zB) * f32(-0.769230783))) - f32(1.57079637));
}

}  // namespace openee
