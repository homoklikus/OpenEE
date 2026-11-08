#include "openee/symulacja.hpp"

#include <cmath>

namespace openee {

const std::vector<OpisPodsystemu>& podsystemy() {
    static const std::vector<OpisPodsystemu> l = {
        {"matematyka Titan (UMCos/UMSin/UMArcCos/UMArcTan2, SetOrientationYPR)", StatusPodsystemu::wdrozony, ""},
        {"tablice z Low-Level Engine.dll (PE jako dane)", StatusPodsystemu::wdrozony, "2 warianty GOG+NeoEE"},
        {"generator LCG", StatusPodsystemu::wdrozony, "miejsca losowań: 2/takt + ObstacleDetected; Idle [N]"},
        {"teren: GetMeshZ, nachylenie, reguła stoku", StatusPodsystemu::wdrozony, "siatka własna; import mapy – nie"},
        {"fizyka EEPMLand tryby 0/3/4/5, EE i AoC", StatusPodsystemu::wdrozony, ""},
        {"test pojedynczego kroku", StatusPodsystemu::niewdrozony, "brak pól nieprzejezdnych w Core"},
        {"maszyna stanów (.tai, podzbiór ruchu)", StatusPodsystemu::czesciowy,
         "zdarzenia walki/transportu = fałsz + licznik"},
        {"kolejka celów, Shift", StatusPodsystemu::niewdrozony, "jeden cel bieżący"},
        {"A*, podsektory, objazd 9002", StatusPodsystemu::niewdrozony, "trasa podawana z zewnątrz"},
        {"odpychanie 0x549179 (wzór)", StatusPodsystemu::czesciowy, "wzór i 5 przypadków; lista kontaktów – nie"},
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
    jednostki_.push_back(u);
    return u.id;
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
    if (n == "CompletedUnitFacing")
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
            break;
        case 8000:  // PrepareToMove: trasa gotowa (podana z zewnątrz; prośba do EEPathManager niewdrożona)
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
        case 9002:  // RepathAroundObstacle – objazd niewdrożony: trasa nie jest przygotowana
            u.trasa_gotowa = false;
            ++diag_.wejscia_niewdrozone;
            diag_.ostatnie_niewdrozone = s.nazwa;
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
    const KontekstFizyki k{mat_, teren_, dt_, tps_};
    for (std::size_t i = jednostki_.size(); i-- > 0;) {  // od końca listy (0x547AAD)
        Jednostka& u = jednostki_[i];
        krok_maszyny(u);
        FizykaLadowa::takt(k, u);
        // krok końcowy kolizji (0x549E61): bez listy kontaktów i pchania licznik blokady = 0
        if (u.kontakty == 0 && u.push_x == 0 && u.push_y == 0) u.licznik_blokady_ms = 0;
    }
}

std::vector<MigawkaJednostki> Swiat::migawka() const {
    std::vector<MigawkaJednostki> w;
    w.reserve(jednostki_.size());
    for (const auto& u : jednostki_)
        w.push_back({u.id, u.x, u.y, u.z, u.v, u.omega, mat_.kurs_z_macierzy(u.orientacja), u.orientacja, u.stan,
                     u.tryb, u.zdjete_punkty, u.pozostalo_punktow(), u.licznik_blokady_ms});
    return w;
}

}  // namespace openee
