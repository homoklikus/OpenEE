#include "openee_symulacja.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <array>
#include <cstdio>

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
    ClassDB::bind_method(D_METHOD("wczytaj_mape_scn", "A", "B", "tekstura", "flagi", "f10", "wysokosc", "rodziny"),
                         &OpenEESymulacja::wczytaj_mape_scn);
    ClassDB::bind_method(D_METHOD("dodaj_obiekt_mapy", "obiekt"), &OpenEESymulacja::dodaj_obiekt_mapy);
    ClassDB::bind_method(D_METHOD("mapa_teren", "x", "y"), &OpenEESymulacja::mapa_teren);
    ClassDB::bind_method(D_METHOD("mapa_pewnosc", "x", "y"), &OpenEESymulacja::mapa_pewnosc);
    ClassDB::bind_method(D_METHOD("utworz_swiat_na_mapie", "wariant", "teren_dozwolony"), &OpenEESymulacja::utworz_swiat_na_mapie);
    ClassDB::bind_method(D_METHOD("pole_przejezdne", "x", "y"), &OpenEESymulacja::pole_przejezdne);
    ClassDB::bind_method(D_METHOD("ustaw_walke", "id", "gracz", "czlowiek", "parametry", "hp"), &OpenEESymulacja::ustaw_walke);
    ClassDB::bind_method(D_METHOD("ustaw_tablice_walki", "tablice", "wagi"), &OpenEESymulacja::ustaw_tablice_walki);
    ClassDB::bind_method(D_METHOD("rozkaz_ataku", "id", "cel"), &OpenEESymulacja::rozkaz_ataku);
    ClassDB::bind_method(D_METHOD("walka", "id"), &OpenEESymulacja::walka);
    ClassDB::bind_method(D_METHOD("zdarzenia_walki"), &OpenEESymulacja::zdarzenia_walki);
}

String OpenEESymulacja::wersja() const { return "OpenEE Core 0.9.0 (etap 31, C++20, godot-cpp 10.0.0, API 4.7)"; }

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

// ------------------------------------------------------------------------------------------- mapa (etap 30)
Dictionary OpenEESymulacja::wczytaj_mape_scn(int64_t A, int64_t B, const PackedByteArray& tekstura, const PackedByteArray& flagi,
                                             const PackedFloat32Array& f10, const PackedFloat32Array& wysokosc,
                                             const Dictionary& rodziny) {
    Dictionary w;
    openee::DaneTerenuScn d;
    d.A = int(A);
    d.B = int(B);
    d.tekstura.assign(tekstura.ptr(), tekstura.ptr() + tekstura.size());
    d.flagi.assign(flagi.ptr(), flagi.ptr() + flagi.size());
    d.f10.assign(f10.ptr(), f10.ptr() + f10.size());
    d.wysokosc.assign(wysokosc.ptr(), wysokosc.ptr() + wysokosc.size());
    std::array<std::int16_t, 256> rd;
    rd.fill(-1);
    const Array k = rodziny.keys();
    for (int64_t i = 0; i < k.size(); ++i) {
        const int64_t id = int64_t(k[i]);
        if (id >= 0 && id < 256) rd[std::size_t(id)] = std::int16_t(int64_t(rodziny[k[i]]));
    }
    try {
        mapa_ = std::make_unique<openee::MapaTitan>(openee::MapaTitan::z_scn(d, rd));
    } catch (const std::exception& e) {
        ostatni_blad_ = gtekst(e.what());
        UtilityFunctions::push_error("OpenEE: ", ostatni_blad_);
        w["ok"] = false;
        w["blad"] = ostatni_blad_;
        return w;
    }
    w["ok"] = true;
    w["szerokosc"] = mapa_->szerokosc();
    w["brzeg_s1"] = mapa_->brzeg_s1();
    w["brzeg_s2"] = mapa_->brzeg_s2();
    w["brzeg_d"] = mapa_->brzeg_d();
    w["skrot"] = gtekst([&] { char b[20]; std::snprintf(b, sizeof b, "%016llx", (unsigned long long)mapa_->skrot()); return std::string(b); }());
    return w;
}

bool OpenEESymulacja::dodaj_obiekt_mapy(const Dictionary& o) {
    if (!mapa_) return false;
    openee::ObiektMapy ob;
    ob.id = std::uint32_t(int64_t(o.get("id", 0)));
    ob.typ_db = int(int64_t(o.get("typ", -1)));
    ob.gracz = int(int64_t(o.get("gracz", 0)));
    ob.pole_x = int(int64_t(o.get("X", 0)));
    ob.pole_y = int(int64_t(o.get("Y", 0)));
    ob.kwadrat = int(int64_t(o.get("kwadrat", 1)));
    ob.blokuje = bool(o.get("blokuje", false));
    mapa_->obiekty().push_back(ob);
    return true;
}

int64_t OpenEESymulacja::mapa_teren(int64_t x, int64_t y) const { return mapa_ ? mapa_->teren(int(x), int(y)) : -1; }
int64_t OpenEESymulacja::mapa_pewnosc(int64_t x, int64_t y) const { return mapa_ ? int64_t(mapa_->pewnosc(int(x), int(y))) : 3; }

bool OpenEESymulacja::utworz_swiat_na_mapie(const String& wariant, const PackedByteArray& teren_dozwolony) {
    if (!tablice_ || !mapa_) {
        ostatni_blad_ = "Potrzebne tablice (zaladuj_tablice / tryb przybliżony) i mapa (wczytaj_mape_scn).";
        UtilityFunctions::push_error("OpenEE: ", ostatni_blad_);
        return false;
    }
    std::array<std::uint8_t, 16> dz{};
    for (int64_t i = 0; i < teren_dozwolony.size() && i < 16; ++i) dz[std::size_t(i)] = teren_dozwolony[i];
    try {
        swiat_ = std::make_unique<openee::Swiat>(tablice_, mapa_->siatka(dz), openee::WariantTitan::z_nazwy(tekst(wariant)));
    } catch (const std::exception& e) {
        ostatni_blad_ = gtekst(e.what());
        UtilityFunctions::push_error("OpenEE: ", ostatni_blad_);
        return false;
    }
    return true;
}

bool OpenEESymulacja::pole_przejezdne(int64_t x, int64_t y) const { return swiat_ && swiat_->teren().pole_przejezdne(x, y); }

// ---------------------------------------------------------------------------------------------- walka (etap 31)

bool OpenEESymulacja::ustaw_walke(int64_t id, int64_t gracz, bool czlowiek, const Dictionary& d, int64_t hp) {
    if (!swiat_) return false;
    openee::ParametryWalki p;
    p.hp_max = int(liczba(d, "hp_max", double(hp)));
    p.atak = float(liczba(d, "atak", 0));
    if (d.has("pancerz")) {
        const Array a = d["pancerz"];
        for (int64_t i = 0; i < a.size() && i < 6; ++i) p.pancerz[std::size_t(i)] = float(double(a[i]));
    }
    p.zasieg_max = float(liczba(d, "zasieg_max", 0));
    p.pole_widzenia = float(liczba(d, "pole_widzenia", 0));
    p.obszar = float(liczba(d, "obszar", 0));
    p.przeladowanie_ms = int(liczba(d, "przeladowanie_ms", 0));
    p.rodzaj_ataku = int(liczba(d, "rodzaj_ataku", 0));
    p.wiersz_celu = int(liczba(d, "wiersz_celu", 0));
    p.klasa_trafienia = int(liczba(d, "klasa_trafienia", 0));
    p.rodzina_ataku = int(liczba(d, "rodzina_ataku", 0));
    p.opoznienie_trafienia_ms = int(liczba(d, "opoznienie_trafienia_ms", -1));
    p.luk_ataku = float(liczba(d, "luk_ataku", 0));
    p.kat_broni = float(liczba(d, "kat_broni", 0));
    p.rozmiar = float(liczba(d, "rozmiar", 0.5));
    p.rozmiar_jeden = bool(liczba(d, "rozmiar_jeden", 0));
    p.punktowy = bool(liczba(d, "punktowy", 0));
    p.szukanie_ms = int(liczba(d, "szukanie_ms", 0));
    p.zasieg_min = float(liczba(d, "zasieg_min", 0));
    p.pole_ac = float(liczba(d, "pole_ac", 0));
    p.typ_bazy = int(liczba(d, "typ_bazy", 0));
    p.typ_jednostki = int(liczba(d, "typ_jednostki", 0));
    return swiat_->ustaw_walke(openee::IdJednostki(id), int(gracz), czlowiek, p, int(hp));
}

bool OpenEESymulacja::ustaw_tablice_walki(const Dictionary& d, const Array& wagi) {
    if (!swiat_) return false;
    openee::TabliceObrazen t;
    t.trudnosc = int(liczba(d, "trudnosc", 0));
    if (d.has("mnozniki")) {
        const Array m = d["mnozniki"];
        for (int64_t i = 0; i < m.size(); ++i) {
            const Array r = m[i];
            std::array<float, 6> a{};
            for (int64_t k = 0; k < r.size() && k < 6; ++k) a[std::size_t(k)] = float(double(r[k]));
            t.mnozniki.push_back(a);
        }
    }
    const char* kl[3] = {"08", "0C", "10"};
    if (d.has("trafienie")) {
        const Dictionary tr = d["trafienie"];
        for (int i = 0; i < 3; ++i) {
            if (!tr.has(kl[i])) continue;
            const Dictionary k = tr[kl[i]];
            const Array klucze = k.keys();
            for (int64_t j = 0; j < klucze.size(); ++j) {
                const PackedFloat32Array f = k[klucze[j]];
                std::vector<float> v(f.ptr(), f.ptr() + f.size());
                t.trafienie[std::size_t(i)][int(klucze[j])] = v;
            }
        }
    }
    std::array<openee::WagiCelu, 3> w{};
    for (int64_t i = 0; i < wagi.size() && i < 3; ++i) {
        const Array r = wagi[i];
        std::vector<int> v;
        for (int64_t k = 0; k < r.size(); ++k) v.push_back(int(r[k]));
        w[std::size_t(i)] = openee::WagiCelu::z_rekordu(v);
    }
    swiat_->ustaw_tablice_walki(std::move(t), w);
    return true;
}

bool OpenEESymulacja::rozkaz_ataku(int64_t id, int64_t cel) {
    return swiat_ && swiat_->rozkaz_ataku(openee::IdJednostki(id), openee::IdJednostki(cel));
}

Dictionary OpenEESymulacja::walka(int64_t id) const {
    Dictionary d;
    if (!swiat_) return d;
    const openee::Jednostka* u = swiat_->jednostka(openee::IdJednostki(id));
    if (!u || !u->boj) return d;
    d["hp"] = u->boj->s.hp;
    d["przeladowanie_ms"] = u->boj->s.przeladowanie_ms;
    d["szukanie_ms"] = u->boj->szukanie_ms;
    d["animacja"] = u->boj->animacja;
    d["zabicia"] = u->boj->s.zabicia;
    d["gracz"] = u->gracz;
    int64_t cel = 0;
    if (!u->kolejka_celow.empty() && u->kolejka_celow.front().typ == openee::TypCelu::jednostka)
        cel = int64_t(u->kolejka_celow.front().cel_jednostka);
    d["cel"] = cel;
    return d;
}

Array OpenEESymulacja::zdarzenia_walki() const {
    Array a;
    if (!swiat_) return a;
    for (const auto& e : swiat_->zdarzenia_walki()) {
        Dictionary d;
        d["takt"] = int64_t(e.takt);
        d["kto"] = int64_t(e.kto);
        d["cel"] = int64_t(e.cel);
        d["rodzaj"] = String(e.rodzaj.c_str());
        d["wartosc"] = e.wartosc;
        a.push_back(d);
    }
    return a;
}
