#include "openee/matematyka.hpp"

#include <stdexcept>

namespace openee {

double StaleTitan::pi_2() { return f32(1.57079632679489661923); }
double StaleTitan::pi() { return f32(3.14159265358979323846); }
double StaleTitan::dwa_pi() { return f32(6.28318530717958647692); }
double StaleTitan::prog_acos() { return f32(0.9995); }
double StaleTitan::k_cos() { return f32(5215.18896); }

MatematykaTitan::MatematykaTitan(std::shared_ptr<const TabliceTrig> tablice) : tablice_(std::move(tablice)) {
    if (!tablice_ || tablice_->cos.size() != ROZMIAR_TABLICY_COS || tablice_->acos.size() != ROZMIAR_TABLICY_ACOS)
        throw std::invalid_argument("MatematykaTitan: brak albo niepełne tablice trygonometryczne");
}

double MatematykaTitan::um_cos(double x) const {
    x = f32(x);
    const double pi = StaleTitan::pi(), dpi = StaleTitan::dwa_pi();
    while (x < -pi) x = x + dpi;  // rejestr, bez zapisu f32
    while (x > pi) x = x - dpi;
    if (x < 0.0) x = -x;
    const std::int64_t i = rint_parzyste(f32(StaleTitan::k_cos() * x));
    return double(tablice_->cos[std::size_t(i)]);
}

double MatematykaTitan::um_sin(double x) const { return um_cos(f32(StaleTitan::pi_2() - f32(x))); }

double MatematykaTitan::um_arccos(double x) const {
    x = f32(x);
    if (x > 0.0) {
        if (x < StaleTitan::prog_acos()) {
            const std::int64_t i = rint_parzyste(f32(x * 32768.0));  // fmul dword 32768; fstp dword; fistp
            return double(tablice_->acos[std::size_t(i)]);
        }
        if (x >= 1.0) return 0.0;
        // szereg arcus tangens z t = sqrt(1 − x²)/x, kolejność operacji jak w kodzie DLL
        static const double C3 = f32(1.0 / 3.0), C5 = f32(0.2), C7 = f32(1.0 / 7.0);
        const double s = 1.0 - x * x;
        const double t = std::sqrt(s) / x;
        const double t2 = f32(t * t);
        const double a = f32(t);
        const double p = t * t2;
        const double r1 = f32(a - C3 * p);
        const double p2 = p * t2;
        const double sm = C5 * p2 + r1;
        return sm - (t2 * p2) * C7;
    }
    if (x >= 0.0) return StaleTitan::pi_2();  // x == ±0
    if (x < -1.0) x = -1.0;
    return StaleTitan::pi() - um_arccos(f32(-x));
}

double MatematykaTitan::um_arctan2(double a, double b) const {
    a = f32(a);
    b = f32(b);
    if (b == 0.0) return a >= 0.0 ? StaleTitan::pi_2() : -StaleTitan::pi_2();  // także −0,0; (0, 0) → +π/2
    const double r = std::sqrt(a * a + b * b);
    const double c = f32(b / r);
    const double v = um_arccos(c);
    return a < 0.0 ? -v : v;
}

Macierz3 MatematykaTitan::set_orientation_ypr(double yaw, double pitch, double roll) const {
    const double cY = um_cos(yaw), sY = um_sin(yaw);
    const double cP = um_cos(pitch), sP = um_sin(pitch);
    const double cR = um_cos(roll), sR = um_sin(roll);
    const double nsY = -sY, nsP = -sP;
    const double t = f32(nsP * cY);
    const double sPsY = nsP * nsY;
    Macierz3 r;
    r.m[0] = f32(sPsY * sR + cR * cY);
    r.m[1] = f32(cP * nsY);
    r.m[2] = f32(sPsY * cR + (-sR) * cY);
    r.m[3] = f32(t * sR + cR * sY);
    r.m[4] = f32(cP * cY);
    r.m[5] = f32(t * cR + (-sR) * sY);
    r.m[6] = f32(sR * cP);
    r.m[7] = sP;  // kopia bitowa
    r.m[8] = f32(cR * cP);
    return r;
}

double MatematykaTitan::kat_do_celu(double px, double py, double wx, double wy) const {
    const double dy = f32(f32(wy) - f32(py));
    const double dx = f32(-(f32(wx) - f32(px)));
    return um_arctan2_f32(dx, dy);
}

double MatematykaTitan::normalizuj_roznice(double d) {
    const double pi = StaleTitan::pi(), dpi = StaleTitan::dwa_pi();
    while (d > pi) d -= dpi;
    while (d < -pi) d += dpi;
    return f32(d);
}

}  // namespace openee
