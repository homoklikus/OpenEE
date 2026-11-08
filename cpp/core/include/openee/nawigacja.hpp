// OpenEE Core – A* po polach mapy Titan (etap 29).
// docs/titan/astar_pola.md, astar_wyniki.md: EEAIAStarMachine (EE 0x4A4FE1 / 0x4A5428 / 0x4A5E13, AoC 0x4AA4E5 …).
// Koszty całkowite 10/14, H = 10·Manhattan, 8 sąsiadów w stałej kolejności, reguła narożników, lista otwarta
// = posortowana lista + 53 kubełki z uzupełnianiem po 15 (remisy LIFO), zamknięta = 53 kubełki, limity iteracji,
// wybór najbliższego węzła (0x4A6339). Port modelu weryfikacyjnego etapu 24 (zgodny z trasami z gry A–E).
// EE i AoC: algorytm identyczny [P]; różni się tylko źródło dostępności terenu (dostarcza wywołujący).
#pragma once

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace openee {

struct Pole {
    int x = 0, y = 0;
    bool operator==(const Pole& o) const { return x == o.x && y == o.y; }
    bool operator!=(const Pole& o) const { return !(*this == o); }
};

struct ParametryAStar {
    int limit_wywolania = 15;    // cel+0x20: −1 = bez limitu; po zawieszeniu rośnie o 1 do 32
    int limit_calkowity = -1;    // cel+0x24: −1 = bez limitu
    bool reguly_naroznikow = true;  // maszyna+0x1C (prośby jednostek: zawsze 1)
    bool koniec_bez_testu_dostepnosci = false;  // cel+0x2A = 1 (Bounded)
    /// Kara kosztu za obiekty na polu docelowym kroku (+50/+150) – nie dotyczy pola celu; brak = 0.
    std::function<int(int, int)> kara;
    bool zapisz_przebieg = false;
};

struct RozwinietyWezel {
    int x, y;
    std::uint32_t G, F;
};

struct WynikAStar {
    std::vector<Pole> trasa_od_celu;  // od węzła końcowego do startu (jak wektor w 0x41CE5F)
    int iteracje = 0;
    int wywolania = 0;
    std::string zakonczenie;          // "test celu" / "limit" / ""
    bool szukaj_najblizszego = false; // flaga +0x28
    bool koniec_najblizszy = false;   // koniec wybrany przez 0x4A6339
    Pole koniec;
    std::vector<RozwinietyWezel> przebieg;
};

/// Dostępność pola (x, y) w granicach mapy; pole poza 0..W−1, 0..H−1 jest zawsze niedostępne.
using Dostepnosc = std::function<bool(int, int)>;

class AStarTitan {
public:
    static WynikAStar szukaj(Pole start, Pole cel, const Dostepnosc& dostepne, int W, int H,
                             const ParametryAStar& p = {});

    /// Indeks kubełka ((x << 4) + y) mod 53 z dzieleniem ze znakiem (gałąź ELF dla h ≥ 2^28).
    static int kubelek(int x, int y);
};

}  // namespace openee
