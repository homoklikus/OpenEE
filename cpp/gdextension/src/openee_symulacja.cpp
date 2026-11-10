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
    ClassDB::bind_method(D_METHOD("kat_rozkazu", "ids", "x", "y"), &OpenEESymulacja::kat_rozkazu);
    ClassDB::bind_method(D_METHOD("ustaw_modyfikator_wysokosci", "wlaczony"), &OpenEESymulacja::ustaw_modyfikator_wysokosci);
    ClassDB::bind_method(D_METHOD("ustaw_efekty_obszaru", "dane"), &OpenEESymulacja::ustaw_efekty_obszaru);
    ClassDB::bind_method(D_METHOD("odtworz_efekty_obszaru"), &OpenEESymulacja::odtworz_efekty_obszaru);
    ClassDB::bind_method(D_METHOD("morale", "id"), &OpenEESymulacja::morale);
    ClassDB::bind_method(D_METHOD("ustaw_graf_podsektorow", "dane"), &OpenEESymulacja::ustaw_graf_podsektorow);
    ClassDB::bind_method(D_METHOD("sciezka_grafu", "x0", "y0", "x1", "y1"), &OpenEESymulacja::sciezka_grafu);
    ClassDB::bind_method(D_METHOD("zbuduj_graf_z_przydzialu", "id_xH", "W", "H", "komorka"), &OpenEESymulacja::zbuduj_graf_z_przydzialu);
    ClassDB::bind_method(D_METHOD("zbuduj_graf_z_wejscia", "wejscie", "komorka"), &OpenEESymulacja::zbuduj_graf_z_wejscia);
    ClassDB::bind_method(D_METHOD("ustaw_z", "id", "z"), &OpenEESymulacja::ustaw_z);
    ClassDB::bind_method(D_METHOD("uporzadkuj_wg_pozycji"), &OpenEESymulacja::uporzadkuj_wg_pozycji);
    ClassDB::bind_method(D_METHOD("ustaw_skrypt_jednostki", "id", "nazwa"), &OpenEESymulacja::ustaw_skrypt_jednostki);
    ClassDB::bind_method(D_METHOD("ustaw_stan_rng", "stan"), &OpenEESymulacja::ustaw_stan_rng);
    ClassDB::bind_method(D_METHOD("kolejka_fizyki"), &OpenEESymulacja::kolejka_fizyki);
    ClassDB::bind_method(D_METHOD("wejscie_regionow_z_mapy"), &OpenEESymulacja::wejscie_regionow_z_mapy);
    ClassDB::bind_method(D_METHOD("wejscie_regionow_z_scn", "obiekty", "zestawy"), &OpenEESymulacja::wejscie_regionow_z_scn);
    ClassDB::bind_method(D_METHOD("podsektor", "id"), &OpenEESymulacja::podsektor);
    ClassDB::bind_method(D_METHOD("walka", "id"), &OpenEESymulacja::walka);
    ClassDB::bind_method(D_METHOD("zdarzenia_walki"), &OpenEESymulacja::zdarzenia_walki);
    ClassDB::bind_method(D_METHOD("stan_jednostek"), &OpenEESymulacja::stan_jednostek);
    ClassDB::bind_method(D_METHOD("zdarzenia_walki_od", "od"), &OpenEESymulacja::zdarzenia_walki_od);
    ClassDB::bind_method(D_METHOD("ustaw_wrogow", "g1", "g2", "wrog"), &OpenEESymulacja::ustaw_wrogow);
    ClassDB::bind_method(D_METHOD("takty"), &OpenEESymulacja::takty);
}

String OpenEESymulacja::wersja() const { return "OpenEE Core 0.19.0 (etap 45, C++20, godot-cpp 10.0.0, API 4.7)"; }

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
    // etap 44 [P: 638 – obywatel (rozmiar 0,3) nie jest odpychany przez gwardię w odległości 0,47]: promień kolizji
    // +0x244 = typ+0x474 („Size of collider”) · min(skala, 1), co najmniej 0,05 (ruch_jednostki.md § 3) – domyślnie
    // z rozmiaru typu (skala 1). Wcześniej stałe 0,5 dla każdej jednostki.
    r.promien_kolizji = liczba(p, "promien_kolizji", std::max(0.05, r.rozmiar));
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
        d["graf_z_gry"] = swiat_->graf_podsektorow().z_gry;       // etap 40: tryb diagnostyczny
        d["graf_zrodlo"] = gtekst(swiat_->graf_podsektorow().zrodlo);
        d["graf_prosby"] = int64_t(g.graf_prosby);
        d["graf_punkty"] = int64_t(g.graf_punkty);
        Array gs;
        for (int id : g.graf_ostatnia) gs.push_back(id);
        d["graf_ostatnia"] = gs;
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
    p.regeneracja = int(liczba(d, "regeneracja", 0));
    p.smierc_klatki = int(liczba(d, "smierc_klatki", 0));       // etap 44: dbgraphics gniazdo 4 – liczba klatek
    p.smierc_ms_klatki = int(liczba(d, "smierc_ms_klatki", 0)); // „wartość” sekwencji = ms na klatkę
    p.rozklad_ms = int(liczba(d, "rozklad_ms", 0));             // dbobjects „Rotting time” × 1000
    p.zasoby = int(liczba(d, "zasoby", 0));
    openee::UstawieniaAI ai;   // etap 38: ustawienia AI typu/postawy (domyślne jak dotąd; pola z d – dane wejściowe)
    ai.szuka_wrogow = bool(liczba(d, "ai_szuka_wrogow", 1));
    ai.poscig_poza_icl = bool(liczba(d, "ai_poscig_poza_icl", 1));
    ai.wraca_do_icl = bool(liczba(d, "ai_wraca_do_icl", 0));
    ai.moze_swobodnie = bool(liczba(d, "ai_moze_swobodnie", 1));
    if (!swiat_->ustaw_walke(openee::IdJednostki(id), int(gracz), czlowiek, p, int(hp), ai)) return false;
    // stan licznika +0x290 w chwili startu (odczyt z nagrania; domyślnie 0 = regeneracja w pierwszym takcie) [P: kod]
    swiat_->jednostka(openee::IdJednostki(id))->boj->regeneracja_ms = int(liczba(d, "regeneracja_ms", 0));
    return true;
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

// etap 38: modyfikator wysokości z cfg gry (odczyt 587/588 [P]) – jak w testach Core (ModyfikatorWysokosci::z_gry)
void OpenEESymulacja::ustaw_modyfikator_wysokosci(bool wlaczony) {
    if (!swiat_) return;
    auto m = openee::ModyfikatorWysokosci::z_gry(swiat_->wariant().gra == openee::Gra::aoc);
    m.wlaczony = wlaczony;
    swiat_->ustaw_modyfikator_wysokosci(m);
}

// etap 38: efekty obszarowe i budynki z pliku narzędzia narzedzia/titan/efekty_obszaru.py (format jak wczytaj_efekty
// w testach Core): {szablony: [...], budynki: [...]}. Zwraca liczbę budynków.
int64_t OpenEESymulacja::ustaw_efekty_obszaru(const Dictionary& d) {
    if (!swiat_) return -1;
    const Array sz = d.get("szablony", Array());
    for (int64_t i = 0; i < sz.size(); ++i) {
        const Dictionary t = sz[i];
        openee::SzablonEfektu e;
        e.id = int(liczba(t, "id", 0)); e.typ = int(liczba(t, "typ", 0)); e.ksztalt = int(liczba(t, "ksztalt", 1));
        e.relacja = int(liczba(t, "relacja", 2)); e.rozmiar = float(liczba(t, "rozmiar", 0));
        e.maks_morale = int(liczba(t, "maks_morale", 0)); e.wartosc_40 = int(liczba(t, "wartosc_40", 0));
        const Array z = t.get("zestaw", Array());
        for (int64_t k = 0; k < z.size(); ++k) e.zestaw.push_back(int(int64_t(z[k])));
        swiat_->dodaj_szablon_efektu(std::move(e));
    }
    const Array bu = d.get("budynki", Array());
    for (int64_t i = 0; i < bu.size(); ++i) {
        const Dictionary b = bu[i];
        openee::Budynek x;
        x.typ_db = int(liczba(b, "typ", 0)); x.gracz = int(liczba(b, "gracz", 0));
        const Array pole = b.get("pole", Array()); const Array sr = b.get("srodek", Array());
        if (pole.size() >= 2) { x.pole_x = int(int64_t(pole[0])); x.pole_y = int(int64_t(pole[1])); }
        x.rozmiar_pol = int(liczba(b, "rozmiar", 1));
        if (sr.size() >= 2) { x.x = float(double(sr[0])); x.y = float(double(sr[1])); }
        std::vector<int> ef;
        const Array e = b.get("efekty", Array());
        for (int64_t k = 0; k < e.size(); ++k) ef.push_back(int(int64_t(e[k])));
        swiat_->dodaj_budynek(x, ef);
    }
    return bu.size();
}

// etap 40: graf podsektorów w formacie odczytu Riverlands_MCP `podsektory` (id, sektor [i, j, id], rodzaj,
// punkt_i32, sasiedzi, pola [[x, y_min, y_max], …]) – tryb diagnostyczny „graf z gry”. Zwraca liczbę podsektorów.
int64_t OpenEESymulacja::ustaw_graf_podsektorow(const Dictionary& d) {
    if (!swiat_) return -1;
    openee::GrafPodsektorow g;
    g.z_gry = true;
    g.zrodlo = "gra (odczyt)";
    const Array lst = d.get("podsektory", Array());
    for (int64_t i = 0; i < lst.size(); ++i) {
        const Dictionary e = lst[i];
        openee::Podsektor p;
        p.id = int(liczba(e, "id", 0));
        const Array sek = e.get("sektor", Array());
        if (sek.size() >= 2) { p.sektor_i = int(int64_t(sek[0])); p.sektor_j = int(int64_t(sek[1])); }
        p.rodzaj = int(liczba(e, "rodzaj", 0));
        const Array pt = e.get("punkt_i32", Array());
        if (pt.size() >= 2) { p.punkt_x = int(int64_t(pt[0])); p.punkt_y = int(int64_t(pt[1])); }
        const Array sas = e.get("sasiedzi", Array());
        for (int64_t k = 0; k < sas.size(); ++k) if (sas[k].get_type() != Variant::NIL) p.sasiedzi.push_back(int(int64_t(sas[k])));
        const Array pola = e.get("pola", Array());
        for (int64_t k = 0; k < pola.size(); ++k) {
            const Array r = pola[k];
            if (r.size() < 3) continue;
            const int64_t x = int64_t(r[0]);
            for (int64_t y = int64_t(r[1]); y <= int64_t(r[2]); ++y) g.pole_podsektor[(x << 32) | (y & 0xffffffff)] = p.id;
        }
        g.podsektory[p.id] = std::move(p);
    }
    const int64_t n = int64_t(g.podsektory.size());
    swiat_->ustaw_graf_podsektorow(std::move(g));
    return n;
}

// etap 41: graf z przydziału pól (punkty 0x42C2D5 i sąsiedzi 0x4246E8 liczone w Core); przydział – wejście [N]
int64_t OpenEESymulacja::zbuduj_graf_z_przydzialu(const PackedInt32Array& a, int64_t W, int64_t H, int64_t komorka) {
    if (!swiat_ || a.size() != W * H) return -1;
    std::vector<int> g(a.size());
    for (int64_t i = 0; i < a.size(); ++i) g[std::size_t(i)] = a[i];
    auto G = openee::zbuduj_graf_z_przydzialu(g, int(W), int(H), int(komorka));
    const int64_t n = int64_t(G.podsektory.size());
    swiat_->ustaw_graf_podsektorow(std::move(G));
    return n;
}

// etap 42: graf z wejścia mapy (regiony 0x4240D3 → przydział 0x42434F → punkty i sąsiedzi) – układ słownika jak
// odczyt Riverlands_MCP `regiony_wejscie` (N, rodzaj_pola, bajt14 / siatka_wys, obszar, obszary_rodzaj_id,
// jednostki {indeks: [[id, hp, gracz, vtable, typ], …]}, typy {typ: [+0x568, +0x600, +0x4B4, +0x612]}, brzeg [e0, e1, e2]).
Dictionary OpenEESymulacja::zbuduj_graf_z_wejscia(const Dictionary& d, int64_t komorka) {
    Dictionary wyn;
    openee::WejscieRegionow w;
    w.N = int(d.get("N", 0));
    const int64_t n = int64_t(w.N) * w.N;
    auto tab = [&](const Variant& v, std::vector<int>& out) {
        const Array a = v;
        if (a.size() != n) return false;
        out.resize(std::size_t(n));
        for (int64_t i = 0; i < n; ++i) out[std::size_t(i)] = int(a[i]);
        return true;
    };
    const Variant wys = d.get("siatka_wys", Variant());
    const bool obszary_z_gry = d.has("obszar") && d.has("obszary_rodzaj_id");
    if (!swiat_ || w.N <= 0 || !tab(d.get("rodzaj_pola", Array()), w.rodzaj_pola) ||
        (obszary_z_gry && !tab(d.get("obszar", Array()), w.obszar)) ||
        !tab(wys.get_type() == Variant::ARRAY ? wys : d.get("bajt14", Array()), w.wysokosc)) {
        wyn["blad"] = "niepełne wejście";
        return wyn;
    }
    const Array ob = obszary_z_gry ? Array(d.get("obszary_rodzaj_id", Array())) : Array();
    for (int64_t i = 0; i < ob.size(); ++i) {
        const Variant e = ob[i];
        if (e.get_type() == Variant::ARRAY) { const Array p = e; w.obszary.push_back({int(p[0]), int(p[1])}); }
        else w.obszary.push_back({0, 0});
    }
    const Dictionary typy = d.get("typy", Dictionary());
    const Dictionary jed = d.get("jednostki", Dictionary());
    const Array klucze = jed.keys();
    for (int64_t k = 0; k < klucze.size(); ++k) {
        const int idx = String(klucze[k]).to_int();
        const Array lista = jed[klucze[k]];
        auto& v = w.obiekty[idx];
        for (int64_t j = 0; j < lista.size(); ++j) {
            const Array u = lista[j];
            openee::ObiektPolaRegionu o;
            o.id = std::uint32_t(String(u[0]).hex_to_int());
            o.hp = int(u[1]);
            o.gracz = u[2].get_type() == Variant::NIL ? -1 : int(u[2]);
            const Array t = typy.get(u[4], Array());
            if (t.size() >= 4) { o.klasa568 = int(t[0]); o.flaga600 = int(t[1]); o.klasa4b4 = int(t[2]); o.flaga612 = int(t[3]); }
            o.vt58 = false;   // jednostka złożona: bajt +0x345 (0x5F3487) – nieodczytany [H: 0]
            v.push_back(o);
        }
    }
    const Array br = d.get("brzeg", Array());
    if (br.size() == 3) { w.brzeg_e0 = int(br[0]); w.brzeg_e1 = int(br[1]); w.brzeg_e2 = int(br[2]); }
    if (!obszary_z_gry) openee::zbuduj_obszary(w);   // etap 42: obszary z rodzajów pól (model z pomiaru)
    const auto R = openee::zbuduj_siatke_regionow(w);
    const auto g = openee::zbuduj_przydzial_podsektorow(R, int(komorka));
    PackedInt32Array pr, pp;
    pr.resize(n); pp.resize(n);
    for (int64_t i = 0; i < n; ++i) { pr.set(i, R.etykieta[std::size_t(i)]); pp.set(i, g[std::size_t(i)]); }
    auto G = openee::zbuduj_graf_z_wejscia(w, int(komorka));
    wyn["regionow"] = int64_t(R.rodzaj.size()) - 1;
    wyn["obszarow"] = int64_t(w.obszary.size()) - 1;
    wyn["obszary_z_gry"] = obszary_z_gry;
    wyn["podsektorow"] = int64_t(G.podsektory.size());
    wyn["regiony"] = pr;
    wyn["przydzial"] = pp;
    swiat_->ustaw_graf_podsektorow(std::move(G));
    return wyn;
}

// etap 43: wysokość z zapisu scenariusza (nieaktualna do pierwszej aktualizacji fizyki – 631 [P])
// etap 44: kolejność listy jednostek jak kolejka fizyki EE po wczytaniu scenariusza (x, potem y rosnąco)
// etap 45: skrypt .tai typu jednostki w Core ("land", "obywatel")
// etap 45: kolejka fizyki 0x918DDC – identyfikatory od początku kolejki (pętla 0x547AAD przetwarza od końca)
Array OpenEESymulacja::kolejka_fizyki() const {
    Array a;
    if (swiat_)
        for (const auto& u : swiat_->jednostki())
            if (u.w_fizyce) a.push_back(int64_t(u.id));
    return a;
}

// etap 45: stan generatora RTSPhysics (diagnostyka odtworzeń – synchronizacja z nagraniem gry)
void OpenEESymulacja::ustaw_stan_rng(int64_t stan) {
    if (swiat_) swiat_->generator().ustaw_ziarno(std::uint32_t(stan));
}

bool OpenEESymulacja::ustaw_skrypt_jednostki(int64_t id, const String& nazwa) {
    return swiat_ && swiat_->ustaw_skrypt_jednostki(openee::IdJednostki(id), std::string(nazwa.utf8().get_data()));
}

void OpenEESymulacja::uporzadkuj_wg_pozycji() { if (swiat_) swiat_->uporzadkuj_wg_pozycji(); }

bool OpenEESymulacja::ustaw_z(int64_t id, double z) { return swiat_ && swiat_->ustaw_z(openee::IdJednostki(id), z); }

// etap 43: wejście floodu regionów z mapy SCN w Core (rodzaj pola 0x516E8C, bajt +0x14 wody 0x426577) – bez danych
// z pamięci gry; obiekty pól (jednostki, typy) dodaje wywołujący – w Core brak listy obiektów na polach [N]
Dictionary OpenEESymulacja::wejscie_regionow_z_mapy() const {
    Dictionary d;
    if (!mapa_) return d;
    const auto r = mapa_->rodzaj_pol_titan();
    const auto h = mapa_->bajt14_wody(r);
    Array rp, hb;
    rp.resize(int64_t(r.size())); hb.resize(int64_t(h.size()));
    for (std::size_t i = 0; i < r.size(); ++i) { rp[int64_t(i)] = r[i]; hb[int64_t(i)] = h[i]; }
    d["N"] = mapa_->szerokosc();
    d["rodzaj_pola"] = rp;
    d["bajt14"] = hb;
    Array br; br.push_back(mapa_->brzeg_s1()); br.push_back(mapa_->brzeg_s2()); br.push_back(mapa_->brzeg_d());
    d["brzeg"] = br;
    d["komorka"] = openee::komorka_sektora(mapa_->brzeg_d());   // etap 44: bok sektora podsektorów (0x42439A)
    d["zrodlo"] = "Core z mapy SCN (klasyfikacja 0x516E8C/0x512FB0)";
    return d;
}

// etap 44: pełne wejście floodu regionów z danych lokalnych – mapa SCN (klasyfikacja w Core) + obiekty kawałka 5
// zarejestrowane na polach w Core (openee::dodaj_obiekty_scn) z parametrami typów dbobjects i zestawem 9 dbunitset
// (+0x612). obiekty: [{id, gracz, X, Y, kwadrat, hp, typ, zasob, budynek, unit_type}] w kolejności rekordów SCN;
// zestawy: [{ID, obiekty: [...], rodziny: [...], dolacz, wyklucz}] (dbunitset). Wynik w układzie Riverlands_MCP
// `regiony_wejscie` (jednostki/typy) – zbuduj_graf_z_wejscia przyjmuje go bez danych z pamięci gry.
Dictionary OpenEESymulacja::wejscie_regionow_z_scn(const Array& obiekty, const Array& zestawy) const {
    Dictionary d = wejscie_regionow_z_mapy();
    if (d.is_empty()) return d;
    std::map<int, openee::ZestawJednostek> zj;
    for (int64_t i = 0; i < zestawy.size(); ++i) {
        const Dictionary z = zestawy[i];
        openee::ZestawJednostek e;
        const Array ob = z.get("obiekty", Array()), rd = z.get("rodziny", Array());
        for (int64_t j = 0; j < ob.size(); ++j) e.obiekty.push_back(int(ob[j]));
        for (int64_t j = 0; j < rd.size(); ++j) e.rodziny.push_back(int(rd[j]));
        e.dolacz = int(z.get("dolacz", -1)); e.wyklucz = int(z.get("wyklucz", -1));
        zj[int(z.get("ID", -1))] = e;
    }
    openee::WejscieRegionow w;
    w.N = int(d["N"]);
    const Array rp = d["rodzaj_pola"];
    w.rodzaj_pola.resize(std::size_t(rp.size()));
    for (int64_t i = 0; i < rp.size(); ++i) w.rodzaj_pola[std::size_t(i)] = int(rp[i]);
    std::vector<openee::ObiektScnPola> lista;
    std::map<int, std::array<int, 4>> typy;
    for (int64_t i = 0; i < obiekty.size(); ++i) {
        const Dictionary o = obiekty[i];
        openee::ObiektScnPola p;
        p.id = std::uint32_t(int64_t(o.get("id", 0)));
        p.gracz = int(o.get("gracz", 0)); p.X = int(o.get("X", 0)); p.Y = int(o.get("Y", 0));
        p.kwadrat = int(o.get("kwadrat", 1)); p.hp = int(o.get("hp", 0));
        const int typ = int(o.get("typ", -1));
        p.klasa568 = int(o.get("zasob", 0)); p.flaga600 = int(o.get("budynek", 0)) ? 1 : 0;
        p.klasa4b4 = int(o.get("unit_type", 0));
        p.flaga612 = openee::zestaw_zawiera(zj, 9, typ) ? 1 : 0;
        typy[typ] = {p.klasa568, p.flaga600, p.klasa4b4, p.flaga612};
        lista.push_back(p);
    }
    openee::dodaj_obiekty_scn(w, lista);
    // serializacja do układu MCP: klucz typu „typ:<ID dbobjects>”
    std::map<std::uint32_t, int> typ_id;
    for (int64_t i = 0; i < obiekty.size(); ++i) {
        const Dictionary o = obiekty[i];
        typ_id[std::uint32_t(int64_t(o.get("id", 0)))] = int(o.get("typ", -1));
    }
    Dictionary jed, ty;
    for (const auto& [idx, l] : w.obiekty) {
        Array a;
        for (const auto& p : l) {
            Array e;
            e.push_back(String("0x") + String::num_int64(p.id, 16));
            e.push_back(p.hp); e.push_back(p.gracz); e.push_back(String(""));
            e.push_back(String("typ:") + String::num_int64(typ_id[p.id]));
            a.push_back(e);
        }
        jed[String::num_int64(idx)] = a;
    }
    for (const auto& [typ, f] : typy) {
        Array e; for (int v : f) e.push_back(v);
        ty[String("typ:") + String::num_int64(typ)] = e;
    }
    d["jednostki"] = jed;
    d["typy"] = ty;
    d["zrodlo"] = "Core z mapy SCN i kawałka 5 (klasyfikacja 0x516E8C/0x512FB0, obiekty pól, zestaw 9)";
    return d;
}

// etap 43: podgląd podsektora grafu (punkt reprezentatywny, sąsiedzi w kolejności listy, rodzaj, sektor) – diagnostyka
Dictionary OpenEESymulacja::podsektor(int64_t id) const {
    Dictionary d;
    if (!swiat_) return d;
    const auto& g = swiat_->graf_podsektorow();
    const auto it = g.podsektory.find(int(id));
    if (it == g.podsektory.end()) return d;
    const auto& p = it->second;
    Array pkt; pkt.push_back(p.punkt_x); pkt.push_back(p.punkt_y);
    Array sas;
    for (int q : p.sasiedzi) sas.push_back(q);
    Array sek; sek.push_back(p.sektor_i); sek.push_back(p.sektor_j);
    d["punkt"] = pkt; d["sasiedzi"] = sas; d["rodzaj"] = p.rodzaj; d["sektor"] = sek;
    return d;
}

Array OpenEESymulacja::sciezka_grafu(int64_t x0, int64_t y0, int64_t x1, int64_t y1) const {
    Array a;
    if (!swiat_) return a;
    const auto& g = swiat_->graf_podsektorow();
    for (int id : openee::szukaj_w_grafie(g, g.podsektor_pola(x0, y0), g.podsektor_pola(x1, y1))) a.push_back(id);
    return a;
}

void OpenEESymulacja::odtworz_efekty_obszaru() { if (swiat_) swiat_->odtworz_efekty_obszaru(); }

Array OpenEESymulacja::morale(int64_t id) const {
    Array a;
    if (!swiat_) return a;
    const openee::Jednostka* u = swiat_->jednostka(openee::IdJednostki(id));
    if (!u) return a;
    for (int v : swiat_->poziomy_morale(*u)) a.push_back(v);
    return a;
}

double OpenEESymulacja::kat_rozkazu(const Array& ids, double x, double y) const {
    if (!swiat_) return 0.0;
    std::vector<openee::IdJednostki> v;
    for (int64_t i = 0; i < ids.size(); ++i) v.push_back(openee::IdJednostki(int64_t(ids[i])));
    return swiat_->kat_rozkazu(v, x, y);
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
    // etap 39: pełna kolejka celów (rodzaj, punkt, cel-jednostka, od gracza, próby) – porównanie z kolejką gry
    Array q;
    for (const auto& c : u->kolejka_celow) {
        Dictionary e;
        e["rodzaj"] = c.typ == openee::TypCelu::jednostka ? String("EEUGAttackUnit") : String("EEUGLocation");
        e["x"] = c.x;
        e["y"] = c.y;
        e["cel"] = int64_t(c.cel_jednostka);
        e["od_gracza"] = c.od_gracza;
        e["proby"] = int64_t(c.proby);
        q.push_back(e);
    }
    d["kolejka"] = q;
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

// ---------------------------------------------------------------------------------------------------------------
// Etap 36 – odczyty dla sceny potyczki (Godot tylko prezentuje stan Core).

Array OpenEESymulacja::stan_jednostek() const {
    Array a;
    if (!swiat_) return a;
    for (const auto& u : swiat_->jednostki()) {
        Dictionary d;
        d["id"] = int64_t(u.id);
        d["x"] = u.x;
        d["y"] = u.y;
        d["z"] = u.z;
        d["v"] = u.v;
        d["kurs"] = swiat_->matematyka().kurs_z_macierzy(u.orientacja);
        d["stan"] = u.stan;
        d["tryb"] = int(u.tryb);
        d["gracz"] = u.gracz;
        if (u.boj) {
            d["hp"] = u.boj->s.hp;
            d["hp_max"] = u.boj->p.hp_max;
            d["animacja"] = u.boj->animacja;
            int64_t cel = 0;
            if (!u.kolejka_celow.empty() && u.kolejka_celow.front().typ == openee::TypCelu::jednostka)
                cel = int64_t(u.kolejka_celow.front().cel_jednostka);
            d["cel"] = cel;
        }
        a.push_back(d);
    }
    return a;
}

Array OpenEESymulacja::zdarzenia_walki_od(int64_t od) const {
    Array a;
    if (!swiat_) return a;
    const auto& z = swiat_->zdarzenia_walki();
    for (std::size_t i = std::size_t(od < 0 ? 0 : od); i < z.size(); ++i) {
        Dictionary d;
        d["indeks"] = int64_t(i);
        d["takt"] = int64_t(z[i].takt);
        d["kto"] = int64_t(z[i].kto);
        d["cel"] = int64_t(z[i].cel);
        d["rodzaj"] = String(z[i].rodzaj.c_str());
        d["wartosc"] = z[i].wartosc;
        a.push_back(d);
    }
    return a;
}

void OpenEESymulacja::ustaw_wrogow(int64_t g1, int64_t g2, bool wrog) {
    if (swiat_) swiat_->ustaw_wrogow(int(g1), int(g2), wrog);
}

int64_t OpenEESymulacja::takty() const { return swiat_ ? int64_t(swiat_->takty()) : 0; }
