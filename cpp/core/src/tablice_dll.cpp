#include "openee/tablice_dll.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>

namespace openee {

const std::vector<DeskryptorDLL>& wspierane_dll() {
    // Sumy i adresy: etap 27/28 (docs/cpp/ARCHITEKTURA_CORE.md § 10). Tablice we wszystkich wariantach są bajtowo
    // identyczne; czysta instalacja GOG i instalacja z NeoEE różnią się sumą pliku, ale nie adresami tablic
    // (sprawdzone wyszukaniem bajtów tablic w obu plikach, etap 28).
    static const std::vector<DeskryptorDLL> lista = {
        {"EE (Empire Earth, GOG – instalacja referencyjna)",
         "e3f6a2f6d1ec5c3144f7cdd918cf54166de86547d4bbb6b3c9177d3eeb003214", 0x3D7FC01Bu, 0x10000000u, 0x100D9130u,
         0x100E9134u, 0xC19C0CCE748B6A61ull, 0x9635BBCFCB0049B6ull},
        {"AoC (The Art of Conquest, GOG – instalacja referencyjna)",
         "adbd1a05c419a45eb135ecf083038a3f18113b489edfcac7a97c7ae26850cf69", 0x3D5D6AFBu, 0x10000000u, 0x100DD8A4u,
         0x100ED8A8u, 0xC19C0CCE748B6A61ull, 0x9635BBCFCB0049B6ull},
        {"EE (Empire Earth, GOG + NeoEE)", "0350ef776b68d3a6ac84d8addf05e710907bea911aa15b23b8dffdbf68e8b05b",
         0x3D7FC01Bu, 0x10000000u, 0x100D9130u, 0x100E9134u, 0xC19C0CCE748B6A61ull, 0x9635BBCFCB0049B6ull},
        {"AoC (The Art of Conquest, GOG + NeoEE)", "4acf04043867c02edd2ac95201f03342400840cf8469414c44ed3363fd8cbefb",
         0x3D5D6AFBu, 0x10000000u, 0x100DD8A4u, 0x100ED8A8u, 0xC19C0CCE748B6A61ull, 0x9635BBCFCB0049B6ull},
    };
    return lista;
}

std::uint64_t fnv1a64(const std::uint8_t* d, std::size_t n) {
    std::uint64_t h = 0xCBF29CE484222325ull;
    for (std::size_t i = 0; i < n; ++i) {
        h ^= d[i];
        h *= 0x100000001B3ull;
    }
    return h;
}

// --- SHA-256 (FIPS 180-4) ---
namespace {
constexpr std::uint32_t K256[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98,
    0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8,
    0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819,
    0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
    0xc67178f2};
inline std::uint32_t rotr(std::uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }
void blok(std::uint32_t h[8], const std::uint8_t* p) {
    std::uint32_t w[64];
    for (int i = 0; i < 16; ++i) {
        w[i] = (std::uint32_t(p[4 * i]) << 24) | (std::uint32_t(p[4 * i + 1]) << 16) |
               (std::uint32_t(p[4 * i + 2]) << 8) | std::uint32_t(p[4 * i + 3]);
    }
    for (int i = 16; i < 64; ++i) {
        const std::uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        const std::uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    std::uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], k = h[7];
    for (int i = 0; i < 64; ++i) {
        const std::uint32_t S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        const std::uint32_t ch = (e & f) ^ (~e & g);
        const std::uint32_t t1 = k + S1 + ch + K256[i] + w[i];
        const std::uint32_t S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        const std::uint32_t mj = (a & b) ^ (a & c) ^ (b & c);
        const std::uint32_t t2 = S0 + mj;
        k = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += k;
}
}  // namespace

std::string sha256_hex(const std::uint8_t* d, std::size_t n) {
    std::uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                          0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    std::size_t i = 0;
    for (; i + 64 <= n; i += 64) blok(h, d + i);
    std::uint8_t ost[128] = {0};
    const std::size_t r = n - i;
    std::memcpy(ost, d + i, r);
    ost[r] = 0x80;
    const std::size_t dl = (r < 56) ? 64 : 128;
    const std::uint64_t bity = std::uint64_t(n) * 8;
    for (int j = 0; j < 8; ++j) ost[dl - 1 - j] = std::uint8_t(bity >> (8 * j));
    blok(h, ost);
    if (dl == 128) blok(h, ost + 64);
    char buf[65];
    for (int j = 0; j < 8; ++j) std::snprintf(buf + 8 * j, 9, "%08x", h[j]);
    return std::string(buf, 64);
}

namespace {
std::uint16_t u16(const std::vector<std::uint8_t>& b, std::size_t o) { return std::uint16_t(b[o] | (b[o + 1] << 8)); }
std::uint32_t u32(const std::vector<std::uint8_t>& b, std::size_t o) {
    return std::uint32_t(b[o]) | (std::uint32_t(b[o + 1]) << 8) | (std::uint32_t(b[o + 2]) << 16) |
           (std::uint32_t(b[o + 3]) << 24);
}
WynikLadowaniaDLL blad(KodBleduDLL k, std::string m) {
    WynikLadowaniaDLL w;
    w.kod = k;
    w.komunikat = std::move(m);
    return w;
}
struct Sekcja { std::uint32_t va, vsize, raw, rawsize; };

// RVA → offset pliku; cały zakres [rva, rva+n) musi leżeć w danych surowych jednej sekcji.
bool rva_na_offset(const std::vector<Sekcja>& s, std::uint32_t rva, std::uint32_t n, std::size_t rozmiar_pliku,
                   std::size_t& off) {
    for (const auto& x : s) {
        const std::uint64_t pocz = x.va, kon = std::uint64_t(x.va) + std::max(x.vsize, x.rawsize);
        if (rva >= pocz && std::uint64_t(rva) + n <= kon) {
            const std::uint64_t w = std::uint64_t(rva - x.va);
            if (w + n > x.rawsize) return false;  // część tablicy poza danymi surowymi
            const std::uint64_t o = std::uint64_t(x.raw) + w;
            if (o + n > rozmiar_pliku) return false;
            off = std::size_t(o);
            return true;
        }
    }
    return false;
}

bool kontrola_cos(const std::vector<float>& t) {
    if (t.size() != ROZMIAR_TABLICY_COS) return false;
    if (t.front() != 1.0f || t[8192] != 0.0f || t.back() != -1.0f) return false;
    for (std::size_t i = 1; i < t.size(); ++i) {
        if (!std::isfinite(t[i]) || t[i] > t[i - 1]) return false;  // nierosnąca
        if (std::fabs(double(t[i]) - std::cos(double(i) * 3.14159265358979323846 / 16384.0)) > 2e-6) return false;
    }
    return true;
}
bool kontrola_acos(const std::vector<float>& t) {
    if (t.size() != ROZMIAR_TABLICY_ACOS) return false;
    if (t.back() != 0.0f) return false;
    for (std::size_t i = 0; i < t.size(); ++i) {
        if (!std::isfinite(t[i]) || (i > 0 && t[i] > t[i - 1])) return false;
        if (std::fabs(double(t[i]) - std::acos(double(i) / 32768.0)) > 2e-6) return false;
    }
    return true;
}
}  // namespace

WynikLadowaniaDLL zaladuj_tablice_dll(const std::string& sciezka) {
    std::ifstream f(sciezka, std::ios::binary);
    if (!f) return blad(KodBleduDLL::brak_pliku, "Nie znaleziono pliku Low-Level Engine.dll: " + sciezka);
    std::vector<std::uint8_t> b((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    if (f.bad()) return blad(KodBleduDLL::blad_odczytu, "Błąd odczytu pliku: " + sciezka);
    if (b.size() < 0x200 || b[0] != 'M' || b[1] != 'Z')
        return blad(KodBleduDLL::to_nie_pe, "Plik nie jest plikiem PE (brak sygnatury MZ): " + sciezka);
    const std::uint32_t pe = u32(b, 0x3C);
    if (std::uint64_t(pe) + 24 + 96 > b.size() || u32(b, pe) != 0x00004550u)
        return blad(KodBleduDLL::zly_naglowek_pe, "Uszkodzony nagłówek PE (brak sygnatury PE\\0\\0).");
    const std::uint16_t maszyna = u16(b, pe + 4);
    const std::uint16_t lsekcji = u16(b, pe + 6);
    const std::uint32_t czas = u32(b, pe + 8);
    const std::uint16_t rozm_opt = u16(b, pe + 20);
    const std::size_t opt = pe + 24;
    if (maszyna != 0x014C || u16(b, opt) != 0x10B)
        return blad(KodBleduDLL::nieobslugiwana_architektura,
                    "Oczekiwano 32-bitowej biblioteki PE (i386, PE32) – to nie jest Low-Level Engine.dll z EE/AoC.");
    const std::uint32_t baza = u32(b, opt + 28);
    const std::size_t tab = opt + rozm_opt;
    if (lsekcji == 0 || lsekcji > 96 || tab + std::size_t(lsekcji) * 40 > b.size())
        return blad(KodBleduDLL::zly_naglowek_pe, "Nieprawidłowa tablica sekcji PE.");
    std::vector<Sekcja> sek;
    for (std::size_t i = 0; i < lsekcji; ++i) {
        const std::size_t o = tab + i * 40;
        Sekcja s{u32(b, o + 12), u32(b, o + 8), u32(b, o + 20), u32(b, o + 16)};
        if (std::uint64_t(s.raw) + s.rawsize > b.size())
            return blad(KodBleduDLL::zly_naglowek_pe, "Sekcja PE wychodzi poza koniec pliku.");
        sek.push_back(s);
    }
    WynikLadowaniaDLL w;
    w.sha256 = sha256_hex(b.data(), b.size());
    const DeskryptorDLL* d = nullptr;
    for (const auto& x : wspierane_dll())
        if (w.sha256 == x.sha256) d = &x;
    if (!d) {
        w.kod = KodBleduDLL::nieznana_wersja;
        w.komunikat = "Nieznana wersja Low-Level Engine.dll (SHA-256 " + w.sha256 +
                      "). Wspierane: instalacje GOG + NeoEE EE i AoC (docs/cpp/BUDOWANIE.md).";
        return w;
    }
    if (d->znacznik_czasu != czas || d->baza_obrazu != baza) {
        w.kod = KodBleduDLL::nieznana_wersja;
        w.komunikat = "Niezgodny nagłówek PE dla wariantu " + std::string(d->nazwa);
        return w;
    }
    auto czytaj = [&](std::uint32_t va, std::size_t n, std::uint64_t fnv, std::vector<float>& out) -> bool {
        if (va < baza) return false;
        std::size_t off = 0;
        if (!rva_na_offset(sek, va - baza, std::uint32_t(n * 4), b.size(), off)) return false;
        if (fnv1a64(b.data() + off, n * 4) != fnv) return false;
        out.resize(n);
        for (std::size_t i = 0; i < n; ++i) {  // little-endian f32, niezależnie od porządku bajtów hosta
            const std::uint32_t u = u32(b, off + 4 * i);
            std::memcpy(&out[i], &u, 4);
        }
        return true;
    };
    auto t = std::make_shared<TabliceTrig>();
    if (!czytaj(d->va_cos, ROZMIAR_TABLICY_COS, d->fnv_cos, t->cos) ||
        !czytaj(d->va_acos, ROZMIAR_TABLICY_ACOS, d->fnv_acos, t->acos)) {
        w.kod = KodBleduDLL::adres_poza_sekcja;
        w.komunikat = "Adres tablicy poza sekcją albo niezgodna suma kontrolna tablicy (" + std::string(d->nazwa) + ").";
        return w;
    }
    if (!kontrola_cos(t->cos) || !kontrola_acos(t->acos)) {
        w.kod = KodBleduDLL::tablica_uszkodzona;
        w.komunikat = "Tablice nie przeszły kontroli wartości (monotoniczność, zakres).";
        return w;
    }
    t->zrodlo = sciezka + " [" + d->nazwa + "]";
    t->zgodne_z_oryginalem = true;
    w.wariant = d->nazwa;
    w.tablice = std::move(t);
    w.komunikat = "Wczytano tablice UMCos (16385) i UMArcCos (32769): " + w.wariant;
    return w;
}

std::shared_ptr<const TabliceTrig> tablice_przyblizone() {
    auto t = std::make_shared<TabliceTrig>();
    const double pi = 3.14159265358979323846;
    t->cos.resize(ROZMIAR_TABLICY_COS);
    t->acos.resize(ROZMIAR_TABLICY_ACOS);
    for (std::size_t i = 0; i < ROZMIAR_TABLICY_COS; ++i)
        t->cos[i] = float(std::round(std::cos(double(i) * pi / 16384.0) * 1e6) / 1e6);
    for (std::size_t i = 0; i < ROZMIAR_TABLICY_ACOS; ++i)
        t->acos[i] = float(std::round(std::acos(double(i) / 32768.0) * 1e6) / 1e6);
    t->zrodlo = "PRZYBLIŻONE (wzór; niezgodne z oryginałem – tylko diagnostyka)";
    t->zgodne_z_oryginalem = false;
    return t;
}

}  // namespace openee
