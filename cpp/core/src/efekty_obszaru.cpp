// OpenEE Core – efekty obszarowe Titan (etap 34). Arytmetyka zgodna z x87 (docs/cpp/PRECYZJA_NUMERYCZNA.md).
#include "openee/efekty_obszaru.hpp"

#include <cmath>
#include <cstdint>

namespace openee {

int poziom_efektu(const EfektObszaru& e, const SzablonEfektu& s) {
    if (s.typ == 5) return e.licznik < e.poziom_max ? e.licznik : e.poziom_max;  // 0x664202 (jl)
    if (s.typ == 2) return s.wartosc_40;                                         // 0x6640B3
    return 0;  // typ 6 (bohaterowie) nieodwzorowany [N]
}

float promien_efektu(const SzablonEfektu& s, float mnoznik) {
    // 0x66497B: fld mnoznik (0x66409A: [źródło+0x34]+0x84, bez źródła 1,0); fmul [rekord+0x2C]; wynik na stosie –
    // wywołujący zapisuje go fstp do f32 (0x664270, 0x5EC075).
    return float((long double)mnoznik * (long double)s.rozmiar);
}

namespace {
std::int32_t ftol(float v) { return std::int32_t(v); }  // __ftol2 0x53BA92 – obcięcie
std::int32_t fistp(float v) { return std::int32_t(std::nearbyint(v)); }  // tryb zaokrąglania FPU: do najbliższej
}  // namespace

ProstokatPol prostokat_zliczania(float x, float y, float promien) {
    // 0x664230…0x6642FE: ix = ftol(x), iy = ftol(y), r = fistp(promień f32). Ułamek x zapisany do f32, ułamek y na
    // stosie. Środek „w połowie pola” (0,25 < ułamek < 0,75 dla obu osi) → [i − r, i + r]; inaczej [i − r, i + r − 1].
    const std::int32_t ix = ftol(x), iy = ftol(y), r = fistp(promien);
    const float fx = float((long double)x - (long double)ix);
    const long double fy = (long double)y - (long double)iy;
    const bool srodek = fx > 0.25f && fx < 0.75f && fy > 0.25L && fy < 0.75L;
    const int d = srodek ? 0 : 1;
    return {ix - r, ix + r - d, iy - r, iy + r - d};
}

bool w_obszarze(int ksztalt, float r, float cx, float cy, float px, float py) {
    if (ksztalt == 1) {
        // 0x664C00: dx = f32(fabs(c.x − p.x)) (fstp), dy = fabs(c.y − p.y) na stosie; dx > r lub dy > r → poza
        const float dx = float(std::fabs(double((long double)cx - (long double)px)));
        const double dy = std::fabs(double((long double)cy - (long double)py));
        if (dx > r) return false;
        return !(dy > double(r));
    }
    if (ksztalt == 2) {
        // 0x664C50: odległość przez funkcję importowaną [0xB2F9F4] (UVector2 – długość) [W: sqrt(dx²+dy²)]
        const long double dx = (long double)px - (long double)cx, dy = (long double)py - (long double)cy;
        return !(std::sqrt(dx * dx + dy * dy) > (long double)r);
    }
    return false;
}

bool efekty_rownowazne(int a, int b) {
    if (a == b) return true;
    const auto morale = [](int t) { return t == 2 || t == 5 || t == 6; };
    return morale(a) && morale(b);
}

}  // namespace openee
