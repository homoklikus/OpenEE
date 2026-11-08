// OpenEE Core – reprezentacja jednostki i jej stanu ruchu (etap 28).
// Pola odpowiadają polom rozpoznanym w EXE (przesunięcie EE w komentarzu), ale układ pamięci jest własny.
#pragma once

#include <cstdint>
#include <deque>
#include <optional>
#include <string>
#include <vector>

#include "openee/matematyka.hpp"
#include "openee/wariant.hpp"

namespace openee {

using IdJednostki = std::uint32_t;  // stabilny identyfikator nadawany przez Swiat; nie wskaźnik

/// Parametry ruchu typu jednostki (EEUnitClassUpgrade +0x34, typ +0x430…). Wartości tak, jak je wczytano
/// (z bazy gry są to f32; zestaw syntetyczny podaje je dziesiętnie – docs/cpp/ARCHITEKTURA_CORE.md).
struct ParametryRuchu {
    double a = 2.0;          // przyspieszenie liniowe (na wejściu zaokrąglane do f32)
    double vmax = 0.6;       // prędkość maks. (f32)
    double alfa = 12.21731;  // przyspieszenie kątowe [rad/s²]
    double wmax = 13.96264;  // maks. prędkość kątowa [rad/s]
    double rozmiar = 0.5;    // rozmiar typu: promień zaliczenia punktu pośredniego
    double c4 = 0.5;         // współczynnik kroków hamowania liniowego (typ+0x4C4)
    double c8 = 0.08185;     // współczynnik kroków hamowania obrotu (typ+0x4C8)
    double t488 = 0.5;       // reguła stoku (typ+0x488); ≥ 1 wyłącza
    bool pochyla = false;    // pochylanie macierzy na stoku (typ+0x5F3)
    double promien_kolizji = 0.5;  // +0x244
};

/// Tryb fizyki EEPMLand (+0x264, AoC +0x268).
enum class TrybRuchu : std::uint8_t { jazda = 0, spoczynek = 3, hamowanie = 4, obrot_w_miejscu = 5 };

/// Typ celu (kolejka celów, etap 21) – na razie tylko miejsce.
enum class TypCelu : std::uint8_t { brak = 0, miejsce = 1 };

struct Punkt2 {
    double x = 0, y = 0;  // f32 przechowywane jako double
};

/// Cel w kolejce celów (EEUGLocation, kolejka_rozkazow.md). Poziom 0 zwykłej jednostki lądowej.
struct CelRuchu {
    TypCelu typ = TypCelu::miejsce;
    double x = 0, y = 0;                  // dokładny punkt rozkazu
    std::optional<double> kurs_koncowy;   // cel+0x2C
    bool od_gracza = true;
    bool punkt_automatyczny = false;      // flaga +0x32 (punkty pośrednie podsystemu tras) – niewdrożone
    std::uint32_t proby = 0;              // cel+0x18: licznik prób przygotowania trasy
};

struct Jednostka {
    IdJednostki id = 0;
    WariantTitan wariant = WariantTitan::ee();
    ParametryRuchu param;

    // --- transformacja (+0x130): rotacja + pozycja (+0x13C/+0x14C/+0x15C) ---
    Macierz3 orientacja;
    double x = 0, y = 0, z = 0;

    double v = 0;      // +0x238
    double omega = 0;  // +0x17C
    TrybRuchu tryb = TrybRuchu::spoczynek;

    // --- maszyna stanów (+0x1E8) ---
    int stan = 5000;               // numer stanu (5000 Idle, 10003 Advance …)
    std::uint32_t termin_oceny = 0xFFFFFFFFu;  // +0x254 (BO-8)

    // --- trasa: kolejka punktów (+0x7C) i suma długości ---
    std::vector<Punkt2> trasa;
    std::size_t zdjete_punkty = 0;  // pozycja w kolejce (punkty zdjęte 0x5EDCF4)
    std::vector<double> dl_przed;   // f32: suma długości odcinków przed punktem i
    std::vector<double> dl_po;      // f32: suma do punktu i włącznie

    // --- cel (kolejka celów, uproszczona do bieżącego celu) ---
    TypCelu cel = TypCelu::brak;
    bool cel_od_gracza = true;
    std::optional<double> kurs_koncowy;  // cel+0x2C

    // --- liczniki i flagi ruchu ---
    bool osiagnieto_punkt = false;  // +0x33F
    bool trasa_gotowa = false;      // +0x33E
    double licznik_blokady_ms = 0;  // +0x248
    IdJednostki blokujacy = 0;      // +0x20C (0 = brak)
    std::uint16_t flaga_330 = 0;    // +0x330
    double push_x = 0, push_y = 0;  // +0x230 / +0x234
    std::uint32_t kontakty = 0;     // +0xC8 liczba kontaktów (= lista_kontaktow.size())
    std::vector<IdJednostki> lista_kontaktow;  // +0xC4 (symetryczna; odbudowa przy zmianie komórki)
    std::int64_t komorka_x = 0, komorka_y = 0;  // +0x1C/+0x20 pole jednostki (zapis transformacji)
    std::deque<CelRuchu> kolejka_celow;         // +0x90 poziom 0; front = cel bieżący (+0x1F0)
    std::uint64_t kroki_cofniete = 0, kroki_slizg = 0;  // diagnostyka testu kroku

    std::size_t pozostalo_punktow() const { return trasa.size() - zdjete_punkty; }
    bool ma_cel() const { return !kolejka_celow.empty() || cel != TypCelu::brak; }
};

}  // namespace openee
