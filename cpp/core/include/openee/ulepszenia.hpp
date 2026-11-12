// OpenEE Core – premie atrybutów typu jednostki dla gracza (etap 49), ograniczone do parametrów ruchu.
// Titan [W: 0x627078, 0x627030, 0x626FB0, 0x628051; P: 648/649/650 – prorok gracza 1: +0xAC 0,45 → 0,5,
// a 2,0 → 2,22222, α 12,21731 → 13,57478, ωmax 13,96264 → 15,51404, +0xC4 = 1/a, +0xC8 = 1/α]:
//  - gracz ma liczbę poziomów każdego atrybutu (rekord gracza +4 + 4·atrybut); atrybut 14 (0xE) = prędkość;
//  - wartość' = wartość + poziomy · max(baza(typ, atrybut) · procent(typ, atrybut), minimum), procent z tabeli
//    typu +0x410 (+8 + 8·atrybut, 0 → 0,1), minimum prędkości 0,05 (0x825508), innych atrybutów 1,0 (0x3F800000);
//  - SetSpeed (0x628051): vmax' = wartość', a, α, ωmax (i +0xB8) mnożone przez vmax'/v_typu (+0x430), odwrotności
//    +0xC4 = 1/a, +0xC8 = 1/α, +0xCC = 1/ωmax, +0xD0 = 1/vmax.
// Źródło liczby poziomów u gracza (cywilizacja w scenariuszu) i baza 0x626834 – [N]; Core przyjmuje je z danych.
#pragma once

#include "openee/jednostka.hpp"

namespace openee {

struct PremiaAtrybutu {
    int poziomy = 0;        // poziomy atrybutu u gracza
    double procent = 0.1;   // typ +0x410 [+8 + 8·atrybut] (0 → 0,1)
};

/// Atrybut 14 (prędkość) – przyrost addytywny i proporcjonalne skalowanie a, α, ωmax (SetSpeed).
ParametryRuchu z_premia_predkosci(const ParametryRuchu& baza, const PremiaAtrybutu& p);

/// Przyrost jednego atrybutu (0x627030): wartość + poziomy · max(baza · procent, minimum), w f32 jak w EXE.
double wartosc_z_premia(double wartosc, double baza, const PremiaAtrybutu& p, double minimum);

}  // namespace openee
