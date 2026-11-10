// OpenEE Core – reprezentacja jednostki i jej stanu ruchu (etap 28).
// Pola odpowiadają polom rozpoznanym w EXE (przesunięcie EE w komentarzu), ale układ pamięci jest własny.
#pragma once

#include <cstdint>
#include <deque>
#include <optional>
#include <string>
#include <vector>

#include "openee/matematyka.hpp"
#include "openee/walka.hpp"
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
enum class TrybRuchu : std::uint8_t { jazda = 0, do_celu = 1, zatrzymanie = 2, spoczynek = 3, hamowanie = 4, obrot_w_miejscu = 5 };
// tryb 2 (etap 45): EEPMLand vt+0x30 = EE 0x54DDFF – v = 0 (0x54A55B), ω = 0, bez kroku końcowego vt+0x48 [W: kod;
// P: 638, t = 66988 – obywatel ginie w ruchu: tryb 2, v 0,418 → 0, pozycja bez zmian w takcie śmierci].
// tryb 1 (etap 31): EEPMLand vt+0x10 = EE 0x54DA82 – obrót do celu ataku (vt+0x1C z flagą broni), hamowanie v.

/// Typ celu (kolejka celów, etap 21): rodzaj celu +5 – 1 miejsce (EEUGLocation), 2 jednostka (EEUGAttackUnit, etap 31).
enum class TypCelu : std::uint8_t { brak = 0, miejsce = 1, jednostka = 2 };

struct Punkt2 {
    double x = 0, y = 0;  // f32 przechowywane jako double
};

/// Cel w kolejce celów (EEUGLocation, kolejka_rozkazow.md). Poziom 0 zwykłej jednostki lądowej.
struct CelRuchu {
    TypCelu typ = TypCelu::miejsce;
    double x = 0, y = 0;                  // dokładny punkt rozkazu
    std::optional<double> kurs_koncowy;   // cel+0x2C
    bool od_gracza = true;
    bool punkt_automatyczny = false;      // flaga +0x32 (punkt pośredni z grafu podsektorów, etap 40)
    bool etap_grafu = false;              // flaga +0x1D: etap grafu podsektorów wykonany dla tego celu (0x4A2764)
    std::uint32_t proby = 0;              // cel+0x18: licznik prób przygotowania trasy
    // EEUGAttackUnit (etap 31): +0x30 jednostka celu, +0x34/+0x38 pole celu (−10000 bez celu), punkt +0x20/+0x24
    std::uint32_t cel_jednostka = 0;
    std::int64_t pole_x = -10000, pole_y = -10000;
};

/// Ustawienia AI jednostki (EE +0x208 → bajty): +7 pościg poza LOS miejsca kontaktu, +8 szuka wrogów bez celu,
/// +9 wraca do miejsca kontaktu, +0xA ucieka. moze_swobodnie = wynik 0x4D6B5B (CanIMoveFreely) [H: stała].
struct UstawieniaAI {
    bool poscig_poza_icl = true;
    bool szuka_wrogow = true;
    bool wraca_do_icl = false;
    bool ucieka = false;
    bool moze_swobodnie = true;
};

/// Stan bojowy jednostki w świecie (etap 31). Pola: HP +0x3C, przeładowanie +0x2A0 (AoC +0x2A4), szukanie +0x2AC,
/// animacja +0x260, miejsce pierwszego kontaktu +0x118 i kurs +0x214 (−10000 = brak).
/// Wpis mapy celów nieosiągalnych jednostki (EEUnit +0xA0, klucz = id celu +0x24), etap 37 [P: kod 0x5E8651/0x5EC9BB]:
/// pola atakującego i celu w chwili wpisu oraz termin = czas gry + 30000 ms.
struct CelNieosiagalny {
    std::uint32_t cel = 0;
    std::int64_t pole_x = 0, pole_y = 0;          // pole atakującego (+0x1C/+0x20) przy wpisie
    std::int64_t pole_celu_x = 0, pole_celu_y = 0; // pole celu przy wpisie
    std::uint32_t termin_ms = 0;
};

struct BojJednostki {
    ParametryWalki p;
    StanWalki s;
    int szukanie_ms = 0;
    int animacja = 7;                  // 13 ruch, 0 atak, 7/8 spoczynek (pomiar etapu 30)
    double icl_x = 0, icl_y = 0, icl_kurs = -10000.0;
    std::uint64_t takt_wejscia_ataku = 0;
    UstawieniaAI ai;
    // Modyfikatory obrażeń jednostki (EEUnit +0xF8, wektor +0x100…+0x104), etap 33: poziomy morale obiektów
    // EEAEMoraleFromBuildings (min(+0x24, +0x20)). Źródło (budynki i ich zasięg) – poza Core [N]; ustawiane z zewnątrz.
    std::vector<int> morale;
    std::vector<CelNieosiagalny> nieosiagalne;   // EEUnit +0xA0 (etap 37)
    // etap 44: animacja umierania (+0x2FC – ms od ostatniej klatki, klatka, +0x337 – koniec sekwencji) i licznik +0x2A8
    // stanów 6001 (narastająco, co 4000 ms −1 zasób) / 6002 (odliczanie czasu rozkładu)
    int hp_29c = 0;                       // etap 45: EEUnit +0x29C – HP z aktualizacji typu (TakingLightDamage: +0x29C > HP)
    std::uint32_t ostatni_atakujacy = 0;   // etap 45: atakujący dla FleeDanger (0x62FE01 – wybór uproszczony [H])
    int smierc_ms = 0, smierc_klatka = 0;
    bool smierc_koniec = false;
    int licznik_2a8 = 0;
    int zasoby = 0;
    int regeneracja_ms = 0;   // EEUnit +0x290: odliczanie do regeneracji HP (0x625B47; etap 38 [P: 619 – −34 ms/takt, 1000 po regeneracji])
};

class SkryptStanow;
struct Jednostka {
    IdJednostki id = 0;
    const SkryptStanow* skrypt = nullptr;   // etap 45: skrypt .tai typu (nullptr = skrypt świata)
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
    // etap 45 – kolejka fizyki EEPhysics+0xADC (0x918DDC) [W: 0x530896/0x530913/0x53066A; P: 641 – 590 G1 i 578 G3]:
    // obiekt jest w kolejce od dodania (koniec kolejki) do zatwierdzenia usunięcia na początku następnego taktu.
    bool w_fizyce = true;
    bool usun_z_fizyki = false;   // kolejka usunięć +0xB04 (zatwierdzana w 0x53066A)

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

    // --- walka (etap 31) ---
    int gracz = 0;
    bool czlowiek = false;                 // gracz vt+0x74 (wybór tablicy trafień 0x4D5F2C)
    std::optional<BojJednostki> boj;       // brak = jednostka bez walki (dotychczasowe testy ruchu)
    double cel_walki_x = 0, cel_walki_y = 0;  // pozycja celu dla trybu 1 (ustawiana przed fizyką)
    // efekty obszarowe działające na jednostkę (EEUnitAreaEffectList +0xF8, wektor +0x100…+0x104), etap 34:
    // indeksy w Swiat::efekty_obszaru(); odbudowa co przebieg menedżera (0x663DBD)
    std::vector<std::size_t> efekty_obszaru;

    std::size_t pozostalo_punktow() const { return trasa.size() - zdjete_punkty; }
    bool ma_cel() const { return !kolejka_celow.empty() || cel != TypCelu::brak; }
};

}  // namespace openee
