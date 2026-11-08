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

    static WariantTitan ee() { return {Gra::ee, RegulaObrotu::ee, OdbudowaKontaktow::po_zapisie, "EE"}; }
    static WariantTitan aoc() { return {Gra::aoc, RegulaObrotu::aoc, OdbudowaKontaktow::przed_zapisem, "AoC"}; }
    static WariantTitan z_nazwy(const std::string& n) { return (n == "aoc" || n == "AoC") ? aoc() : ee(); }
};

}  // namespace openee
