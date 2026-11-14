// OpenEE Core – świat symulacji i jeden takt Titan (etap 28).
// Kolejność taktu: docs/titan/specyfikacja_ruchu_godot.md § 3 (EEPhysics 0x546C63 → pętla jednostek od końca
// listy 0x547AAD → krok maszyny stanów 0x5F0F7E → fizyka trybu 0x549F82 → krok końcowy kolizji 0x549E61).
#pragma once

#include <array>
#include <cstdint>
#include <map>
#include <optional>
#include <memory>
#include <string>
#include <vector>

#include "openee/efekty_obszaru.hpp"
#include "openee/fizyka.hpp"
#include "openee/generator.hpp"
#include "openee/interfejsy.hpp"
#include "openee/jednostka.hpp"
#include "openee/maszyna_stanow.hpp"
#include "openee/nawigacja.hpp"
#include "openee/teren.hpp"
#include "openee/walka.hpp"

namespace openee {

/// Licznik zdarzeń i mechanizmów, których Core jeszcze nie odtwarza – widoczny w diagnostyce.
struct Diagnostyka {
    std::uint64_t zdarzenia_nieobslugiwane = 0;   // ocenione jako fałsz
    std::string ostatnie_nieobslugiwane;
    std::uint64_t wejscia_niewdrozone = 0;        // np. RepathAroundObstacle, stany walki
    std::string ostatnie_niewdrozone;
    std::uint64_t losowania_idle_pominiete = 0;   // wejście w Idle: warunkowe losowania [N]
    std::uint64_t osiagalnosc_astar = 0;          // etap 40: wywołania A* w 0x62D696
    std::uint64_t graf_prosby = 0;                // etap 40: etapy grafu podsektorów (0x4A1AFF bajt +0x1C)
    std::uint64_t graf_punkty = 0;                // wstawione punkty +0x32 (0x4A26E3)
    std::vector<int> graf_ostatnia;               // ostatnia ścieżka grafu (od celu do startu)
    std::uint64_t objazdy_niezweryfikowane = 0;   // wejścia w 9002 (objazd A* ±50 – [W], bez pomiaru)
    std::uint64_t kolizje = 0;                    // wywołania 0x549179 z kolizją
    std::uint64_t kroki_odpychania = 0;           // udane przesunięcia 0x549A08
    std::uint64_t cele_zajete = 0;                // reguła (a)
    std::uint64_t pary_duze = 0;                  // etap 53: pary skierowane do gałęzi dużej (0x548A3C) – bez reakcji w Core
    WynikAStar ostatnia_trasa;                    // ostatnie pełne A* (diagnostyka)
    bool ostatnia_bounded_sukces = false;
    int ostatnia_poprawa_poczatku = 0;   // etap 48: 0x4A2B29/0x4A3757 – 0 brak, 1 sukces, −1 porażka
    // --- walka (etap 31) ---
    std::uint64_t omijania_atakujacych = 0;      // etap 49: gałąź 0x549353 (omijanie przeładowującego sojusznika)
    std::uint64_t szukania_wroga = 0;            // wywołania 0x61AC11 z przeglądem kandydatów
    std::uint64_t wybory_celu = 0;               // utworzone cele EEUGAttackUnit
    std::uint64_t trafienia = 0, zgony = 0;
    std::uint64_t zalozenia_walki = 0;           // ocenione mechanizmy [N] z założeniem (osiągalność, mgła, …)
    std::string ostatnie_zalozenie;
    // --- efekty obszarowe (etap 34) ---
    std::uint64_t przebiegi_efektow = 0;         // przebiegi menedżera 0x663DBD (co 2000 ms czasu gry)
    std::uint64_t efekty_nieodwzorowane = 0;     // szablony typów innych niż 2 i 5 (leczenie, bohaterowie …) [N]
};

/// Zdarzenie walki w świecie (diagnostyka i porównania z grą).
struct ZdarzenieWalkiSwiata {
    std::uint64_t takt;
    IdJednostki kto;
    IdJednostki cel;
    std::string rodzaj;   // wybor_celu, atak, trafienie, smierc
    int wartosc;
};

/// Migawka jednej jednostki do przekazania warstwie prezentacji.
struct MigawkaJednostki {
    IdJednostki id;
    double x, y, z, v, omega, kurs;
    Macierz3 orientacja;
    int stan;
    TrybRuchu tryb;
    std::size_t zdjete_punkty, pozostalo_punktow;
    double licznik_blokady_ms;
};

enum class StartTrasy {
    rozkaz,   // jak rozkaz gracza: stan 8000 PrepareToMove z gotową trasą
    advance,  // bezpośrednio w Advance (start przypadków referencyjnych etapu 27 – model v4)
};

/// Graf podsektorów Titan (EEAIContinentManager, EE 0x917BC8) – etap 40. Struktura z kodu [W]; algorytm budowy
/// podsektorów (0x42434F/0x41E990) nieodtworzony – dane podaje wywołujący (tryb diagnostyczny: odczyt z pamięci gry).
struct Podsektor {
    int id = 0;                 // +0x50
    int sektor_i = 0, sektor_j = 0;   // sektor +0x44 → +0x40/+0x44 (komórka siatki sektorów)
    int rodzaj = 0;             // +0x54
    int punkt_x = 0, punkt_y = 0;     // +0x3C/+0x40 – punkt reprezentatywny (pole)
    std::vector<int> sasiedzi;  // +0x2C…+0x34 (kolejność z pamięci; pętla grafu przechodzi od końca)
};
struct GrafPodsektorow {
    // etap 47 – stan przyrostowy 0x4278C3 [W]: listy podsektorów sektorów (lista sektora +0x08, kolejność tworzenia),
    // największe id (+0x10E menedżera) i wolne id (+0xBC; 0x425E8D bierze ostatni, inaczej ++największe)
    std::map<std::pair<int, int>, std::vector<int>> sektory;
    int maks_id = 0;
    std::vector<int> wolne_id;
    bool z_gry = false;         // dane odczytane z pamięci gry (nie zbudowane w Core)
    std::string zrodlo = "brak";   // etap 41: „gra (odczyt)”, „Core z przydziału pól”; etap 42: „Core z wejścia mapy”
    std::map<int, Podsektor> podsektory;
    std::map<std::int64_t, int> pole_podsektor;   // (x << 32 | y) → id (pola z U2DSparseArrayPointContainer +0x10)
    int podsektor_pola(std::int64_t x, std::int64_t y) const {
        auto it = pole_podsektor.find((x << 32) | (y & 0xffffffff));
        return it == pole_podsektor.end() ? -1 : it->second;
    }
};
/// A* grafu podsektorów 0x4A5807 [W: kod]: koszt krawędzi 0x41E584 (ten sam sektor 1, sąsiedni w osi 10, po
/// przekątnej 14), H = 10·Manhattan komórek sektorów (0x4A6077), sąsiedzi od końca listy, test celu 0x41E3C0 (węzeł =
/// cel albo sektor w odległości ≤ 1 i cel na liście sąsiadów węzła). Wynik: identyfikatory od celu do startu
/// (z celem na początku). Remisy F – LIFO [H, jak lista otwarta pól].
std::vector<int> szukaj_w_grafie(const GrafPodsektorow& g, int start, int cel);

/// Etap 41 – część budowy grafu z kodu Titan [P: odczyt 1857 podsektorów e35_a]: z przydziału pól do podsektorów
/// (siatka id, układ x·H + y, 0 = pole poza grafem) Core wyznacza sektory (komórka siatki), punkty reprezentatywne
/// U2DSparseArrayPointContainer::ComputeCenterPoint(true) (0x42C2D5; 1851/1857 zgodnych) i listy sąsiadów 0x4246E8
/// (skan x↑, y↑; pola (x−1, y), (x, y−1), (x−1, y−1), (x+1, y−1); dopisanie wzajemne na koniec listy; 1857/1857
/// zgodnych co do zbioru i kolejności). Przydział pól (flood 0x42434F po siatce regionów 0x423E3F) – [N]: wejście.
GrafPodsektorow zbuduj_graf_z_przydzialu(const std::vector<int>& id_xH, int W, int H, int komorka);
/// Etap 42 – wejście floodu regionów 0x4240D3 (dane mapy na pole, układ x·N + y). Pola z kodu EE:
/// rodzaj pola = obiekt pola +0x04 (−1 = brak obiektu pola), wysokość = siatka 0x917CB8 albo bajt +0x14 pola,
/// obszar = siatka +0xF4 managera (indeks w wektorze +0x3C; obszar: rodzaj +0xD8, id +0xDA), obiekty z listy pola +0x08.
struct ObiektPolaRegionu {
    std::uint32_t id = 0;   // jednostka +0x24
    int hp = 0;             // +0x3C
    int gracz = 0;          // gracz(+0x18) +0x45C
    int klasa568 = 0;       // typ +0x568 (3 = obiekt klasy przeszkody wodnej – 0x42CA21)
    int flaga600 = 0;       // typ +0x600
    int klasa4b4 = 0;       // typ +0x4B4 (0x19, 1)
    int flaga612 = 0;       // typ +0x612
    bool vt58 = false;      // vt+0x58 (jednostka złożona: bajt +0x345; prosta: 0)
};
struct WejscieRegionow {
    int N = 0;
    std::vector<int> rodzaj_pola, wysokosc, obszar;
    std::vector<std::pair<int, int>> obszary;   // indeks → (rodzaj +0xD8, id +0xDA)
    std::map<int, std::vector<ObiektPolaRegionu>> obiekty;   // indeks pola → lista (kolejność listy pola)
    int brzeg_e0 = 0, brzeg_e1 = 0, brzeg_e2 = 0;           // map+0x1816EC / +0x1816F0 / +0x1816F4
};
struct SiatkaRegionow {
    int N = 0;
    std::vector<int> etykieta;     // x·N + y; 0 = brak regionu
    std::vector<int> rodzaj;       // etykieta → rodzaj regionu (+0x7C = tryb +0x94 maszyny), [0] nieużywane
};
/// Etap 42 – siatka obszarów (+0xF4) z rodzajów pól, model z pomiaru [P: e35_a 39 480/39 480 pól i id; funkcja
/// budująca w kodzie EE nieustalona – N]: klasa pola = 4 na brzegu rombu, 2 dla rodzaju pola 1, 3 dla rodzaju 9,
/// inaczej 1; składowe (brzeg i klify – 8-spójność, pozostałe – 4-spójność; klify od etapu 44 – e13_para), start
/// x malejąco, y malejąco, id od 1.
/// Uzupełnia w.obszar i w.obszary.
void zbuduj_obszary(WejscieRegionow& w);
/// Etap 44 [W: 0x42439A; P: e35_a 19, e13_para 12 – odczyt managera +0xE0]: bok sektora podsektorów z map+0x1816F4
/// (połowa szerokości rombu, MapaTitan::brzeg_d): ≤ 42 → 7, ≤ 58 → 10, ≤ 75 → 12, ≤ 105 → 15, ≤ 160 → 19, ≤ 220 → 21,
/// powyżej → 15.
int komorka_sektora(int brzeg_d);
/// Etap 44 – obiekt scenariusza do rejestracji na polach mapy (kawałek 5 SCN + dbobjects).
/// Etap 48 – pozostałość budynku (dbobjects „Debris on death#2”, np. 361 „Amb - Debris 1x”, 362 „2x”) [P: 647, 648 –
/// obiekt HP 1 na polu budynku od taktu śmierci, na początku listy pola; bez zgłoszenia mapy; trwa po 6003].
struct Gruz {
    std::uint32_t id = 0;
    int typ = 0, X = 0, Y = 0, kwadrat = 1;
    std::uint64_t takt = 0;
    IdJednostki budynek = 0;
};
struct ObiektScnPola {
    std::uint32_t id = 0;
    int gracz = 0, X = 0, Y = 0;   // pole rekordu SCN (X, Y)
    int kwadrat = 1;               // dbobjects „Square occupied”
    int hp = 0;                    // dbobjects „Health” (regiony sprawdzają tylko hp > 0)
    int klasa568 = 0, flaga600 = 0, klasa4b4 = 0, flaga612 = 0;   // „Resource type”, „Is building?”, „Unit type”, zestaw 9
    bool vt58 = false;
};
/// Etap 44 [P: e35_a 5335/5335 obiektów]: obiekt zajmuje pola X..X+n−1 × Y..Y+n−1 (n = „Square occupied”); obiekty
/// wstawiane na POCZĄTEK listy pola (+0x08) w kolejności rekordów SCN (gracze 0…, rekordy w kolejności pliku) – lista pola
/// ma więc kolejność odwrotną do pliku. Pola spoza mapy (rodzaj −1) są pomijane. Uzupełnia w.obiekty.
void dodaj_obiekty_scn(WejscieRegionow& w, const std::vector<ObiektScnPola>& obiekty);
/// Etap 44 – zestaw jednostek dbunitset (0x52BFA4, [W]): obiekty (ID ≥ 0), zestaw dołączony („Include unit set”) i
/// wykluczony („Exclude unit set”). Rodziny pomijane: 0x52BFA4 sprawdza je tylko przy fladze zestawu +0x38 [N].
struct ZestawJednostek {
    std::vector<int> obiekty;
    std::vector<int> rodziny;      // tylko do testu „zestaw pusty” (obie listy puste → każdy typ); wartości > 0 [H]
    int dolacz = -1, wyklucz = -1;
};
/// Czy typ obiektu należy do zestawu nr (0x52BFA4: dopasowanie → wykluczenie; brak dopasowania → zestaw dołączony).
/// Typ +0x612 = zestaw 9 („Walls 1” → 10 → 71 → 68) – 0x621EB4 [W; P: e35_a 70/70 typów].
bool zestaw_zawiera(const std::map<int, ZestawJednostek>& zestawy, int nr, int typ);
/// Flood regionów 0x4240D3 → 0x42A66D z dostępnością 0x41B9C9 [P: e35_a 39 480/39 480 pól, 1135/1135 rodzajów przy
/// wejściu odczytanym z gry]. Start: x malejąco, y malejąco, pole z obszarem i bez etykiety; etykiety od 1.
SiatkaRegionow zbuduj_siatke_regionow(const WejscieRegionow& w);
/// Przydział pól do podsektorów 0x42434F (flood 0x42AA10 w prostokącie sektora, ta sama etykieta regionu; flaga
/// przekątnej z rodzaju regionu – 0x41EAE7: bez warunku boku dla rodzajów 3, 5, 6, 12, 13, 14) [P: 1857/1857].
std::vector<int> zbuduj_przydzial_podsektorow(const SiatkaRegionow& r, int komorka);
/// Pełny graf z wejścia mapy: regiony → przydział → zbuduj_graf_z_przydzialu (+ rodzaje podsektorów).
GrafPodsektorow zbuduj_graf_z_wejscia(const WejscieRegionow& w, int komorka);
/// Etap 47 – przyrostowa przebudowa jednego sektora (0x4278C3) [W: kod 0x4278C3, 0x42809D, 0x425E8D, 0x424DDD]:
/// regiony liczone od nowa z bieżącego wejścia (budowniczy 0x4290A2 → 0x429B6D, jak w budowie pełnej); podsektory sektora
/// (si, sj) usuwane (id na koniec listy wolnych, w kolejności listy sektora; usunięcie z list sąsiadów), flood w
/// prostokącie sektora (x malejąco, y malejąco) z id z listy wolnych (od końca) albo ++maks_id; punkty reprezentatywne
/// tylko nowych; sąsiedzi z przeglądu okna sektora powiększonego o 1 pole (x↑, y↑, reguła 0x4246E8, dopisanie na koniec
/// bez powtórzeń). Pozostałe podsektory i ich id bez zmian. Zwraca id nowych podsektorów.
std::vector<int> przebuduj_sektor(GrafPodsektorow& G, const WejscieRegionow& w, int komorka, int si, int sj);
/// Punkt reprezentatywny 0x42C2D5 dla listy pól w kolejności kontenera (kolumny od ostatniej, przedziały y rosnąco).
std::pair<int, int> punkt_reprezentatywny(const std::vector<std::pair<int, int>>& pola);

/// Etap 52 – pozycja produkcji (rekord dbtechtree z „Is object?” = 1) i dane tworzonej jednostki.
struct ParametryProdukcji {
    int tech_id = -1;
    int typ_db = -1;                       // dbtechtree „Object ID” (dbobjects)
    std::array<int, 5> koszt{};            // dbtechtree: żywność, drewno, kamień, złoto, żelazo
    int czas_ms = 0;                       // dbtechtree „Build time”
    double mnoznik_czasu = 1.0;            // ulepszenie typu +0x94 (start pozycji: czas × m [W: AoC 0x5FDDAF, EE 0x5EFB48])
    int populacja = 1;                     // koszt populacji (klasa vt+0x6C) [P: 677 – obywatel +1; 704/706 – Maceman +1]
    // etap 53: losowy zamiennik przy starcie pozycji. Gdy ≥ 0, start losuje URandom::Generate i przy wyniku ≥ 0,5
    // bieżącą pozycją zostaje technologia `losowy_zamiennik` (Citizen 1074 → Female Citizen 1451) [W: AoC 0x5FDDED…
    // 0x5FDE6B, EE 0x5EFB91 – tylko technologia obiektu dbobjects 32; P: 7/7 startów 677–679]. Inne technologie nie
    // losują przy starcie [P: 704/706 – Maceman, 5 startów AoC i 5 EE bez losowania].
    int losowy_zamiennik = -1;
    ParametryRuchu ruch;
    ParametryWalki walka;
    int hp = 0;
    std::string skrypt = "obywatel";
};

class Swiat {
public:
    Swiat(std::shared_ptr<const TabliceTrig> tablice, TerenSiatka teren, WariantTitan wariant = WariantTitan::ee());

    const MatematykaTitan& matematyka() const { return mat_; }
    const TerenSiatka& teren() const { return teren_; }
    GeneratorTitan& generator() { return rng_; }
    const GeneratorTitan& generator() const { return rng_; }
    const WariantTitan& wariant() const { return wariant_; }
    const Diagnostyka& diagnostyka() const { return diag_; }
    void ustaw_skrypt(SkryptStanow s) { skrypt_ = std::move(s); }
    /// Etap 45: skrypt .tai typu jednostki ("land" – skrypt świata, "obywatel" – citizen.tai).
    bool ustaw_skrypt_jednostki(IdJednostki id, const std::string& nazwa);
    bool ustaw_faze_leczenia(IdJednostki id, int takty_od_szukania);   // etap 46

    double dt() const { return dt_; }
    std::uint64_t takty() const { return takty_; }
    // CompletedUnitFacing (EE 0x614F52) – obrót do kursu celu zakończony (|Δ| ≤ 1° f32); używane też w testach
    static bool ukonczony_obrot(const MatematykaTitan& mat, const Macierz3& orientacja, double kurs_celu);
    std::uint32_t zegar_ms() const { return zegar_ms_; }

    /// Nowa jednostka w spoczynku (Idle). Kolejność dodawania = kolejność listy jednostek.
    IdJednostki dodaj_jednostke(const ParametryRuchu& p, double x, double y, double kurs);
    /// Etap 43: wysokość jednostki z zapisu scenariusza (translacja macierzy rekordu, +44). Gra trzyma ją bez zmian do
    /// pierwszej aktualizacji fizyki jednostki (dosadzenie do terenu) – przechwycenie 0x62C963 liczy odległość 3D
    /// z tą wartością [P: 631 – cel stojący z = 1,837 (zapis), teren 0,408; punkt (164,5001; 110,184) odtworzony].
    bool ustaw_z(IdJednostki id, double z);
    /// Etap 53: orientacja z elementów macierzy gry (kolumna „przód”: m01, m11) – stan początkowy z nagrania. Kurs jednostki
    /// po wczytaniu scenariusza nie leży na siatce tablic UMCos (np. m01 = 0,7070934, m11 = −0,7071197), a decyzja
    /// prędkości ma próg |diff| ≤ π/4 – odtworzenie macierzy z kąta przez tablice zmienia stronę progu [P: taran 690].
    bool ustaw_kurs_macierzy(IdJednostki id, double m01, double m11);
    /// Etap 44: kolejność listy jednostek po wczytaniu scenariusza – pozycja x rosnąco, potem y (kolejka fizyki 0x918DDC).
    void uporzadkuj_wg_pozycji();
    Jednostka* jednostka(IdJednostki id);
    const Jednostka* jednostka(IdJednostki id) const;
    const std::vector<Jednostka>& jednostki() const { return jednostki_; }

    /// Rozkaz ruchu do punktu (kolejka celów, etap 21): zwykły – czyści kolejkę i wstawia cel na początek (8000);
    /// shift – dopisuje na koniec, gdy jednostka ma cel (inaczej jak zwykły). Trasa: A* w Core przy wejściu w 8000.
    /// Kąt szyku rozkazu PPM bez przeciągnięcia (EEUICCommandUnits 0x641BDA → 0x64138B, etap 37) [P: kod; W: środek]:
    /// środek prostokąta pozycji zaznaczonych jednostek (0x5F6377) → punkt kliknięcia, θ = UMArcTan2(−Δx, Δy).
    /// Wartość trafia do celu EEUGLocation +0x2C jako kurs końcowy (620: kurs po 9006 zgodny z grą).
    double kat_rozkazu(const std::vector<IdJednostki>& ids, double x, double y) const;
    bool rozkaz_ruchu(IdJednostki id, double x, double y, std::optional<double> kurs_koncowy = std::nullopt,
                      bool shift = false);

    // --- walka (etap 31): stan bojowy w tej samej liście jednostek, ten sam zegar, RNG i maszyna stanów ---
    /// Nadaje jednostce stan bojowy (HP, parametry typu i gracza, ustawienia AI).
    bool ustaw_walke(IdJednostki id, int gracz, bool czlowiek, const ParametryWalki& p, int hp, UstawieniaAI ai = {});
    // --- efekty obszarowe i budynki (etap 34): morale z budynków liczone w Core ---
    /// Szablon efektu (rekord dbareaeffect). Zwraca indeks.
    std::size_t dodaj_szablon_efektu(SzablonEfektu s);
    /// „Alter max morale (dynamic)” wariantu gry (dbgamevariant: Scenarios 0, Tournament 0, Standard 2).
    void ustaw_premie_morale_wariantu(int p) { premia_morale_wariantu_ = p; }
    /// Budynek z efektami (identyfikatory szablonów z dbobjects „Area Effect ID” 1–4). Tworzy efekty typów 2 i 5
    /// (fabryka 0x663A70); inne typy – licznik efekty_nieodwzorowane. Dom (typ 37) wywołuje przeliczenie gracza.
    IdJednostki dodaj_budynek(Budynek b, const std::vector<int>& szablony = {});
    /// Zniszczenie/usunięcie budynku (gracz vt[49] – EE 0x55C397): efekty zostają przy jednostkach do następnego
    /// przebiegu (wyczyszczenie list 0x5E948A), dom wywołuje przeliczenie gracza (vt[47] 0x55C00E).
    bool usun_budynek(IdJednostki id);
    /// Zmiana właściciela: usunięcie u starego gracza i dodanie u nowego (przeliczenie obu, gdy dom).
    /// Numer gracza w istniejących efektach (+0x18) się nie zmienia [N – brak dowodu na ponowne utworzenie].
    bool zmien_wlasciciela_budynku(IdJednostki id, int gracz);
    const std::vector<Budynek>& budynki() const { return budynki_; }
    const std::vector<EfektObszaru>& efekty_obszaru() const { return efekty_; }
    const std::vector<SzablonEfektu>& szablony_efektow() const { return szablony_; }
    /// Odtworzenie stanu efektów przy starcie z migawki gry (gra miała je już przypisane): jeden przebieg menedżera
    /// poza rytmem 2000 ms; akumulator +0x9C bez zmian (faza z migawki nieznana – [N]).
    void odtworz_efekty_obszaru() { przebieg_efektow(); }
    /// Poziomy morale działające na jednostkę teraz (lista +0xF8 po usunięciu nadmiarowych + ustawione ręcznie).
    std::vector<int> poziomy_morale(const Jednostka& u) const;
    /// Poziomy morale (EEAEMoraleFromBuildings) jednostki – źródło w budynkach poza Core (etap 33).
    bool ustaw_morale(IdJednostki id, std::vector<int> poziomy) {
        Jednostka* u = jednostka(id);
        if (!u || !u->boj) return false;
        u->boj->morale = std::move(poziomy);
        return true;
    }
    /// Dyplomacja: wiersz gracza +0x9E4 (≠ 0 = wróg). Domyślnie różni gracze są wrogami.
    void ustaw_wrogow(int g1, int g2, bool wrog);
    bool wrogowie(int g1, int g2) const;
    /// Tablice obrażeń (0x8D2050, tablice trafień) i wagi wyboru celu (3 tryby) – dane referencyjne z gry.
    void ustaw_tablice_walki(TabliceObrazen t, std::array<WagiCelu, 3> wagi);
    /// AoC: granice losowego przeładowania [[0x92FCA8]+0x984/+0x988].
    void ustaw_przeladowanie_aoc(double lo, double hi) { aoc_lo_ = lo; aoc_hi_ = hi; }
    /// Modyfikator wysokości obrażeń (konfiguracja reguł gry) i premia gracza +0xA3C.
    void ustaw_modyfikator_wysokosci(ModyfikatorWysokosci m) { mod_wys_ = m; }
    void ustaw_graf_podsektorow(GrafPodsektorow g) { graf_ = std::move(g); }
    // etap 46 – dynamiczny graf [W: 0x4288A7 → 0x4A36F3 → 0x4A3641/0x4278C3]: wejście mapy zachowane w świecie,
    // usunięcie obiektu pola zgłasza zmianę, przebudowa po terminie +0xD4 (nie co takt)
    void ustaw_wejscie_mapy(WejscieRegionow w, int komorka, bool zbuduj = true);
    bool usun_obiekt_mapy(std::uint32_t id);
    void zglos_zmiane_mapy(const std::vector<int>& pola, bool natychmiast);
    /// Etap 47: tryb przebudowy – przyrostowy (0x4278C3, jeden sektor na wywołanie, kolejne po 100 ms) albo pełny
    /// (wariant zastępczy etapu 46 – cały graf z wejścia, do porównań i pomiarów wydajności).
    void ustaw_przebudowe_pelna(bool p) { przebudowa_pelna_ = p; }
    std::size_t zmienione_sektory() const { return zmienione_sektory_.size(); }
    std::uint64_t przebudowy_sektorow() const { return przebudowy_sektorow_; }
    const std::vector<int>& ostatnie_nowe_podsektory() const { return ostatnie_nowe_; }
    /// Etap 47 – budynek jako obiekt symulacji (ta sama lista jednostek, cele, obrażenia, stany, kolejka fizyki).
    /// X, Y – kotwica (rekord SCN), n – „Square occupied”, (x, y, z) – pozycja; w_siatce: blokada pól już naliczona przez
    /// MapaTitan::siatka (obiekt mapy) – wtedy bez ponownego dodania. Skrypt: Simple Building (Generic Death).
    const std::vector<Gruz>& gruz() const { return gruz_; }
    bool ustaw_gruz_budynku(IdJednostki id, int typ, int kwadrat);
    /// Etap 48 – budynek postawiony w trakcie gry (EEPlayer – dodanie jednostki 0x55C315 → 0x4288A7(obiekt, 0)) [W]:
    /// rejestracja na polach (początek list, jak obiekty SCN), blokada pól od razu (fundament = ten sam obiekt) i
    /// zgłoszenie zmiany mapy z terminem „zwykłym” (+0xD4 = teraz + *0x9183C0·10000 ms, opoznienie_przebudowy_s [N]).
    IdJednostki postaw_budynek(int gracz, int typ_db, int X, int Y, int n, double x, double y, double z,
                               const ParametryWalki& p, int hp, std::uint32_t id_mapy, int flaga600, int klasa4b4,
                               int flaga612, bool kolizyjny = true);
    IdJednostki dodaj_obiekt_budynku(int gracz, int typ_db, int X, int Y, int n, double x, double y, double z,
                                     const ParametryWalki& p, int hp, bool blokuje, std::uint32_t id_mapy, bool w_siatce,
                                     bool kolizyjny = true);
    /// Etap 49 – listy kontaktów wszystkich obiektów od nowa, w bieżącej kolejności listy (jak tworzenie obiektów przy
    /// wczytaniu: obiekt dopisuje wcześniejsze z własnego okna; odbudowa po kolei daje te same pary) [W: 0x5ED24B → 0x616F9D].
    void odbuduj_kontakty_wszystkich();
    /// Etap 50 – fundament budynku z rozkazu budowy (EEMBuildUnit) [P: 658/659]: obiekt na polach od razu (HP 1, +0x340 = 0),
    /// bez zgłoszenia zmiany mapy – zgłoszenie (termin zwykły) przy ukończeniu (BuildingRepaired).
    IdJednostki postaw_fundament(int gracz, int typ_db, int X, int Y, int n, double x, double y, double z,
                                 const ParametryWalki& p, std::uint32_t id_mapy, int flaga600, int klasa4b4, int flaga612);
    /// Etap 51 – zasoby gracza (EEPlayer +0xAF8.. i32: żywność, drewno, kamień, złoto, żelazo [P: 660]).
    void ustaw_zasoby(int gracz, const std::array<int, 5>& z) { zasoby_[gracz] = z; }
    std::array<int, 5> zasoby(int gracz) const { auto it = zasoby_.find(gracz); return it == zasoby_.end() ? std::array<int, 5>{} : it->second; }
    /// Etap 51 – opłata za budynek przy postawieniu fundamentu [P: 660/663 – dom: drewno −50, kamień −40 w chwili utworzenia
    /// fundamentu; 661 – przy braku zasobów gra odmawia już przy wyborze budynku: „Zbyt mało surowców…”, bez fundamentu
    /// i bez zmiany zasobów]. Zwraca false (bez zmian), gdy którejkolwiek pozycji brakuje.
    bool oplac(int gracz, const std::array<int, 5>& koszt);
    /// Etap 50 – rozkaz budowy obywatela (cel EEUGBuildRepair): miejsce pracy na obwodzie fundamentu, trasa, stany citizen.tai.
    bool rozkaz_budowy(IdJednostki obywatel, IdJednostki budynek);
    Punkt2 miejsce_budowy(const Jednostka& u, const Jednostka& b) const;
    /// Etap 51 – zbieranie (EEUGGather): źródło surowca jako obiekt Core (drzewo – obiekt Świata już w siatce), rozkaz
    /// zbierania z punktem pracy (gracz klika źródło), cykl Gather.tai, oddanie w magazynie (zasoby gracza).
    IdJednostki dodaj_zrodlo(int gracz, int typ_db, int X, int Y, double x, double y, double z, int hp, int ilosc,
                             int zasob_typ, int zasob_indeks, int tempo_indeks, std::uint32_t id_mapy);
    bool ustaw_magazyn(IdJednostki budynek, bool m);
    bool rozkaz_zbierania(IdJednostki obywatel, IdJednostki zrodlo, double x, double y);
    // --- etap 52: produkcja jednostek w budynkach (docs/titan/produkcja.md) ---
    void ustaw_produkcje(const ParametryProdukcji& p) { produkcja_typow_[p.tech_id] = p; }
    /// Populacja gracza (AoC +0xB14 / EE +0xB10) i składniki limitu: 1 + a + b + globalny (gracz vt+0x7C – AoC 0x56528B,
    /// EE 0x556EBC) [W; P: 678 – globalny 100, a = b = 0, panel „x/100”].
    void ustaw_populacje(int gracz, int populacja, int globalny, int a = 0, int b = 0) { populacja_[gracz] = {populacja, globalny, a, b}; }
    int populacja(int gracz) const { auto it = populacja_.find(gracz); return it == populacja_.end() ? 0 : it->second[0]; }
    int limit_populacji(int gracz) const { auto it = populacja_.find(gracz); return it == populacja_.end() ? 1 : 1 + it->second[1] + it->second[2] + it->second[3]; }
    /// Rozkaz produkcji (komunikat „Research Technology” → 0x5F5F97 / EE 0x5E8908): koszt pobierany od razu
    /// (gracz vt+0xB4, mnożnik 1,0), pozycja na koniec kolejki; wolny budynek zaczyna w tym samym takcie [P: 677].
    /// false – brak zasobów (bez zmian [P: 678]), budynek nieukończony albo nieznana pozycja.
    bool rozkaz_produkcji(IdJednostki budynek, int tech_id);
    /// Anulowanie: indeks 0 – pozycja bieżąca (0x5FD8F3: zwrot 1,0, licznik 0), k ≥ 1 – k-ta pozycja kolejki (zwrot 1,0)
    /// [W]; pomiar [N].
    bool anuluj_produkcje(IdJednostki budynek, int indeks);
    /// Etap 53: anulowanie z interfejsu (PPM na przycisku technologii; AoC 0x5FD984 z flagą „wszystkie” = 0) – pierwsza
    /// pozycja kolejki tej technologii (obywatel i obywatelka są równoważne), a gdy żadnej nie ma – bieżąca pozycja tej
    /// technologii (0x5FD8F3). Pełny zwrot kosztu [P: AoC 705, EE 706]. false = nic nie anulowano.
    bool anuluj_technologie(IdJednostki budynek, int tech_id);
    /// Etap 54: punkt zbiórki budynku (PPM w teren przy zaznaczonym budynku). Obowiązuje dla jednostek tworzonych od
    /// tej chwili: miejsce powstania = pierwsze wolne miejsce w polach obwodu budynku uporządkowanych według odległości
    /// pola od pola punktu, kurs na punkt, rozkaz ruchu do wolnego miejsca w polu punktu (docs/titan/produkcja.md § 6).
    bool ustaw_punkt_zbiorki(IdJednostki budynek, double x, double y);
    bool usun_punkt_zbiorki(IdJednostki budynek);
    /// Pola obwodu budynku [X..X+n−1]² w kolejności prób miejsca powstania [W: AoC 0x64BB36 bez punktu, 0x641299 z
    /// punktem – emulacja kodu]. Współrzędne względne (dx, dy) do kotwicy budynku.
    static std::vector<std::pair<int, int>> pola_wyjscia(int n, bool zbiorka, int zdx, int zdy);
    /// Miejsca w polu (dx, dy) względem budynku n × n dla jednostki o rozmiarze s [W: AoC 0x63F697 – emulacja]:
    /// kolejne przesunięcia w polu (ułamki pola), najwyżej floor(1/s) (krawędź), 1 (narożnik) albo floor(1/s)² (pole
    /// wewnętrzne – także miejsca w polu punktu zbiórki).
    static std::vector<std::pair<double, double>> miejsca_w_polu(int n, int dx, int dy, double s);
    /// Identyfikatory jednostek utworzonych w ostatnim takcie (do mapowania na obiekty gry w odtworzeniach).
    const std::vector<IdJednostki>& nowe_jednostki() const { return nowe_jednostki_; }
    std::uint64_t wersja_grafu() const { return wersja_grafu_; }
    std::uint64_t przebudowy_grafu() const { return przebudowy_grafu_; }
    bool przebudowa_zaplanowana() const { return przebudowa_d8_; }
    std::uint32_t termin_przebudowy() const { return termin_d4_; }
    const WejscieRegionow* wejscie_mapy() const { return wejscie_ ? &*wejscie_ : nullptr; }   // etap 48
    float opoznienie_przebudowy_s = 1.5f;   // *0x9183C0 [P: etap 50, 658 – +0xD4 = ukończenie domu + 15000 ms] (wcześniej 0 [N])
    const GrafPodsektorow& graf_podsektorow() const { return graf_; }
    /// N progu 9016 ShouldMoveToNextAutoWaypoint ([0x917DC8], 0x4243AC) z rozmiaru mapy
    static int prog_punktu_auto(int rozmiar_mapy);
    void ustaw_premie_wysokosci(int gracz, float p) { premia_wys_[gracz] = p; }
    /// Rozkaz ataku gracza (EEUGAttackUnit z +0x1C = 1): jak PPM na wrogu – cel na początek kolejki, stan CheckRange
    /// ([H]: wejście rozkazu ataku w InitialAttackState/CheckRange nieodczytane; tu – CheckRange).
    bool rozkaz_ataku(IdJednostki id, IdJednostki cel);
    const std::vector<ZdarzenieWalkiSwiata>& zdarzenia_walki() const { return zdarzenia_walki_; }
    /// Ustawia stan maszyny bez akcji wejścia (start z migawki gry).
    void ustaw_stan(IdJednostki id, int stan);

    /// Włącza/wyłącza kolizje w takcie (testy izolowane). Domyślnie włączone.
    void ustaw_kolizje(bool w) { kolizje_wlaczone_ = w; }
    TerenSiatka& teren_edycja() { return teren_; }

    /// Gotowa trasa (bez A*) i cel-miejsce z opcjonalnym kursem końcowym.
    bool nadaj_trase(IdJednostki id, const std::vector<Punkt2>& punkty, std::optional<double> kurs_koncowy,
                     StartTrasy start);

    /// Jeden takt symulacji.
    void takt();

    std::vector<MigawkaJednostki> migawka() const;

private:
    GrafPodsektorow graf_;
    std::optional<WejscieRegionow> wejscie_;
    int komorka_grafu_ = 0;
    std::vector<int> pola_zmienione_;          // 0x422DB6: posortowane, bez powtórzeń
    std::map<std::pair<int, int>, std::vector<std::pair<int, int>>> zmienione_sektory_;   // etap 47: +0x10 (klucz – sektor)
    bool przebudowa_pelna_ = false;
    std::uint64_t przebudowy_sektorow_ = 0;
    std::vector<int> ostatnie_nowe_;
    std::vector<IdJednostki> kolejka_dodan_;   // etap 47: kolejka dodań fizyki +0xAF0
    std::vector<Gruz> gruz_;                    // etap 48: pozostałości budynków (obiekty mapy Świata)
    std::uint32_t nastepny_gruz_ = 0x7F000000u;
    void smierc_budynku(Jednostka& t);
    void krok_budynku(Jednostka& u);
    bool przebudowa_d8_ = false;               // EEPathManager +0xD8
    std::uint32_t termin_d4_ = 0;              // EEPathManager +0xD4
    std::uint64_t wersja_grafu_ = 0, przebudowy_grafu_ = 0;
    void krok_przebudowy();
    void krok_maszyny(Jednostka& u);
    std::optional<bool> zdarzenie(Jednostka& u, const std::string& nazwa);
    bool ocen_przejscie(Jednostka& u, const Przejscie& p);
    void wejdz_w_stan(Jednostka& u, const StanSkryptu& s);
    void nieobslugiwane(const std::string& n);
    bool przygotuj_trase(Jednostka& u, int okno);
    void etap_grafu(Jednostka& u);
    bool osiagalny_62d696(Jednostka& u, const Jednostka& t);
    void aktywuj_cel(Jednostka& u);
    void po_ruchu(Jednostka& u, double x0, double y0);
    void odbuduj_kontakty(Jednostka& u, double cx, double cy);
    void krok_koncowy(Jednostka& u);
    void zastosuj_push(Jednostka& u);
    IdJednostki srodek_w_polu(std::int64_t ix, std::int64_t iy, IdJednostki pytajaca) const;
    // walka
    Jednostka* cel_ataku(const Jednostka& u);
    void omijanie_atakujacego(Jednostka& u, const Jednostka& o);   // etap 49: 0x549179 (ru = ro, +0x61A)
    void krok_budowy(Jednostka& u);   // etap 50: RepairBuilding (4002)
    int przyrost_budowy_titan(Jednostka& u, const Jednostka& b);   // etap 51: 0x60BF56
    void krok_zbierania(Jednostka& u);   // etap 51: GatherResource (4004) – 0x611801
    std::optional<bool> zdarzenie_zbierania(Jednostka& u, const std::string& n);
    Punkt2 punkt_obwodu(const Jednostka& cel, double px, double py, double r) const;   // rzut na obwód (etap 51)
    std::optional<bool> zdarzenie_budowy(Jednostka& u, const std::string& n);
    std::optional<bool> zdarzenie_walki(Jednostka& u, const std::string& n);
    bool szukaj_wroga(Jednostka& u);
    bool cel_nieosiagalny(Jednostka& u, const Jednostka& t, bool sprawdz_pola);   // 0x5EC9BB (etap 37)
    void oznacz_nieosiagalny(Jednostka& u, const Jednostka& t);                   // 0x5E8651 (etap 37)
    double odl2(const Jednostka& a, const Jednostka& b) const;
    bool widoczny_dla(int gracz, const Jednostka& c) const;
    Punkt2 punkt_podejscia(Jednostka& u, const Jednostka& t);
    double kat_do_celu_broni(const Jednostka& u, const Jednostka& t) const;
    std::optional<double> m_trafienia(const Jednostka& a, const Jednostka& c) const;
    double w_mnoznik(const Jednostka& a, const Jednostka& c) const;
    void liczniki_walki(Jednostka& u);
    void zalozenie(const char* opis);
    void przebieg_efektow();
    void przelicz_efekty_gracza(int gracz);
    void zlicz_domy(EfektObszaru& e, const SzablonEfektu& s, float mnoznik);
    bool relacja_efektu(int relacja, int wlasciciel, int gracz) const;
    std::vector<SzablonEfektu> szablony_;
    std::vector<EfektObszaru> efekty_;
    std::vector<Budynek> budynki_;
    int premia_morale_wariantu_ = 0;
    float akumulator_efektow_ms_ = 0.0f;   // EEPhysics +0x9C (reset 0x54656E: 0)
    bool kolizje_wlaczone_ = true;
    std::map<std::pair<int, int>, bool> dyplomacja_;
    TabliceObrazen tablice_walki_;
    std::array<WagiCelu, 3> wagi_celu_{};
    double aoc_lo_ = 0.0, aoc_hi_ = 0.0;
    ModyfikatorWysokosci mod_wys_;
    std::map<int, float> premia_wys_;
    std::vector<ZdarzenieWalkiSwiata> zdarzenia_walki_;

    MatematykaTitan mat_;
    TerenSiatka teren_;
    WariantTitan wariant_;
    GeneratorTitan rng_;
    SkryptStanow skrypt_;
    std::map<int, std::array<int, 5>> zasoby_;   // etap 51
    std::map<int, ParametryProdukcji> produkcja_typow_;   // etap 52
    std::map<int, std::array<int, 4>> populacja_;         // etap 52: populacja, globalny, a, b
    struct NowaJednostka { int tech_id; IdJednostki budynek; double x, y; bool zbiorka = false; double zx = 0, zy = 0; };
    std::vector<NowaJednostka> do_utworzenia_;
    std::vector<IdJednostki> nowe_jednostki_;
    void krok_produkcji(Jednostka& b);
    bool start_produkcji(Jednostka& b);
    bool miejsce_wyjscia(const Jednostka& b, const ParametryProdukcji& p, double& x, double& y) const;
    Punkt2 punkt_przy_obiekcie(const Jednostka& ob, double px, double py, double rozmiar) const;   // etap 54
    bool miejsce_zbiorki(const Jednostka& b, const ParametryProdukcji& p, double& x, double& y) const;
    bool miejsce_wolne(double x, double y, double s, bool z_oczekujacymi = true, IdJednostki pomin = 0) const;
    std::map<std::string, SkryptStanow> skrypty_;   // etap 45: skrypty typów (adresy stabilne – std::map)
    const SkryptStanow& skr(const Jednostka& u) const { return u.skrypt ? *u.skrypt : skrypt_; }
    int losuj_zakres(int lo, int hi);
    void ucieczka(Jednostka& u);
    Jednostka* zagrozenie_62fe01(const Jednostka& u);
    void krok_licznika_22c(BojJednostki& b);
    bool potrzebuje_leczenia(const Jednostka& u, const Jednostka& h) const;
    bool w_zasiegu_leczenia(const Jednostka& u, const Jednostka& h) const;
    Jednostka* szukaj_leczonego(Jednostka& u);
    Diagnostyka diag_;
    std::vector<Jednostka> jednostki_;
    IdJednostki nastepny_id_ = 1;
    double dt_;
    double tps_;
    std::uint64_t takty_ = 0;
    double czas_ms_ = 0;
    std::uint32_t zegar_ms_ = 0;
};

}  // namespace openee
