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
};

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
