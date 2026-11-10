#include "openee/symulacja.hpp"

#include <algorithm>
#include <deque>
#include <cmath>
#include <cstdlib>

#include "openee/kolizje.hpp"

namespace openee {

const std::vector<OpisPodsystemu>& podsystemy() {
    static const std::vector<OpisPodsystemu> l = {
        {"matematyka Titan (UMCos/UMSin/UMArcCos/UMArcTan2, SetOrientationYPR)", StatusPodsystemu::wdrozony, ""},
        {"tablice z Low-Level Engine.dll (PE jako dane)", StatusPodsystemu::wdrozony, "2 warianty GOG+NeoEE"},
        {"generator LCG", StatusPodsystemu::wdrozony, "miejsca losowań: 2/takt + ObstacleDetected; Idle [N]"},
        {"teren: GetMeshZ, nachylenie, reguła stoku", StatusPodsystemu::wdrozony, "siatka z mapy SCN (MapaTitan, etap 30)"},
        {"import mapy SCN (MapaTitan): romb, wysokości, teren komórek, obiekty", StatusPodsystemu::czesciowy,
         "teren z reguły 99,6 % pól (klify [N]); blokada obiektu z pamięci gry"},
        {"fizyka EEPMLand tryby 0/3/4/5, EE i AoC", StatusPodsystemu::wdrozony, ""},
        {"test pojedynczego kroku", StatusPodsystemu::wdrozony, "kolejność z kodu [W]; bez pomiaru izolowanego"},
        {"maszyna stanów (.tai, podzbiór ruchu)", StatusPodsystemu::czesciowy,
         "zdarzenia walki/transportu = fałsz + licznik"},
        {"kolejka celów, Shift (poziom 0)", StatusPodsystemu::czesciowy, "punkty +0x32 i porzucenie – nie"},
        {"A* po polach + Bounded", StatusPodsystemu::wdrozony, "18 przypadków bitowo z modelem e24; synchronicznie"},
        {"graf podsektorów", StatusPodsystemu::czesciowy, "etap 44: budowa z SCN i baz gry (klasyfikacja 0x516E8C/0x512FB0, obiekty pól, regiony, podsektory) – e35_a zgodna; obszary +0xF4 – model z pomiaru [N]"},
        {"objazd 9002", StatusPodsystemu::czesciowy, "A* ±50 – NIEZWERYFIKOWANY dynamicznie"},
        {"kolizje w takcie (kontakty, 0x549179, 0x549A08, reguła (a))", StatusPodsystemu::czesciowy,
         "wzór [P]; okno kontaktów 0x5E8F0E [W, etap 30]; kolejność EE/AoC [W]"},
        {"walka: wzór obrażeń, HP, przeładowanie, cykl ataku pojedynku", StatusPodsystemu::czesciowy,
         "pojedynek EE 564 co takt = gra; .tai walki w Swiat, obrót, pościg, obszar – nie"},
        {"efekty obszarowe: morale z budynków (EEAEMoraleFromBuildings, EEAEMorale)", StatusPodsystemu::czesciowy,
         "przebieg co 2000 ms, zliczanie domów, max z równoważnych [P: kod]; leczenie, bohaterowie, budowa [N]"},
        {"grupy i szyk", StatusPodsystemu::niewdrozony, ""},
    };
    return l;
}

Swiat::Swiat(std::shared_ptr<const TabliceTrig> tablice, TerenSiatka teren, WariantTitan wariant)
    : mat_(std::move(tablice)), teren_(std::move(teren)), wariant_(wariant), skrypt_(SkryptStanow::wbudowany_land()) {
    dt_ = f32(1.5 / 44.0);  // EEPhysics+0x8C: G/n s czasu gry na takt
    tps_ = 1.0 / dt_;
}

void Swiat::uporzadkuj_wg_pozycji() {
    // Etap 44 [P: kolejka fizyki 0x918DDC odczytana w EE, zad. 639 – e42_1v1 i e44_kontakt_590; W: pętla 0x547AAD od
    // końca]: po wczytaniu scenariusza kolejność obiektów to x rosnąco, przy równym x – y rosnąco (pozycje z zapisu).
    // Odtworzenia 631, 633, 634 i 638 (kontakt jak 590 G1) zgodne co takt z tą kolejnością.
    std::stable_sort(jednostki_.begin(), jednostki_.end(), [](const Jednostka& a, const Jednostka& b) {
        return a.x < b.x || (a.x == b.x && a.y < b.y);
    });
}

bool Swiat::ustaw_z(IdJednostki id, double z) {
    for (auto& u : jednostki_)
        if (u.id == id) { u.z = f32(z); return true; }
    return false;
}

IdJednostki Swiat::dodaj_jednostke(const ParametryRuchu& p, double x, double y, double kurs) {
    Jednostka u;
    u.id = nastepny_id_++;
    u.wariant = wariant_;
    u.param = p;
    u.x = f32(x);
    u.y = f32(y);
    u.orientacja = mat_.set_orientation_ypr(f32(kurs));
    u.z = teren_.pusty() ? 0.0 : teren_.get_mesh_z(u.x, u.y);
    u.stan = 5000;
    u.tryb = TrybRuchu::spoczynek;
    u.komorka_x = podloga(u.x);
    u.komorka_y = podloga(u.y);
    jednostki_.push_back(u);
    odbuduj_kontakty(jednostki_.back(), jednostki_.back().x, jednostki_.back().y);
    return jednostki_.back().id;
}

Jednostka* Swiat::jednostka(IdJednostki id) {
    for (auto& u : jednostki_)
        if (u.id == id) return &u;
    return nullptr;
}
const Jednostka* Swiat::jednostka(IdJednostki id) const {
    for (const auto& u : jednostki_)
        if (u.id == id) return &u;
    return nullptr;
}

bool Swiat::nadaj_trase(IdJednostki id, const std::vector<Punkt2>& punkty, std::optional<double> kurs_koncowy,
                        StartTrasy start) {
    Jednostka* u = jednostka(id);
    if (!u) return false;
    u->trasa.clear();
    u->dl_przed.clear();
    u->dl_po.clear();
    u->zdjete_punkty = 0;
    double c = 0.0, px = u->x, py = u->y;
    for (const auto& p : punkty) {  // suma długości odcinków (0x5EC655): w rejestrze, zapis f32
        const Punkt2 q{f32(p.x), f32(p.y)};
        u->dl_przed.push_back(f32(c));
        c += std::hypot(q.x - px, q.y - py);
        u->dl_po.push_back(f32(c));
        px = q.x;
        py = q.y;
        u->trasa.push_back(q);
    }
    u->cel = TypCelu::miejsce;
    u->cel_od_gracza = true;
    u->kurs_koncowy = kurs_koncowy;
    u->trasa_gotowa = true;
    u->kolejka_celow.clear();
    if (!punkty.empty()) u->kolejka_celow.push_back({TypCelu::miejsce, punkty.back().x, punkty.back().y, kurs_koncowy, true, false, 0});
    u->licznik_blokady_ms = 0;
    const StanSkryptu* s = skr(*u).stan(start == StartTrasy::advance ? 10003 : 8000);
    if (s) wejdz_w_stan(*u, *s);
    else u->stan = start == StartTrasy::advance ? 10003 : 8000;
    return true;
}

void Swiat::nieobslugiwane(const std::string& n) {
    ++diag_.zdarzenia_nieobslugiwane;
    diag_.ostatnie_nieobslugiwane = n;
}

std::optional<bool> Swiat::zdarzenie(Jednostka& u, const std::string& n) {
    const bool miejsce = u.cel == TypCelu::miejsce;
    if (n == "AlwaysTrue") return true;
    if (u.boj) {  // etap 31: zdarzenia walki i celów-jednostek (tylko jednostki ze stanem bojowym)
        if (auto w = zdarzenie_walki(u, n)) return w;
    }
    if (n == "ArrivedAtMoveWaypoint") return u.osiagnieto_punkt;
    if (n == "ObstacleDetected") {  // 0x61B677 – losowanie co ocenę
        if (u.blokujacy != 0) return true;
        const double los = rng_.losuj();
        const std::int64_t T = rint_parzyste(f32((0.75 + los * 0.5) * 4000.0));
        // modyfikatory T dla celu ataku / budowy – niewdrożone (cel tylko „miejsce”)
        if (u.licznik_blokady_ms > double(T)) {
            u.licznik_blokady_ms = 0;
            return true;
        }
        return false;
    }
    if (n == "OneWaypointRemaining") return u.pozostalo_punktow() == 1;
    if (n == "NextWaypointRetrieved") return u.pozostalo_punktow() > 0;
    if (n == "NoMoreWaypoints") return u.trasa_gotowa && u.pozostalo_punktow() == 0;
    if (n == "MovePreparationComplete") return u.trasa_gotowa && u.pozostalo_punktow() > 0;
    if (n == "ShouldMoveToNextAutoWaypoint") {
        // 9016 (0x5F0844) [W, etap 40]: cel EEUGLocation z +0x32, w poziomie > 1 cel, trasa kompletna i pozostało
        // ≤ N punktów (N = [0x917DC8] z rozmiaru mapy). Gałąź „≤ 2N i region końca bliski” (0x409914 < 2) – [N].
        if (u.kolejka_celow.empty() || !u.kolejka_celow.front().punkt_automatyczny) return false;
        if (u.kolejka_celow.size() < 2 || !u.trasa_gotowa) return false;
        return int(u.pozostalo_punktow()) <= prog_punktu_auto(std::max(teren_.szerokosc(), teren_.wysokosc()) - 1);
    }
    if (n == "UnitHasGoal") return u.cel != TypCelu::brak;
    if (n == "GoalIsLocation") return miejsce;
    if (n == "GoalIsNotAttack") return true;
    if (n == "GoalIsNotPlayerInitiated") return !u.cel_od_gracza;
    if (n == "GoalIsUnit" || n == "GoalIsLoadContainer" || n == "GoalIsPatrol" || n == "GoalIsAttackLocation" ||
        n == "GoalIsExplore" || n == "GoalIsAttack")
        return false;  // typy celów inne niż miejsce nie istnieją w Core
    if (n == "UnitFacingNotRequired") {
        // Etap 37 [P: kod]: zdarzenie 9014 obsługuje cel bieżący (vt+0x64). EEUGLocation (0x6153A3 → 0x6153CA):
        // prawda, gdy cel+0x31 = 0 albo w poziomie kolejki jest więcej niż 1 cel. Pozostałe cele (EEUGAttackUnit
        // 0x60B5CB → baza 0x62871E): zawsze prawda – bez warunku na v i ω [P: 619 – 9006 trwa 1 takt przy v = 0,259].
        if (u.cel == TypCelu::brak) return false;
        if (u.cel != TypCelu::miejsce) return true;
        if (u.kolejka_celow.size() > 1) return true;
        // cel+0x31 = 0 odpowiada w Core brakowi kursu końcowego; warunek v = ω = 0 – model v4 [W] (S1–S7)
        return !u.kurs_koncowy && u.v == 0.0 && u.omega == 0.0;
    }
    if (n == "CompletedUnitFacing") {
        // etap 32 [P]: EEUGLocation vt+0x64 (0x6153A3) → 0x614F52; bez warunku na v i ω (189 taktów 9006 z pomiarów
        // EE/AoC: 188 zgodnych). Przy prawdzie macierz ustawiana dokładnie na kurs celu (0x5F043B).
        if (!u.kurs_koncowy || !ukonczony_obrot(mat_, u.orientacja, *u.kurs_koncowy)) return false;
        u.orientacja = mat_.set_orientation_ypr(f32(*u.kurs_koncowy));
        return true;
    }
    nieobslugiwane(n);  // walka, transport, mury, ICL…
    return std::nullopt;
}

bool Swiat::ukonczony_obrot(const MatematykaTitan& mat, const Macierz3& orientacja, double kurs_celu) {
    // 0x614F52: kurs = UMArcTan2(−x, y) wektora M·(0, 1, 0) minus kurs celu (f32 +0x2C); zawinięcie stałymi f32
    // −π / π / 2π (0x82ACE0, 0x828020, 0x828018); |Δ| ≤ f32 0,017453292 (0x831E5C), porównania x87 na rozszerzonej
    const double pi_f = double(3.14159274f), dwa_pi_f = double(6.28318548f), prog_f = double(0.0174532924f);
    double d = mat.kurs_z_macierzy(orientacja) - f32(kurs_celu);
    if (d < -pi_f) d += dwa_pi_f;
    else if (d > pi_f) d -= dwa_pi_f;
    return -prog_f <= d && d <= prog_f;
}

bool Swiat::ocen_przejscie(Jednostka& u, const Przejscie& p) {
    // leniwa ocena: AND do pierwszego fałszu, OR do pierwszej prawdy
    if (p.typ == Przejscie::Typ::allof) {
        for (const auto& z : p.zdarzenia)
            if (!zdarzenie(u, z).value_or(false)) return false;
        return true;
    }
    for (const auto& z : p.zdarzenia)
        if (zdarzenie(u, z).value_or(false)) return true;
    return false;
}

void Swiat::wejdz_w_stan(Jednostka& u, const StanSkryptu& s) {
    u.stan = s.numer;
    switch (s.numer) {
        case 5000:  // Idle: tryb 3, czyści trasę, zdejmuje cel, +0x254 = 0xFFFFFFFF
            u.tryb = TrybRuchu::spoczynek;
            u.trasa.clear();
            u.dl_przed.clear();
            u.dl_po.clear();
            u.zdjete_punkty = 0;
            u.trasa_gotowa = false;
            u.cel = TypCelu::brak;
            u.kurs_koncowy.reset();
            u.termin_oceny = 0xFFFFFFFFu;
            ++diag_.losowania_idle_pominiete;  // warunkowe losowania przy wejściu w Idle – warunek [N]
            // 0x5EAE25(0): zdjęcie celu bieżącego i aktywacja następnego (EEUGLocation vt+0x54 → stan 8000)
            if (!u.kolejka_celow.empty()) u.kolejka_celow.pop_front();
            if (!u.kolejka_celow.empty()) aktywuj_cel(u);
            break;
        case 8000:  // PrepareToMove: cel+0x18++, prośba o trasę (A* w Core – synchronicznie, w grze w kolejnych taktach)
            if (!u.kolejka_celow.empty() && u.kolejka_celow.front().typ == TypCelu::jednostka) {
                // cel-jednostka (PrepareToMove 0x6222A8 → cel vt+0x08 = 0x60AF05): punkt podejścia – cel w ruchu:
                // przechwycenie 0x62C963 (gdy cel ma > 1 punkt trasy, inaczej jego pozycja [P: 564]); cel stojący:
                // własna pozycja w zasięgu albo miejsce przy celu 0x63234D [P: 578 G3, takt 2018]. Pole celu := pole
                // jednostki celu (0x60B9D8). Trasa do punktu jak do miejsca (A* po polach, ostatni punkt dokładny).
                if (Jednostka* t = cel_ataku(u)) {
                    const Punkt2 pp = punkt_podejscia(u, *t);   // EEUGAttackUnit vt+0x08 = 0x60AF05
                    u.kolejka_celow.front().x = pp.x;
                    u.kolejka_celow.front().y = pp.y;
                    u.kolejka_celow.front().pole_x = t->komorka_x;   // 0x60B9D8 [P: 578, takt 2076]
                    u.kolejka_celow.front().pole_y = t->komorka_y;
                }
                u.trasa.clear();
                u.dl_przed.clear();
                u.dl_po.clear();
                u.zdjete_punkty = 0;
                u.trasa_gotowa = false;
            }
            // etap 40: etap grafu podsektorów prośby 0x4A1AFF (bajt +0x1C) i wynik 0x4A26E3 – może wstawić punkty +0x32
            // na czoło kolejki; licznik prób (+0x18) zwiększa się na celu z czoła po wstawieniu [P: 624 – EEUGLocation
            // proby 1, EEUGAttackUnit 0 w takcie wstawienia]
            etap_grafu(u);
            if (!u.kolejka_celow.empty()) ++u.kolejka_celow.front().proby;
            if (!u.trasa_gotowa && !u.kolejka_celow.empty()) przygotuj_trase(u, 0);
            break;
        case 8021:  // GetNextAutoWaypoint: zdjęcie celu +0x32 (0x5EAE25) i aktywacja następnego [W: ruch_trasa_przeszkody § 6]
            if (!u.kolejka_celow.empty() && u.kolejka_celow.front().punkt_automatyczny) {
                u.kolejka_celow.pop_front();
                if (!u.kolejka_celow.empty()) aktywuj_cel(u);
            }
            break;
        case 10003:  // Advance: tryb 0, +0x33F = 0
            u.tryb = TrybRuchu::jazda;
            u.osiagnieto_punkt = false;
            break;
        case 9000:  // GetNextMoveWaypoint: zdjęcie punktu (0x5EDCF4 zeruje +0x248)
            if (u.zdjete_punkty < u.trasa.size()) ++u.zdjete_punkty;
            u.licznik_blokady_ms = 0;
            break;
        case 9006:  // TurnToUnitFacing: tryb 5
            u.tryb = TrybRuchu::obrot_w_miejscu;
            break;
        case 5001:  // ReacquireGoal: akcja 0x61B241 – tryb ruchu bez zmian [P: 578, tryb 5 w stanie 5001]
            break;
        case 2015:
            break;
        case 2013:  // CheckRange 0x61ADD7: pierwsze wejście zapamiętuje miejsce kontaktu (+0x118) i kurs (+0x214)
            if (u.boj && u.boj->icl_kurs == -10000.0) {
                u.boj->icl_x = u.x;
                u.boj->icl_y = u.y;
                u.boj->icl_kurs = mat_.kurs_z_macierzy(u.orientacja);
            }
            break;
        case 2012:  // FaceEnemyUnit (EEUGAttackUnit vt+0x40 = 0x60B26F): tryb 1, animacja ruchu gdy nie zwrócona; 0x5E9770
        case 2001:  // AttackEnemyUnit: tryb 1, animacja ataku, +0x2A0 := przeładowanie (AoC: losowe 0x5FEA22), +0x2AC := 0
            u.tryb = TrybRuchu::do_celu;
            u.trasa.clear();  // 0x5E9770 – trasa zdjęta [P: 564, trasa_n 1 → 0 przy wejściu w 2012]
            u.dl_przed.clear();
            u.dl_po.clear();
            u.zdjete_punkty = 0;
            u.trasa_gotowa = false;
            if (u.boj) {
                if (s.numer == 2012) {
                    Jednostka* t = cel_ataku(u);
                    if (t && kat_do_celu_broni(u, *t) > f32(0.0436332313)) u.boj->animacja = 13;
                } else {
                    u.boj->animacja = 0;
                    int r = u.boj->p.przeladowanie_ms;
                    if (u.wariant.gra == Gra::aoc) r = przeladowanie_aoc(rng_.losuj(), aoc_lo_, aoc_hi_, r);
                    u.boj->s.przeladowanie_ms = r;
                    u.boj->szukanie_ms = 0;
                    u.boj->s.trafienie_w_cyklu = false;
                    u.boj->takt_wejscia_ataku = takty_;
                    zdarzenia_walki_.push_back({takty_, u.id, cel_ataku(u) ? cel_ataku(u)->id : 0, "atak", r});
                }
            }
            break;
        case 2021:  // WaitForReload 0x61AF33: tryb 3 tylko gdy animacja ≠ 0 (atak skończony) i typ+0x5D4 bit 0 = 0
            if (u.boj && !u.boj->p.reszta_przeladowania_bez_spoczynku && u.boj->animacja != 0) {
                u.tryb = TrybRuchu::spoczynek;
                u.boj->animacja = 7;
            }
            break;
        case 2016:  // InitialAttackState – akcja wejścia 0x61ADD7 (ICL zapisywane w Core przy 2013) [W]; etap 36
        case 2024:
        case 2025:
        case 5002:
            break;
        case 2026:  // ReturnToInitialContactLocation 0x61AF7F: nowy cel EEUGLocation w miejscu kontaktu (+0x118), kurs +0x214
            if (u.boj && u.boj->icl_kurs != -10000.0) {
                zalozenie("powrót do miejsca kontaktu: parametry celu 0x614D47 częściowo [W]");
                if (!u.kolejka_celow.empty()) u.kolejka_celow.pop_front();
                u.kolejka_celow.push_front({TypCelu::miejsce, u.boj->icl_x, u.boj->icl_y, u.boj->icl_kurs, false, false, 0});
                u.cel = TypCelu::miejsce;
                u.cel_od_gracza = false;
                u.kurs_koncowy = u.boj->icl_kurs;
                u.trasa.clear();
                u.zdjete_punkty = 0;
                u.trasa_gotowa = false;
            }
            break;
        case 8019:  // FleeDanger 0x61B2D5 → EEUC vt+0x40 = 0x620687 (EEUCLand i EEUCLandCitizen) [W]
            ucieczka(u);
            break;
        case 6001:  // ResourcesRotting 0x61B1F6: +0x2A8 = 0 [W]
            if (u.boj) u.boj->licznik_2a8 = 0;
            break;
        case 6003:  // Dead: obiekt do usunięcia z kolejki fizyki (0x530913) – zatwierdzenie w następnym takcie
            // [P: 641 – 578: 0x5000ad0 stan 6003 w t = 105945, poza kolejką od t = 105979; 0x5000ad3 138164 → 138198;
            //  590: analogicznie]; wywołujący z grupy 0x5EED94/0x5EF968/0x5F120A/0x6163E3 [N: który]
            u.usun_z_fizyki = true;
            break;
        case 6002:  // UnitRotting 0x61B25E: +0x2A8 = czas rozkładu typu (+0x548) [W]
            if (u.boj) u.boj->licznik_2a8 = u.boj->p.rozklad_ms;
            break;
        case 6000:  // Dying: animacja umierania (sekwencja gniazda 4); dalej 6001–6003 (etap 44)
            if (u.boj) { u.boj->smierc_ms = 0; u.boj->smierc_klatka = 0; u.boj->smierc_koniec = false; u.boj->zasoby = u.boj->p.zasoby; }
            u.tryb = TrybRuchu::zatrzymanie;   // etap 45: tryb 2 [P: 638 t = 66988; 590/578 – jednostki stały]
            u.trasa.clear();
            u.zdjete_punkty = 0;
            u.kolejka_celow.clear();   // etap 32 [P: 578 G3, 590 – w takcie śmierci kolejka celów pusta]
            u.cel = TypCelu::brak;
            if (u.boj) u.boj->animacja = 4;
            break;
        case 9002:  // RepathAroundObstacle – objazd A* w oknie ±50 pól: NIEZWERYFIKOWANY dynamicznie [W]
            ++diag_.objazdy_niezweryfikowane;
            u.blokujacy = 0;
            u.licznik_blokady_ms = 0;
            u.trasa_gotowa = false;
            if (!u.kolejka_celow.empty()) przygotuj_trase(u, 50);
            break;
        default:
            ++diag_.wejscia_niewdrozone;
            diag_.ostatnie_niewdrozone = s.nazwa;
            break;
    }
}

void Swiat::krok_maszyny(Jednostka& u) {
    // 0x5F0F7E: najwyżej jedno przejście. BO-8: w Idle ocena pomijana tylko, gdy termin < zegar (bez znaku).
    const SkryptStanow& sk = skr(u);
    const StanSkryptu* s = sk.stan(u.stan);
    if (!s) return;
    if (u.stan == 5000) {
        if (u.termin_oceny < zegar_ms_) return;
        u.termin_oceny = zegar_ms_ + 350u;
    }
    for (const auto& p : s->przejscia) {
        const bool w = ocen_przejscie(u, p);
        const std::string& cel = w ? p.cel_prawda : p.cel_falsz;
        if (cel.empty()) continue;
        auto it = sk.stany().find(cel);
        if (it != sk.stany().end()) wejdz_w_stan(u, it->second);
        return;
    }
}

void Swiat::takt() {
    // EEPhysics: czas gry += 1000·G/n ms; co najmniej 2 losowania globalne na takt (EE 0x546CE9, 0x547C09) [W]
    ++takty_;
    czas_ms_ += 1000.0 * 1.5 / 44.0;
    zegar_ms_ = std::uint32_t(czas_ms_);
    rng_.krok();  // 0x546CE9 (0x546C63)
    // etap 45: zatwierdzenie kolejek dodań/usunięć fizyki 0x53066A (wywołanie 0x546D35): nowe obiekty na koniec (w Core
    // już przy dodaniu – vector), usunięte znikają z kolejki; kolejność pozostałych bez zmian [W; P: 641]
    for (auto& u : jednostki_)
        if (u.usun_z_fizyki) { u.usun_z_fizyki = false; u.w_fizyce = false; }
    rng_.krok();  // 0x547C09 w 0x547B6B, wywołanej z 0x546D4C – przed pętlą jednostek 0x547AAD (wywołanie 0x546D6B) [W]
    // Efekty obszarowe 0x547742 (AoC 0x553C59) – po menedżerze tras (0x4A396B), przed pętlą jednostek (0x547AAD):
    // +0x9C += +0x98 (f32, porównanie na stosie x87); ≥ 2000 → przebieg menedżera 0x663DBD i +0x9C −= 2000 [P: kod]
    {
        const long double suma = (long double)f32(1000.0 * 1.5 / 44.0) + (long double)akumulator_efektow_ms_;
        akumulator_efektow_ms_ = float(suma);
        if (suma >= 2000.0L) {
            przebieg_efektow();
            akumulator_efektow_ms_ = float((long double)akumulator_efektow_ms_ - 2000.0L);
        }
    }
    KontekstFizyki k{mat_, teren_, dt_, tps_};
    // Zwykłe jednostki NIE blokują pola w teście kroku [P – etap 29, pomiary 546/547: jednostka w ruchu weszła na
    // pole ze środkiem innej jednostki, +0x20C pozostało 0]. Blokują tylko obiekty z typem blokującym (drzewa, mury,
    // budynki – w Core jeszcze nieodwzorowane, zob. TerenSiatka::pole_przejezdne). Mechanizm +0x20C zostaje w
    // FizykaLadowa::test_kroku (callback srodek_w_polu) dla takich obiektów.
    k.srodek_w_polu = nullptr;
    for (std::size_t i = jednostki_.size(); i-- > 0;) {  // od końca listy (0x547AAD)
        Jednostka& u = jednostki_[i];
        if (!u.w_fizyce) continue;   // poza kolejką 0x918DDC – bez maszyny stanów i fizyki (0x547E0E)
        krok_maszyny(u);
        if (u.tryb == TrybRuchu::do_celu) {  // tryb 1: pozycja celu ataku (cel +0x30 → +0x13C/+0x14C) w chwili fizyki
            if (Jednostka* t = cel_ataku(u)) {
                u.cel_walki_x = t->x;
                u.cel_walki_y = t->y;
            } else if (!u.kolejka_celow.empty() && u.kolejka_celow.front().typ == TypCelu::miejsce) {
                // etap 38: cel EEUGLocation (rozkaz ruchu w trakcie ataku, tryb 1 z 2012/2001 jeszcze aktywny) – obrót do
                // punktu celu (+0x30) [P: 622, takt 86682 – ω +0,4165 w stronę punktu ruchu, nie własnej pozycji]
                u.cel_walki_x = u.kolejka_celow.front().x;
                u.cel_walki_y = u.kolejka_celow.front().y;
            } else {
                u.cel_walki_x = u.x;
                u.cel_walki_y = u.y;
            }
        }
        const double x0 = u.x, y0 = u.y;
        FizykaLadowa::takt(k, u);
        if (u.boj) liczniki_walki(u);
        po_ruchu(u, x0, y0);
        if (u.tryb != TrybRuchu::zatrzymanie) krok_koncowy(u);  // 0x549E61 (po każdym trybie oprócz 2: 0x549FD2)
    }
}

IdJednostki Swiat::srodek_w_polu(std::int64_t ix, std::int64_t iy, IdJednostki pytajaca) const {
    IdJednostki w = 0;
    for (const auto& o : jednostki_)
        if (o.id != pytajaca && podloga(o.x) == ix && podloga(o.y) == iy) w = o.id;  // ostatni obiekt listy [W]
    return w;
}

double Swiat::kat_rozkazu(const std::vector<IdJednostki>& ids, double x, double y) const {
    // 0x5F6377: prostokąt z pozycji (+0x13C, +0x14C) jednostek grupy (pierwsza ustawia oba rogi, kolejne rozszerzają –
    // import 0xB2FB70) [P: kod]; środek prostokąta (import 0xB2FBF4) [W]; 0x64138B: θ = UMArcTan2(−(x − sx), y − sy)
    bool jest = false;
    double x0 = 0, y0 = 0, x1 = 0, y1 = 0;
    for (const auto id : ids) {
        const Jednostka* u = nullptr;
        for (const auto& o : jednostki_) if (o.id == id) u = &o;
        if (!u) continue;
        const double px = f32(u->x), py = f32(u->y);
        if (!jest) { x0 = x1 = px; y0 = y1 = py; jest = true; }
        else { x0 = std::min(x0, px); x1 = std::max(x1, px); y0 = std::min(y0, py); y1 = std::max(y1, py); }
    }
    if (!jest) return 0.0;
    return mat_.kat_do_celu(f32((x0 + x1) * 0.5), f32((y0 + y1) * 0.5), x, y);
}

bool Swiat::rozkaz_ruchu(IdJednostki id, double x, double y, std::optional<double> kurs_koncowy, bool shift) {
    Jednostka* u = jednostka(id);
    if (!u) return false;
    CelRuchu c{TypCelu::miejsce, f32(x), f32(y), kurs_koncowy, true, false, 0};
    if (shift && u->ma_cel() && !u->kolejka_celow.empty()) {  // 0x4412D4: na koniec, stan bez zmian
        u->kolejka_celow.push_back(c);
        return true;
    }
    // zwykły PPM: zdjęcie celu bieżącego (0x5EAE25), wyczyszczenie poziomu (0x5E9664), cel na początek (0x5F05BD), 8000
    // etap 40: trasa zwykłego PPM idzie przez prośbę grupową (stan grupy 8000 → 0x4A15E7); po zwykłym rozkazie
    // kolejka nie ma punktów +0x32 nawet przy długim obejściu [P: nawigacja_wejscie.md pkt 3, EE 444/445, AoC 454;
    // 616 – brak punktu (159,5; 106,5) mimo ścieżki grafu 3 podsektorów] – cel traktowany jak po etapie grafu
    // (+0x1D = 1) [H: kto ustawia flagę]. Cel z Shift przechodzi etap grafu przy aktywacji (punkty przed celem B [P]).
    c.etap_grafu = true;
    u->kolejka_celow.clear();
    u->kolejka_celow.push_front(c);
    aktywuj_cel(*u);
    return true;
}

void Swiat::aktywuj_cel(Jednostka& u) {
    const CelRuchu& c = u.kolejka_celow.front();
    if (c.typ == TypCelu::jednostka) {
        // etap 40: aktywacja celu ataku z kolejki (EEUGAttackUnit vt+0x54) → InitialAttackState 2016 [P: 619/624 –
        // po zdjęciu punktu +0x32: 9000 → (8021) → 2016 → 2012]
        u.cel = c.typ;
        u.cel_od_gracza = c.od_gracza;
        u.kurs_koncowy.reset();
        u.trasa.clear();
        u.dl_przed.clear();
        u.dl_po.clear();
        u.zdjete_punkty = 0;
        u.trasa_gotowa = false;
        auto it = skr(u).stany().find("InitialAttackState");
        if (it != skr(u).stany().end()) { wejdz_w_stan(u, it->second); return; }
    }
    u.cel = c.typ;
    u.cel_od_gracza = c.od_gracza;
    u.kurs_koncowy = c.kurs_koncowy;
    u.trasa.clear();
    u.dl_przed.clear();
    u.dl_po.clear();
    u.zdjete_punkty = 0;
    u.trasa_gotowa = false;
    const StanSkryptu* s = skr(u).stan(8000);
    if (s) wejdz_w_stan(u, *s);
}

bool Swiat::przygotuj_trase(Jednostka& u, int okno) {
    // Prośba jednostki (nawigacja_wejscie.md, astar_wyniki.md § 5–6): Bounded w kwadracie wokół startu, przy porażce
    // pełne A* od końca Bounded. W grze pełne A* biegnie w kolejnych taktach (limit na wywołanie 15…32) – tu od razu.
    const CelRuchu cel = u.kolejka_celow.front();
    const Pole start{int(u.komorka_x), int(u.komorka_y)}, meta{int(podloga(cel.x)), int(podloga(cel.y))};
    const int W = teren_.szerokosc() - 1, H = teren_.wysokosc() - 1;  // pola = komórki między wierzchołkami
    auto kara = [this, &u](int x, int y) {  // 0x41CFFF pkt 3: jednostki na polu w stanie 5000/2001 [W, bez pomiaru]
        int k = 0;
        for (const auto& o : jednostki_) {
            if (o.id == u.id || podloga(o.x) != x || podloga(o.y) != y) continue;
            if (o.stan != 5000 && o.stan != 2001) continue;
            k += (o.param.promien_kolizji >= 1.0 && u.param.promien_kolizji < 1.0) ? 150 : 50;
        }
        return k;
    };
    std::vector<Pole> pola;
    if (okno > 0) {  // 9002: A* w oknie ±okno pól
        auto d = [&](int x, int y) {
            return std::abs(x - start.x) <= okno && std::abs(y - start.y) <= okno && teren_.pole_przejezdne(x, y);
        };
        ParametryAStar p;
        p.limit_calkowity = 3000;
        p.kara = kara;
        diag_.ostatnia_trasa = AStarTitan::szukaj(start, meta, d, W, H, p);
        pola.assign(diag_.ostatnia_trasa.trasa_od_celu.rbegin(), diag_.ostatnia_trasa.trasa_od_celu.rend());
    } else {
        int dd = std::abs(meta.x - start.x) + std::abs(meta.y - start.y);
        if (dd > 20) dd /= 20;
        const int m = dd + std::min(0 + 4, 11);  // zawieszone prośby = 0 [W]
        const int x0 = std::max(0, start.x - (m + 1)), x1 = std::min(W - 1, start.x + (m + 1));
        const int y0 = std::max(0, start.y - (m + 1)), y1 = std::min(H - 1, start.y + (m + 1));
        ParametryAStar pb;
        pb.limit_wywolania = -1;
        pb.limit_calkowity = m;
        pb.koniec_bez_testu_dostepnosci = true;
        pb.kara = kara;
        const auto b = AStarTitan::szukaj(start, meta, [&](int x, int y) {
            return x >= x0 && x <= x1 && y >= y0 && y <= y1 && teren_.pole_przejezdne(x, y);
        }, W, H, pb);
        std::vector<Pole> pb_pola(b.trasa_od_celu.rbegin(), b.trasa_od_celu.rend());
        diag_.ostatnia_bounded_sukces = !b.koniec_najblizszy;
        if (!b.koniec_najblizszy) {
            pola = pb_pola;
        } else {
            ParametryAStar p;
            p.limit_calkowity = 3000;  // budżet całkowity prośby [W]
            p.kara = kara;
            const Pole od = pb_pola.empty() ? start : pb_pola.back();
            diag_.ostatnia_trasa = AStarTitan::szukaj(od, meta, [&](int x, int y) { return teren_.pole_przejezdne(x, y); }, W, H, p);
            pola = pb_pola;
            std::vector<Pole> reszta(diag_.ostatnia_trasa.trasa_od_celu.rbegin(), diag_.ostatnia_trasa.trasa_od_celu.rend());
            for (std::size_t i = (reszta.empty() ? 0 : 1); i < reszta.size(); ++i) pola.push_back(reszta[i]);
        }
    }
    // 0x5EE4E6: pomiń pole startu, gdy jednostka na nim stoi – tylko gdy trasa ma więcej niż 1 pole (lista n > 1;
    // przy jednym polu punkt zostaje) [P: kod, etap 37; 619 – trasa 1 punkt (161,5; 105,5) przy starcie w tym polu,
    // gdy cel-jednostka stoi na polu nieprzejezdnym]; punkty (x + 0,5; y + 0,5); ostatni = dokładny cel [W]
    std::vector<Punkt2> pts;
    for (std::size_t i = 0; i < pola.size(); ++i) {
        if (i == 0 && pola.size() > 1 && pola[i] == start) continue;
        pts.push_back({double(pola[i].x) + 0.5, double(pola[i].y) + 0.5});
    }
    if (!pola.empty() && pola.back() == meta) {
        if (pts.empty()) pts.push_back({cel.x, cel.y});
        else pts.back() = {cel.x, cel.y};
    }
    if (pts.empty()) {
        u.trasa_gotowa = true;  // NoMoreWaypoints → TurnToUnitFacing
        return false;
    }
    u.trasa.clear();
    u.dl_przed.clear();
    u.dl_po.clear();
    u.zdjete_punkty = 0;
    double c = 0.0, px = u.x, py = u.y;
    for (const auto& q0 : pts) {
        const Punkt2 q{f32(q0.x), f32(q0.y)};
        u.dl_przed.push_back(f32(c));
        c += std::hypot(q.x - px, q.y - py);
        u.dl_po.push_back(f32(c));
        px = q.x;
        py = q.y;
        u.trasa.push_back(q);
    }
    u.trasa_gotowa = true;
    return true;
}

void Swiat::odbuduj_kontakty(Jednostka& u, double cx, double cy) {
    // 0x5E960D / 0x5E8F0E (AoC 0x5F6817): okno ±R (R = rozmiar, min 0,5), lista symetryczna [W]; obrys obiektu [H]
    for (auto& o : jednostki_) {
        if (o.id == u.id) continue;
        auto& l = o.lista_kontaktow;
        for (std::size_t i = 0; i < l.size(); ++i)
            if (l[i] == u.id) { l.erase(l.begin() + std::ptrdiff_t(i)); break; }
        o.kontakty = std::uint32_t(l.size());
    }
    u.lista_kontaktow.clear();
    // Etap 30 [W: kod 0x5E8F0E; P: zrzut list komórek EEMap, zad. 552 – każda jednostka jest na liście jednego pola]:
    // R = max(0,5; 0,5·s), s = rozmiar kolizji typu (×2 gdy ≥ 1,0); kandydaci = obiekty, których POLE (+0x1C/+0x20,
    // komorka_x/y) leży w oknie [floor(x−R), floor(x+R)] × [floor(y−R), floor(y+R)].
    // [Etap 29 – zastąpione: obiekt na listach wszystkich pól pod obrysem (promień kolizji) – hipoteza obalona.]
    const double s = u.param.rozmiar >= 1.0 ? u.param.rozmiar + u.param.rozmiar : u.param.rozmiar;
    const double R = std::max(f32(s * 0.5), 0.5);
    const std::int64_t xa = podloga(f32(cx - R)), xb = podloga(f32(cx + R)), ya = podloga(f32(cy - R)), yb = podloga(f32(cy + R));
    for (auto& o : jednostki_) {
        if (o.id == u.id) continue;
        if (o.komorka_x < xa || o.komorka_x > xb || o.komorka_y < ya || o.komorka_y > yb) continue;
        u.lista_kontaktow.push_back(o.id);
        o.lista_kontaktow.push_back(u.id);
        o.kontakty = std::uint32_t(o.lista_kontaktow.size());
    }
    u.kontakty = std::uint32_t(u.lista_kontaktow.size());
}

void Swiat::po_ruchu(Jednostka& u, double x0, double y0) {
    // zapis transformacji i pola (0x5F043B): przy zmianie komórki 0x616F9D zeruje +0x248 i odbudowuje kontakty.
    // EE: od nowej pozycji (po zapisie); AoC (0x5FE611): od starej (przed zapisem) [W – bez testu dynamicznego].
    const std::int64_t nx = podloga(u.x), ny = podloga(u.y);
    if (nx == u.komorka_x && ny == u.komorka_y) return;
    u.komorka_x = nx;
    u.komorka_y = ny;
    u.licznik_blokady_ms = 0;
    if (u.wariant.kontakty == OdbudowaKontaktow::przed_zapisem) odbuduj_kontakty(u, x0, y0);
    else odbuduj_kontakty(u, u.x, u.y);
}

void Swiat::krok_koncowy(Jednostka& u) {
    if (!kolizje_wlaczone_) return;
    if (u.lista_kontaktow.empty() && u.licznik_blokady_ms == 0) return;
    const bool aktywna = u.v != 0.0 || u.omega != 0.0 ||
                         (u.param.vmax > 0 && std::max(std::fabs(u.push_x), std::fabs(u.push_y)) >= 0.001);
    if (!aktywna) {
        u.licznik_blokady_ms = 0;
        return;
    }
    const std::vector<IdJednostki> lista = u.lista_kontaktow;
    for (IdJednostki oid : lista) {  // 0x5498C4 → 0x549179 dla każdego kontaktu
        Jednostka* o = jednostka(oid);
        if (!o) continue;
        const auto r = odpychanie_male(u.x, u.y, u.param.promien_kolizji, o->x, o->y, o->param.promien_kolizji, o->v,
                                       o->param.vmax);
        if (!r.kolizja) continue;
        ++diag_.kolizje;
        if (u.pozostalo_punktow() == 1) {  // reguła (a) „cel zajęty” [P: EE 528]; zaliczenie w następnej fizyce [P: 634]
            const Punkt2& W = u.trasa[u.zdjete_punkty];
            if (std::hypot(W.x - o->x, W.y - o->y) <= o->param.promien_kolizji * 0.5) {
                u.v = 0.0;
                u.flaga_330 = 8;
                ++diag_.cele_zajete;
            }
        }
        o->push_x = f32(o->push_x + r.push_o_x);
        o->push_y = f32(o->push_y + r.push_o_y);
        u.push_x = f32(u.push_x + r.push_u_x);
        u.push_y = f32(u.push_y + r.push_u_y);
    }
    zastosuj_push(u);
}

void Swiat::zastosuj_push(Jednostka& u) {
    // 0x549A08: k = 1 (do 2000 jednostek); |vx| + |vy| < 0,02 → brak ruchu; przycięcie do max(vmax, 0,005/dt) [W]
    double vx = u.push_x, vy = u.push_y;
    u.push_x = u.push_y = 0.0;
    if (std::fabs(vx) + std::fabs(vy) < 0.02) return;
    const double m = std::max(f32(u.param.vmax), 0.005 / dt_), a = std::max(std::fabs(vx), std::fabs(vy));
    if (a > m) {
        vx *= m / a;
        vy *= m / a;
    }
    const double nx = f32(u.x + dt_ * vx), ny = f32(u.y + dt_ * vy);
    const std::int64_t cx = podloga(nx), cy = podloga(ny);
    bool ok = (cx == u.komorka_x && cy == u.komorka_y);
    if (!ok) {
        ok = teren_.pole_przejezdne(cx, cy);
        if (ok && cx != u.komorka_x && cy != u.komorka_y)
            ok = teren_.pole_przejezdne(u.komorka_x, cy) || teren_.pole_przejezdne(cx, u.komorka_y);
    }
    if (!ok) return;
    const double x0 = u.x, y0 = u.y;
    const double k248 = u.licznik_blokady_ms;
    u.x = nx;
    u.y = ny;
    po_ruchu(u, x0, y0);
    u.licznik_blokady_ms = k248 + 1000.0 * 1.5 / 44.0;  // odpychanie przywraca licznik i dodaje takt
    u.z = teren_.get_mesh_z(u.x, u.y);                  // dosadzenie 0x5EE7D7
    ++diag_.kroki_odpychania;
}

std::vector<MigawkaJednostki> Swiat::migawka() const {
    std::vector<MigawkaJednostki> w;
    w.reserve(jednostki_.size());
    for (const auto& u : jednostki_)
        w.push_back({u.id, u.x, u.y, u.z, u.v, u.omega, mat_.kurs_z_macierzy(u.orientacja), u.orientacja, u.stan,
                     u.tryb, u.zdjete_punkty, u.pozostalo_punktow(), u.licznik_blokady_ms});
    return w;
}


// ============================================================================================ walka w świecie (etap 31)
// Atlas: docs/titan/walka.md § 8–12. Adresy EE. Zdarzenia celu ataku: EEUGAttackUnit vt+0x64 (0x60B5CB), zdarzenia
// jednostki: dispatcher 0x61B677 (wołany po celu). Wszystkie mechanizmy bez pomiaru oznaczone [W]/[H]/[N]; miejsca
// z założeniem liczy Diagnostyka::zalozenia_walki.

void Swiat::zalozenie(const char* opis) {
    ++diag_.zalozenia_walki;
    diag_.ostatnie_zalozenie = opis;
}

bool Swiat::ustaw_walke(IdJednostki id, int gracz, bool czlowiek, const ParametryWalki& p, int hp, UstawieniaAI ai) {
    Jednostka* u = jednostka(id);
    if (!u) return false;
    u->gracz = gracz;
    u->czlowiek = czlowiek;
    BojJednostki b;
    b.p = p;
    b.s.hp = hp;
    b.hp_29c = hp;
    b.ai = ai;
    u->boj = b;
    return true;
}

void Swiat::ustaw_wrogow(int g1, int g2, bool wrog) { dyplomacja_[{g1, g2}] = wrog; }

bool Swiat::wrogowie(int g1, int g2) const {
    if (g1 == g2) return false;
    auto it = dyplomacja_.find({g1, g2});
    return it == dyplomacja_.end() ? true : it->second;
}

// ---------------------------------------------------------------------------------------------------------------
// Efekty obszarowe (etap 34) – docs/titan/walka.md § 25.

std::size_t Swiat::dodaj_szablon_efektu(SzablonEfektu s) {
    szablony_.push_back(std::move(s));
    return szablony_.size() - 1;
}

IdJednostki Swiat::dodaj_budynek(Budynek b, const std::vector<int>& szablony) {
    b.id = nastepny_id_++;
    b.efekty.clear();
    for (int sid : szablony) {
        if (sid <= 0) continue;
        std::size_t i = 0;
        while (i < szablony_.size() && szablony_[i].id != sid) ++i;
        if (i == szablony_.size()) {
            ++diag_.efekty_nieodwzorowane;
            continue;
        }
        const SzablonEfektu& s = szablony_[i];
        if (s.typ != 5 && s.typ != 2) {  // fabryka 0x663A70: typy 1, 3, 4, 6, 7, 8 – nieodwzorowane w Core [N]
            ++diag_.efekty_nieodwzorowane;
            continue;
        }
        EfektObszaru e;
        e.szablon = i;
        e.zrodlo = b.id;
        e.gracz = b.gracz;                                 // 0x663B95: [źródło+0x18]+0x45C
        if (s.typ == 5) e.poziom_max = s.maks_morale + premia_morale_wariantu_;  // 0x6641E2…0x6641F4
        e.brudny = true;                                   // 0x6641F8
        efekty_.push_back(e);
        b.efekty.push_back(efekty_.size() - 1);
    }
    budynki_.push_back(std::move(b));
    // dodanie obiektu do gracza (gracz vt[26], EE 0x555CE7): dom (typ 37) → SuggestRecomputeAllAreaEffects (0x555D98)
    if (budynki_.back().typ_db == 37) przelicz_efekty_gracza(budynki_.back().gracz);
    return budynki_.back().id;
}

bool Swiat::usun_budynek(IdJednostki id) {
    for (std::size_t i = 0; i < budynki_.size(); ++i) {
        if (budynki_[i].id != id) continue;
        const Budynek b = budynki_[i];
        budynki_.erase(budynki_.begin() + std::ptrdiff_t(i));
        if (b.typ_db == 37) przelicz_efekty_gracza(b.gracz);  // gracz vt[49] (EE 0x55C397) → 0x55C4FD
        return true;
    }
    return false;
}

bool Swiat::zmien_wlasciciela_budynku(IdJednostki id, int gracz) {
    for (Budynek& b : budynki_) {
        if (b.id != id) continue;
        const int stary = b.gracz;
        b.gracz = gracz;
        if (b.typ_db == 37) {
            przelicz_efekty_gracza(stary);
            przelicz_efekty_gracza(gracz);
        }
        return true;
    }
    return false;
}

void Swiat::przelicz_efekty_gracza(int gracz) {
    // EEPSuggestRecomputeAllAreaEffects (0x55C00E → 0x55C02A → 0x664F22): obiekty gracza – vt+0x3C (+0x1C = 1)
    for (const Budynek& b : budynki_)
        if (b.gracz == gracz)
            for (std::size_t e : b.efekty) efekty_[e].brudny = true;
}

bool Swiat::relacja_efektu(int relacja, int wlasciciel, int gracz) const {
    // 0x664A89: 1 – ten sam gracz; 2 – IsAlly 0x513B62 (ten sam albo +0x9E4 = 0 w obu kierunkach); 3 – inny gracz,
    // którego właściciel uważa za wroga; 4 – każdy
    switch (relacja) {
        case 1: return wlasciciel == gracz;
        case 2: return wlasciciel == gracz || (!wrogowie(wlasciciel, gracz) && !wrogowie(gracz, wlasciciel));
        case 3: return wlasciciel != gracz && wrogowie(wlasciciel, gracz);
        case 4: return true;
        default: return false;
    }
}

void Swiat::zlicz_domy(EfektObszaru& e, const SzablonEfektu& s, float mnoznik) {
    // 0x664214: domy (typ+0x4B8 == 0x25) gracza efektu (+0x18, równość), HP > 0, +0x340, kotwica w prostokącie;
    // kształt 2 – dodatkowo odległość² kotwicy od (ftol x, ftol y) ≤ r² (0x66478E). Duplikaty usuwane (0x411BD1).
    const float r = promien_efektu(s, mnoznik);
    const ProstokatPol p = prostokat_zliczania(e.x, e.y, r);
    const float r2 = float((long double)r * (long double)r);
    const std::int32_t cx = std::int32_t(e.x), cy = std::int32_t(e.y);
    int n = 0;
    for (const Budynek& h : budynki_) {
        if (h.typ_db != 37 || h.gracz != e.gracz || h.hp <= 0 || !h.na_mapie) continue;
        if (h.pole_x < p.x0 || h.pole_x > p.x1 || h.pole_y < p.y0 || h.pole_y > p.y1) continue;
        if (s.ksztalt != 1) {
            const std::int32_t dx = cx - h.pole_x, dy = cy - h.pole_y;
            if ((long double)(dx * dx) + (long double)(dy * dy) > (long double)r2) continue;
        }
        ++n;
    }
    // 0x66436F: m = min(+0x20, n); m < 0 → 0; inaczej min(n, +0x20)
    const int m = e.poziom_max < n ? e.poziom_max : n;
    e.licznik = m < 0 ? 0 : (n > e.poziom_max ? e.poziom_max : n);
    e.brudny = false;
}

void Swiat::przebieg_efektow() {
    // Menedżer 0x663DBD (AoC 0x67B634), kolejność [P: kod]:
    ++diag_.przebiegi_efektow;
    // 1. ClearAreaEffects (0x5E948A): wyczyszczenie list +0xF8 wszystkich jednostek
    for (Jednostka& u : jednostki_) u.efekty_obszaru.clear();
    // 2. 0x5EC018 → 0x6637B3: każdy obiekt z efektami (+0x340) – jednostki w obszarze dostają efekt (vt+0x08 =
    //    0x664B52: zestaw typów, relacja graczy, +0x340, kształt). Kolejność kandydatów: siatka regionów [H] – tu
    //    kolejność listy jednostek (ma znaczenie tylko przy remisie poziomów).
    for (const Budynek& b : budynki_) {
        if (!b.na_mapie || b.efekty.empty()) continue;
        for (std::size_t ei : b.efekty) {
            const SzablonEfektu& s = szablony_[efekty_[ei].szablon];
            const float r = promien_efektu(s, b.mnoznik_obszaru);
            for (Jednostka& u : jednostki_) {
                if (!u.boj) continue;  // typ jednostki (typ+0x4B8) znany tylko dla jednostek ze stanem bojowym
                bool w_zestawie = false;
                for (int t : s.zestaw) w_zestawie |= (t == u.boj->p.typ_bazy);
                if (!w_zestawie || !relacja_efektu(s.relacja, b.gracz, u.gracz)) continue;
                if (!w_obszarze(s.ksztalt, r, b.x, b.y, float(u.x), float(u.y))) continue;
                u.efekty_obszaru.push_back(ei);
            }
        }
    }
    // 3. RemoveRedundantAreaEffects (0x664EDB → 0x664E0B): z efektów równoważnych zostaje najsilniejszy (vt+0x18,
    //    porównanie bez znaku, przy remisie pierwszy). Poziomy z poprzedniego przebiegu (krok 4 jest później).
    for (Jednostka& u : jednostki_) {
        if (u.efekty_obszaru.size() < 2) continue;
        std::vector<std::size_t> nowa;
        for (std::size_t ei : u.efekty_obszaru) {
            const SzablonEfektu& s = szablony_[efekty_[ei].szablon];
            std::size_t j = 0;
            while (j < nowa.size() && !efekty_rownowazne(s.typ, szablony_[efekty_[nowa[j]].szablon].typ)) ++j;
            if (j < nowa.size()) {
                const auto pn = std::uint32_t(poziom_efektu(efekty_[ei], s));
                const auto ps = std::uint32_t(poziom_efektu(efekty_[nowa[j]], szablony_[efekty_[nowa[j]].szablon]));
                if (pn <= ps) continue;
                nowa.erase(nowa.begin() + std::ptrdiff_t(j));
            }
            nowa.push_back(ei);
        }
        u.efekty_obszaru = std::move(nowa);
    }
    // 4. UpdateGeneratedAreaEffects (0x5F133D → 0x664F3D): pozycja źródła → +0x08/+0x0C, vt+0x44 (typ 5: 0x664214,
    //    przeliczenie tylko przy +0x1C). Wszystkie obiekty z efektami (bez warunku +0x340).
    for (const Budynek& b : budynki_)
        for (std::size_t ei : b.efekty) {
            EfektObszaru& e = efekty_[ei];
            e.x = b.x;
            e.y = b.y;
            const SzablonEfektu& s = szablony_[e.szablon];
            if (s.typ == 5 && e.brudny) zlicz_domy(e, s, b.mnoznik_obszaru);
        }
    // 5./6. RebuildAreaEffectRegionList, UpdateAffectedByAreaEffects (vt+0x48 – dla morale bez działania 0x605652)
}

std::vector<int> Swiat::poziomy_morale(const Jednostka& u) const {
    std::vector<int> w;
    for (std::size_t ei : u.efekty_obszaru) {
        const SzablonEfektu& s = szablony_[efekty_[ei].szablon];
        if (s.typ == 2 || s.typ == 5) w.push_back(poziom_efektu(efekty_[ei], s));
    }
    if (u.boj) w.insert(w.end(), u.boj->morale.begin(), u.boj->morale.end());
    return w;
}

void Swiat::ustaw_tablice_walki(TabliceObrazen t, std::array<WagiCelu, 3> wagi) {
    tablice_walki_ = std::move(t);
    wagi_celu_ = wagi;
}

void Swiat::ustaw_stan(IdJednostki id, int stan) {
    if (Jednostka* u = jednostka(id)) u->stan = stan;
}

bool Swiat::rozkaz_ataku(IdJednostki id, IdJednostki cel) {
    Jednostka* u = jednostka(id);
    Jednostka* t = jednostka(cel);
    if (!u || !t || !u->boj) return false;
    CelRuchu c{TypCelu::jednostka, t->x, t->y, std::nullopt, true, false, 0};
    c.cel_jednostka = t->id;
    c.pole_x = t->komorka_x;
    c.pole_y = t->komorka_y;
    u->kolejka_celow.clear();
    u->kolejka_celow.push_front(c);
    u->cel = TypCelu::jednostka;
    u->cel_od_gracza = true;
    u->kurs_koncowy.reset();
    u->trasa.clear();
    u->zdjete_punkty = 0;
    u->trasa_gotowa = false;
    // Etap 36 [P: 619 – próbki co takt; W: wejście]: rozkaz ataku gracza wchodzi w InitialAttackState (2016), a krok
    // maszyny w tym samym takcie przechodzi GoalIsUnit → FaceEnemyUnit (2012: tryb 1 – obrót do celu już w takcie
    // rozkazu). Dalej skrypt: 2013 → 2024 → 8000 → 2015 → 10003, jak w grze (619: zgodne czasy przejść i kurs co takt;
    // to samo 9000 → 2016 → 2012 przy aktywacji celu ataku z kolejki gwardii 0x1000858).
    // *[Etap 36 – zastąpione: „wejście w CheckRange [H]” (etap 31) – kurs o 1 takt za grą, przejścia o 1 takt za wcześnie.]*
    auto it = skr(*u).stany().find("InitialAttackState");
    if (it != skr(*u).stany().end()) wejdz_w_stan(*u, it->second);
    return true;
}

Jednostka* Swiat::cel_ataku(const Jednostka& u) {
    if (u.kolejka_celow.empty() || u.kolejka_celow.front().typ != TypCelu::jednostka) return nullptr;
    return jednostka(u.kolejka_celow.front().cel_jednostka);
}

bool Swiat::widoczny_dla(int gracz, const Jednostka& c) const {
    // Widoczność pola celu dla gracza (0x631B64 → mapa widoczności EEMap, 0x44E46E). [H, etap 31 – pomiar 578]:
    // pole widoczne, gdy odległość środków pól od pola jednostki gracza ≤ jej pole widzenia (5 wykryć przy
    // odległości pól 2,24–3,61; brak wykrycia przez 40 s przy odległości pól 4,12 i odległości jednostek 3,79).
    // Moment aktualizacji mapy widoczności i obiekty bez LOS – [N].
    for (const auto& o : jednostki_) {
        if (o.gracz != gracz || !o.boj || o.boj->s.hp <= 0) continue;
        const double dx = double(o.komorka_x - c.komorka_x), dy = double(o.komorka_y - c.komorka_y);
        const double l = o.boj->p.pole_widzenia;
        if (dx * dx + dy * dy <= l * l) return true;
    }
    return false;
}

Punkt2 Swiat::punkt_podejscia(Jednostka& u, const Jednostka& t) {
    const Punkt2 poz_celu{t.x, t.y};
    if (t.v > 0.0) {
        // 0x62C963: przechwycenie tylko, gdy cel ma > 1 punkt trasy (+0x8C); inaczej pozycja celu
        if (t.pozostalo_punktow() <= 1) return poz_celu;
        const Punkt2 W = t.trasa[t.zdjete_punkty];            // 0x5EC49B – bieżący punkt trasy celu [W]
        // DistanceTo w 3D; punkty trasy mają z = 0 [P: zapis trasy z pamięci] – Dt.z = −z celu [P: 578, takt 2076 –
        // punkt (177,1906; 106,795) odtworzony tym wzorem]
        const double d = f32(std::sqrt((u.x - t.x) * (u.x - t.x) + (u.y - t.y) * (u.y - t.y) + (u.z - t.z) * (u.z - t.z)));
        const double va = f32(u.param.vmax), vt = f32(t.param.vmax);
        const double dtx = f32(W.x - t.x), dty = f32(W.y - t.y), dtz = f32(0.0 - t.z);
        const double dax = f32(u.x - t.x), day = f32(u.y - t.y), daz = f32(u.z - t.z);
        // oryginał: |Da| = sqrt(dx² + dy² + 2·dz) i iloczyn z „+ dz_t + dz_a” zamiast mnożenia (fadd zamiast fmul) –
        // odtwarzane dosłownie [W kod; skutek tylko przy różnicy wysokości] (BO-10, docs/titan/BLEDY_ORYGINALU.md)
        const double la = f32(std::sqrt(day * day + dax * dax + (daz + daz)));
        const double iloczyn = f32(dty * day + (dtz + daz) + dtx * dax);
        const double lt = std::sqrt(dtz * dtz + dty * dty + dtx * dtx);
        const double cosk = iloczyn / (lt * la);
        const double A = (va == vt) ? 0.0 : va * va - vt * vt;
        const double B = f32(2.0 * (cosk * vt * d));
        const double C = f32(-(d * d));
        double r1 = 0, r2 = 0;
        bool ok = true;
        if (A == 0.0) {                                       // UMQuadraticEquation: gałąź liniowa
            if (B == 0.0) ok = false;
            else r1 = r2 = f32(-C / B);
        } else {
            const double disc = B * B - A * C * 4.0;
            const double sq = std::sqrt(disc);
            r1 = f32((sq - B) / f32(A + A));
            r2 = f32((-B - sq) / f32(A + A));
        }
        const double r = (ok && r1 >= 0.0) ? r1 : ((ok && r2 >= 0.0) ? r2 : -1.0);
        if (r < 0.0) return poz_celu;
        const double s = f32(r * vt);
        const Punkt2 p{f32(t.x + s * t.orientacja.m01()), f32(t.y + s * t.orientacja.m11())};
        if (!teren_.komorka_istnieje(podloga(p.x), podloga(p.y))) return poz_celu;
        return p;
    }
    // cel stojący: 0x62CF6A (typy +0x61A): w zasięgu → własna pozycja; inaczej 0x632CF4 → 0x63234D
    if (u.boj && t.boj && u.boj->p.punktowy) {
        if (w_zasiegu_punktowy(odl2(u, t), u.boj->p.rozmiar, t.boj->p.rozmiar_jeden ? 1.0 : double(t.boj->p.rozmiar)))
            return Punkt2{u.x, u.y};
        if (t.boj->p.pole_ac > 0.0f) {
            // 8 miejsc wokół celu w odległości R = 0,5·s_ja + 0,5·s_cel (kolejność wstawiania z kodu), sortowanie wg
            // odległości od atakującego, pierwsze przejezdne (budynki blokujące – brak w Core) [W]
            const double R = f32(f32(0.5 * double(u.boj->p.rozmiar)) + f32(0.5 * double(t.boj->p.rozmiar)));
            const double tx = t.x, ty = t.y;
            std::vector<Punkt2> k = {{tx, f32(R + ty)},     {f32(R + tx), ty},     {tx, f32(ty - R)},     {f32(tx - R), ty},
                                     {f32(R + tx), f32(R + ty)}, {f32(R + tx), f32(ty - R)}, {f32(tx - R), f32(ty - R)},
                                     {f32(tx - R), f32(R + ty)}};
            std::stable_sort(k.begin(), k.end(), [&](const Punkt2& a, const Punkt2& b) {
                return (a.x - u.x) * (a.x - u.x) + (a.y - u.y) * (a.y - u.y) <
                       (b.x - u.x) * (b.x - u.x) + (b.y - u.y) * (b.y - u.y);
            });
            zalozenie("miejsce podejścia 0x63234D: porządek przy równych odległościach [W]");
            // etap 39 – zajętość miejsca (0x63234D, pętla 0x63267C) [W: kod; P: 619/620 – druga gwardia omija miejsce
            // zajęte przez pierwszą]: obiekty w promieniu R + 2,0 od celu (0x63603B, d² ≤ r²); miejsce zajęte, gdy dla
            // żywej jednostki (HP > 0) A² > d² + 0,1·s_ja, A = 0,5·(s_obiektu + s_ja), d² – kwadrat odległości miejsca od
            // pozycji obiektu (GE2DPoint::DistanceToSquared). Obiekty z typ+0x619 (zajmujące pole) – przez przejezdność
            // terenu Core [W]. Flagi typu +0x600/+0x606 nieodczytane – przyjęte dla każdej jednostki bojowej [H].
            const double rr = f32(R + 2.0);
            std::vector<const Jednostka*> blisko;
            for (const auto& o : jednostki_) {
                const double dx = f32(o.x - tx), dy = f32(o.y - ty);
                if (f32(dx * dx + dy * dy) <= f32(rr * rr)) blisko.push_back(&o);
            }
            const double s_ja = f32(double(u.boj->p.rozmiar));
            for (const auto& p : k) {
                if (!teren_.pole_przejezdne(podloga(p.x), podloga(p.y))) continue;   // 0x62C7C8
                bool wolne = true;
                for (const Jednostka* o : blisko) {
                    if (!o->boj || o->boj->s.hp <= 0) continue;
                    const double A = f32(f32(double(o->boj->p.rozmiar) + s_ja) * 0.5);
                    const double dx = f32(o->x - p.x), dy = f32(o->y - p.y);
                    const double d2 = f32(dx * dx + dy * dy);
                    if (f32(A * A) > f32(f32(0.1f * float(s_ja)) + d2)) { wolne = false; break; }
                }
                if (wolne) return p;
            }
            // brak przejezdnego miejsca → 0x632CF4 fałsz → 0x62CD76: cel wpisany (albo odświeżony) w mapie
            // nieosiągalnych (0x5E8651, termin + 30 s) przy każdym PrepareToMove; dalej obsługa garnizonu (brak w Core)
            // [P: kod 0x62D1F2–0x62D207, 0x62CD88; W: warunek „brak miejsca” jako jedyna przyczyna fałszu 0x632CF4;
            // 616 – ponowny wybór 30 s po ostatnim 8000, etap 37]
            oznacz_nieosiagalny(u, t);
        }
        zalozenie("punkt podejścia: gałąź 0x62C315 (ulepszenie +0xAC = 0 albo brak miejsca) – pozycja celu [N]");
        return poz_celu;
    }
    zalozenie("punkt podejścia typu niepunktowego 0x631444/0x62CF6A – pozycja celu [N]");
    return poz_celu;
}

double Swiat::odl2(const Jednostka& a, const Jednostka& b) const {
    // GE3DPoint::DistanceToSquared (Low-Level Engine) na pozycjach (typy +0x61A: vt+0x5C), z wyzerowane [W]
    const double dx = a.x - b.x, dy = a.y - b.y;
    return f32(dx * dx + dy * dy);
}

double Swiat::kat_do_celu_broni(const Jednostka& u, const Jednostka& t) const {
    // 0x61FCAF: przód = M·R(+0x458)·(0,1,0) z z = 0, unormowany; do celu = (t − u) unormowany; |UMArcCos(iloczyn)|
    if (t.x == u.x && t.y == u.y) return 0.0;
    double fx = u.orientacja.m01(), fy = u.orientacja.m11();
    if (u.boj && u.boj->p.kat_broni != 0.0f) {
        const Macierz3 r = mat_.set_orientation_ypr(f32(mat_.kurs_z_macierzy(u.orientacja) + u.boj->p.kat_broni));
        fx = r.m01();
        fy = r.m11();
        const_cast<Swiat*>(this)->zalozenie("kąt broni +0x458 ≠ 0: złożenie macierzy uproszczone [W]");
    }
    const double lf = std::sqrt(fx * fx + fy * fy);
    fx = f32(fx / lf);
    fy = f32(fy / lf);
    double tx = f32(t.x - u.x), ty = f32(t.y - u.y);
    const double lt = std::sqrt(tx * tx + ty * ty);
    tx = f32(tx / lt);
    ty = f32(ty / lt);
    double d = fy * ty + fx * tx;
    if (d > 1.0) d = 1.0;
    if (d < -1.0) d = -1.0;
    return std::fabs(mat_.um_arccos(f32(d)));
}

std::optional<double> Swiat::m_trafienia(const Jednostka& a, const Jednostka& c) const {
    // 0x4D5F2C: tablica wg trudności i ludzi/komputera, [klasa celu +0x4C4][rodzina atakującego +0x4C8]
    if (!a.boj || !c.boj) return std::nullopt;
    const auto idx = wybor_tablicy_trafien(a.czlowiek, c.czlowiek, tablice_walki_.trudnosc);
    if (!idx) return std::nullopt;
    const auto& tab = tablice_walki_.trafienie[std::size_t(*idx)];
    auto it = tab.find(c.boj->p.klasa_trafienia);
    if (it == tab.end()) return std::nullopt;
    const int r = a.boj->p.rodzina_ataku;
    if (r < 0 || std::size_t(r) >= it->second.size()) return std::nullopt;
    return double(it->second[std::size_t(r)]);
}

double Swiat::w_mnoznik(const Jednostka& a, const Jednostka& c) const {
    const auto& m = tablice_walki_.mnozniki;
    const int w = c.boj->p.wiersz_celu, k = std::clamp(a.boj->p.rodzaj_ataku, 0, 5);
    if (w < 0 || std::size_t(w) >= m.size()) return 1.0;
    return double(m[std::size_t(w)][std::size_t(k)]);
}

bool Swiat::cel_nieosiagalny(Jednostka& u, const Jednostka& t, bool sprawdz_pola) {
    // 0x5EC9BB: wyszukanie wpisu celu; termin ≤ czas gry → wpis usunięty, fałsz; bez sprawdzania pól → prawda;
    // z polami: pole atakującego i pole celu jak przy wpisie → prawda, inaczej wpis usunięty i fałsz [P: kod, etap 37]
    auto& w = u.boj->nieosiagalne;
    for (std::size_t i = 0; i < w.size(); ++i) {
        if (w[i].cel != t.id) continue;
        if (!(w[i].termin_ms > zegar_ms_)) {
            w.erase(w.begin() + std::ptrdiff_t(i));
            return false;
        }
        if (!sprawdz_pola) return true;
        if (w[i].pole_x == u.komorka_x && w[i].pole_y == u.komorka_y && w[i].pole_celu_x == t.komorka_x &&
            w[i].pole_celu_y == t.komorka_y)
            return true;
        w.erase(w.begin() + std::ptrdiff_t(i));
        return false;
    }
    return false;
}

void Swiat::oznacz_nieosiagalny(Jednostka& u, const Jednostka& t) {
    // 0x5E8651: nowy wpis (pola atakującego i celu, termin = czas gry + 30000 ms) albo odświeżenie samego terminu
    for (auto& e : u.boj->nieosiagalne)
        if (e.cel == t.id) {
            e.termin_ms = zegar_ms_ + 30000u;
            return;
        }
    u.boj->nieosiagalne.push_back({t.id, u.komorka_x, u.komorka_y, t.komorka_x, t.komorka_y, zegar_ms_ + 30000u});
}

bool Swiat::szukaj_wroga(Jednostka& u) {
    // 0x61AC11 (CanISeeEnemy / EnemyUnitSpotted) → 0x62EBD2/0x62EBEE → przegląd 0x63969A/0x639D7D, ocena 0x6399CA
    BojJednostki& b = *u.boj;
    const CelRuchu* g = u.kolejka_celow.empty() ? nullptr : &u.kolejka_celow.front();
    const bool lok = g && g->typ == TypCelu::miejsce && !g->punkt_automatyczny;
    if (b.szukanie_ms > 0 && !lok) return false;
    ++diag_.szukania_wroga;
    // środek: własne pole; wariant „wokół miejsca kontaktu” (+0x214 ≠ −10000, AI +9, cel nie od gracza) [W]
    std::int64_t cx = u.komorka_x, cy = u.komorka_y;
    bool srodek_wlasny = true;
    if (b.icl_kurs != -10000.0 && b.ai.wraca_do_icl && (!g || !g->od_gracza)) {
        cx = podloga(b.icl_x);
        cy = podloga(b.icl_y);
        srodek_wlasny = (cx == u.komorka_x && cy == u.komorka_y);
    }
    const ParametryWalki& p = b.p;
    const double f = 1.0;
    const double zf = f32(double(p.zasieg_max) * f);
    const double los = p.pole_widzenia;
    const double rmax = zf > los ? zf : los;
    std::int64_t r = std::int64_t(std::nearbyint(rmax));
    if (double(r) < rmax) ++r;  // fistp + korekta w górę (sufit)
    const double max2 = zf > los ? f32(zf * zf) : f32(los * los);
    const double z2 = f32(zf * zf);
    const int tryb = p.punktowy ? 0 : (p.zasieg_max <= p.pole_widzenia ? 1 : 2);
    const WagiCelu& w = wagi_celu_[std::size_t(tryb)];
    Jednostka* best = nullptr;
    int best_wynik = -100000;   // funktor +0x68 = 0xFFFE7960
    bool koniec = false;
    if (p.atak != 0.0f) {
        // kolejność kandydatów: strefy siatki EEMap+0x181724 (bliskie, potem dalekie, obrót listy o [0x919774]+0xB0)
        // [N] – w Core kolejność listy jednostek; ma znaczenie tylko przy równych wynikach (porównanie ścisłe >)
        zalozenie("kolejność kandydatów wyboru celu = lista jednostek Core [N]");
        for (auto& c : jednostki_) {
            if (koniec) break;
            if (c.id == u.id || !c.boj || c.gracz == u.gracz || !wrogowie(u.gracz, c.gracz)) continue;  // 0x639993
            if (c.boj->s.hp <= 0) continue;
            if (c.komorka_x < cx - r || c.komorka_x > cx + r || c.komorka_y < cy - r || c.komorka_y > cy + r) continue;
            double d2 = odl2(u, c);
            if (!srodek_wlasny) {
                const double px = double(cx) + 0.5, py = double(cy) + 0.5, dx = px - c.x, dy = py - c.y;
                d2 = f32(dx * dx + dy * dy);
            }
            if (d2 > max2) continue;
            if (!widoczny_dla(u.gracz, c)) continue;  // 0x631B64(kandydat, gracz, 1) – mgła wojny pól [H]
            // 0x639B61: mapa celów nieosiągalnych (+0xB0 ≠ 0) – ważny wpis (termin, te same pola) odrzuca kandydata
            // [P: kod; 616 – ponowny wybór obywatela 207 ms po upływie 30 s od porzucenia, 619 – wybór innego celu, etap 37]
            if (!b.nieosiagalne.empty() && cel_nieosiagalny(u, c, true)) continue;
            const auto m = m_trafienia(u, c);
            if (!m) {
                zalozenie("tablica trafień dla tej pary graczy nieznana – kandydat odrzucony [N]");
                continue;
            }
            if (p.pole_ac == 0.0f && tryb == 1 && d2 >= z2) continue;          // funktor +0x6C, tryb 1
            if (d2 < f32(double(p.zasieg_min) * p.zasieg_min)) continue;       // +0x3C
            if (!(*m > 0.0)) continue;
            bool atakuje_mnie = false;
            if (!c.kolejka_celow.empty() && c.kolejka_celow.front().typ == TypCelu::jednostka &&
                c.kolejka_celow.front().cel_jednostka == u.id)
                atakuje_mnie = true;
            bool spec = false;
            const int wynik = ocena_celu(p, c.boj->p, zf, d2, *m, atakuje_mnie, w, spec);
            if (spec || wynik > best_wynik) {
                zalozenie("osiągalność kandydata 0x62D696 = prawda [N]");
                best = &c;
                best_wynik = spec ? 0 : wynik;
                if (spec || wynik >= w.prog) koniec = true;
            }
        }
    }
    b.szukanie_ms = p.szukanie_ms;  // 0x61AD21: +0x2AC := typ+0x564 po każdym przeglądzie
    if (!best) return false;
    // 0x60AD45 + 0x5F05BD: cel EEUGAttackUnit (+0x1C = 0 – nie od gracza) na początek kolejki, bez zmiany stanu
    CelRuchu c{TypCelu::jednostka, double(best->komorka_x) + 0.5, double(best->komorka_y) + 0.5, std::nullopt, false,
               false, 0};
    c.cel_jednostka = best->id;
    c.pole_x = best->komorka_x;
    c.pole_y = best->komorka_y;
    u.kolejka_celow.push_front(c);
    u.cel = TypCelu::jednostka;
    u.cel_od_gracza = false;
    ++diag_.wybory_celu;
    zdarzenia_walki_.push_back({takty_, u.id, best->id, "wybor_celu", best_wynik});
    return true;
}

std::optional<bool> Swiat::zdarzenie_walki(Jednostka& u, const std::string& n) {
    BojJednostki& b = *u.boj;
    const CelRuchu* g = u.kolejka_celow.empty() ? nullptr : &u.kolejka_celow.front();
    Jednostka* t = cel_ataku(u);
    if (n == "CanISeeEnemy" || n == "EnemyUnitSpotted") {  // 0x61BFF4 / 0x61C00F
        if (!b.ai.szuka_wrogow) {
            zalozenie("AI +8 = 0: warunek 0x61C251 (lista celów) [N] – fałsz");
            return false;
        }
        return szukaj_wroga(u);
    }
    if (n == "CanITargetEnemies") return b.ai.szuka_wrogow;               // 0x61B6EE (+0x61C251 [N])
    if (n == "GoalIsUnit") return g && g->typ == TypCelu::jednostka;       // 0x61BA18
    if (n == "GoalIsLocation") return g && g->typ == TypCelu::miejsce;     // 0x61BA29
    if (n == "GoalIsNotAttack") return !(g && g->typ == TypCelu::jednostka);  // 0x61BF48 (rodzaj ≠ 2, 3)
    if (n == "GoalIsAttackLocation") return false;                          // rodzaj 3 – brak w Core
    if (n == "GoalIsPlayerInitiated") return g && g->od_gracza;            // 0x61BAA4 (+0x1C)
    if (n == "GoalIsNotPlayerInitiated") return !g || !g->od_gracza;       // 0x61C16B
    if (n == "CanIMoveFreely") return b.ai.moze_swobodnie;                 // 0x4D6B5B [H: stała ustawień]
    if (n == "CanIPursuePastInitialContactLOS") return b.ai.poscig_poza_icl;  // 0x61B800 (+7; 0x61C251 [N])
    if (n == "EnemyInsideInitialContactLOS") {  // 0x61B81E – [H]: cel w polu widzenia od miejsca kontaktu
        zalozenie("EnemyInsideInitialContactLOS: odległość celu od miejsca kontaktu ≤ pole widzenia [H]");
        if (!t || b.icl_kurs == -10000.0) return false;
        const double dx = t->x - b.icl_x, dy = t->y - b.icl_y;
        return dx * dx + dy * dy <= double(b.p.pole_widzenia) * b.p.pole_widzenia;
    }
    if (n == "HasValidInitialContactLocation") return b.icl_kurs != -10000.0;  // [W]
    if (n == "ReturnsToInitialContactLocation") return b.ai.wraca_do_icl;       // 0x61B968 (+9)
    if (n == "ShouldIRun") return false;           // 0x61C130: wymaga napastnika +0x1DC – nieodwzorowane [N]
    if (n == "ShouldIRetaliate") return false;     // 0x61C020: jw. [N]
    if (n == "TargetIsSpecialEnemy") return false;  // 0x60B175 [N]
    if (n == "BlockedByWall") return false;        // 0x637F5A: brak murów w Core; przy sąsiednich polach zawsze fałsz [W]
    if (n == "AttackMoveEnabled") return false;
    if (n == "GoalIsPatrol") return false;
    // zdarzenia celu ataku (vt+0x64); bez celu-jednostki → fałsz jak w dispatcherze jednostki (0x61C1EF)
    static const char* ZD_CELU[] = {"EnemyUnitDestroyed", "UnitNotOnMap", "CeaseFire", "EnemyWithinMinimumRange",
                                    "EnemyUnitNoLongerVisible", "EnemyUnitMoved", "EnemyUnitHasNotMovedOneTile",
                                    "EnemyUnitReachable", "UnitInWeaponRange", "FacingEnemyUnit",
                                    "EnemyUnitInsideFiringArch", "AttackerIsRangedUnit"};
    if (!g || g->typ != TypCelu::jednostka)
        for (const char* z : ZD_CELU)
            if (n == z) return false;
    if (n == "EnemyUnitDestroyed") return !t || !t->boj || t->boj->s.hp <= 0;   // 0x60B60F
    if (n == "UnitNotOnMap") return !t;                                         // 0x60B62F (pole −10000)
    if (n == "CeaseFire") return t && (t->gracz == u.gracz || !wrogowie(u.gracz, t->gracz));  // 0x60B7F9 (+0x200 = 0)
    if (n == "EnemyWithinMinimumRange") {                                       // 2035 → 0x62871E
        if (b.p.zasieg_min > 0.0f) zalozenie("EnemyWithinMinimumRange przy zasięgu minimalnym > 0 [N]");
        return false;
    }
    if (n == "EnemyUnitNoLongerVisible") {   // 0x60B64E: komputer z zasięgiem ≥ LOS → fałsz; inaczej !0x631B64(cel, gracz, 0)
        if (!t) return false;
        if (!u.czlowiek && b.p.zasieg_max >= b.p.pole_widzenia) return false;
        return !widoczny_dla(u.gracz, *t);
    }
    if (n == "AttackerIsRangedUnit") return b.p.zasieg_max > 1.0f;                // 0x60B763 (> 1,0)
    if (n == "EnemyUnitMoved") return t && (t->komorka_x != g->pole_x || t->komorka_y != g->pole_y);  // 0x60B827
    if (n == "EnemyUnitHasNotMovedOneTile") return t && t->komorka_x == g->pole_x && t->komorka_y == g->pole_y;  // 0x60B8B7
    if (n == "EnemyUnitReachable") {
        // 0x60B1EA: (typ+0x61A → 0x5ECAD0) i osiągalność 0x62D696 [N – w Core prawda] i licznik prób celu ≤ 25
        // (cmp 25, [cel+0x18]; sbb; inc) [P: kod; 619 – 2013 przy +0x18 = 25, porzucenie przy 26, etap 37].
        // *[Etap 37 – zastąpione: „< 25” (etap 31).]*
        zalozenie("EnemyUnitReachable: 0x5ECAD0 (spójność regionów) = prawda [N]");
        const bool r = t && t->boj && t->boj->s.hp > 0 && g->proby <= 25 && osiagalny_62d696(u, *t);
        // ścieżka fałszu (0x60B241): cel wpisany do mapy nieosiągalnych na 30 s, o ile nie ma ważnego wpisu [P: kod]
        if (!r && t && !cel_nieosiagalny(u, *t, true)) oznacz_nieosiagalny(u, *t);
        return r;
    }
    if (n == "UnitInWeaponRange") {    // 0x5F0CE8
        if (!t || !t->boj || b.p.zasieg_max == 0.0f || t->boj->s.hp <= 0) return false;
        const double d2 = odl2(u, *t);
        if (b.p.punktowy)
            return w_zasiegu_punktowy(d2, b.p.rozmiar, t->boj->p.rozmiar_jeden ? 1.0 : double(t->boj->p.rozmiar));
        zalozenie("UnitInWeaponRange typu niepunktowego: d² ≤ zasięg² bez punktu celowania 0x633413 [W]");
        return d2 <= f32(double(b.p.zasieg_max) * b.p.zasieg_max);
    }
    if (n == "FacingEnemyUnit") return t && kat_do_celu_broni(u, *t) <= f32(0.0436332313);  // 0x61FC51(…, 0)
    if (n == "EnemyUnitInsideFiringArch") {                                                 // 0x61FC51(…, 1)
        if (!t) return false;
        if (b.p.luk_ataku == f32(6.2831853)) return true;
        return kat_do_celu_broni(u, *t) <= double(b.p.luk_ataku) * 0.5;
    }
    if (n == "Reloaded") return b.s.przeladowanie_ms == 0;   // 0x61B746: +0x2A0 == 0 (AoC +0x2A4)
    // etap 44 – Generic Death.tai (0x61B677): 6000 DyingAnimationFinished: +0x337 ≠ 0 (koniec sekwencji, 0x62462B) albo
    // czas klatki typu = 1; 6001 ResourcesRottedAway: zasoby +0x40 = 0; 6002 UnitRottedAway: +0x2A8 = 0 [W]
    if (n == "DyingAnimationFinished") {
        if (b.p.smierc_klatki <= 0) return std::nullopt;
        return b.smierc_koniec || b.p.smierc_ms_klatki == 1;
    }
    if (n == "TakingLightDamage") return b.hp_29c > b.s.hp;   // 0x61BA3A: +0x29C > HP [W]
    if (n == "BuildingInBuildQueue") return false;           // budowa poza Core
    if (n == "ResourcesRottedAway") return b.zasoby == 0;
    if (n == "UnitRottedAway") return b.licznik_2a8 == 0;
    return std::nullopt;
}

void Swiat::liczniki_walki(Jednostka& u) {
    // liczniki +0x2A0 i +0x2AC: −34 ms na takt, także po śmierci [P: 561/564]; trafienie w cyklu ataku
    BojJednostki& b = *u.boj;
    const int ms = 34;
    b.s.przeladowanie_ms = std::max(0, b.s.przeladowanie_ms - ms);
    b.szukanie_ms = std::max(0, b.szukanie_ms - ms);
    b.hp_29c = b.s.hp;   // etap 45: aktualizacja typu (0x600664 i pokrewne) zapisuje +0x29C = HP po kroku maszyny [W]
    // etap 44: animacja umierania (0x62462B): +0x2FC += ms taktu; przy ≥ czasie klatki – kolejne klatki (reszta zostaje),
    // po ostatniej klatce +0x337 = 1 [W]. Stany rozkładu (0x5FB218): 6001 – +0x2A8 += ms, co 4000 ms −(+0x2A8/4000)
    // zasobów (reszta zostaje); 6002 – +0x2A8 −= ms, nie poniżej 0 [W].
    if (u.stan == 6000 && b.p.smierc_klatki > 0 && !b.smierc_koniec) {
        b.smierc_ms += ms;
        if (b.p.smierc_ms_klatki > 0 && b.smierc_ms >= b.p.smierc_ms_klatki) {
            b.smierc_klatka += b.smierc_ms / b.p.smierc_ms_klatki;
            b.smierc_ms %= b.p.smierc_ms_klatki;
            if (b.smierc_klatka >= b.p.smierc_klatki) b.smierc_koniec = true;
        }
    } else if (u.stan == 6001) {
        int a = b.licznik_2a8 + ms;
        if (a > 4000) { b.zasoby = std::max(0, b.zasoby - a / 4000); a %= 4000; }
        b.licznik_2a8 = a;
    } else if (u.stan == 6002) {
        b.licznik_2a8 = std::max(0, b.licznik_2a8 - ms);
    }
    // regeneracja HP 0x625B47 (wywołanie z aktualizacji typu 0x60071D/0x60498C/0x605490, gdy typ+0x578 ≠ 0) [P: kod +
    // pomiar 619 – bohater 173: +2 HP co 30 taktów]: +0x290 −= czas taktu; ≤ 0 → HP = min(HP + regeneracja, HP max)
    // (zapis tylko przy HP > 0), +0x290 := 1000 (bez przenoszenia nadwyżki). Flaga [0x918EA0] ≠ 0 pomija – w Core 0 [W].
    if (b.p.regeneracja != 0) {
        int r = b.regeneracja_ms - ms;
        if (r <= 0) {
            const int nowe = std::min(b.s.hp + b.p.regeneracja, b.p.hp_max);
            if (b.s.hp > 0 && nowe > 0) b.s.hp = nowe;
            r = 1000;
        }
        b.regeneracja_ms = r;
    }
    if (b.s.hp <= 0) return;
    if (b.s.trafienie_w_cyklu || b.p.opoznienie_trafienia_ms < 0 || (u.stan != 2021 && u.stan != 2001)) return;
    // czas od wejścia w AttackEnemyUnit liczony jak licznik +0x2A0 (takt wejścia = 34 ms) [P: 564 – 1122 ms]
    const int od_wejscia = int(takty_ - b.takt_wejscia_ataku + 1) * ms;
    if (od_wejscia < b.p.opoznienie_trafienia_ms) return;
    Jednostka* t = cel_ataku(u);
    if (!t || !t->boj || t->boj->s.hp <= 0) return;
    b.s.trafienie_w_cyklu = true;
    const auto m = m_trafienia(u, *t);
    if (!m) {
        zalozenie("trafienie: tablica trafień nieznana – brak obrażeń [N]");
        return;
    }
    if (!mod_wys_.wlaczony) zalozenie("modyfikator wysokości 0x61E500 bez konfiguracji reguł – r = 1 [N]");
    const auto pw = premia_wys_.find(u.gracz);
    const double r = modyfikator_wysokosci(mod_wys_, b.p.typ_jednostki, t->boj->p.typ_jednostki, u.z, t->z,
                                           pw == premia_wys_.end() ? 0.0 : double(pw->second));
    const auto o = oblicz_obrazenia(b.p, t->boj->p, *m, w_mnoznik(u, *t), r, u.gracz == t->gracz);
    ++diag_.trafienia;
    // TakeDamage 0x6172BC → 0x664EA1: vt+0x30 każdego efektu z listy +0xF8 celu (morale: 0x6640BA) [P]
    const int obr = obrazenia_po_modyfikatorach(o.obrazenia, poziomy_morale(*t));
    zdarzenia_walki_.push_back({takty_, u.id, t->id, "trafienie", obr});
    t->boj->szukanie_ms = 0;   // TakeDamage 0x6172BC zeruje +0x2AC [W]
    // liczniki +0x2C4/+0x2C8 (0x5EDCA4) – w Core 0 [N]
    t->boj->ostatni_atakujacy = u.id;   // etap 45: źródło dla FleeDanger (0x62FE01 [H])
    if (przyjmij_obrazenia(t->boj->s, obr)) {
        ++b.s.zabicia;
        ++diag_.zgony;
        zdarzenia_walki_.push_back({takty_, t->id, u.id, "smierc", 0});
        auto it = skr(*t).stany().find("Dying");
        if (it != skr(*t).stany().end()) wejdz_w_stan(*t, it->second);
        else t->stan = 6000;
    }
}

bool Swiat::osiagalny_62d696(Jednostka& u, const Jednostka& t) {
    // 0x62D696 (etap 40) [W: kod; P: 619/620 – porzucenie celu przez 0x1000858 stojącą na polu nieprzejezdnym,
    // a 0x1000856 przy obywatelu w odległości 1 – szybka prawda]:
    if (t.komorka_x == -10000) return false;
    const BojJednostki& b = *u.boj;
    const double z2 = f32(double(b.p.zasieg_max) * double(b.p.zasieg_max));
    const double T = z2 < 2.0 ? 2.0 : z2;   // max(zasięg², 2,0) (0x825784)
    // typ+0x430 = 0 albo (typ+0x5D4 & 6) = 0 → prawda: pól typu nie odczytano – przyjęte ≠ 0 dla jednostek bojowych [H]
    const double dx = f32(t.x - u.x), dy = f32(t.y - u.y);
    if (f32(dx * dx + dy * dy) <= T) return true;          // 0x406D5E: kwadrat odległości pozycji
    // garnizon/transport (+0x1D8) – brak w Core
    const double los = double(b.p.pole_widzenia);
    const double r = los > T ? los : T;
    const int pol = int(std::ceil(r));
    const int esi = 2 * pol;
    const int W = teren_.szerokosc() - 1, H = teren_.wysokosc() - 1;
    const int ax = int(u.komorka_x), ay = int(u.komorka_y), tx = int(t.komorka_x), ty = int(t.komorka_y);
    const int x0 = std::max(0, std::min(ax, tx) - esi), y0 = std::max(0, std::min(ay, ty) - esi);
    const int x1 = std::min(W - 1, std::max(ax, tx) + esi), y1 = std::min(H - 1, std::max(ay, ty) + esi);
    const int d2p = (tx - ax) * (tx - ax) + (ty - ay) * (ty - ay);   // 0x409914: kwadrat odległości pól (całkowity)
    const int budzet = std::min(2 * std::max(esi, d2p), 0x23);
    ParametryAStar p;
    p.limit_wywolania = -1;
    p.limit_calkowity = budzet;
    p.koniec_bez_testu_dostepnosci = true;   // maszyna Bounded (klucz 0xB) – koniec = najbliższy węzeł [W]
    zalozenie("0x62D696: A* Bounded 0x4A189C jako AStarTitan z limitem całkowitym, bez modyfikatora celu [W]");
    const auto w = AStarTitan::szukaj({ax, ay}, {tx, ty}, [&](int x, int y) {
        return x >= x0 && x <= x1 && y >= y0 && y <= y1 && teren_.pole_przejezdne(x, y);
    }, W, H, p);
    ++diag_.osiagalnosc_astar;
    if (w.trasa_od_celu.empty()) return false;
    const Pole k = w.trasa_od_celu.front();   // pierwszy punkt wyniku = węzeł końcowy
    const int d2k = (tx - k.x) * (tx - k.x) + (ty - k.y) * (ty - k.y);
    return double(d2k) <= T;
}

// ---------------------------------------------------------------------------------------------------------------
// Graf podsektorów (etap 40) – docs/titan/architektura_nawigacji.md § 5, walka.md § 30.

int Swiat::prog_punktu_auto(int r) {
    // 0x4243AC: [0x917DC8] wg rozmiaru mapy [W]
    if (r <= 42) return 8;
    if (r <= 58) return 10;
    if (r <= 75) return 12;
    if (r <= 105) return 14;
    if (r <= 160) return 16;
    if (r <= 220) return 18;
    return 14;
}

std::pair<int, int> punkt_reprezentatywny(const std::vector<std::pair<int, int>>& L) {
    // ComputeCenterPoint(true) (Low-Level Engine 0x1005FD31 → 0x100609AB): średnia f32 (Σ x/n od końca listy),
    // obcięcie (_ftol); punkt spoza zbioru → najbliższy (d² całkowite), start od ostatniego, przy remisie mniejszy indeks
    if (L.empty()) return {0, 0};
    // etap 43: iloraz x/n w precyzji rozszerzonej x87 (bez zaokrąglenia do f32), suma zapisywana do f32 po każdym
    // dodaniu (fstp dword) [P: 1857/1857 punktów e35_a; wcześniej iloraz w f32 – 1851/1857]
    const double n = double(L.size());
    float cx = 0.0f, cy = 0.0f;
    for (std::size_t i = L.size(); i-- > 0;) {
        cx = float(double(cx) + double(L[i].first) / n);
        cy = float(double(cy) + double(L[i].second) / n);
    }
    const std::pair<int, int> c{int(cx), int(cy)};
    for (const auto& p : L) if (p == c) return c;
    std::pair<int, int> best = L.back();
    auto d2 = [&](const std::pair<int, int>& p) { return (c.first - p.first) * (c.first - p.first) + (c.second - p.second) * (c.second - p.second); };
    int bd = d2(best);
    for (std::size_t i = L.size() - 1; i-- > 0;) {
        const int d = d2(L[i]);
        if (d <= bd) { best = L[i]; bd = d; }
    }
    return best;
}

GrafPodsektorow zbuduj_graf_z_przydzialu(const std::vector<int>& g, int W, int H, int komorka) {
    GrafPodsektorow G;
    G.zrodlo = "Core z przydziału pól";
    auto id = [&](int x, int y) { return (x < 0 || y < 0 || x >= W || y >= H) ? 0 : g[std::size_t(x) * H + y]; };
    std::map<int, std::vector<std::pair<int, int>>> pola;
    for (int x = W - 1; x >= 0; --x)          // kolejność kontenera: kolumny od ostatniej, y rosnąco
        for (int y = 0; y < H; ++y)
            if (const int c = id(x, y)) {
                pola[c].push_back({x, y});
                G.pole_podsektor[(std::int64_t(x) << 32) | std::uint32_t(y)] = c;
            }
    for (auto& [c, L] : pola) {
        Podsektor p;
        p.id = c;
        p.sektor_i = komorka > 0 ? L.front().first / komorka : 0;
        p.sektor_j = komorka > 0 ? L.front().second / komorka : 0;
        const auto r = punkt_reprezentatywny(L);
        p.punkt_x = r.first;
        p.punkt_y = r.second;
        G.podsektory[c] = std::move(p);
    }
    auto lacz = [&](int a, int b) {
        auto& la = G.podsektory[a].sasiedzi;
        if (std::find(la.begin(), la.end(), b) == la.end()) la.push_back(b);
        auto& lb = G.podsektory[b].sasiedzi;
        if (std::find(lb.begin(), lb.end(), a) == lb.end()) lb.push_back(a);
    };
    for (int x = 0; x < W; ++x)                // 0x4246E8
        for (int y = 0; y < H; ++y) {
            const int c = id(x, y);
            if (!c) continue;
            const int s[4][2] = {{x - 1, y}, {x, y - 1}, {x - 1, y - 1}, {x + 1, y - 1}};
            for (const auto& q : s) {
                const int d = id(q[0], q[1]);
                if (d && d != c) lacz(c, d);
            }
        }
    return G;
}

// ---------------------------------------------------------------------------------------------------------------
// Etap 42: regiony 0x4240D3 i przydział podsektorów 0x42434F – docs/titan/architektura_nawigacji.md „Etap 42”.

namespace {
struct KlasaRegionu {
    int obszar = 0, rodzaj_obszaru = 0, tryb = 0;
    bool flaga = true;          // +0x1C maszyny: przekątna tylko przy dostępnym boku
    std::uint32_t uid = 0;      // +0x6C
    int gracz = 0;              // +0x70
};
}  // namespace

void zbuduj_obszary(WejscieRegionow& w) {
    const int N = w.N;
    auto brzeg = [&](int x, int y) {
        return x + y == w.brzeg_e0 || x + y == w.brzeg_e1 || y - x == w.brzeg_e2 || x - y == w.brzeg_e2;
    };
    auto klasa = [&](int x, int y) {
        if (brzeg(x, y)) return 4;
        const int k = w.rodzaj_pola[std::size_t(x) * N + y];
        return k == 1 ? 2 : k == 9 ? 3 : 1;
    };
    w.obszar.assign(std::size_t(N) * N, 0);
    w.obszary.assign(1, {0, 0});
    std::vector<std::pair<int, int>> stos;
    int n = 0;
    for (int x = N - 1; x >= 0; --x)
        for (int y = N - 1; y >= 0; --y) {
            const std::size_t s = std::size_t(x) * N + y;
            if (w.rodzaj_pola[s] == -1 || w.obszar[s]) continue;
            const int kl = klasa(x, y);
            w.obszary.push_back({kl, ++n});
            w.obszar[s] = n;
            stos.assign(1, {x, y});
            while (!stos.empty()) {
                const auto [a, b] = stos.back();
                stos.pop_back();
                for (int dx = -1; dx <= 1; ++dx)
                    for (int dy = -1; dy <= 1; ++dy) {
                        // etap 44 [P: e13_para 22 725/22 725 pól i 42/42 obszary; e35_a i czysta mapa bez zmian]: klasa 3
                        // (klify) łączy się także po przekątnej, jak brzeg rombu
                        if ((!dx && !dy) || (dx && dy && kl != 4 && kl != 3)) continue;
                        const int c = a + dx, d = b + dy;
                        if (c < 0 || d < 0 || c >= N || d >= N) continue;
                        const std::size_t j = std::size_t(c) * N + d;
                        if (w.rodzaj_pola[j] == -1 || w.obszar[j] || klasa(c, d) != kl) continue;
                        w.obszar[j] = n;
                        stos.push_back({c, d});
                    }
            }
        }
}

int Swiat::losuj_zakres(int lo, int hi) {
    // 0x5531C2 [W]: f = generator RTSPhysics ([0x919774]+0x18, import 0xB2FBC8); v = f·(hi + 1 − lo) + lo zapisane do
    // f32, zaokrąglenie fistp (do najbliższej, remis do parzystej); v = hi + 1 → hi
    const double f = rng_.losuj();
    const double v = f32((long double)f * (long double)(hi + 1 - lo) + (long double)lo);
    int r = int(std::nearbyint(v));
    if (r == hi + 1) r = hi;
    return r;
}

void Swiat::ucieczka(Jednostka& u) {
    // 0x620687 [W; P: 638 – obywatel (164,5; 108,5) → EEUGLocation (168,5; 104,5), pochodzenie 1, kat 0, stan 8000]:
    //  1) atakujący 0x62FE01 (brak → Idle); 2) odległość: gracz ≠ 0 → fistp(f32(pole widzenia·1,5)), gracz 0 →
    //  losowanie 1..2; 3) oktant od jednostki do atakującego 0x62F451 (pola +0x1C/+0x20, UMArcTan2(ux − ax, ay − uy):
    //  |θ| ≤ π/8 → 4, θ > π/8 → trunc((θ − π/8)·4/π), θ < −π/8 → trunc(5 − (θ + π/8)·4/π), 8 → 3);
    //  4) 0x632FFC(oktant, 1): n = losuj(0, 3) + 3, b = losuj(0, 1) ≠ 0, obrót 0x637AB9 o n kroków w kierunku b;
    //  5) do 8 prób: pole = pole jednostki + krok kierunku 0x632E7C × odległość, przejezdne (0x62C7C8) – inaczej
    //  kierunek + 1 (mod 8); 6) cel EEUGLocation w punkcie (pole + część ułamkowa pozycji), stan 8000.
    auto idle = [&]() { if (const StanSkryptu* s = skr(u).stan(5000)) wejdz_w_stan(u, *s); };
    Jednostka* a = (u.boj && u.boj->ostatni_atakujacy) ? jednostka(u.boj->ostatni_atakujacy) : nullptr;
    if (!a) { idle(); return; }
    int d;
    if (u.gracz != 0) d = int(std::nearbyint(f32(f32(u.boj->p.pole_widzenia) * 1.5f)));
    else d = losuj_zakres(1, 2);
    const std::int64_t ux = u.komorka_x, uy = u.komorka_y, ax = a->komorka_x, ay = a->komorka_y;
    const long double th = mat_.um_arctan2(double(ux - ax), double(ay - uy));
    const long double c = (long double)0.39269909262657166f, k = (long double)1.2732394933700562f;
    int okt = 4;
    if (th > c) okt = int((th - c) * k);
    else if (th < -c) { okt = int(5.0L - (th + c) * k); if (okt >= 8) okt = 3; }
    const int n = losuj_zakres(0, 3) + 3;
    const bool b = losuj_zakres(0, 1) != 0;
    static const int OBR[8][2] = {{1, 4}, {2, 0}, {3, 1}, {7, 2}, {0, 5}, {4, 6}, {5, 7}, {6, 3}};   // [oktant][b]
    for (int i = 0; i < n % 8; ++i) okt = OBR[okt][b ? 1 : 0];
    static const int KROK[8][2] = {{-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {0, 1}, {1, 1}, {1, 0}, {1, -1}};
    const double fx = f32(f32(u.x) - double(ux)), fy = f32(f32(u.y) - double(uy));
    for (int proba = 0; proba < 8; ++proba) {
        const std::int64_t tx = ux + KROK[okt][0] * d, ty = uy + KROK[okt][1] * d;
        const double px = f32(double(tx) + fx), py = f32(double(ty) + fy);
        okt = (okt + 1) % 8;
        if (!teren_.pole_przejezdne(podloga(px), podloga(py))) continue;
        CelRuchu cel{TypCelu::miejsce, px, py, std::nullopt, true, false, 0};
        u.kolejka_celow.clear();
        u.kolejka_celow.push_front(cel);
        u.cel = TypCelu::miejsce;
        u.cel_od_gracza = true;    // pochodzenie +0x1C = 1 [P: 638]
        u.kurs_koncowy.reset();
        u.trasa.clear();
        u.dl_przed.clear();
        u.dl_po.clear();
        u.zdjete_punkty = 0;
        u.trasa_gotowa = false;
        if (const StanSkryptu* s = skr(u).stan(8000)) wejdz_w_stan(u, *s);
        return;
    }
    idle();
}

bool Swiat::ustaw_skrypt_jednostki(IdJednostki id, const std::string& nazwa) {
    Jednostka* u = jednostka(id);
    if (!u) return false;
    if (nazwa.empty() || nazwa == "land") { u->skrypt = nullptr; return true; }
    auto it = skrypty_.find(nazwa);
    if (it == skrypty_.end()) {
        if (nazwa == "obywatel" || nazwa == "Citizen")   // dbobjects „TAI Script” = Citizen (typ 32 [P])
            it = skrypty_.emplace(nazwa, SkryptStanow::wbudowany_obywatel()).first;
        else return false;
    }
    u->skrypt = &it->second;
    return true;
}

int komorka_sektora(int r) {
    if (r <= 42) return 7;
    if (r <= 58) return 10;
    if (r <= 75) return 12;
    if (r <= 105) return 15;
    if (r <= 160) return 19;
    if (r <= 220) return 21;
    return 15;
}

void dodaj_obiekty_scn(WejscieRegionow& w, const std::vector<ObiektScnPola>& obiekty) {
    const int N = w.N;
    for (const auto& o : obiekty) {
        const int n = std::max(1, o.kwadrat);
        for (int x = o.X; x < o.X + n; ++x)
            for (int y = o.Y; y < o.Y + n; ++y) {
                if (x < 0 || y < 0 || x >= N || y >= N) continue;
                const int i = x * N + y;
                if (w.rodzaj_pola[std::size_t(i)] == -1) continue;
                ObiektPolaRegionu p;
                p.id = o.id; p.hp = o.hp; p.gracz = o.gracz; p.klasa568 = o.klasa568; p.flaga600 = o.flaga600;
                p.klasa4b4 = o.klasa4b4; p.flaga612 = o.flaga612; p.vt58 = o.vt58;
                auto& l = w.obiekty[i];
                l.insert(l.begin(), p);   // wstawienie na początek listy pola
            }
    }
}

bool zestaw_zawiera(const std::map<int, ZestawJednostek>& zestawy, int nr, int typ) {
    for (int glebokosc = 0; glebokosc < 64; ++glebokosc) {
        const auto it = zestawy.find(nr);
        if (it == zestawy.end()) return false;
        const auto& z = it->second;
        const bool pusty = std::none_of(z.obiekty.begin(), z.obiekty.end(), [](int v) { return v >= 0; }) &&
                           std::none_of(z.rodziny.begin(), z.rodziny.end(), [](int v) { return v > 0; });
        const bool jest = pusty || std::find(z.obiekty.begin(), z.obiekty.end(), typ) != z.obiekty.end();
        if (jest) return !(z.wyklucz >= 0 && zestaw_zawiera(zestawy, z.wyklucz, typ));
        if (z.dolacz < 0) return false;
        nr = z.dolacz;
    }
    return false;
}

SiatkaRegionow zbuduj_siatke_regionow(const WejscieRegionow& w) {
    const int N = w.N;
    SiatkaRegionow R;
    R.N = N;
    R.etykieta.assign(std::size_t(N) * N, 0);
    R.rodzaj.assign(1, 0);
    static const std::vector<ObiektPolaRegionu> pusta;
    auto ob = [&](int i) -> const std::vector<ObiektPolaRegionu>& {
        auto it = w.obiekty.find(i);
        return it == w.obiekty.end() ? pusta : it->second;
    };
    auto klasa3 = [&](int i) {            // 0x42CA21: pole ≠ 1 i obiekt typu z +0x568 = 3
        if (w.rodzaj_pola[i] == 1) return false;
        for (const auto& o : ob(i)) if (o.klasa568 == 3) return true;
        return false;
    };
    auto blokujaca = [](const ObiektPolaRegionu& o) {
        return (o.flaga600 || o.klasa4b4 == 0x19) && !o.vt58 && (o.hp > 0 || o.klasa4b4 == 1);
    };
    auto bez_blokujacych = [&](int i) {
        for (const auto& o : ob(i)) if (blokujaca(o)) return false;
        return true;
    };
    auto brzeg = [&](int x, int y) {
        return x + y == w.brzeg_e0 || y - x == w.brzeg_e2 || x + y == w.brzeg_e1 || x - y == w.brzeg_e2;
    };
    auto start = [&](int i) {             // 0x41BF51
        KlasaRegionu k;
        k.obszar = w.obszar[i];
        k.rodzaj_obszaru = w.obszary[std::size_t(k.obszar)].first;
        const int rp = w.rodzaj_pola[i], h = w.wysokosc[i];
        if (k.rodzaj_obszaru == 1) {
            k.tryb = rp == 0xA ? (h < 0 ? 8 : h > 0 ? 9 : 7) : 1;
            if (klasa3(i)) { k.tryb = 4; k.flaga = false; }
            else for (const auto& o : ob(i))
                if (blokujaca(o)) {
                    k.uid = o.id; k.gracz = o.gracz; k.tryb = 0xC; k.flaga = false;
                    if (o.klasa4b4 == 0x19) k.tryb = 0xE;
                    else if (o.flaga612) k.tryb = 0xD;
                    break;
                }
        } else if (k.rodzaj_obszaru == 2) k.tryb = h < 0 ? 0xA : h > 0 ? 0xB : 2;
        else if (k.rodzaj_obszaru == 4) { k.tryb = 6; k.flaga = false; }
        else if (k.rodzaj_obszaru == 3) { k.tryb = 3; k.flaga = false; }
        return k;
    };
    auto dostepne = [&](const KlasaRegionu& k, int x, int y) {   // 0x41B9C9 (kolejne pola, tabela 0x41C235)
        if (x < 0 || y < 0 || x >= N || y >= N) return false;
        const int i = x * N + y;
        if (w.rodzaj_pola[i] == -1 || w.obszar[i] != k.obszar) return false;
        const int rp = w.rodzaj_pola[i], h = w.wysokosc[i];
        bool ok = false;
        switch (k.tryb) {
            case 1: ok = rp != 0xA && !klasa3(i) && bez_blokujacych(i); break;
            case 2: ok = rp == 1 && h == 0; break;
            case 3: ok = rp == 9; break;
            case 4: ok = klasa3(i); break;
            case 6: ok = true; break;
            case 7: case 8: case 9:
                ok = rp == 0xA && (k.tryb == 7 ? h == 0 : k.tryb == 8 ? h < 0 : h > 0) && !klasa3(i) && bez_blokujacych(i);
                break;
            case 0xA: ok = rp == 1 && h < 0; break;
            case 0xB: ok = rp == 1 && h > 0; break;
            case 0xC: case 0xE: {
                if (klasa3(i)) break;
                std::int64_t uid = -1;
                for (const auto& o : ob(i)) {
                    if (!(o.hp > 0 || o.klasa4b4 == 1)) continue;
                    if (k.tryb == 0xE && o.klasa4b4 == 0x19 && o.gracz == k.gracz) { uid = o.id; break; }
                    if ((o.flaga600 && !o.vt58) || o.klasa4b4 == 0x19) { uid = o.id; break; }
                }
                ok = uid == std::int64_t(k.uid);
                break;
            }
            case 0xD:
                if (klasa3(i)) break;
                for (const auto& o : ob(i)) {
                    if (o.flaga612 && o.hp > 0 && o.klasa4b4 != 0x19 && o.gracz == k.gracz && !o.vt58) { ok = true; break; }
                    if (blokujaca(o)) break;
                }
                break;
            default: break;
        }
        return ok && (brzeg(x, y) == (k.rodzaj_obszaru == 4));
    };
    int nr = 0;
    std::deque<std::pair<int, int>> q;
    for (int x = N - 1; x >= 0; --x)
        for (int y = N - 1; y >= 0; --y) {
            const int i = x * N + y;
            if (w.rodzaj_pola[i] == -1 || !w.obszar[i] || R.etykieta[i]) continue;
            const KlasaRegionu k = start(i);
            R.rodzaj.push_back(k.tryb);
            R.etykieta[i] = ++nr;
            q.assign(1, {x, y});
            while (!q.empty()) {
                const auto [a, b] = q.front();
                q.pop_front();
                auto dodaj = [&](int c, int d) {
                    const int j = c * N + d;
                    if (!R.etykieta[j]) { R.etykieta[j] = nr; q.push_back({c, d}); }
                };
                const bool g = dostepne(k, a, b - 1), l = dostepne(k, a - 1, b), p = dostepne(k, a + 1, b),
                           d = dostepne(k, a, b + 1);
                if (g) dodaj(a, b - 1);
                if (l) dodaj(a - 1, b);
                if (p) dodaj(a + 1, b);
                if (d) dodaj(a, b + 1);
                const int przek[4][4] = {{-1, -1, l, g}, {1, -1, g, p}, {1, 1, p, d}, {-1, 1, d, l}};
                for (const auto& e : przek)
                    if ((!k.flaga || e[2] || e[3]) && dostepne(k, a + e[0], b + e[1])) dodaj(a + e[0], b + e[1]);
            }
        }
    return R;
}

std::vector<int> zbuduj_przydzial_podsektorow(const SiatkaRegionow& r, int K) {
    const int N = r.N;
    std::vector<int> g(std::size_t(N) * N, 0);
    int nid = 0;
    std::vector<std::pair<int, int>> stos;
    for (int x = N - 1; x >= 0; --x)          // 0x424565
        for (int y = N - 1; y >= 0; --y) {
            const int i = x * N + y;
            const int reg = r.etykieta[i];
            if (!reg || g[i]) continue;
            const int si = x / K, sj = y / K;
            const int x0 = si * K, x1 = std::min(si * K + K - 1, N - 1), y0 = sj * K, y1 = std::min(sj * K + K - 1, N - 1);
            const int rk = reg < int(r.rodzaj.size()) ? r.rodzaj[std::size_t(reg)] : 0;
            const bool flaga = !(rk == 3 || rk == 5 || rk == 6 || rk == 12 || rk == 13 || rk == 14);   // 0x41EAE7
            auto ok = [&](int a, int b) { return a >= x0 && a <= x1 && b >= y0 && b <= y1 && r.etykieta[std::size_t(a) * N + b] == reg; };
            ++nid;
            g[i] = nid;
            stos.assign(1, {x, y});
            while (!stos.empty()) {     // zbiór pól składowej nie zależy od kolejności (dostępność bez historii)
                const auto [a, b] = stos.back();
                stos.pop_back();
                for (int dx = -1; dx <= 1; ++dx)
                    for (int dy = -1; dy <= 1; ++dy) {
                        if (!dx && !dy) continue;
                        const int c = a + dx, d = b + dy;
                        if (!ok(c, d) || g[std::size_t(c) * N + d]) continue;
                        if (dx && dy && flaga && !(ok(a + dx, b) || ok(a, b + dy))) continue;
                        g[std::size_t(c) * N + d] = nid;
                        stos.push_back({c, d});
                    }
            }
        }
    return g;
}

GrafPodsektorow zbuduj_graf_z_wejscia(const WejscieRegionow& w, int komorka) {
    const SiatkaRegionow R = zbuduj_siatke_regionow(w);
    const std::vector<int> g = zbuduj_przydzial_podsektorow(R, komorka);
    GrafPodsektorow G = zbuduj_graf_z_przydzialu(g, w.N, w.N, komorka);
    for (int x = 0; x < w.N; ++x)
        for (int y = 0; y < w.N; ++y) {
            const std::size_t i = std::size_t(x) * w.N + y;
            if (g[i]) G.podsektory[g[i]].rodzaj = R.rodzaj[std::size_t(R.etykieta[i])];
        }
    G.zrodlo = "Core z wejścia mapy";
    return G;
}

std::vector<int> szukaj_w_grafie(const GrafPodsektorow& g, int start, int cel) {
    auto pc = g.podsektory.find(cel), ps = g.podsektory.find(start);
    if (pc == g.podsektory.end() || ps == g.podsektory.end()) return {};
    const Podsektor& C = pc->second;
    struct W { int id; int G; int F; int rodzic; std::uint64_t kolejnosc; bool zamkniety; };
    std::map<int, W> w;
    std::uint64_t licznik = 0;
    auto H = [&](const Podsektor& p) { return 10 * (std::abs(p.sektor_i - C.sektor_i) + std::abs(p.sektor_j - C.sektor_j)); };
    auto koszt = [](const Podsektor& a, const Podsektor& b) {  // 0x41E584
        if (a.sektor_i == b.sektor_i && a.sektor_j == b.sektor_j) return 1;
        if (a.sektor_i == b.sektor_i || a.sektor_j == b.sektor_j) return 10;
        return 14;
    };
    w[start] = {start, 0, H(ps->second), -1, licznik++, false};
    for (int it = 0; it < 100000; ++it) {
        // zdjęcie najlepszego: najmniejsze F, przy remisie ostatnio wstawiony (LIFO) [H]
        int best = -1;
        for (const auto& [id, x] : w) {
            if (x.zamkniety) continue;
            if (best < 0 || x.F < w[best].F || (x.F == w[best].F && x.kolejnosc > w[best].kolejnosc)) best = id;
        }
        if (best < 0) return {};
        W& b = w[best];
        b.zamkniety = true;
        const Podsektor& B = g.podsektory.at(best);
        // test celu 0x41E3C0
        bool koniec = best == cel;
        if (!koniec && std::abs(B.sektor_i - C.sektor_i) <= 1 && std::abs(B.sektor_j - C.sektor_j) <= 1)
            koniec = std::find(B.sasiedzi.begin(), B.sasiedzi.end(), cel) != B.sasiedzi.end();
        if (koniec) {
            std::vector<int> wynik;
            if (best != cel) wynik.push_back(cel);
            for (int x = best; x >= 0; x = w[x].rodzic) wynik.push_back(x);
            return wynik;   // od celu do startu
        }
        for (auto s = B.sasiedzi.rbegin(); s != B.sasiedzi.rend(); ++s) {   // od końca (0x4A5859)
            auto pn = g.podsektory.find(*s);
            if (pn == g.podsektory.end()) continue;   // filtr rodzaju 0x41E5B6 – wszystkie rodzaje dozwolone [H]
            const int Gn = b.G + koszt(B, pn->second);
            auto e = w.find(*s);
            if (e != w.end()) {
                if (e->second.G <= Gn) continue;
                e->second.G = Gn; e->second.F = Gn + H(pn->second); e->second.rodzic = best; e->second.zamkniety = false;
                e->second.kolejnosc = licznik++;
            } else {
                w[*s] = {*s, Gn, Gn + H(pn->second), best, licznik++, false};
            }
        }
    }
    return {};
}

void Swiat::etap_grafu(Jednostka& u) {
    // Prośba jednostki 0x4A1AFF: etap grafu, gdy bajt +0x1C = 1 – PrepareToMove 0x622431: cel bez +0x32 i z
    // +0x1D = 0 (cel położenia oraz każdy inny cel). Wynik 0x4A26E3: +0x1D := 1; dla ścieżki n > 2 podsektorów
    // punkty reprezentatywne podsektorów 0 … n − 3 (od celu) jako EEUGLocation (+0x32, kurs 0, pochodzenie z celu)
    // na czoło kolejki (0x5F05BD) [W: kod; P: 624 – (163,5; 103,5) = punkt podsektora 472 z polem celu].
    if (graf_.podsektory.empty() || u.kolejka_celow.empty()) return;
    CelRuchu& c = u.kolejka_celow.front();
    if (c.punkt_automatyczny || c.etap_grafu) return;
    c.etap_grafu = true;
    const int ps = graf_.podsektor_pola(u.komorka_x, u.komorka_y);
    const int pc = graf_.podsektor_pola(podloga(c.x), podloga(c.y));
    ++diag_.graf_prosby;
    if (ps < 0 || pc < 0 || ps == pc) return;
    const std::vector<int> sciezka = szukaj_w_grafie(graf_, ps, pc);
    diag_.graf_ostatnia = sciezka;
    if (sciezka.size() <= 2) return;
    const bool od_gracza = c.od_gracza;
    for (std::size_t i = 0; i + 2 < sciezka.size(); ++i) {
        const Podsektor& p = graf_.podsektory.at(sciezka[i]);
        CelRuchu l{TypCelu::miejsce, f32(p.punkt_x + 0.5), f32(p.punkt_y + 0.5), 0.0, od_gracza, true, 0};
        u.kolejka_celow.push_front(l);
        ++diag_.graf_punkty;
    }
    const CelRuchu& f = u.kolejka_celow.front();
    u.cel = f.typ;
    u.cel_od_gracza = f.od_gracza;
    u.kurs_koncowy = f.kurs_koncowy;
    u.trasa.clear();
    u.dl_przed.clear();
    u.dl_po.clear();
    u.zdjete_punkty = 0;
    u.trasa_gotowa = false;
}

}  // namespace openee
