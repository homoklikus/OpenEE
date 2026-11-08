#include "openee_symulacja.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
constexpr int POLA = 12;  // id, x, y, z, v, omega, kurs, stan, tryb, zdjete, pozostalo, licznik_blokady_ms
std::string tekst(const String& s) { return std::string(s.utf8().get_data()); }
String gtekst(const std::string& s) { return String::utf8(s.c_str()); }
double liczba(const Dictionary& d, const char* k, double dom) {
    return d.has(k) ? double(d[k]) : dom;
}
}  // namespace

void OpenEESymulacja::_bind_methods() {
    ClassDB::bind_method(D_METHOD("wersja"), &OpenEESymulacja::wersja);
    ClassDB::bind_method(D_METHOD("zaladuj_tablice", "sciezka_dll"), &OpenEESymulacja::zaladuj_tablice);
    ClassDB::bind_method(D_METHOD("uzyj_tablic_przyblizonych"), &OpenEESymulacja::uzyj_tablic_przyblizonych);
    ClassDB::bind_method(D_METHOD("utworz_swiat", "wariant"), &OpenEESymulacja::utworz_swiat);
    ClassDB::bind_method(D_METHOD("dodaj_jednostke", "parametry", "x", "y", "kurs"), &OpenEESymulacja::dodaj_jednostke);
    ClassDB::bind_method(D_METHOD("nadaj_trase", "id", "punkty_xy", "kurs_koncowy", "start"),
                         &OpenEESymulacja::nadaj_trase);
    ClassDB::bind_method(D_METHOD("rozkaz_ruchu", "id", "x", "y", "kurs_koncowy", "shift"), &OpenEESymulacja::rozkaz_ruchu);
    ClassDB::bind_method(D_METHOD("ustaw_przejezdnosc", "ix", "iy", "przejezdne"), &OpenEESymulacja::ustaw_przejezdnosc);
    ClassDB::bind_method(D_METHOD("takt", "ile"), &OpenEESymulacja::takt);
    ClassDB::bind_method(D_METHOD("migawka"), &OpenEESymulacja::migawka);
    ClassDB::bind_method(D_METHOD("pola_migawki"), &OpenEESymulacja::pola_migawki);
    ClassDB::bind_method(D_METHOD("jednostka", "id"), &OpenEESymulacja::jednostka);
    ClassDB::bind_method(D_METHOD("diagnostyka"), &OpenEESymulacja::diagnostyka);
}

String OpenEESymulacja::wersja() const { return "OpenEE Core 0.7.0 (etap 29, C++20, godot-cpp 10.0.0, API 4.7)"; }

Dictionary OpenEESymulacja::zaladuj_tablice(const String& sciezka_dll) {
    Dictionary w;
    const auto r = openee::zaladuj_tablice_dll(tekst(sciezka_dll));
    w["ok"] = r.ok();
    w["komunikat"] = gtekst(r.komunikat);
    w["wariant"] = gtekst(r.wariant);
    w["sha256"] = gtekst(r.sha256);
    if (r.ok()) {
        tablice_ = r.tablice;
        swiat_.reset();  // świat z innymi tablicami trzeba utworzyć od nowa
    } else {
        ostatni_blad_ = gtekst(r.komunikat);
    }
    return w;
}

void OpenEESymulacja::uzyj_tablic_przyblizonych() {
    tablice_ = openee::tablice_przyblizone();
    swiat_.reset();
    UtilityFunctions::push_warning("OpenEE: tablice PRZYBLIŻONE – wyniki niezgodne z Titan (tylko diagnostyka).");
}

bool OpenEESymulacja::utworz_swiat(const String& wariant) {
    if (!tablice_) {
        ostatni_blad_ = "Najpierw wczytaj tablice (zaladuj_tablice) albo włącz tryb przybliżony.";
        UtilityFunctions::push_error("OpenEE: ", ostatni_blad_);
        return false;
    }
    try {
        swiat_ = std::make_unique<openee::Swiat>(tablice_, openee::TerenSiatka::syntetyczny_etap27(),
                                                 openee::WariantTitan::z_nazwy(tekst(wariant)));
    } catch (const std::exception& e) {
        ostatni_blad_ = gtekst(e.what());
        swiat_.reset();
        return false;
    }
    return true;
}

int64_t OpenEESymulacja::dodaj_jednostke(const Dictionary& p, double x, double y, double kurs) {
    if (!swiat_) return 0;
    openee::ParametryRuchu r;
    r.a = liczba(p, "a", r.a);
    r.vmax = liczba(p, "vmax", r.vmax);
    r.alfa = liczba(p, "alfa", r.alfa);
    r.wmax = liczba(p, "wmax", r.wmax);
    r.rozmiar = liczba(p, "rozmiar", r.rozmiar);
    r.c4 = liczba(p, "c4", r.c4);
    r.c8 = liczba(p, "c8", r.c8);
    r.t488 = liczba(p, "t488", r.t488);
    r.pochyla = p.has("pochyla") ? bool(p["pochyla"]) : false;
    return int64_t(swiat_->dodaj_jednostke(r, x, y, kurs));
}

bool OpenEESymulacja::nadaj_trase(int64_t id, const PackedFloat64Array& xy, const Variant& kurs_koncowy,
                                  const String& start) {
    if (!swiat_ || xy.size() < 2 || xy.size() % 2 != 0) return false;
    std::vector<openee::Punkt2> pts;
    for (int64_t i = 0; i + 1 < xy.size(); i += 2) pts.push_back({xy[i], xy[i + 1]});
    std::optional<double> kk;
    if (kurs_koncowy.get_type() == Variant::FLOAT || kurs_koncowy.get_type() == Variant::INT)
        kk = double(kurs_koncowy);
    const auto s = start == String("advance") ? openee::StartTrasy::advance : openee::StartTrasy::rozkaz;
    return swiat_->nadaj_trase(openee::IdJednostki(id), pts, kk, s);
}

bool OpenEESymulacja::rozkaz_ruchu(int64_t id, double x, double y, const Variant& kurs_koncowy, bool shift) {
    if (!swiat_) return false;
    std::optional<double> kk;
    if (kurs_koncowy.get_type() == Variant::FLOAT || kurs_koncowy.get_type() == Variant::INT) kk = double(kurs_koncowy);
    return swiat_->rozkaz_ruchu(openee::IdJednostki(id), x, y, kk, shift);
}

void OpenEESymulacja::ustaw_przejezdnosc(int64_t ix, int64_t iy, bool przejezdne) {
    if (swiat_) swiat_->teren_edycja().ustaw_przejezdnosc(ix, iy, przejezdne);
}

int64_t OpenEESymulacja::takt(int64_t ile) {
    if (!swiat_) return 0;
    for (int64_t i = 0; i < ile; ++i) swiat_->takt();  // jedno wywołanie na dowolną liczbę taktów
    return int64_t(swiat_->takty());
}

PackedStringArray OpenEESymulacja::pola_migawki() const {
    PackedStringArray p;
    for (const char* n : {"id", "x", "y", "z", "v", "omega", "kurs", "stan", "tryb", "zdjete_punkty",
                          "pozostalo_punktow", "licznik_blokady_ms"})
        p.push_back(n);
    return p;
}

PackedFloat64Array OpenEESymulacja::migawka() const {
    PackedFloat64Array w;
    if (!swiat_) return w;
    const auto m = swiat_->migawka();
    w.resize(int64_t(m.size()) * POLA);
    int64_t i = 0;
    for (const auto& u : m) {
        for (double v : {double(u.id), u.x, u.y, u.z, u.v, u.omega, u.kurs, double(u.stan), double(int(u.tryb)),
                         double(u.zdjete_punkty), double(u.pozostalo_punktow), u.licznik_blokady_ms})
            w.set(i++, v);
    }
    return w;
}

Dictionary OpenEESymulacja::jednostka(int64_t id) const {
    Dictionary d;
    if (!swiat_) return d;
    const openee::Jednostka* u = swiat_->jednostka(openee::IdJednostki(id));
    if (!u) return d;
    d["id"] = int64_t(u->id);
    d["x"] = u->x;
    d["y"] = u->y;
    d["z"] = u->z;
    d["v"] = u->v;
    d["omega"] = u->omega;
    d["kurs"] = swiat_->matematyka().kurs_z_macierzy(u->orientacja);
    d["stan"] = u->stan;
    d["stan_nazwa"] = String(openee::nazwa_stanu(u->stan));
    d["tryb"] = int(u->tryb);
    PackedFloat64Array m;
    for (double v : u->orientacja.m) m.push_back(v);
    d["macierz"] = m;
    d["zdjete_punkty"] = int64_t(u->zdjete_punkty);
    d["pozostalo_punktow"] = int64_t(u->pozostalo_punktow());
    return d;
}

Dictionary OpenEESymulacja::diagnostyka() const {
    Dictionary d;
    d["wersja"] = wersja();
    d["tablice"] = tablice_ ? gtekst(tablice_->zrodlo) : String("brak");
    d["tablice_zgodne"] = tablice_ ? tablice_->zgodne_z_oryginalem : false;
    d["ostatni_blad"] = ostatni_blad_;
    if (swiat_) {
        d["wariant"] = String(swiat_->wariant().nazwa);
        d["takty"] = int64_t(swiat_->takty());
        d["zegar_ms"] = int64_t(swiat_->zegar_ms());
        d["dt"] = swiat_->dt();
        d["rng_stan"] = int64_t(swiat_->generator().stan());
        d["rng_losowania"] = int64_t(swiat_->generator().liczba_losowan());
        d["jednostki"] = int64_t(swiat_->jednostki().size());
        const auto& g = swiat_->diagnostyka();
        d["zdarzenia_nieobslugiwane"] = int64_t(g.zdarzenia_nieobslugiwane);
        d["ostatnie_nieobslugiwane"] = gtekst(g.ostatnie_nieobslugiwane);
        d["wejscia_niewdrozone"] = int64_t(g.wejscia_niewdrozone);
        d["kolizje"] = int64_t(g.kolizje);
        d["kroki_odpychania"] = int64_t(g.kroki_odpychania);
        d["objazdy_niezweryfikowane"] = int64_t(g.objazdy_niezweryfikowane);
        d["astar_iteracje"] = int64_t(g.ostatnia_trasa.iteracje);
    }
    Array ps;
    for (const auto& p : openee::podsystemy()) {
        Dictionary e;
        e["nazwa"] = String::utf8(p.nazwa);
        e["status"] = p.status == openee::StatusPodsystemu::wdrozony ? "wdrożony"
                      : p.status == openee::StatusPodsystemu::czesciowy ? "częściowy" : "niewdrożony";
        e["uwagi"] = String::utf8(p.uwagi);
        ps.push_back(e);
    }
    d["podsystemy"] = ps;
    return d;
}
