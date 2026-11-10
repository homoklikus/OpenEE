// OpenEE Core – mapa scenariusza w reprezentacji Titan (etap 30): romb pól, wysokości, teren komórek (EETile+4),
// obiekty z zajmowanymi polami. Jedna interpretacja danych SCN dla Core i Godota (GDExtension przekazuje surowe
// tablice kawałka 4; importer GDScript i narzędzia Python tylko dekodują bajty, nie interpretują).
// Reguły i pewność: docs/titan/import_mapy.md.
#pragma once

#include <array>
#include <cstdint>
#include <string>
#include <vector>

#include "openee/teren.hpp"

namespace openee {

/// Surowe dane terenu z kawałka 4 SCN (kolejność rombu: wiersze pól od y = 0, w wierszu kolumny rosnąco).
struct DaneTerenuScn {
    int A = 0, B = 0;
    std::vector<std::uint8_t> tekstura, flagi;  // na pole (T = 2AB + A + B)
    std::vector<float> f10;                     // na pole: pierwszy f32 rekordu pola
    std::vector<float> wysokosc;                // na punkt (V = 2AB + 3A + 3B + 1)
};

struct ZakresWiersza {
    int od = 0, do_ = -1;  // kolumny [od, do_] (włącznie)
};

/// Zakresy kolumn wierszy rombu (narzedzia/eeformaty/scn.py _wiersze; FORMATY.md).
std::vector<ZakresWiersza> wiersze_rombu(int n, int lo, int hi, int gorna, int postoj);

enum class PewnoscPola : std::uint8_t { pamiec_gry = 0, regula = 1, niepewne = 2, brak = 3 };

/// Obiekt mapy (jednostka, budynek, drzewo…) z polami, na których listach jest w EEMap.
struct ObiektMapy {
    std::uint32_t id = 0;
    int typ_db = -1;
    int gracz = 0;
    int pole_x = 0, pole_y = 0;  // +0x1C/+0x20
    double x = 0, y = 0, z = 0;
    int kwadrat = 1;             // dbobjects „Square occupied”: obiekt na listach pól [X..X+n−1] × [Y..Y+n−1] [P]
    bool blokuje = false;        // typ +0x600 (EE) – test pola A* (astar_pola.md § 7)
    bool zywy = true;
};

struct StatystykaTerenu {
    int komorek = 0, zgodnych = 0, roznych = 0, niepewnych_roznych = 0, brakujacych = 0;
};

class MapaTitan {
public:
    /// Reguła etapu 30 (import_mapy.md § 3) – teren komórki z tekstury, flag i f10 pola SCN.
    /// rodzina_tekstury[id] = dbterrain „Terrain family” (−1 = nieznana tekstura → pole niepewne).
    static MapaTitan z_scn(const DaneTerenuScn& d, const std::array<std::int16_t, 256>& rodzina_tekstury);
    static int teren_z_pola(std::uint8_t tekstura, std::uint8_t flagi, float f10,
                            const std::array<std::int16_t, 256>& rodzina_tekstury);

    int szerokosc() const { return n_; }  // pola na bok (A + B)
    int brzeg_s1() const { return s1_; }
    int brzeg_s2() const { return s2_; }
    int brzeg_d() const { return d_; }
    bool komorka_istnieje(int x, int y) const;
    int teren(int x, int y) const;         // −1 poza rombem
    PewnoscPola pewnosc(int x, int y) const;
    double wysokosc_punktu(int x, int y) const;
    bool punkt_istnieje(int x, int y) const;

    /// Nadpisanie terenu komórki wartością odczytaną z pamięci gry (dane referencyjne, pewność pamiec_gry).
    void ustaw_teren_z_pamieci(int x, int y, int t);
    StatystykaTerenu porownaj_teren(const std::vector<std::array<int, 3>>& pamiec) const;  // {x, y, t}

    std::vector<ObiektMapy>& obiekty() { return obiekty_; }
    const std::vector<ObiektMapy>& obiekty() const { return obiekty_; }

    /// Siatka do fizyki i nawigacji Core dla typu jednostki: wysokości (romb, bez punktów spoza mapy), linie brzegu,
    /// przejezdność = teren_dozwolony[teren] (EEUnitClass+0x5D6) i brak żywego obiektu blokującego na liście pola.
    TerenSiatka siatka(const std::array<std::uint8_t, 16>& teren_dozwolony, bool z_obiektami = true) const;

    std::uint64_t skrot() const;  // FNV-1a terenu, wysokości i obiektów (regresja)

    /// Etap 43 – rodzaj obiektu pola (+0x04) z kodu Titan: Map::UpdateTiles 0x51183B → Tile::SetKind 0x516E8C [W, P]:
    /// f10 ≥ 0 → rodzina tekstury (dbterrain „Terrain family”, rekord +0x5C); f10 < −0,75·G → 1; inaczej, gdy mniej niż
    /// 3 narożniki pola mają wysokość ≥ 0 → 10, w przeciwnym razie rodzina. G = [0x9130E4] = 0,408248 (odczyt w grze).
    /// Etap 44: przed SetKind ładowanie 0x51241D zastępuje teksturę klifu (rodzina 9) terenem domyślnym mapy, a 0x512FB0
    /// ustawia rodzaj 9 z wysokości narożników (przebieg 1) i z tekstur klifu na polach (x−1..x, y−1..y) (przebieg 2) –
    /// e35_a 39 480/39 480 [P]. rodzina_domyslna < 0 → rodzina pierwszego znanego terenu (ID rosnąco).
    /// Układ wyniku x·N + y, −1 = brak pola. Niezależne od teren() (reguła etapu 30 – przejezdność, skrót bez zmian).
    std::vector<int> rodzaj_pol_titan(double g = 0.40824827551841736, int rodzina_domyslna = -1) const;
    /// Etap 43 – bajt +0x14 pól wody (rodzaj 1 i 10) z 0x4282B8 + 0x426577 (tryb 1) [W; P – znak]: S1 = pola wody
    /// z sąsiadem lądowym (rodzaj ∉ {1, 10, 9}) wśród 8 sąsiadów, S2 = pola wody bez lądu, z sąsiadem rodzaju 9;
    /// h = 10·(sąsiedzi ∈ S1 + sąsiedzi ∈ S2), dla pola ∈ S1: −10 − h; przycięcie ±120. Pola lądu: 0 (ich +0x14
    /// liczy 0x426577 tryb 0 po budowie regionów – z obiektów klasy 3; nieużywane przez regiony).
    std::vector<int> bajt14_wody(const std::vector<int>& rodzaj_xN) const;

private:
    int n_ = 0, s1_ = 0, s2_ = 0, d_ = 0;
    std::vector<std::int8_t> teren_;     // n × n, −1 = brak pola
    std::vector<PewnoscPola> pewnosc_;   // n × n
    std::vector<float> z_;               // (n + 1)², NaN = brak punktu
    std::vector<std::uint8_t> tekstura_; // n × n (etap 43 – klasyfikacja 0x516E8C)
    std::vector<float> f10_;             // n × n
    std::array<std::int16_t, 256> rodzina_{};
    std::vector<ObiektMapy> obiekty_;
};

}  // namespace openee
