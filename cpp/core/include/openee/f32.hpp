// OpenEE Core – arytmetyka zgodna z Titan (etap 28).
// Rejestry x87 w trybie _PC_53 + zaokrąglanie do najbliższej dają dla + − · / sqrt ten sam wynik co IEEE double
// (docs/titan/precyzja_numeryczna.md § 3). „Zapis do f32” w oryginale = jawne f32() tutaj.
// Wymagane flagi kompilatora (cpp/cmake/OpenEEFlagi.cmake): -ffp-contract=off, bez -ffast-math, SSE2 (x86-64)
// albo NEON (aarch64). Sprawdzenie w czasie kompilacji poniżej.
#pragma once

#include <cfloat>
#include <cmath>
#include <cstdint>
#include <cstring>

#if defined(__FAST_MATH__)
#error "OpenEE Core nie może być kompilowany z -ffast-math (zmienia wyniki zmiennoprzecinkowe)."
#endif
#if defined(FLT_EVAL_METHOD) && FLT_EVAL_METHOD != 0
#error "OpenEE Core wymaga FLT_EVAL_METHOD == 0 (SSE2/NEON, bez x87 z nadmiarową precyzją)."
#endif

namespace openee {

/// Zaokrąglenie wartości rejestru do float32 (round-to-nearest-even) i powrót do double.
/// Bariera asm wymusza istnienie wartości float32 w rejestrze: etap 28 wykazał, że GCC 11 z -O3
/// (wektoryzacja SLP) potrafi zmienić wynik pary zapisów f32 (docs/cpp/BUDOWANIE.md § Flagi). Bariera nie
/// generuje żadnej instrukcji, tylko zabrania optymalizatorowi łączenia konwersji.
inline double f32(double v) noexcept {
    float f = static_cast<float>(v);
#if defined(__GNUC__) && (defined(__x86_64__) || defined(__i386__))
    __asm__ volatile("" : "+x"(f));
#elif defined(__GNUC__) && defined(__aarch64__)
    __asm__ volatile("" : "+w"(f));
#endif
    return static_cast<double>(f);
}

/// Reprezentacja bitowa float32 – do testów bitowych i diagnostyki.
inline std::uint32_t bity_f32(double v) noexcept {
    const float f = static_cast<float>(v);
    std::uint32_t u;
    std::memcpy(&u, &f, sizeof u);
    return u;
}

inline double z_bitow_f32(std::uint32_t u) noexcept {
    float f;
    std::memcpy(&f, &u, sizeof f);
    return static_cast<double>(f);
}

/// fistp przy RC = nearest: zaokrąglenie do najbliższej, remis do parzystej. Niezależne od trybu FPU procesu.
inline std::int64_t rint_parzyste(double v) noexcept {
    const double d = std::floor(v);
    const double r = v - d;
    std::int64_t i = static_cast<std::int64_t>(d);
    if (r > 0.5 || (r == 0.5 && (i & 1) != 0)) {
        ++i;
    }
    return i;
}

/// Podłoga w stylu Titan (fistp + korekta „jeśli wynik > v to −1”) – równoważna floor.
inline std::int64_t podloga(double v) noexcept { return static_cast<std::int64_t>(std::floor(v)); }

}  // namespace openee
