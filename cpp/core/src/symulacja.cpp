#include "openee/symulacja.hpp"

#include <algorithm>
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
        {"graf podsektorów", StatusPodsystemu::niewdrozony, ""},
        {"objazd 9002", StatusPodsystemu::czesciowy, "A* ±50 – NIEZWERYFIKOWANY dynamicznie"},
        {"kolizje w takcie (kontakty, 0x549179, 0x549A08, reguła (a))", StatusPodsystemu::czesciowy,
         "wzór [P]; okno kontaktów 0x5E8F0E [W, etap 30]; kolejność EE/AoC [W]"},
        {"walka: wzór obrażeń, HP, przeładowanie, cykl ataku pojedynku", StatusPodsystemu::czesciowy,
         "pojedynek EE 564 co takt = gra; .tai walki w Swiat, obrót, pościg, obszar – nie"},
        {"grupy i szyk", StatusPodsystemu::niewdrozony, ""},
    };
    return l;
}

Swiat::Swiat(std::shared_ptr<const TabliceTrig> tablice, TerenSiatka teren, WariantTitan wariant)
    : mat_(std::move(tablice)), teren_(std::move(teren)), wariant_(wariant), skrypt_(SkryptStanow::wbudowany_land()) {
    dt_ = f32(1.5 / 44.0);  // EEPhysics+0x8C: G/n s czasu gry na takt
    tps_ = 1.0 / dt_;
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
    const StanSkryptu* s = skrypt_.stan(start == StartTrasy::advance ? 10003 : 8000);
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
    if (n == "ShouldMoveToNextAutoWaypoint") return false;  // punkty +0x32 – brak w kolejce Core
    if (n == "UnitHasGoal") return u.cel != TypCelu::brak;
    if (n == "GoalIsLocation") return miejsce;
    if (n == "GoalIsNotAttack") return true;
    if (n == "GoalIsNotPlayerInitiated") return !u.cel_od_gracza;
    if (n == "GoalIsUnit" || n == "GoalIsLoadContainer" || n == "GoalIsPatrol" || n == "GoalIsAttackLocation" ||
        n == "GoalIsExplore" || n == "GoalIsAttack")
        return false;  // typy celów inne niż miejsce nie istnieją w Core
    if (n == "UnitFacingNotRequired")  // [W, model v4]: jednostka musi stanąć
        return !u.kurs_koncowy && u.v == 0.0 && u.omega == 0.0;
    if (n == "CompletedUnitFacing")  // [W, model v4; S2/S4b wymagają ω = 0]. 578 G1 takt 48: gra przechodzi przy ω = 0,4165
        // i |Δkurs| = 0,0077 – sprzeczne z S4b; reguła niepełna [N] (Core: o 1 takt później)
        return u.kurs_koncowy && u.v == 0.0 && u.omega == 0.0 &&
               std::fabs(*u.kurs_koncowy - mat_.kurs_z_macierzy(u.orientacja)) < 0.0175;
    nieobslugiwane(n);  // walka, transport, mury, ICL…
    return std::nullopt;
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
            if (!u.kolejka_celow.empty()) ++u.kolejka_celow.front().proby;
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
            if (!u.trasa_gotowa && !u.kolejka_celow.empty()) przygotuj_trase(u, 0);
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
        case 5001:  // ReacquireGoal: akcja 0x61B241 – [H] brak dalszego ruchu (spoczynek)
            u.tryb = TrybRuchu::spoczynek;
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
        case 6000:  // Dying: animacja umierania; dalsze stany (6001–6003) – czasy animacji [N]
            u.tryb = TrybRuchu::spoczynek;
            u.trasa.clear();
            u.zdjete_punkty = 0;
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
    const StanSkryptu* s = skrypt_.stan(u.stan);
    if (!s) return;
    if (u.stan == 5000) {
        if (u.termin_oceny < zegar_ms_) return;
        u.termin_oceny = zegar_ms_ + 350u;
    }
    for (const auto& p : s->przejscia) {
        const bool w = ocen_przejscie(u, p);
        const std::string& cel = w ? p.cel_prawda : p.cel_falsz;
        if (cel.empty()) continue;
        auto it = skrypt_.stany().find(cel);
        if (it != skrypt_.stany().end()) wejdz_w_stan(u, it->second);
        return;
    }
}

void Swiat::takt() {
    // EEPhysics: czas gry += 1000·G/n ms; co najmniej 2 losowania globalne na takt (EE 0x546CE9, 0x547C09) [W]
    ++takty_;
    czas_ms_ += 1000.0 * 1.5 / 44.0;
    zegar_ms_ = std::uint32_t(czas_ms_);
    rng_.krok();
    rng_.krok();
    KontekstFizyki k{mat_, teren_, dt_, tps_};
    // Zwykłe jednostki NIE blokują pola w teście kroku [P – etap 29, pomiary 546/547: jednostka w ruchu weszła na
    // pole ze środkiem innej jednostki, +0x20C pozostało 0]. Blokują tylko obiekty z typem blokującym (drzewa, mury,
    // budynki – w Core jeszcze nieodwzorowane, zob. TerenSiatka::pole_przejezdne). Mechanizm +0x20C zostaje w
    // FizykaLadowa::test_kroku (callback srodek_w_polu) dla takich obiektów.
    k.srodek_w_polu = nullptr;
    for (std::size_t i = jednostki_.size(); i-- > 0;) {  // od końca listy (0x547AAD)
        Jednostka& u = jednostki_[i];
        krok_maszyny(u);
        if (u.tryb == TrybRuchu::do_celu) {  // tryb 1: pozycja celu ataku (cel +0x30 → +0x13C/+0x14C) w chwili fizyki
            if (Jednostka* t = cel_ataku(u)) {
                u.cel_walki_x = t->x;
                u.cel_walki_y = t->y;
            } else {
                u.cel_walki_x = u.x;
                u.cel_walki_y = u.y;
            }
        }
        const double x0 = u.x, y0 = u.y;
        FizykaLadowa::takt(k, u);
        if (u.boj) liczniki_walki(u);
        po_ruchu(u, x0, y0);
        krok_koncowy(u);  // 0x549E61 (po każdym trybie oprócz 2)
    }
}

IdJednostki Swiat::srodek_w_polu(std::int64_t ix, std::int64_t iy, IdJednostki pytajaca) const {
    IdJednostki w = 0;
    for (const auto& o : jednostki_)
        if (o.id != pytajaca && podloga(o.x) == ix && podloga(o.y) == iy) w = o.id;  // ostatni obiekt listy [W]
    return w;
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
    u->kolejka_celow.clear();
    u->kolejka_celow.push_front(c);
    aktywuj_cel(*u);
    return true;
}

void Swiat::aktywuj_cel(Jednostka& u) {
    const CelRuchu& c = u.kolejka_celow.front();
    u.cel = c.typ;
    u.cel_od_gracza = c.od_gracza;
    u.kurs_koncowy = c.kurs_koncowy;
    u.trasa.clear();
    u.dl_przed.clear();
    u.dl_po.clear();
    u.zdjete_punkty = 0;
    u.trasa_gotowa = false;
    const StanSkryptu* s = skrypt_.stan(8000);
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
    // 0x5EE4E6: pomiń pole startu, gdy jednostka na nim stoi; punkty (x + 0,5; y + 0,5); ostatni = dokładny cel [W]
    std::vector<Punkt2> pts;
    for (std::size_t i = 0; i < pola.size(); ++i) {
        if (i == 0 && pola[i] == start) continue;
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
        if (u.pozostalo_punktow() == 1) {  // reguła (a) „cel zajęty” [P: EE 528]; zaliczenie punktu [H]
            const Punkt2& W = u.trasa[u.zdjete_punkty];
            if (std::hypot(W.x - o->x, W.y - o->y) <= o->param.promien_kolizji * 0.5) {
                u.v = 0.0;
                u.flaga_330 = 8;
                u.osiagnieto_punkt = true;
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
    zalozenie("rozkaz ataku gracza: wejście w CheckRange [H]");
    auto it = skrypt_.stany().find("CheckRange");
    if (it != skrypt_.stany().end()) wejdz_w_stan(*u, it->second);
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

Punkt2 Swiat::punkt_podejscia(const Jednostka& u, const Jednostka& t) {
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
            zalozenie("miejsce podejścia 0x63234D: porządek przy równych odległościach i test obiektów blokujących [W]");
            for (const auto& p : k)
                if (teren_.pole_przejezdne(podloga(p.x), podloga(p.y))) return p;
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
    if (n == "EnemyUnitReachable") {   // 0x60B1EA: osiągalność 0x62D696 [N] i licznik prób celu < 25
        zalozenie("EnemyUnitReachable: osiągalność 0x62D696 = prawda [N]");
        return t && t->boj && t->boj->s.hp > 0 && g->proby < 25;
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
    return std::nullopt;
}

void Swiat::liczniki_walki(Jednostka& u) {
    // liczniki +0x2A0 i +0x2AC: −34 ms na takt, także po śmierci [P: 561/564]; trafienie w cyklu ataku
    BojJednostki& b = *u.boj;
    const int ms = 34;
    b.s.przeladowanie_ms = std::max(0, b.s.przeladowanie_ms - ms);
    b.szukanie_ms = std::max(0, b.szukanie_ms - ms);
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
    zdarzenia_walki_.push_back({takty_, u.id, t->id, "trafienie", o.obrazenia});
    t->boj->szukanie_ms = 0;   // TakeDamage 0x6172BC zeruje +0x2AC [W]
    if (przyjmij_obrazenia(t->boj->s, o.obrazenia)) {
        ++b.s.zabicia;
        ++diag_.zgony;
        zdarzenia_walki_.push_back({takty_, t->id, u.id, "smierc", 0});
        auto it = skrypt_.stany().find("Dying");
        if (it != skrypt_.stany().end()) wejdz_w_stan(*t, it->second);
        else t->stan = 6000;
    }
}

}  // namespace openee
