// OpenEE Core – efekty obszarowe Titan (EEAreaEffect), etap 34: morale z budynków.
// Źródło: docs/titan/walka.md § 25 (EE 0x663A70 fabryka, 0x6641CA konstruktor EEAEMoraleFromBuildings, 0x664214
// zliczanie domów, 0x664B52 test jednostki w obszarze, 0x664E0B usuwanie nadmiarowych, 0x663DBD przebieg co 2000 ms).
// AoC: te same algorytmy pod innymi adresami (0x67B911, 0x67B95B, 0x67C651, 0x553C59) – walka.md § 25.9.
#pragma once

#include <cstdint>
#include <vector>

namespace openee {

/// Szablon efektu (EEAreaEffectTemplate, rekord dbareaeffect – loader EE 0x664C71). Pola jak w pamięci gry.
struct SzablonEfektu {
    int id = 0;
    int typ = 0;          // +0x20 „Effect type”: 2 EEAEMorale, 5 EEAEMoraleFromBuildings, 6 …FromMilitaryHeroes
    int ksztalt = 1;      // +0x24: 1 kwadrat (|dx|,|dy| ≤ r), 2 koło
    int relacja = 2;      // +0x28: 1 ten sam gracz, 2 sojusznik (z sobą), 3 wróg, 4 każdy
    float rozmiar = 0.0f; // +0x2C „Area size”
    int maks_morale = 0;  // +0x3C „Max morale”
    int wartosc_40 = 0;   // +0x40 „Heal effect” – poziom EEAEMorale (vt+0x4C = 0x6640B3)
    /// Typy (ID dbobjects, typ+0x4B8) należące do zestawu „Apply on unit set” (+0x38). Rozwiązanie zestawu
    /// (rodziny, obiekty, włącz/wyłącz – EE 0x52BFA4) wykonuje narzędzie z danych gry; Core dostaje gotową listę.
    std::vector<int> zestaw;
};

/// Egzemplarz efektu wygenerowany przez budynek (EEAreaEffect). Pola EE w komentarzach.
struct EfektObszaru {
    std::size_t szablon = 0;   // +0x10 (indeks w Swiat::szablony_efektow)
    std::uint32_t zrodlo = 0;  // +0x14 obiekt generujący (budynek)
    int gracz = 0;             // +0x18: numer gracza właściciela w chwili utworzenia (0x663B95)
    float x = 0.0f, y = 0.0f;  // +0x08/+0x0C: pozycja źródła z ostatniego przebiegu (0x664F3D); 0 po utworzeniu
    int poziom_max = 0;        // +0x20 = Max morale + „Alter max morale” wariantu gry (konstruktor 0x6641CA)
    int licznik = 0;           // +0x24 = min(liczba domów, +0x20) (0x664214)
    bool brudny = true;        // +0x1C: przeliczyć przy najbliższym przebiegu
};

/// Budynek w świecie (EEComplexUnit z efektami). Pozycja = środek (+0x13C/+0x14C), kotwica = pole +0x1C/+0x20.
struct Budynek {
    std::uint32_t id = 0;
    int typ_db = 0;            // typ +0x4B8 (ID dbobjects): 35 Town Center, 37 House, 41 Capitol …
    int gracz = 0;             // +0x18 → +0x45C
    int pole_x = 0, pole_y = 0;
    int rozmiar_pol = 1;       // typ +0x58C „Square occupied”
    float x = 0.0f, y = 0.0f;
    int hp = 1;                // +0x3C
    bool na_mapie = true;      // +0x340 (zerowane m.in. przy zdjęciu z mapy – 0x5EFFC3) [W]
    float mnoznik_obszaru = 1.0f;  // EEUnitClassUpgrade +0x84 = typ +0x428 (1,0 – 0x61C72C; ulepszenia [N])
    std::vector<std::size_t> efekty;  // lista wygenerowanych (+0xE4, wektor +0xEC…+0xF0)
};

/// Poziom efektu morale (vt+0x18 → vt+0x4C): typ 5 – min(+0x24, +0x20); typ 2 – szablon +0x40.
int poziom_efektu(const EfektObszaru& e, const SzablonEfektu& s);

/// Promień efektu (vt+0x1C = 0x66497B): mnożnik źródła · rozmiar, f32.
float promien_efektu(const SzablonEfektu& s, float mnoznik);

/// Prostokąt zliczania domów (0x664214): kotwica domu musi leżeć w [x0, x1] × [y0, y1] (włącznie).
struct ProstokatPol {
    int x0, x1, y0, y1;
};
ProstokatPol prostokat_zliczania(float x, float y, float promien);

/// Test położenia punktu w obszarze efektu (0x664BE9): kształt 1 – |dx| ≤ r i |dy| ≤ r; kształt 2 – odległość ≤ r.
bool w_obszarze(int ksztalt, float r, float cx, float cy, float px, float py);

/// Klasa równoważności przy usuwaniu nadmiarowych (0x664E0B): typy 2, 5 i 6 traktowane jako jeden (morale).
bool efekty_rownowazne(int typ_a, int typ_b);

}  // namespace openee
