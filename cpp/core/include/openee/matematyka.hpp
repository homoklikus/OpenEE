// OpenEE Core – matematyka Titan: UMCos, UMSin, UMArcCos, UMArcTan2, SetOrientationYPR, kurs z macierzy (etap 28).
// Odtworzenie bitowe według docs/titan/precyzja_numeryczna.md § 2 (Low-Level Engine.dll EE 0x1007DEBB …).
// Wartości „rejestru” to double; f32() w miejscach zapisu do pamięci w oryginale.
#pragma once

#include <array>
#include <memory>

#include "openee/f32.hpp"
#include "openee/tablice_dll.hpp"

namespace openee {

/// Stałe f32 z DLL/EXE (wartości po zaokrągleniu do float32).
struct StaleTitan {
    static double pi_2();     // 0x3FC90FDB
    static double pi();       // 0x40490FDB
    static double dwa_pi();   // 0x40C90FDB
    static double prog_acos();  // f32(0,9995) 0x3F7FDF3B
    static double k_cos();    // f32(5215,18896) = 16384/π
};

/// Macierz orientacji GETransformation (rotacja 3×3, wierszami): m[r][c].
/// Oś „przód” jednostki to kolumna 1: (m01, m11, m21).
struct Macierz3 {
    std::array<double, 9> m{1, 0, 0, 0, 1, 0, 0, 0, 1};  // wartości f32 przechowywane jako double
    double m01() const { return m[1]; }
    double m11() const { return m[4]; }
    double m21() const { return m[7]; }
};

class MatematykaTitan {
public:
    explicit MatematykaTitan(std::shared_ptr<const TabliceTrig> tablice);

    bool zgodna_z_oryginalem() const { return tablice_ && tablice_->zgodne_z_oryginalem; }
    const TabliceTrig& tablice() const { return *tablice_; }

    /// UMCos(float x) – zawinięcie do [−π, π] w rejestrze, indeks rint(f32(|x|·K)).
    double um_cos(double x) const;
    /// sin liczony jak w SetOrientationYPR: UMCos(f32(π/2 − f32(x))).
    double um_sin(double x) const;
    /// UMArcCos(float x) – wartość ST0 (bez zaokrąglenia do f32 w gałęzi szeregu).
    double um_arccos(double x) const;
    /// UMArcTan2(float a, float b) == atan2(a, b); (0, 0) → +π/2. Wartość ST0.
    double um_arctan2(double a, double b) const;
    /// Wołający w EXE od razu zapisuje wynik do f32.
    double um_arctan2_f32(double a, double b) const { return f32(um_arctan2(a, b)); }

    /// GETransformation::SetOrientationYPR(yaw, pitch, roll) – 9 elementów rotacji (f32).
    Macierz3 set_orientation_ypr(double yaw, double pitch = 0.0, double roll = 0.0) const;

    /// Kurs z macierzy jak 0x5484D9: f32(UMArcTan2(−f32(m01), f32(m11))).
    double kurs_z_macierzy(const Macierz3& m) const { return um_arctan2_f32(-f32(m.m01()), f32(m.m11())); }
    double kurs_z_macierzy(double m01, double m11) const { return um_arctan2_f32(-f32(m01), f32(m11)); }

    /// Kąt do punktu jak 0x5484D9: różnice zaokrąglone do f32 przed wywołaniem.
    double kat_do_celu(double px, double py, double wx, double wy) const;

    /// Normalizacja różnicy kątów do (−π, π] stałymi f32, wynik f32.
    static double normalizuj_roznice(double d);

private:
    std::shared_ptr<const TabliceTrig> tablice_;
};

}  // namespace openee
