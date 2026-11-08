// OpenEE Core – świat symulacji i jeden takt Titan (etap 28).
// Kolejność taktu: docs/titan/specyfikacja_ruchu_godot.md § 3 (EEPhysics 0x546C63 → pętla jednostek od końca
// listy 0x547AAD → krok maszyny stanów 0x5F0F7E → fizyka trybu 0x549F82 → krok końcowy kolizji 0x549E61).
#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "openee/fizyka.hpp"
#include "openee/generator.hpp"
#include "openee/interfejsy.hpp"
#include "openee/jednostka.hpp"
#include "openee/maszyna_stanow.hpp"
#include "openee/nawigacja.hpp"
#include "openee/teren.hpp"

namespace openee {

/// Licznik zdarzeń i mechanizmów, których Core jeszcze nie odtwarza – widoczny w diagnostyce.
struct Diagnostyka {
    std::uint64_t zdarzenia_nieobslugiwane = 0;   // ocenione jako fałsz
    std::string ostatnie_nieobslugiwane;
    std::uint64_t wejscia_niewdrozone = 0;        // np. RepathAroundObstacle, stany walki
    std::string ostatnie_niewdrozone;
    std::uint64_t losowania_idle_pominiete = 0;   // wejście w Idle: warunkowe losowania [N]
    std::uint64_t objazdy_niezweryfikowane = 0;   // wejścia w 9002 (objazd A* ±50 – [W], bez pomiaru)
    std::uint64_t kolizje = 0;                    // wywołania 0x549179 z kolizją
    std::uint64_t kroki_odpychania = 0;           // udane przesunięcia 0x549A08
    std::uint64_t cele_zajete = 0;                // reguła (a)
    WynikAStar ostatnia_trasa;                    // ostatnie pełne A* (diagnostyka)
    bool ostatnia_bounded_sukces = false;
};

/// Migawka jednej jednostki do przekazania warstwie prezentacji.
struct MigawkaJednostki {
    IdJednostki id;
    double x, y, z, v, omega, kurs;
    Macierz3 orientacja;
    int stan;
    TrybRuchu tryb;
    std::size_t zdjete_punkty, pozostalo_punktow;
    double licznik_blokady_ms;
};

enum class StartTrasy {
    rozkaz,   // jak rozkaz gracza: stan 8000 PrepareToMove z gotową trasą
    advance,  // bezpośrednio w Advance (start przypadków referencyjnych etapu 27 – model v4)
};

class Swiat {
public:
    Swiat(std::shared_ptr<const TabliceTrig> tablice, TerenSiatka teren, WariantTitan wariant = WariantTitan::ee());

    const MatematykaTitan& matematyka() const { return mat_; }
    const TerenSiatka& teren() const { return teren_; }
    GeneratorTitan& generator() { return rng_; }
    const GeneratorTitan& generator() const { return rng_; }
    const WariantTitan& wariant() const { return wariant_; }
    const Diagnostyka& diagnostyka() const { return diag_; }
    void ustaw_skrypt(SkryptStanow s) { skrypt_ = std::move(s); }

    double dt() const { return dt_; }
    std::uint64_t takty() const { return takty_; }
    std::uint32_t zegar_ms() const { return zegar_ms_; }

    /// Nowa jednostka w spoczynku (Idle). Kolejność dodawania = kolejność listy jednostek.
    IdJednostki dodaj_jednostke(const ParametryRuchu& p, double x, double y, double kurs);
    Jednostka* jednostka(IdJednostki id);
    const Jednostka* jednostka(IdJednostki id) const;
    const std::vector<Jednostka>& jednostki() const { return jednostki_; }

    /// Rozkaz ruchu do punktu (kolejka celów, etap 21): zwykły – czyści kolejkę i wstawia cel na początek (8000);
    /// shift – dopisuje na koniec, gdy jednostka ma cel (inaczej jak zwykły). Trasa: A* w Core przy wejściu w 8000.
    bool rozkaz_ruchu(IdJednostki id, double x, double y, std::optional<double> kurs_koncowy = std::nullopt,
                      bool shift = false);

    /// Włącza/wyłącza kolizje w takcie (testy izolowane). Domyślnie włączone.
    void ustaw_kolizje(bool w) { kolizje_wlaczone_ = w; }
    TerenSiatka& teren_edycja() { return teren_; }

    /// Gotowa trasa (bez A*) i cel-miejsce z opcjonalnym kursem końcowym.
    bool nadaj_trase(IdJednostki id, const std::vector<Punkt2>& punkty, std::optional<double> kurs_koncowy,
                     StartTrasy start);

    /// Jeden takt symulacji.
    void takt();

    std::vector<MigawkaJednostki> migawka() const;

private:
    void krok_maszyny(Jednostka& u);
    std::optional<bool> zdarzenie(Jednostka& u, const std::string& nazwa);
    bool ocen_przejscie(Jednostka& u, const Przejscie& p);
    void wejdz_w_stan(Jednostka& u, const StanSkryptu& s);
    void nieobslugiwane(const std::string& n);
    bool przygotuj_trase(Jednostka& u, int okno);
    void aktywuj_cel(Jednostka& u);
    void po_ruchu(Jednostka& u, double x0, double y0);
    void odbuduj_kontakty(Jednostka& u, double cx, double cy);
    void krok_koncowy(Jednostka& u);
    void zastosuj_push(Jednostka& u);
    IdJednostki srodek_w_polu(std::int64_t ix, std::int64_t iy, IdJednostki pytajaca) const;
    bool kolizje_wlaczone_ = true;

    MatematykaTitan mat_;
    TerenSiatka teren_;
    WariantTitan wariant_;
    GeneratorTitan rng_;
    SkryptStanow skrypt_;
    Diagnostyka diag_;
    std::vector<Jednostka> jednostki_;
    IdJednostki nastepny_id_ = 1;
    double dt_;
    double tps_;
    std::uint64_t takty_ = 0;
    double czas_ms_ = 0;
    std::uint32_t zegar_ms_ = 0;
};

}  // namespace openee
