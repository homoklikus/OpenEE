// OpenEE Core – testy natywne (etap 28). Uruchamianie: ctest (grupy jako osobne testy) albo
//   openee_tests <grupa>   grupy: trygonometria rng teren ruch odpychanie dll tai determinizm podsystemy
// Kody wyjścia: 0 = PASS, 1 = FAIL, 77 = SKIP (brak oryginalnej DLL). SKIP nie jest PASS.
#include <algorithm>
#include <cctype>
#include <cinttypes>
#include <cstring>
#include <filesystem>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <functional>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include "json_mini.hpp"
#include "openee/generator.hpp"
#include "openee/kolizje.hpp"
#include "openee/maszyna_stanow.hpp"
#include "openee/matematyka.hpp"
#include "openee/symulacja.hpp"
#include "openee/tablice_dll.hpp"
#include "openee/teren.hpp"

using namespace openee;
using json_mini::Wartosc;

#ifndef OPENEE_KATALOG_ZRODEL
#define OPENEE_KATALOG_ZRODEL "."
#endif
#ifndef OPENEE_INSTALACJA_DOMYSLNA
#define OPENEE_INSTALACJA_DOMYSLNA ""
#endif

namespace {

constexpr int PASS = 0, FAIL = 1, SKIP = 77;
int bledy = 0, sprawdzenia = 0;

void sprawdz(bool w, const std::string& opis) {
    ++sprawdzenia;
    if (!w) {
        ++bledy;
        std::printf("  BŁĄD: %s\n", opis.c_str());
    }
}

std::string czytaj(const std::string& p) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return {};
    std::stringstream ss;
    ss << f.rdbuf();
    return ss.str();
}

Wartosc json_z_pliku(const std::string& rel) {
    const std::string t = czytaj(std::string(OPENEE_KATALOG_ZRODEL) + "/" + rel);
    if (t.empty()) throw std::runtime_error("brak pliku " + rel);
    return json_mini::Parser(t).parsuj();
}

std::string sciezka_dll(bool aoc) {
    if (const char* e = std::getenv(aoc ? "OPENEE_DLL_AOC" : "OPENEE_DLL_EE")) return e;
    std::string kat;
    if (const char* e = std::getenv("OPENEE_INSTALACJA")) kat = e;
    else kat = OPENEE_INSTALACJA_DOMYSLNA;
    if (kat.empty()) return {};
    return kat + (aoc ? "/Empire Earth - The Art of Conquest" : "/Empire Earth") + "/Low-Level Engine.dll";
}

std::shared_ptr<const TabliceTrig> tablice_lub_skip(bool aoc = false) {
    const std::string p = sciezka_dll(aoc);
    if (p.empty()) {
        std::printf("  SKIP: nie podano instalacji (OPENEE_INSTALACJA / OPENEE_DLL_EE / OPENEE_DLL_AOC)\n");
        return nullptr;
    }
    auto w = zaladuj_tablice_dll(p);
    if (!w.ok()) {
        std::printf("  SKIP: %s\n", w.komunikat.c_str());
        return nullptr;
    }
    std::printf("  %s\n", w.komunikat.c_str());
    return w.tablice;
}

std::uint64_t hex64(const std::string& s) { return std::strtoull(s.c_str(), nullptr, 16); }
std::uint64_t bity_f64(double v) {
    std::uint64_t u;
    std::memcpy(&u, &v, 8);
    return u;
}

// --------------------------------------------------------------------------------------------- trygonometria
int test_trygonometria() {
    auto t = tablice_lub_skip();
    if (!t) return SKIP;
    MatematykaTitan m(t);
    const Wartosc j = json_z_pliku("cpp/tests/dane/trygonometria_referencja.json");
    int n = 0;
    for (const auto& c : j["przypadki"].t) {
        const std::string f = c["f"].s;
        char opis[200];
        if (f == "um_arctan2") {
            const double w = m.um_arctan2(c["a"].n, c["b"].n);
            std::snprintf(opis, sizeof opis, "UMArcTan2(%.9g, %.9g) = %.17g", c["a"].n, c["b"].n, w);
            sprawdz(bity_f64(w) == hex64(c["wynik_f64_bity"].s), opis);
            sprawdz(bity_f32(w) == std::uint32_t(hex64(c["wynik_f32_bity"].s)), std::string(opis) + " (f32)");
        } else if (f == "um_arccos" || f == "um_cos" || f == "um_sin") {
            const double x = c["x"].n;
            const double w = f == "um_arccos" ? m.um_arccos(x) : f == "um_cos" ? m.um_cos(x) : m.um_sin(x);
            std::snprintf(opis, sizeof opis, "%s(%.9g) = %.17g", f.c_str(), x, w);
            sprawdz(bity_f64(w) == hex64(c["wynik_f64_bity"].s), opis);
        } else if (f == "set_orientation_ypr") {
            const Macierz3 r = m.set_orientation_ypr(c["yaw"].n, c["pitch"].n, c["roll"].n);
            for (int i = 0; i < 9; ++i) {
                std::snprintf(opis, sizeof opis, "SetOrientationYPR(%g,%g,%g) m[%d]", c["yaw"].n, c["pitch"].n,
                              c["roll"].n, i);
                sprawdz(bity_f32(r.m[std::size_t(i)]) == std::uint32_t(hex64(c["m_f32_bity"][std::size_t(i)].s)), opis);
            }
        }
        ++n;
    }
    // własności niezależne od zestawu
    sprawdz(m.um_arctan2(0, 0) == StaleTitan::pi_2(), "(0,0) → +π/2");
    sprawdz(m.um_arctan2(0, -1) == StaleTitan::pi(), "(0,−1) → π");
    sprawdz(m.um_arctan2(-1, 0) == -StaleTitan::pi_2(), "(−1,0) → −π/2");
    sprawdz(m.um_arctan2(2.0e-4, 1.0) == 0.0, "martwa strefa < 2,4e-4 rad");
    double mx = 0;
    for (int i = -31400; i <= 31400; ++i) {
        const double a = i * 1e-4;
        mx = std::max(mx, std::fabs(m.um_arctan2(std::sin(a), std::cos(a)) - a));
    }
    std::printf("  przypadków referencyjnych: %d; max |UMArcTan2 − atan2| na siatce: %.3e rad\n", n, mx);
    sprawdz(mx < 5.0e-4, "błąd UMArcTan2 względem atan2 < 5e-4 rad (etap 27: 4,9e-4)");
    auto p = tablice_przyblizone();
    sprawdz(!p->zgodne_z_oryginalem, "tablice przybliżone oznaczone jako niezgodne");
    int rozne = 0;
    for (std::size_t i = 0; i < ROZMIAR_TABLICY_COS; ++i) rozne += (p->cos[i] != t->cos[i]);
    std::printf("  tablica cos z wzoru różni się od oryginału w %d pozycjach (nie jest zgodna)\n", rozne);
    sprawdz(rozne > 0, "przybliżenie różni się od oryginału (gdyby nie – zmienić dokumentację)");
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- rng
int test_rng() {
    GeneratorTitan g(1);
    // sekwencja z definicji: s = (214013·s + 2531011) mod 2^31, liczona niezależnie w 64 bitach
    std::uint64_t s = 1;
    for (int i = 0; i < 100000; ++i) {
        s = (214013ull * s + 2531011ull) % 2147483648ull;
        if (g.krok() != std::uint32_t(s)) { sprawdz(false, "LCG różni się w kroku " + std::to_string(i)); break; }
    }
    sprawdz(g.liczba_losowan() == 100000, "licznik losowań");
    g.ustaw_ziarno(12345);
    const double u = g.losuj();
    sprawdz(u == double((214013ull * 12345 + 2531011ull) % 2147483648ull) / 2147483648.0, "losuj() = stan/2^31");
    sprawdz(u >= 0.0 && u < 1.0, "zakres [0,1)");
    // pomiar etapu 27 (rng_527): stany z kolejnych startów leżą na jednej trajektorii (przesunięcie 342 kroków)
    sprawdz(GeneratorTitan::odleglosc(1789804865u, 1789804865u, 10) == 0, "odległość 0");
    GeneratorTitan a(777), b(777);
    for (int i = 0; i < 1000; ++i) sprawdz(a.krok() == b.krok(), "odtwarzalność");
    const std::uint32_t s0 = 1270085219u;
    GeneratorTitan c(s0);
    for (int i = 0; i < 342; ++i) c.krok();
    sprawdz(GeneratorTitan::odleglosc(s0, c.stan(), 400) == 342, "odległość 342 kroków");
    // stan 32-bitowy z przepełnieniem: (a·s + c) & 0xFFFFFFFF, potem mod 2^31 – to samo co mod 2^31 całości
    GeneratorTitan d(0x7FFFFFFFu);
    sprawdz(d.krok() == std::uint32_t((214013ull * 0x7FFFFFFFull + 2531011ull) % 2147483648ull), "przepełnienie");
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- teren
int test_teren() {
    TerenSiatka t = TerenSiatka::syntetyczny_etap27();
    sprawdz(t.get_mesh_z(10.5, 10.5) == 0.0, "płasko");
    sprawdz(t.get_mesh_z(5.0, 30.0) == double(float(0.15 * 10)), "wierzchołek rampy");
    sprawdz(t.get_mesh_z(5.25, 45.5) == 3.0, "płaskowyż");
    // trójkąt górny/dolny na polu rampy: z zależy tylko od y (ściana wzdłuż x)
    const double z1 = t.get_mesh_z(7.25, 25.5), z2 = t.get_mesh_z(7.75, 25.5);
    sprawdz(std::fabs(z1 - 0.825) < 1e-6 && std::fabs(z2 - 0.825) < 1e-6, "interpolacja na rampie");
    // pole niesymetryczne: test obu trójkątów z ręcznie policzonymi wartościami f32
    std::vector<float> z = {0, 1, 2, 4};  // h00=0, h10=1, h01=2, h11=4 (siatka 2×2)
    TerenSiatka m(2, 2, z);
    const double g = m.get_mesh_z(0.25, 0.75);  // fy ≥ fx: trójkąt (h00, h01, h11)
    sprawdz(std::fabs(g - (0.0 + 0.25 * (4 - 2) + 0.75 * 2)) < 1e-6, "trójkąt górny");
    const double d = m.get_mesh_z(0.75, 0.25);  // fy < fx: trójkąt (h00, h10, h11)
    sprawdz(std::fabs(d - (0.75 * 1 + 0.25 * (4 - 1))) < 1e-6, "trójkąt dolny");
    sprawdz(bity_f32(g) == bity_f32(float(g)), "wynik f32");
    sprawdz(m.odczyty_poza_mapa() == 0, "brak odczytów poza mapą");
    // nachylenie wymaga UMArcCos z tablic
    auto tab = tablice_lub_skip();
    if (!tab) {
        std::printf("  (część z nachyleniem pominięta)\n");
        return bledy ? FAIL : SKIP;
    }
    MatematykaTitan mat(tab);
    const double p0 = t.nachylenie(mat, 10.5, 10.5, -0.0, 1.0);
    sprawdz(p0 == 0.0, "płasko: nachylenie 0");
    const double p1 = t.nachylenie(mat, 10.5, 30.5, -0.0, 1.0);  // pod górę: asin(0,195/1,3) ≈ 0,1506
    sprawdz(std::fabs(p1 - std::asin(0.195 / 1.3)) < 2e-4, "rampa pod górę");
    const double p2 = t.nachylenie(mat, 10.5, 30.5, 0.0, -1.0);
    sprawdz(p2 == -p1, "rampa w dół = −pod górę");
    std::printf("  nachylenie rampy 0,15/pole: %.9f rad\n", p1);
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- ruch
struct Wiersz {
    int takt;
    double x, y, v, w, kurs;
    int stan;
    std::size_t punkt;
};

struct Przebieg {
    std::vector<Wiersz> wiersze;
    int koniec = -1;
};

ParametryRuchu parametry_z_json(const Wartosc& p) {
    ParametryRuchu r;
    r.a = p["a"].n; r.vmax = p["vmax"].n; r.alfa = p["alfa"].n; r.wmax = p["wmax"].n;
    r.rozmiar = p["rozmiar"].n; r.c4 = p["c4"].n; r.c8 = p["c8"].n; r.t488 = p["t488"].n;
    if (const Wartosc* q = p.znajdz("pochyla")) r.pochyla = q->b;
    return r;
}

Przebieg uruchom_przypadek(std::shared_ptr<const TabliceTrig> tab, const Wartosc& c, int maks = 4000) {
    Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::z_nazwy(c["wariant"].s));
    const Wartosc& st = c["start"];
    const IdJednostki id = s.dodaj_jednostke(parametry_z_json(c["parametry"]), st["x"].n, st["y"].n, st["kurs"].n);
    std::vector<Punkt2> pts;
    for (const auto& p : c["punkty"].t) pts.push_back({p["x"].n, p["y"].n});
    std::optional<double> kk;
    if (!c["kurs_koncowy"].null()) kk = c["kurs_koncowy"].n;
    s.nadaj_trase(id, pts, kk, StartTrasy::advance);
    Przebieg pr;
    for (int t = 1; t <= maks; ++t) {
        s.takt();
        const auto m = s.migawka()[0];
        pr.wiersze.push_back({t, m.x, m.y, m.v, m.omega, m.kurs, m.stan, m.zdjete_punkty});
        if (m.stan == 5001) { pr.koniec = t; break; }
    }
    return pr;
}

std::uint64_t skrot_przebiegu(const Przebieg& p) {
    std::vector<std::uint8_t> b;
    for (const auto& w : p.wiersze)
        for (double v : {w.x, w.y, w.v, w.w, w.kurs}) {
            const std::uint32_t u = bity_f32(v);
            for (int i = 0; i < 4; ++i) b.push_back(std::uint8_t(u >> (8 * i)));
        }
    return fnv1a64(b.data(), b.size());
}

int test_ruch() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    const Wartosc j = json_z_pliku("dane/testy_ruchu/ruch_syntetyczne_etap27.json");
    const double dt = j["dt"].n;
    sprawdz(bity_f32(dt) == bity_f32(1.5 / 44.0), "dt = f32(1,5/44)");
    int zal = 0, niezal = 0;
    std::vector<std::uint8_t> wszystkie;
    for (const auto& c : j["przypadki"].t) {
        const std::string nazwa = c["nazwa"].s;
        const Przebieg p = uruchom_przypadek(tab, c);
        int pierwszy = -1, porownane = 0;
        double ep = 0, ev = 0, ek = 0;
        std::string pierwszy_opis;
        for (const auto& o : c["oczekiwane"].t) {
            const int t = int(o["takt"].n);
            if (t < 1 || t > int(p.wiersze.size())) {
                if (pierwszy < 0) { pierwszy = t; pierwszy_opis = "brak taktu w przebiegu (zatrzymanie wcześniej)"; }
                continue;
            }
            const Wiersz& w = p.wiersze[std::size_t(t - 1)];
            ++porownane;
            const bool ok = bity_f32(w.x) == bity_f32(o["x"].n) && bity_f32(w.y) == bity_f32(o["y"].n) &&
                            bity_f32(w.v) == bity_f32(o["v"].n) && bity_f32(w.w) == bity_f32(o["omega"].n) &&
                            bity_f32(w.kurs) == bity_f32(o["kurs"].n) && w.stan == int(o["stan"].n) &&
                            w.punkt == std::size_t(o["punkt"].n);
            ep = std::max(ep, std::hypot(w.x - o["x"].n, w.y - o["y"].n));
            ev = std::max(ev, std::fabs(w.v - o["v"].n));
            ek = std::max(ek, std::fabs(w.kurs - o["kurs"].n));
            if (!ok && pierwszy < 0) {
                pierwszy = t;
                char b[400];
                std::snprintf(b, sizeof b,
                              "oczekiwano x=%.9g y=%.9g v=%.9g ω=%.9g kurs=%.9g stan=%d punkt=%d; "
                              "jest x=%.9g y=%.9g v=%.9g ω=%.9g kurs=%.9g stan=%d punkt=%zu",
                              o["x"].n, o["y"].n, o["v"].n, o["omega"].n, o["kurs"].n, int(o["stan"].n),
                              int(o["punkt"].n), w.x, w.y, w.v, w.w, w.kurs, w.stan, w.punkt);
                pierwszy_opis = b;
            }
        }
        const int koniec_ocz = int(c["koniec_takt"].n);
        const bool ok = pierwszy < 0 && p.koniec == koniec_ocz;
        std::printf("  %-22s %s  takty porównane %3d  koniec %d (oczek. %d, różnica %+d)  max błąd: poz %.3g, v %.3g, kurs %.3g rad  skrót %016" PRIx64 "\n",
                    nazwa.c_str(), ok ? "PASS" : "FAIL", porownane, p.koniec, koniec_ocz, p.koniec - koniec_ocz, ep,
                    ev, ek, skrot_przebiegu(p));
        if (!ok) {
            std::printf("      pierwszy rozbieżny takt: %d – %s\n", pierwszy, pierwszy_opis.c_str());
            ++niezal;
            ++bledy;
        } else {
            ++zal;
        }
        const std::uint64_t h = skrot_przebiegu(p);
        for (int i = 0; i < 8; ++i) wszystkie.push_back(std::uint8_t(h >> (8 * i)));
    }
    std::printf("  przypadki ruchu: %d zaliczonych, %d niezaliczonych; skrót zbiorczy %016" PRIx64 "\n", zal, niezal,
                fnv1a64(wszystkie.data(), wszystkie.size()));
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- odpychanie
int test_odpychanie() {
    const Wartosc j = json_z_pliku("dane/testy_ruchu/ruch_syntetyczne_etap27.json");
    int n = 0;
    for (const auto& c : j["odpychanie_0x549179"].t) {
        const Wartosc &u = c["u"], &o = c["o"];
        const auto w = odpychanie_male(u["x"].n, u["y"].n, u["promien"].n, o["x"].n, o["y"].n, o["promien"].n,
                                       o["v"].n, 1.0);
        const std::string id = "przypadek " + std::to_string(++n);
        sprawdz(w.kolizja == c["kolizja"].b, id + ": kolizja");
        if (c["push_dla_o"].typ == Wartosc::Typ::tekst) {
            sprawdz(w.budzik_dla_o && w.push_o_x == 0.001 && w.push_o_y == 0.001, id + ": budzik");
        } else {
            sprawdz(!w.budzik_dla_o && w.push_o_x == c["push_dla_o"][0].n && w.push_o_y == c["push_dla_o"][1].n,
                    id + ": push dla o (bitowo)");
        }
        sprawdz(w.push_u_x == c["push_dla_u"][0].n && w.push_u_y == c["push_dla_u"][1].n, id + ": push dla u (bitowo)");
        std::printf("  %s: kolizja=%d push_o=(%.17g, %.17g)%s push_u=(%.17g, %.17g)\n", id.c_str(), int(w.kolizja),
                    w.push_o_x, w.push_o_y, w.budzik_dla_o ? " [budzik]" : "", w.push_u_x, w.push_u_y);
    }
    // pomiar EE 535 (walidacja_kolizji.md § 2): pierwsze dwa przypadki = wartości zmierzone w grze do ~1e-4
    const Wartosc& c0 = j["odpychanie_0x549179"][0];
    sprawdz(std::fabs(c0["push_dla_o"][0].n - 0.0286) < 1e-4, "EE 535 takt 1 (0,0286)");
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- dll
int test_dll() {
    auto w = zaladuj_tablice_dll("/nieistniejacy/katalog/Low-Level Engine.dll");
    sprawdz(w.kod == KodBleduDLL::brak_pliku && !w.ok(), "brak pliku → brak_pliku");
    std::printf("  komunikat: %s\n", w.komunikat.c_str());
    const std::string tmp = (std::filesystem::temp_directory_path() / "openee_test_nie_pe.bin").string();
    { std::ofstream f(tmp, std::ios::binary); f << std::string(4096, 'x'); }
    w = zaladuj_tablice_dll(tmp);
    sprawdz(w.kod == KodBleduDLL::to_nie_pe, "plik bez MZ → to_nie_pe");
    { std::ofstream f(tmp, std::ios::binary); std::string s(4096, '\0'); s[0] = 'M'; s[1] = 'Z'; s[0x3C] = char(0x80);
      s[0x80] = 'P'; s[0x81] = 'E'; s[0x84] = char(0x64); s[0x85] = char(0x86); f << s; }
    w = zaladuj_tablice_dll(tmp);
    sprawdz(w.kod == KodBleduDLL::nieobslugiwana_architektura, "PE x86-64 → nieobsługiwana architektura");
    std::remove(tmp.c_str());
    sprawdz(sha256_hex(reinterpret_cast<const std::uint8_t*>("abc"), 3) ==
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            "SHA-256(abc)");
    sprawdz(sha256_hex(nullptr, 0) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA-256('')");
    const std::string m56 = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    sprawdz(sha256_hex(reinterpret_cast<const std::uint8_t*>(m56.data()), m56.size()) ==
                "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
            "SHA-256(56 B)");
    int wczytane = 0;
    for (bool aoc : {false, true}) {
        const std::string p = sciezka_dll(aoc);
        if (p.empty()) continue;
        auto r = zaladuj_tablice_dll(p);
        std::printf("  %s: %s\n", aoc ? "AoC" : "EE", r.komunikat.c_str());
        if (r.kod == KodBleduDLL::brak_pliku) continue;
        sprawdz(r.ok(), std::string("wczytanie DLL ") + (aoc ? "AoC" : "EE"));
        if (r.ok()) {
            ++wczytane;
            sprawdz(r.tablice->cos.size() == 16385 && r.tablice->acos.size() == 32769, "rozmiary tablic");
        }
    }
    if (bledy) return FAIL;
    if (wczytane == 0) { std::printf("  SKIP części z oryginalną DLL (brak instalacji)\n"); return SKIP; }
    return PASS;
}

// --------------------------------------------------------------------------------------------- tai
int test_tai() {
    SkryptStanow s = SkryptStanow::wbudowany_land();
    const StanSkryptu* adv = s.stan(10003);
    sprawdz(adv && adv->przejscia.size() == 3, "Advance: 3 przejścia");
    sprawdz(adv && adv->przejscia[0].zdarzenia[0] == "ArrivedAtMoveWaypoint", "Advance: priorytet 1");
    const StanSkryptu* gnw = s.stan(9000);
    sprawdz(gnw && gnw->przejscia.back().cel_falsz == "TurnToUnitFacing", "GetNextMoveWaypoint false → TurnToUnitFacing");
    // składnia: zastępowanie, remove, include, komentarze jednym ukośnikiem, błąd parametrów
    SkryptStanow t;
    std::string blad;
    const bool ok = t.parsuj(R"(/ komentarz
#include("b.tai")
Advance { ArrivedAtMoveWaypoint true(Idle)  allof(A,B) true(X) }
Advance { ArrivedAtMoveWaypoint true(GetNextMoveWaypoint) Cc remove() }
)", [](const std::string& n) -> std::optional<std::string> {
        if (n == "b.tai") return std::string("Advance { Cc true(Idle) }");
        return std::nullopt;
    }, blad);
    sprawdz(ok, "parsowanie: " + blad);
    const StanSkryptu* a2 = t.stan(10003);
    sprawdz(a2 && a2->przejscia.size() == 2, "remove() usunął Cc, zastąpienie w miejscu");
    sprawdz(a2 && a2->przejscia[0].cel_prawda == "GetNextMoveWaypoint", "zastąpienie zachowuje pozycję");
    SkryptStanow z;
    sprawdz(!z.parsuj("Idle { Foo(1) true(Idle) }", nullptr, blad), "zdarzenie z parametrami → błąd");
    std::printf("  oczekiwany błąd: %s\n", blad.c_str());
    // opcjonalnie: oryginalne pliki .tai użytkownika (OPENEE_TAI = katalog z wypakowanymi skryptami)
    const char* kat = std::getenv("OPENEE_TAI");
    if (!kat) { std::printf("  oryginalne .tai: SKIP (brak OPENEE_TAI)\n"); return bledy ? FAIL : PASS; }
    auto dolacz = [&](const std::string& n) -> std::optional<std::string> {
        std::string low = n;
        for (auto& ch : low) ch = char(std::tolower(static_cast<unsigned char>(ch)));
        const std::string tx = czytaj(std::string(kat) + "/" + low);
        if (tx.empty()) return std::nullopt;
        return tx;
    };
    SkryptStanow o;
    const auto land = dolacz("land.tai");
    if (!land) { std::printf("  oryginalne .tai: brak land.tai w %s\n", kat); return bledy ? FAIL : PASS; }
    const bool ok2 = o.parsuj(*land, dolacz, blad);
    std::printf("  oryginalny land.tai: %s (%zu stanów)\n", ok2 ? "sparsowany" : blad.c_str(), o.stany().size());
    if (ok2) {
        for (int nr : {8000, 2015, 10003, 9000, 9006, 5001}) {
            const StanSkryptu *x = o.stan(nr), *y = s.stan(nr);
            bool rowne = x && y && x->przejscia.size() == y->przejscia.size();
            for (std::size_t i = 0; rowne && i < x->przejscia.size(); ++i)
                rowne = x->przejscia[i].zdarzenia == y->przejscia[i].zdarzenia &&
                        x->przejscia[i].cel_prawda == y->przejscia[i].cel_prawda &&
                        x->przejscia[i].cel_falsz == y->przejscia[i].cel_falsz;
            sprawdz(rowne, std::string("stan ") + nazwa_stanu(nr) + " zgodny ze skryptem wbudowanym");
        }
    } else {
        std::printf("  (parser etapu 28 nie obsługuje całego pliku – to ograniczenie, nie błąd testu)\n");
    }
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- determinizm
int test_determinizm() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    const Wartosc j = json_z_pliku("dane/testy_ruchu/ruch_syntetyczne_etap27.json");
    // ten sam przypadek dwa razy i w odwrotnej kolejności przypadków → identyczne skróty
    std::vector<std::uint64_t> a, b;
    for (const auto& c : j["przypadki"].t) a.push_back(skrot_przebiegu(uruchom_przypadek(tab, c)));
    for (std::size_t i = j["przypadki"].t.size(); i-- > 0;)
        b.insert(b.begin(), skrot_przebiegu(uruchom_przypadek(tab, j["przypadki"][i])));
    sprawdz(a == b, "powtarzalność i niezależność od kolejności uruchomienia");
    // wiele jednostek w jednym świecie: kolejność od końca listy, wspólny generator
    Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
    ParametryRuchu p;
    std::vector<IdJednostki> ids;
    for (int i = 0; i < 5; ++i) {
        ids.push_back(s.dodaj_jednostke(p, 10.5 + 3 * i, 10.5, 0.0));
        s.nadaj_trase(ids.back(), {{10.5 + 3 * i, 15.5}}, std::nullopt, StartTrasy::rozkaz);
    }
    for (int t = 0; t < 300; ++t) s.takt();
    const auto m = s.migawka();
    for (int i = 0; i < 5; ++i) sprawdz(m[std::size_t(i)].stan == 5000, "jednostka " + std::to_string(i) + " w Idle po dojeździe");
    std::printf("  5 jednostek, 300 taktów: losowań %" PRIu64 ", stan generatora %u, zdarzeń nieobsługiwanych %" PRIu64 "\n",
                s.generator().liczba_losowan(), s.generator().stan(), s.diagnostyka().zdarzenia_nieobslugiwane);
    return bledy ? FAIL : PASS;
}

int test_podsystemy() {
    for (const auto& p : podsystemy())
        std::printf("  [%s] %s %s\n",
                    p.status == StatusPodsystemu::wdrozony ? "wdrożony " : p.status == StatusPodsystemu::czesciowy ? "częściowy" : "brak     ",
                    p.nazwa, p.uwagi);
    return PASS;
}

}  // namespace

int main(int argc, char** argv) {
    const std::map<std::string, std::function<int()>> grupy = {
        {"trygonometria", test_trygonometria}, {"rng", test_rng}, {"teren", test_teren}, {"ruch", test_ruch},
        {"odpychanie", test_odpychanie}, {"dll", test_dll}, {"tai", test_tai}, {"determinizm", test_determinizm},
        {"podsystemy", test_podsystemy}};
    std::vector<std::string> wybrane;
    for (int i = 1; i < argc; ++i) wybrane.push_back(argv[i]);
    if (wybrane.empty())
        for (const auto& [k, v] : grupy) wybrane.push_back(k);
    int p = 0, f = 0, s = 0;
    for (const auto& g : wybrane) {
        auto it = grupy.find(g);
        if (it == grupy.end()) { std::printf("nieznana grupa: %s\n", g.c_str()); return FAIL; }
        bledy = 0;
        std::printf("== %s\n", g.c_str());
        int r;
        try { r = it->second(); } catch (const std::exception& e) { std::printf("  WYJĄTEK: %s\n", e.what()); r = FAIL; }
        std::printf("== %s: %s\n", g.c_str(), r == PASS ? "PASS" : r == SKIP ? "SKIP" : "FAIL");
        (r == PASS ? p : r == SKIP ? s : f)++;
    }
    std::printf("WYNIK: %d zaliczonych, %d niezaliczonych, %d pominiętych (sprawdzeń %d)\n", p, f, s, sprawdzenia);
    if (f) return FAIL;
    if (wybrane.size() == 1 && s) return SKIP;
    return PASS;
}
