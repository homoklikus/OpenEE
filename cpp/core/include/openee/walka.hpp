// OpenEE Core – podstawy walki Titan (etap 30): parametry bojowe, stan bojowy, wzór obrażeń bezpośredniego trafienia,
// przyjęcie obrażeń, przeładowanie i cykl ataku pojedynku. Tylko mechanizmy rozpoznane; reszta – [N] w diagnostyce.
// Atlas: docs/titan/walka.md. Adresy EE: DealDamage 0x61DE61, TakeDamage 0x6172BC (vt+0x70), SetHP 0x616F30.
#pragma once

#include <array>
#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace openee {

/// Parametry bojowe typu dla gracza (EEUnitClassUpgrade + EEUnitClass) – odczyt pamięci EE, zad. 565 [P].
struct ParametryWalki {
    int hp_max = 0;                         // upgrade +0x144
    float atak = 0.0f;                      // upgrade +0xD8
    std::array<float, 6> pancerz{};         // upgrade +0xE0: shock, arrow, pierce, gun, laser, missile
    float zasieg_max = 0.0f;                // upgrade +0x9C
    float pole_widzenia = 0.0f;             // upgrade +0xA4
    float obszar = 0.0f;                    // upgrade +0xA0 (≠ 0 → obrażenia obszarowe 0x61DAE6 – niewdrożone)
    int przeladowanie_ms = 0;               // upgrade +0x138
    int rodzaj_ataku = 0;                   // typ +0x4C0: jako atakujący – indeks pancerza i kolumna mnożnika
    int wiersz_celu = 0;                    // typ +0x4C0: jako cel – wiersz tablicy 0x8D2050 (ta sama wartość pola)
    int klasa_trafienia = 0;                // typ +0x4C4: wiersz tablicy trafień (cel)
    int rodzina_ataku = 0;                  // typ +0x4C8: kolumna tablicy trafień (atakujący; = dbobjects „Family attack type”)
    float ogien_bratobojczy = 0.0f;         // typ +0x494
    int opoznienie_trafienia_ms = -1;       // moment trafienia w cyklu (animacja ataku) – z pomiaru; −1 = nieznany [N]
    // --- etap 31: wybór celu, zasięg wręcz, obrót (odczyt typu EE, zad. 575/578 [P]) ---
    float luk_ataku = 0.0f;                 // typ +0x45C [rad] (gwardia 0,349066 = 20°); 2π → bez sprawdzania łuku
    float kat_broni = 0.0f;                 // typ +0x458 [rad] – przesunięcie kierunku broni (obrót trybu 1, łuk)
    float rozmiar = 0.5f;                   // typ +0x474 – rozmiar do zasięgu wręcz 0x631501
    bool rozmiar_jeden = false;             // typ +0x612 ≠ 0: jako cel liczony z rozmiarem 1,0 (0x631935)
    bool punktowy = false;                  // typ +0x61A ≠ 0: zasięg 0x631935, pozycje zamiast punktu celowania
    int szukanie_ms = 0;                    // typ +0x564: okres szukania wroga (+0x2AC := ta wartość po szukaniu)
    float zasieg_min = 0.0f;                // typ +0x41C (kwadrat → funktor +0x3C)
    float pole_ac = 0.0f;                   // ulepszenie +0xAC – używane tylko w ocenie celu (znaczenie [N])
    int typ_bazy = 0;                       // typ +0x4B8 (porównanie z wagą +0x14 „typ specjalny”)
    bool reszta_przeladowania_bez_spoczynku = false;  // typ +0x5D4 bit 0: WaitForReload nie przełącza trybu 3
    int typ_jednostki = 0;                  // typ +0x4B4 (dbobjects „Unit type”): 5 gwardia, 6 obywatel (zad. 579 [P])
};

/// Modyfikator wysokości 0x61E500 (EE; AoC 0x631918): konfiguracja reguł [0x917BB8] (AoC [0x92FCA8]) [W kod].
/// Δz = z atakującego − z celu (+0x15C); próg = wartość · 0,408248 (krok wysokości siatki).
struct ModyfikatorWysokosci {
    bool wlaczony = false;
    float prog_gora = 0.0f;     // cfg +0x5CC
    float prog_dol = 0.0f;      // cfg +0x5E8
    float premia = 1.0f;        // cfg +0x604 (+ gracz +0xA3C)
    float kara = 1.0f;          // cfg +0x620
    bool cel_typ_30 = false;    // AoC 0x631880: lista rodzajów celu zawiera także 30 (0x1E) [W]
    // Odczyt gry (etap 32, zad. 587/588) [P]: EE cfg = [0x917BB8], AoC cfg = [0x92FCA8] – w obu 2,0 / 1,0 / 1,5 / 0,8,
    // premia gracza (EE +0xA3C, AoC +0xA34) = 0. Rodzaj jednostki atakującej ∈ {9, 11, 12, 20} → rodzaj i z obiektu
    // +0x1C0 (+0x210) – w Core nieobsługiwane (piechota) [W].
    static ModyfikatorWysokosci z_gry(bool aoc) { return {true, 2.0f, 1.0f, 1.5f, 0.8f, aoc}; }
};
/// r = 0x61E500(atakujący, cel): 1, gdy rodzaj jednostki atakującej ∉ {5, 6} albo celu ∉ {2,5,6,13,15,16,19,23,24,25,29}.
double modyfikator_wysokosci(const ModyfikatorWysokosci& m, int typ_atak, int typ_cel, double z_atak, double z_cel,
                             double premia_gracza);

/// Wagi oceny celu 0x6399CA: rekord [0x8CFA28 (EE) / 0x8E60C0 (AoC)][tryb] (int32, odczyt 575 [P]).
/// Tryb funktora (+0x50): 0 gdy typ +0x61A ≠ 0; 1 gdy zasięg ≤ pole widzenia; 2 w przeciwnym razie.
struct WagiCelu {
    int atakuje_mnie = 0;        // +0x00: cel bieżący kandydata to EEUGAttackUnit na mnie
    int w_zasiegu = 0;           // +0x08: d² ≤ (zasięg·f)²
    int mniejsze_ac = 0;         // +0x0C: kandydat.+0xAC < moje +0xAC
    int slabszy_atak = 0;        // +0x10: int(mój atak) > atak kandydata
    int typ_specjalny = 0;       // +0x14: kandydat.typ+0x4B8 == ta wartość → wybór od razu
    int waga_trafienia = 0;      // +0x18: + fistp(f32(waga · m))
    int waga_odleglosci = 0;     // +0x1C: + fistp(f32(waga / d²))
    int ac_zero = 0;             // +0x20: kandydat.+0xAC == 0
    int prog = 0;                // +0x24: wynik ≥ próg kończy przegląd
    static WagiCelu z_rekordu(const std::vector<int>& r);  // r = int32 rekordu od +0x00
};

/// Ocena kandydata (0x6399CA, gałąź po filtrach). d2 – kwadrat odległości (DistanceToSquared, z = 0), m – tablica
/// trafień 0x4D5F2C, atakuje_mnie – kandydat ma cel ataku na oceniającego. Zwraca wynik; specjalny = trafienie
/// w typ specjalny (wybór bez porównania wyniku). Filtry wstępne (gracz, dyplomacja, HP, widoczność, typ, zasięg
/// minimalny, m > 0) – w Swiat::szukaj_wroga.
int ocena_celu(const ParametryWalki& ja, const ParametryWalki& kand, double zasieg_f, double d2, double m,
               bool atakuje_mnie, const WagiCelu& w, bool& specjalny);

/// Zasięg wręcz typów punktowych (+0x61A): 0x631935 → 0x631501: 4·d² < ((0,05·1,42 + s_ja + s_cel)·1,42)² [W kod,
/// P: 564 – wejście w FaceEnemyUnit przy d = 0,6533, brak przy 0,8017; próg 0,7604].
bool w_zasiegu_punktowy(double d2, double s_ja, double s_cel);

/// Przeładowanie AoC 0x5FEA22: fistp(f32((lo + r·(hi − lo)) · bazowe)), r = URandom::Generate [W kod].
int przeladowanie_aoc(double r, double lo, double hi, int bazowe);

/// Tablice obrażeń z pamięci gry (EE: 0x8D2050 i tablice trafień 0x8D2008/0C/10) – dane referencyjne, nie z EXE.
struct TabliceObrazen {
    std::vector<std::array<float, 6>> mnozniki;                    // [wiersz celu][rodzaj ataku]
    std::array<std::map<int, std::vector<float>>, 3> trafienie;    // [0x08, 0x0C, 0x10][klasa 4C4][rodzina 4C8]
    int trudnosc = 0;                                              // [0x918808]
    bool pusta() const { return mnozniki.empty(); }
};

/// Wybór tablicy trafień 0x4D5F2C (zależny od trudności i od tego, czy gracz jest człowiekiem).
/// Rozpoznane [P: pojedynek 564, trudność 0]: człowiek → komputer: 0x10; komputer → człowiek: 0x08.
/// Pozostałe kombinacje – kod częściowo przeczytany: zwraca std::nullopt (nie zgadujemy) [N].
std::optional<int> wybor_tablicy_trafien(bool atakujacy_czlowiek, bool cel_czlowiek, int trudnosc);

struct WynikObrazen {
    double m = 0, w = 0, przed_zaokragleniem = 0;
    int obrazenia = 0;     // ≥ 1 (min. 1, jak w 0x61DE61)
    bool zerowy_mnoznik = false;  // m·w ≤ 0 → brak trafienia (gałąź jbe 0x61E113)
};

/// Wzór bezpośredniego trafienia 0x61DE61 [W: kod; P: 13 trafień w pojedynku 564]:
///   d = f32(m · w);  d > 0 → d = f32(d · atak) − pancerz[rodzaj_ataku atakującego]
///   r = modyfikator wysokości 0x61E500 (r ≠ 1: r > 1 → max(r·d, d + 1); r < 1 → min(r·d, d − 1)) [W]
///   ten sam gracz → d ·= ogień bratobójczy;  obrażenia = fistp(f32(d)) (zaokrąglenie do najbliższej, remis do
///   parzystej – tryb FPU domyślny), co najmniej 1.
/// TakeDamage (EE 0x6172BC) → 0x664EA1: każdy modyfikator jednostki liczy wynik z tych samych obrażeń wejściowych
/// i nadpisuje wynik (nie kumulują się – ostatni wygrywa). EEAEMoraleFromBuildings vt+0x30 (0x6640BA):
/// wynik = obrażenia − fistp(f32(min(max(poziom, 0), 10) · 0,1f · obrażenia)) [P: 578/587/589 EE, 580/581 AoC].
int obrazenia_po_modyfikatorach(int obrazenia, const std::vector<int>& morale);

WynikObrazen oblicz_obrazenia(const ParametryWalki& atakujacy, const ParametryWalki& cel, double m, double w,
                              double r_wysokosci = 1.0, bool ten_sam_gracz = false);

/// Stan bojowy jednostki (EEUnit): HP +0x3C, licznik przeładowania +0x2A0 [P], cel (EEUGAttackUnit +0x30).
struct StanWalki {
    int hp = 0;
    int przeladowanie_ms = 0;
    std::uint32_t cel = 0;
    int zabicia = 0;            // +0x332
    bool trafienie_w_cyklu = false;
};

/// TakeDamage 0x6172BC (część rozpoznana): HP = max(0, HP − obrażenia); zwraca true, gdy jednostka zginęła.
bool przyjmij_obrazenia(StanWalki& cel, int obrazenia);

/// Cykl ataku w zasięgu (Generic Attack.tai: FaceEnemyUnit 2012 → AttackEnemyUnit 2001 → WaitForReload 2021 →
/// Reloaded → 2012) z licznikiem +0x2A0 [P: 564]. Model pojedynku dwóch nieruchomych jednostek w zasięgu i
/// zwróconych do siebie – NIE obejmuje obrotu, podejścia, utraty celu ani wyboru celu (te są w .tai, [N] w Core).
struct UczestnikPojedynku {
    ParametryWalki p;
    StanWalki s;
    int stan = 2012;                 // numer stanu .tai
    double m = 0, w = 0;             // mnożniki trafienia i klasy wobec przeciwnika
    int takty_do_pierwszego_ataku = 0;  // obrót do celu przed pierwszym atakiem – dane wejściowe z pomiaru (obrót [N])
};
struct ZdarzenieWalki {
    std::uint64_t takt;
    int kto;                         // 0 / 1
    std::string rodzaj;              // atak, trafienie, smierc
    int wartosc;
};
class PojedynekTitan {
public:
    PojedynekTitan(UczestnikPojedynku a, UczestnikPojedynku b) : u_{a, b} {}
    /// Jeden takt; ms = ubytek licznika przeładowania: EE 34 ms na takt (int(1000·1,5/44)) – pomiar 561/564 [P],
    /// mimo że zegar gry rośnie o 34 albo 35 ms.
    void takt(int ms);
    const UczestnikPojedynku& uczestnik(int i) const { return u_[std::size_t(i)]; }
    const std::vector<ZdarzenieWalki>& zdarzenia() const { return zd_; }
    std::uint64_t takty() const { return takt_; }

private:
    std::array<UczestnikPojedynku, 2> u_;
    std::vector<ZdarzenieWalki> zd_;
    std::uint64_t takt_ = 0;
};

}  // namespace openee
