// OpenEE Core – interfejsy podsystemów przygotowane pod kolejne etapy (etap 28).
// Implementacje „niewdrożone” zgłaszają to jawnie (status), zamiast udawać zgodność z Titan.
#pragma once

#include <cstdint>
#include <optional>
#include <vector>

namespace openee {

struct Punkt2;
struct Jednostka;

enum class StatusPodsystemu { wdrozony, czesciowy, niewdrozony };

struct OpisPodsystemu {
    const char* nazwa;
    StatusPodsystemu status;
    const char* uwagi;
};

/// Stan wdrożenia podsystemów Core (diagnostyka, raport).
const std::vector<OpisPodsystemu>& podsystemy();

/// Nawigacja: A* po polach (etap 24), graf podsektorów (etap 23), objazd 9002. Etap 28: brak implementacji –
/// trasy podaje wywołujący (Swiat::nadaj_trase).
class INawigacja {
public:
    virtual ~INawigacja() = default;
    virtual StatusPodsystemu status() const = 0;
    /// Trasa jednostki z (x, y) do celu; nullopt = brak drogi albo podsystem niewdrożony.
    virtual std::optional<std::vector<Punkt2>> trasa(const Jednostka& u, double cel_x, double cel_y) = 0;
};

/// Kolejka celów jednostki (etap 21: kolejka dwustronna, Shift, BO-4). Etap 28: tylko jeden bieżący cel w Jednostka.
class IKolejkaCelow {
public:
    virtual ~IKolejkaCelow() = default;
    virtual StatusPodsystemu status() const = 0;
    /// Wejście w Idle zdejmuje cel i aktywuje następny; zwraca true, gdy jest następny.
    virtual bool aktywuj_nastepny(Jednostka& u) = 0;
};

/// Grupy ruchu i parametry szyku (k = 2,0; etap 26–27).
class IGrupy {
public:
    virtual ~IGrupy() = default;
    virtual StatusPodsystemu status() const = 0;
};

/// Kolizje: lista kontaktów (zmiana komórki), 0x549179, reguła (a), 0x549A08.
class IKolizje {
public:
    virtual ~IKolizje() = default;
    virtual StatusPodsystemu status() const = 0;
    /// Krok końcowy jednostki po fizyce (vt+0x48).
    virtual void krok_koncowy(Jednostka& u, std::vector<Jednostka>& wszystkie) = 0;
};

}  // namespace openee
