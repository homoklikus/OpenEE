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
        {"teren: GetMeshZ, nachylenie, reguła stoku", StatusPodsystemu::wdrozony, "siatka własna; import mapy – nie"},
        {"fizyka EEPMLand tryby 0/3/4/5, EE i AoC", StatusPodsystemu::wdrozony, ""},
        {"test pojedynczego kroku", StatusPodsystemu::wdrozony, "kolejność z kodu [W]; bez pomiaru izolowanego"},
        {"maszyna stanów (.tai, podzbiór ruchu)", StatusPodsystemu::czesciowy,
         "zdarzenia walki/transportu = fałsz + licznik"},
        {"kolejka celów, Shift (poziom 0)", StatusPodsystemu::czesciowy, "punkty +0x32 i porzucenie – nie"},
        {"A* po polach + Bounded", StatusPodsystemu::wdrozony, "18 przypadków bitowo z modelem e24; synchronicznie"},
        {"graf podsektorów", StatusPodsystemu::niewdrozony, ""},
        {"objazd 9002", StatusPodsystemu::czesciowy, "A* ±50 – NIEZWERYFIKOWANY dynamicznie"},
        {"kolizje w takcie (kontakty, 0x549179, 0x549A08, reguła (a))", StatusPodsystemu::czesciowy,
         "wzór [P]; lista kontaktów i kolejność EE/AoC [W]"},
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
            // 0x5EAE25(0): zdjęcie celu bieżącego i aktywacja następnego (EEUGLocation vt+0x54 → stan 8000)
            if (!u.kolejka_celow.empty()) u.kolejka_celow.pop_front();
            if (!u.kolejka_celow.empty()) aktywuj_cel(u);
            break;
        case 8000:  // PrepareToMove: cel+0x18++, prośba o trasę (A* w Core – synchronicznie, w grze w kolejnych taktach)
            if (!u.kolejka_celow.empty()) ++u.kolejka_celow.front().proby;
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
        const double x0 = u.x, y0 = u.y;
        FizykaLadowa::takt(k, u);
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
    const double R = std::max(u.param.rozmiar, 0.5);
    const std::int64_t xa = podloga(cx - R), xb = podloga(cx + R), ya = podloga(cy - R), yb = podloga(cy + R);
    for (auto& o : jednostki_) {
        if (o.id == u.id) continue;
        // obiekt jest na listach wszystkich pól, na które zachodzi jego obrys (promień kolizji) [H – etap 29:
        // wyjaśnia 2 kontakty 18d w pomiarze 546 i brak nakładania się jednostek; sam środek pola dawał 1]
        const double ro = o.param.promien_kolizji;
        if (podloga(o.x + ro) < xa || podloga(o.x - ro) > xb || podloga(o.y + ro) < ya || podloga(o.y - ro) > yb) continue;
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

}  // namespace openee
