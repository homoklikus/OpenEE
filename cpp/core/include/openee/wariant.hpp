// OpenEE Core – konfiguracja wariantu gry (EE / AoC). Jedno miejsce na różnice kompilacji (etap 28).
#pragma once

#include <string>

namespace openee {

enum class Gra { ee, aoc };

/// Reguła decyzji i hamowania obrotu (docs/titan/precyzja_numeryczna.md § 6).
enum class RegulaObrotu {
    ee,   // 0x54880E / 0x548266: S_rot < |diff| → przyspieszaj, inaczej ω → 0
    aoc,  // 0x554F56 / 0x554738: ceil, reszta kąta; |ω| ≥ α·dt dopóki diff ma ten sam znak
};

/// Kolejność odbudowy listy kontaktów względem zapisu pozycji (docs/titan/walidacja_kolizji.md § 6, [W]).
enum class OdbudowaKontaktow { po_zapisie, przed_zapisem };

struct WariantTitan {
    Gra gra = Gra::ee;
    RegulaObrotu obrot = RegulaObrotu::ee;
    OdbudowaKontaktow kontakty = OdbudowaKontaktow::po_zapisie;
    const char* nazwa = "EE";
    // etap 52: dodatkowe losowania generatora przy utworzeniu jednostki z produkcji budynku [P: EE 679 – 2 utworzenia, po 3;
    // AoC 677 – 4 utworzenia, po 1]; EE tworzy jednostkę w 0x624DF8, AoC w osobnej 0x631B55 [W]; przeznaczenie losowań [N]
    int losowania_utworzenia = 3;

    static WariantTitan ee() { return {Gra::ee, RegulaObrotu::ee, OdbudowaKontaktow::po_zapisie, "EE", 3}; }
    static WariantTitan aoc() { return {Gra::aoc, RegulaObrotu::aoc, OdbudowaKontaktow::przed_zapisem, "AoC", 1}; }
    static WariantTitan z_nazwy(const std::string& n) { return (n == "aoc" || n == "AoC") ? aoc() : ee(); }
};

}  // namespace openee
