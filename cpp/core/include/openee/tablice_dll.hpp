// OpenEE Core – tablice trygonometryczne Titan czytane z Low-Level Engine.dll użytkownika (etap 28).
// Plik PE czytany jako dane (bez ładowania kodu). Do repozytorium nie trafiają ani DLL, ani tablice.
#pragma once

#include <array>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace openee {

constexpr std::size_t ROZMIAR_TABLICY_COS = 16385;   // UMCos: [0, π], krok π/16384
constexpr std::size_t ROZMIAR_TABLICY_ACOS = 32769;  // UMArcCos: [0, 1], krok 1/32768

/// Tablice gotowe do użycia przez MatematykaTitan. Niezmienne po wczytaniu.
struct TabliceTrig {
    std::vector<float> cos;   // 16385 wartości
    std::vector<float> acos;  // 32769 wartości
    std::string zrodlo;       // opis pochodzenia (ścieżka + wariant) albo „PRZYBLIŻONE”
    bool zgodne_z_oryginalem = false;  // false = tryb przybliżony (tylko diagnostyka)
};

/// Wspierany wariant DLL. Adresy są wirtualne (VA) – loader przelicza je na offsety przez nagłówki sekcji.
struct DeskryptorDLL {
    const char* nazwa;          // np. "EE (GOG + NeoEE)"
    const char* sha256;         // suma całego pliku (hex, małe litery)
    std::uint32_t znacznik_czasu;  // IMAGE_FILE_HEADER.TimeDateStamp
    std::uint32_t baza_obrazu;     // ImageBase
    std::uint32_t va_cos;
    std::uint32_t va_acos;
    std::uint64_t fnv_cos;      // FNV-1a 64 bajtów tablicy (kontrola integralności, nie dane)
    std::uint64_t fnv_acos;
};

/// Lista wariantów zweryfikowanych w etapach 26–28.
const std::vector<DeskryptorDLL>& wspierane_dll();

enum class KodBleduDLL {
    brak,
    brak_pliku,
    blad_odczytu,
    to_nie_pe,
    zly_naglowek_pe,
    nieobslugiwana_architektura,
    nieznana_wersja,
    adres_poza_sekcja,
    tablica_uszkodzona,
};

struct WynikLadowaniaDLL {
    KodBleduDLL kod = KodBleduDLL::brak;
    std::string komunikat;          // czytelny opis po polsku
    std::string wariant;            // nazwa deskryptora
    std::string sha256;             // suma wczytanego pliku
    std::shared_ptr<const TabliceTrig> tablice;  // pusty przy błędzie
    bool ok() const { return kod == KodBleduDLL::brak && tablice != nullptr; }
};

/// Czyta tablice z pliku DLL: weryfikuje PE, sekcje, sumę SHA-256, przelicza RVA → offset, sprawdza tablice.
WynikLadowaniaDLL zaladuj_tablice_dll(const std::string& sciezka);

/// Tryb diagnostyczny: tablice z wzoru f32(round(f(i), 6)). NIE są zgodne z oryginałem
/// (15807/16385 i 32012/32769 pozycji – docs/titan/precyzja_numeryczna.md § 2.5).
std::shared_ptr<const TabliceTrig> tablice_przyblizone();

/// SHA-256 (własna implementacja, bez zależności) – zwraca hex.
std::string sha256_hex(const std::uint8_t* dane, std::size_t n);

/// FNV-1a 64.
std::uint64_t fnv1a64(const std::uint8_t* dane, std::size_t n);

}  // namespace openee
