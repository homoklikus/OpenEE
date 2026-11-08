// OpenEE Core – odpychanie małych jednostek 0x549179 (EE; AoC 0x555984) – etap 28.
// Wzór potwierdzony pomiarem EE 535 (docs/titan/walidacja_kolizji.md § 2). Lista kontaktów i zastosowanie
// wektora (0x549A08) nie są jeszcze wdrożone w takcie (docs/cpp/ARCHITEKTURA_CORE.md § Niewdrożone).
#pragma once

namespace openee {

struct WynikOdpychania {
    bool kolizja = false;
    bool budzik_dla_o = false;     // o dostaje (0,001; 0,001) zamiast wektora
    double push_o_x = 0, push_o_y = 0;
    double push_u_x = 0, push_u_y = 0;
};

/// Wkład jednostki u (przetwarzającej) do wektora push kontaktu o oraz do własnego.
/// o_v – prędkość o, o_vmax – vmax o (0 = jednostka nieruchoma).
WynikOdpychania odpychanie_male(double ux, double uy, double ru, double ox, double oy, double ro, double o_v,
                                double o_vmax);

}  // namespace openee
