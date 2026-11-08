// OpenEE Core – teren Titan: siatka wierzchołków, GetMeshZ, nachylenie wzdłuż osi jednostki (etap 28).
// docs/titan/fizyka_terenu.md § 1–3; GETerrainMesh::GetMeshZ (DLL EE 0x1003B6AC).
#pragma once

#include <array>
#include <cstdint>
#include <cstdlib>
#include <vector>

#include "openee/matematyka.hpp"

namespace openee {

class TerenSiatka {
public:
    TerenSiatka() = default;
    /// Siatka (szer × wys) wierzchołków; z w f32. Wierzchołek (ix, iy) leży w punkcie (ix, iy) świata.
    TerenSiatka(int szer, int wys, std::vector<float> z);

    /// Syntetyczny teren z zestawu referencyjnego etapu 27:
    /// z = 0 dla iy < 20; 0,15·(iy − 20) dla 20 ≤ iy ≤ 40; 3,0 dla iy > 40; (szer, wys) = (61, 61).
    static TerenSiatka syntetyczny_etap27();

    int szerokosc() const { return szer_; }
    int wysokosc() const { return wys_; }
    bool pusty() const { return z_.empty(); }
    bool wierzcholek_istnieje(std::int64_t ix, std::int64_t iy) const {
        return ix >= 0 && iy >= 0 && ix < szer_ && iy < wys_;
    }
    double h(std::int64_t ix, std::int64_t iy) const;  // poza siatką: 0 i licznik poza_mapa
    /// Komórka (pole) istnieje, gdy istnieją jej 4 wierzchołki.
    bool komorka_istnieje(std::int64_t ix, std::int64_t iy) const {
        return wierzcholek_istnieje(ix, iy) && wierzcholek_istnieje(ix + 1, iy + 1);
    }

    /// GetMeshZ: interpolacja na dwóch trójkątach pola (przekątna (ix,iy)–(ix+1,iy+1)), zapisy f32 jak w DLL.
    double get_mesh_z(double x, double y) const;

    /// Nachylenie 0x51216A: punkty P ± 0,65·(m01, m11), asin(Δz/1,3) przez tablicowe UMArcCos.
    double nachylenie(const MatematykaTitan& mat, double px, double py, double m01, double m11) const;

    std::uint64_t odczyty_poza_mapa() const { return poza_mapa_; }

    // --- przejezdność (etap 29): teren dozwolony dla typu jednostki i obiekty stałe blokujące pole ---
    /// Pole (ix, iy) – komórka między wierzchołkami (ix..ix+1, iy..iy+1); domyślnie przejezdne.
    void ustaw_przejezdnosc(std::int64_t ix, std::int64_t iy, bool p);
    /// Komórka istnieje, nie leży na linii brzegu rombu i jest przejezdna (teren + obiekty stałe).
    bool pole_przejezdne(std::int64_t ix, std::int64_t iy) const;
    /// Linie brzegu rombu mapy (EEMap +0x1816EC/F0/F4): x + y = a, x + y = b, |y − x| = c. Wyłączone, gdy brak.
    void ustaw_romb(int a, int b, int c) { romb_ = {a, b, c}; romb_aktywny_ = true; }
    bool na_brzegu_rombu(std::int64_t ix, std::int64_t iy) const {
        return romb_aktywny_ && (ix + iy == romb_[0] || ix + iy == romb_[1] || std::llabs(iy - ix) == romb_[2]);
    }

private:
    int szer_ = 0, wys_ = 0;
    std::vector<float> z_;
    std::vector<std::uint8_t> przejezdne_;
    std::array<int, 3> romb_{0, 0, 0};
    bool romb_aktywny_ = false;
    mutable std::uint64_t poza_mapa_ = 0;
};

}  // namespace openee
