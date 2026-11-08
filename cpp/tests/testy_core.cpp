// OpenEE Core – testy natywne (etap 28). Uruchamianie: ctest (grupy jako osobne testy) albo
//   openee_tests <grupa>   grupy: trygonometria rng teren ruch odpychanie dll tai determinizm podsystemy
// Kody wyjścia: 0 = PASS, 1 = FAIL, 77 = SKIP (brak oryginalnej DLL). SKIP nie jest PASS.
#include <algorithm>
#include <array>
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
#include "openee/mapa.hpp"
#include "openee/walka.hpp"
#include "openee/maszyna_stanow.hpp"
#include "openee/nawigacja.hpp"
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


// --------------------------------------------------------------------------------------------- astar
int test_astar() {
    const Wartosc j = json_z_pliku("cpp/tests/dane/astar_referencja.json");
    int zal = 0, niezal = 0;
    for (const auto& c : j["przypadki"].t) {
        const int W = int(c["W"].n), H = int(c["H"].n);
        std::vector<char> blok(std::size_t(W) * std::size_t(H), 0);
        for (const auto& b : c["zablokowane"].t) blok[std::size_t(b[0].n) * std::size_t(H) + std::size_t(b[1].n)] = 1;
        std::map<std::pair<int, int>, int> kary;
        for (const auto& [k, v] : c["kara_pola"].o) {
            const auto przec = k.find(',');
            kary[{std::stoi(k.substr(0, przec)), std::stoi(k.substr(przec + 1))}] = int(v.n);
        }
        ParametryAStar p;
        p.limit_wywolania = int(c["limit_wywolania"].n);
        p.limit_calkowity = int(c["limit_calkowity"].n);
        p.reguly_naroznikow = c["naroza"].b;
        p.koniec_bez_testu_dostepnosci = c["bez_testu"].b;
        p.zapisz_przebieg = true;
        if (!kary.empty()) p.kara = [&](int x, int y) { auto it = kary.find({x, y}); return it == kary.end() ? 0 : it->second; };
        const auto w = AStarTitan::szukaj({int(c["start"][0].n), int(c["start"][1].n)}, {int(c["cel"][0].n), int(c["cel"][1].n)},
                                          [&](int x, int y) { return !blok[std::size_t(x) * std::size_t(H) + std::size_t(y)]; }, W, H, p);
        bool trasa_ok = w.trasa_od_celu.size() == c["trasa_od_celu"].t.size();
        for (std::size_t i = 0; trasa_ok && i < w.trasa_od_celu.size(); ++i)
            trasa_ok = w.trasa_od_celu[i].x == int(c["trasa_od_celu"][i][0].n) && w.trasa_od_celu[i].y == int(c["trasa_od_celu"][i][1].n);
        std::size_t rozb = std::size_t(-1);
        const auto& prz = c["przebieg"].t;
        for (std::size_t i = 0; i < std::max(prz.size(), w.przebieg.size()); ++i) {
            if (i >= prz.size() || i >= w.przebieg.size() || w.przebieg[i].x != int(prz[i][0].n) || w.przebieg[i].y != int(prz[i][1].n)) { rozb = i; break; }
        }
        const bool ok = trasa_ok && rozb == std::size_t(-1) && w.iteracje == int(c["iteracje"].n) &&
                        w.wywolania == int(c["wywolania"].n) && w.szukaj_najblizszego == c["f28"].b &&
                        w.zakonczenie == c["zakonczenie"].s;
        std::printf("  %-26s %s  iteracje %d (oczek. %d)  wywołania %d (%d)  trasa %zu pól %s  kolejność rozwijania %s\n",
                    c["nazwa"].s.c_str(), ok ? "PASS" : "FAIL", w.iteracje, int(c["iteracje"].n), w.wywolania,
                    int(c["wywolania"].n), w.trasa_od_celu.size(), trasa_ok ? "zgodna" : "RÓŻNA",
                    rozb == std::size_t(-1) ? "zgodna" : ("rozbieżna od węzła " + std::to_string(rozb)).c_str());
        (ok ? zal : niezal)++;
        if (!ok) ++bledy;
    }
    std::printf("  A*: %d zaliczonych, %d niezaliczonych\n", zal, niezal);
    sprawdz(AStarTitan::kubelek(0, 0) == 0 && AStarTitan::kubelek(3, 5) == (53 % 53 == 0 ? 0 : 53 % 53), "kubełek (3,5) = 53 mod 53 = 0");
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- astar na mapie z gry (lokalnie)
std::string katalog_lokalny() {
    const char* e = std::getenv("OPENEE_DANE_LOKALNE");
    return e ? e : "";
}

int test_astar_gra() {
    const std::string kat = katalog_lokalny();
    const std::string t = kat.empty() ? "" : czytaj(kat + "/astar_mapa_e24_lokalne.json");
    if (t.empty()) {
        std::printf("  SKIP: brak lokalnych danych mapy (OPENEE_DANE_LOKALNE/astar_mapa_e24_lokalne.json – nie publikowane)\n");
        return SKIP;
    }
    const Wartosc j = json_mini::Parser(t).parsuj();
    const int W = int(j["W"].n), H = int(j["H"].n);
    std::vector<char> d(std::size_t(W) * std::size_t(H), 0);
    for (const auto& k : j["dostepne"].t) {
        const auto p = k.s.find(',');
        d[std::size_t(std::stoi(k.s.substr(0, p))) * std::size_t(H) + std::size_t(std::stoi(k.s.substr(p + 1)))] = 1;
    }
    for (const auto& c : j["przypadki"].t) {
        const Pole s{int(c["start"][0].n), int(c["start"][1].n)}, g{int(c["cel"][0].n), int(c["cel"][1].n)};
        ParametryAStar p;
        p.limit_calkowity = 3000;
        const auto w = AStarTitan::szukaj(s, g, [&](int x, int y) { return d[std::size_t(x) * std::size_t(H) + std::size_t(y)] != 0; }, W, H, p);
        std::vector<Pole> tr(w.trasa_od_celu.rbegin(), w.trasa_od_celu.rend());
        const Wartosc& pg = c["pomiar_gry"];
        std::string opis;
        if (const Wartosc* tb = pg.znajdz("trasa_bez_startu")) {
            bool ok = tr.size() == tb->t.size() + 1;
            for (std::size_t i = 0; ok && i < tb->t.size(); ++i)
                ok = tr[i + 1].x == int((*tb)[i][0].n) && tr[i + 1].y == int((*tb)[i][1].n);
            sprawdz(ok, "trasa z gry " + c["nazwa"].s);
            opis += ok ? "trasa = gra; " : "trasa ≠ gra; ";
        }
        if (const Wartosc* it = pg.znajdz("iteracje")) {
            const bool ok = w.iteracje == int(it->n) && w.wywolania == int(pg["wywolania"].n);
            sprawdz(ok, "iteracje/wywołania z gry " + c["nazwa"].s);
            opis += "iteracje " + std::to_string(w.iteracje) + "/" + std::to_string(w.wywolania) + (ok ? " = gra; " : " ≠ gra; ");
        }
        const Wartosc& m = c["model_e24"];
        bool mod = tr.size() == m["trasa"].t.size();
        for (std::size_t i = 0; mod && i < tr.size(); ++i) mod = tr[i].x == int(m["trasa"][i][0].n) && tr[i].y == int(m["trasa"][i][1].n);
        sprawdz(mod, "trasa = model e24 " + c["nazwa"].s);
        std::printf("  przypadek %s: %s trasa %zu pól, model e24 %s\n", c["nazwa"].s.c_str(), opis.c_str(), tr.size(), mod ? "zgodny" : "RÓŻNY");
    }
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- import mapy (etap 30)
DaneTerenuScn mapa_syntetyczna(int A, int B) {
    DaneTerenuScn d;
    d.A = A; d.B = B;
    const std::size_t T = std::size_t(2 * A * B + A + B), V = std::size_t(2 * A * B + 3 * A + 3 * B + 1);
    d.tekstura.assign(T, 3); d.flagi.assign(T, 0); d.f10.assign(T, 0.0f);
    d.wysokosc.resize(V);
    for (std::size_t i = 0; i < V; ++i) d.wysokosc[i] = float(0.204 * double(i % 7));
    return d;
}

int test_mapa() {
    std::array<std::int16_t, 256> rodz;
    rodz.fill(-1);
    rodz[3] = 0; rodz[26] = 0; rodz[31] = 11; rodz[51] = 9;
    // 1. reguła terenu pola (import_mapy.md § 3)
    sprawdz(MapaTitan::teren_z_pola(3, 0, 0.0f, rodz) == 0, "ląd → rodzina tekstury");
    sprawdz(MapaTitan::teren_z_pola(26, 1, -0.408f, rodz) == 1, "woda f10 < −0,3 → 1");
    sprawdz(MapaTitan::teren_z_pola(26, 1, -0.204f, rodz) == 10, "woda płytka bez bitów → 10");
    sprawdz(MapaTitan::teren_z_pola(31, 0x0F, -0.204f, rodz) == 11, "płytka z ≥ 3 bitami 1–4 → rodzina (11)");
    sprawdz(MapaTitan::teren_z_pola(31, 0x0D, -0.204f, rodz) == 10, "płytka z 2 bitami → 10");
    sprawdz(MapaTitan::teren_z_pola(99, 0, 0.0f, rodz) == -1, "nieznana tekstura → −1");
    // 2. geometria rombu (A = B = 3 → 6 wierszy) i linie brzegu jak w EEMap (dla 140×140: 139, 419, 140)
    {
        auto d = mapa_syntetyczna(3, 3);
        const auto m = MapaTitan::z_scn(d, rodz);
        sprawdz(m.szerokosc() == 6 && m.brzeg_s1() == 2 && m.brzeg_s2() == 8 && m.brzeg_d() == 3, "romb 3×3: N 6, s1 2, s2 8, d 3");
        sprawdz(m.komorka_istnieje(2, 0) && m.komorka_istnieje(3, 0) && !m.komorka_istnieje(1, 0) && !m.komorka_istnieje(4, 0), "wiersz 0: kolumny 2–3");
        std::array<std::uint8_t, 16> dozw{};
        dozw.fill(1);
        m.siatka(dozw);
        auto& ob = const_cast<MapaTitan&>(m).obiekty();
        ob.push_back({1, 34, 1, 2, 2, 2.5, 2.5, 0.0, 2, true, true});
        const TerenSiatka s = m.siatka(dozw);
        sprawdz(!s.pole_przejezdne(2, 2) && !s.pole_przejezdne(3, 3) && (s.pole_przejezdne(4, 2) || !s.komorka_istnieje(4, 2)), "obiekt 2×2 blokuje pola X..X+1, Y..Y+1");
        sprawdz(!s.pole_przejezdne(2, 0), "pole na linii brzegu x + y = s1 nieprzejezdne");
        sprawdz(s.get_mesh_z(0.5, 0.5) == 0.0, "poza rombem: wysokość 0 (kafelek nie istnieje)");
    }
    // 3. dane lokalne: scenariusz z gry + zrzut pamięci (Riverlands_MCP mapa_zrzut) – eksport_mapy.py
    const std::string kat = katalog_lokalny();
    const std::string t = kat.empty() ? "" : czytaj(kat + "/mapa_troja_ee.json");
    if (t.empty()) {
        std::printf("  SKIP części lokalnej: brak OPENEE_DANE_LOKALNE/mapa_troja_ee.json (dane gry – nie publikowane)\n");
        return bledy ? FAIL : PASS;
    }
    const Wartosc j = json_mini::Parser(t).parsuj();
    DaneTerenuScn d;
    d.A = int(j["A"].n); d.B = int(j["B"].n);
    for (const auto& v : j["tekstura"].t) d.tekstura.push_back(std::uint8_t(v.n));
    for (const auto& v : j["flagi"].t) d.flagi.push_back(std::uint8_t(v.n));
    for (const auto& v : j["f10"].t) d.f10.push_back(float(v.n));
    for (const auto& v : j["wysokosc"].t) d.wysokosc.push_back(float(v.n));
    std::array<std::int16_t, 256> rd;
    rd.fill(-1);
    for (const auto& [k, v] : j["rodzina_tekstury"].o) rd[std::size_t(std::stoi(k))] = std::int16_t(v.n);
    MapaTitan m = MapaTitan::z_scn(d, rd);
    std::printf("  skrót mapy z SCN (reguła, bez obiektów) %016" PRIx64 " – ten sam musi dać importer GDScript (testy GDExtension)\n", m.skrot());
    const Wartosc& pm = j["pamiec"];
    const Wartosc& hd = pm["naglowek"];
    sprawdz(m.szerokosc() == int(hd["W"].n) && m.brzeg_s1() == int(hd["brzeg_s1"].n) && m.brzeg_s2() == int(hd["brzeg_s2"].n) &&
                m.brzeg_d() == int(hd["brzeg_d"].n),
            "szerokość i linie brzegu z SCN = EEMap z pamięci");
    std::vector<std::array<int, 3>> mt;
    for (const auto& [k, v] : pm["teren"].o) {
        const auto p = k.find(',');
        mt.push_back({std::stoi(k.substr(0, p)), std::stoi(k.substr(p + 1)), int(v.n)});
    }
    const auto st = m.porownaj_teren(mt);
    sprawdz(st.brakujacych == 0 && st.komorek == int(mt.size()), "każda komórka EEMap istnieje w rombie SCN");
    std::printf("  teren reguła vs pamięć: %d komórek, zgodnych %d (%.2f %%), różnych %d, w tym oznaczonych jako niepewne %d\n",
                st.komorek, st.zgodnych, 100.0 * st.zgodnych / std::max(1, st.komorek), st.roznych, st.niepewnych_roznych);
    // obiekty: pola z „Square occupied” (kwadrat od X, Y) vs listy komórek EEMap
    std::map<std::string, std::vector<std::pair<int, int>>> listy;   // id → pola z pamięci
    for (const auto& [k, v] : pm["obiekty_komorek"].o) {
        const auto p = k.find(',');
        for (const auto& o : v.t) listy[o[0].s].push_back({std::stoi(k.substr(0, p)), std::stoi(k.substr(p + 1))});
    }
    int zg = 0, rz = 0, por = 0;
    for (const auto& o : j["obiekty"].t) {
        char idb[16];
        std::snprintf(idb, sizeof idb, "0x%x", unsigned(o["id"].n));
        auto it = listy.find(idb);
        if (it == listy.end()) continue;
        const Wartosc* ty = j["typy"].znajdz(std::to_string(int(o["typ"].n)));
        if (!ty) continue;
        const int n = int((*ty)["kwadrat"].n), X = int(o["X"].n), Y = int(o["Y"].n);
        auto pola = it->second;
        std::sort(pola.begin(), pola.end());
        std::vector<std::pair<int, int>> oczek;
        for (int dx = 0; dx < n; ++dx)
            for (int dy = 0; dy < n; ++dy) oczek.push_back({X + dx, Y + dy});
        std::sort(oczek.begin(), oczek.end());
        ++por;
        (pola == oczek ? zg : rz)++;
    }
    std::printf("  pola obiektów (kwadrat od X, Y) vs listy komórek EEMap: %d porównanych, zgodnych %d, różnych %d (jednostki ruchome mogły zmienić pole)\n", por, zg, rz);
    sprawdz(por > 1000 && rz * 100 < por, "pola obiektów = listy komórek EEMap (≥ 99 %, różnice: jednostki w ruchu)");
    // wysokości: GetMeshZ z wierzchołków SCN vs z jednostek z pamięci gry
    std::array<std::uint8_t, 16> dozw{};
    for (std::size_t i = 0; i < 16 && i < j["teren_dozwolony"]["422"].t.size(); ++i) dozw[i] = std::uint8_t(j["teren_dozwolony"]["422"][i].n);
    MapaTitan m_regula = m;                                                 // wariant: teren z reguły [W]
    for (const auto& [x, y, tv] : mt) m.ustaw_teren_z_pamieci(x, y, tv);   // dane referencyjne dla nawigacji
    for (const auto& o : j["obiekty"].t) {
        const Wartosc* ty = j["typy"].znajdz(std::to_string(int(o["typ"].n)));
        const Wartosc* tp = pm["typy"].znajdz(std::to_string(int(o["typ"].n)));
        ObiektMapy ob;
        ob.id = std::uint32_t(o["id"].n); ob.typ_db = int(o["typ"].n); ob.gracz = int(o["gracz"].n);
        ob.pole_x = int(o["X"].n); ob.pole_y = int(o["Y"].n);
        ob.kwadrat = ty ? int((*ty)["kwadrat"].n) : 1;
        ob.blokuje = tp && int((*tp)["blokuje"].n) != 0;
        m.obiekty().push_back(ob);
        m_regula.obiekty().push_back(ob);
    }
    const TerenSiatka s = m.siatka(dozw);
    const TerenSiatka s_reg = m_regula.siatka(dozw);
    int rozne_przej = 0;
    for (int y = 0; y < m.szerokosc(); ++y)
        for (int x = 0; x < m.szerokosc(); ++x) rozne_przej += s.pole_przejezdne(x, y) != s_reg.pole_przejezdne(x, y);
    std::printf("  przejezdność dla typu 422: teren z reguły vs z pamięci – różnych pól %d\n", rozne_przej);
    double emax = 0;
    int nz = 0;
    for (const auto& p : j["probki_z"].t) {
        emax = std::max(emax, std::fabs(s.get_mesh_z(p[0].n, p[1].n) - p[2].n));
        ++nz;
    }
    std::printf("  wysokość GetMeshZ(SCN) vs z jednostek z gry: %d próbek, błąd max %.6f\n", nz, emax);
    sprawdz(nz == 0 || emax < 1e-6, "wysokości SCN = siatka gry (GetMeshZ)");
    // nawigacja: przypadki etapu 24 na mapie zaimportowanej (teren z pamięci + obiekty ze SCN)
    const std::string t24 = czytaj(kat + "/astar_mapa_e24_lokalne.json");
    if (!t24.empty()) {
        const Wartosc j24 = json_mini::Parser(t24).parsuj();
        for (const auto& c : j24["przypadki"].t) {
            const Pole s0{int(c["start"][0].n), int(c["start"][1].n)}, g{int(c["cel"][0].n), int(c["cel"][1].n)};
            ParametryAStar p;
            p.limit_calkowity = 3000;
            const auto w = AStarTitan::szukaj(s0, g, [&](int x, int y) { return s.pole_przejezdne(x, y); }, m.szerokosc(), m.szerokosc(), p);
            const auto wr = AStarTitan::szukaj(s0, g, [&](int x, int y) { return s_reg.pole_przejezdne(x, y); }, m.szerokosc(), m.szerokosc(), p);
            std::vector<Pole> tr(w.trasa_od_celu.rbegin(), w.trasa_od_celu.rend());
            const bool ta_sama = wr.trasa_od_celu.size() == w.trasa_od_celu.size() && wr.iteracje == w.iteracje &&
                                 std::equal(wr.trasa_od_celu.begin(), wr.trasa_od_celu.end(), w.trasa_od_celu.begin(),
                                            [](const Pole& a, const Pole& b) { return a.x == b.x && a.y == b.y; });
            const Wartosc& pg = c["pomiar_gry"];
            std::string opis;
            if (const Wartosc* tb = pg.znajdz("trasa_bez_startu")) {
                bool ok = tr.size() == tb->t.size() + 1;
                for (std::size_t i = 0; ok && i < tb->t.size(); ++i) ok = tr[i + 1].x == int((*tb)[i][0].n) && tr[i + 1].y == int((*tb)[i][1].n);
                sprawdz(ok, "mapa z SCN: trasa z gry " + c["nazwa"].s);
                opis += ok ? "trasa = gra; " : "trasa ≠ gra; ";
            }
            if (const Wartosc* it = pg.znajdz("iteracje")) {
                const bool ok = w.iteracje == int(it->n) && w.wywolania == int(pg["wywolania"].n);
                sprawdz(ok, "mapa z SCN: iteracje/wywołania z gry " + c["nazwa"].s);
                opis += "iteracje " + std::to_string(w.iteracje) + "/" + std::to_string(w.wywolania) + (ok ? " = gra" : " ≠ gra");
            }
            std::printf("  mapa z SCN, przypadek %s: %s (%zu pól); teren z reguły: %s\n", c["nazwa"].s.c_str(), opis.c_str(), tr.size(),
                        ta_sama ? "ta sama trasa i iteracje" : "INNA trasa");
        }
    }
    std::printf("  skrót mapy %016" PRIx64 "\n", m.skrot());
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- walka (etap 30)
ParametryWalki gwardia_ee() {   // EEUnitClassUpgrade gwardii królewskiej Argos (zad. 565) [P]
    ParametryWalki p;
    p.hp_max = 215; p.atak = 15.0f; p.pancerz = {0, 6, 0, 0, 0, 0}; p.zasieg_max = 0.5f; p.pole_widzenia = 4.0f;
    p.przeladowanie_ms = 2000; p.rodzaj_ataku = 0; p.wiersz_celu = 0; p.klasa_trafienia = 13; p.rodzina_ataku = 48;
    p.opoznienie_trafienia_ms = 1122;   // pomiar 564: trafienie, gdy +0x2A0 = 878 (13/13 trafień)
    return p;
}

int test_walka() {
    const ParametryWalki g = gwardia_ee();
    // 1. wzór 0x61DE61: m = 2,1 (tablica 0x10, człowiek → komputer), w = 1 → 15·2,1 = 31,4999… (f32) → 31
    const auto o1 = oblicz_obrazenia(g, g, 2.1, 1.0);
    std::printf("  obrażenia gwardia→gwardia: m 2,1 → %.7f → %d; m 1,071 → %d\n", o1.przed_zaokragleniem, o1.obrazenia,
                oblicz_obrazenia(g, g, 1.071, 1.0).obrazenia);
    sprawdz(o1.obrazenia == 31, "m 2,1: 31 (f32: 2,1f·15 = 31,4999… → fistp 31; jak w grze)");
    sprawdz(oblicz_obrazenia(g, g, 1.071, 1.0).obrazenia == 16, "m 1,071: 16 (jak w grze)");
    ParametryWalki pancerna = g;
    pancerna.pancerz[0] = 40.0f;
    sprawdz(oblicz_obrazenia(g, pancerna, 1.0, 1.0).obrazenia == 1, "pancerz > atak: minimum 1");
    sprawdz(oblicz_obrazenia(g, g, 0.0, 1.0).zerowy_mnoznik, "m·w = 0: brak trafienia");
    sprawdz(oblicz_obrazenia(g, g, 1.0, 1.0, 2.0).obrazenia == 30 && oblicz_obrazenia(g, g, 1.0, 1.0, 0.5).obrazenia == 8,
            "modyfikator wysokości r: max(r·d, d+1) / min(r·d, d−1) [W]");
    sprawdz(oblicz_obrazenia(g, g, 1.0, 1.0, 1.02).obrazenia == 16, "r = 1,02: d + 1 = 16 > r·d = 15,3");
    StanWalki st;
    st.hp = 20;
    sprawdz(!przyjmij_obrazenia(st, 15) && st.hp == 5 && przyjmij_obrazenia(st, 31) && st.hp == 0, "TakeDamage: HP ≥ 0, śmierć przy 0");
    sprawdz(wybor_tablicy_trafien(true, false, 0) == 2 && wybor_tablicy_trafien(false, true, 0) == 0 &&
                !wybor_tablicy_trafien(false, false, 0).has_value(),
            "wybór tablicy trafień: rozpoznane tylko człowiek↔komputer przy trudności 0");
    // 2. cykl: 60 taktów na atak (2000 ms, takty 34/35 ms)
    {
        UczestnikPojedynku a{g, {215, 0, 0, 0, false}, 2012, 2.1, 1.0, 0}, b{g, {215, 0, 0, 0, false}, 2012, 1.071, 1.0, 1000000};
        PojedynekTitan p(a, b);
        std::vector<std::uint64_t> ataki;
        for (int k = 0; k < 400; ++k) p.takt(34);
        for (const auto& e : p.zdarzenia()) if (e.rodzaj == "atak" && e.kto == 0) ataki.push_back(e.takt);
        sprawdz(ataki.size() >= 3 && ataki[1] - ataki[0] == 60 && ataki[2] - ataki[1] == 60, "cykl ataku 60 taktów (2000 ms + 1 takt na Reloaded → atak)");
        sprawdz(p.uczestnik(1).s.hp == 0 && p.uczestnik(1).stan == 6000, "7 trafień po 31 → śmierć (215 → 0)");
    }
    // 3. dane lokalne: pojedynek EE 564 (pomiar co takt)
    const std::string kat = katalog_lokalny();
    const std::string t = kat.empty() ? "" : czytaj(kat + "/pojedynek_564.json");
    if (t.empty()) {
        std::printf("  SKIP części lokalnej: brak OPENEE_DANE_LOKALNE/pojedynek_564.json (pomiar gry – nie publikowany)\n");
        return bledy ? FAIL : PASS;
    }
    const Wartosc j = json_mini::Parser(t).parsuj();
    UczestnikPojedynku a{g, {215, 0, 0, 0, false}, 2012, j["m"][0].n, j["w"][0].n, int(j["takty_do_pierwszego_ataku"][0].n)};
    UczestnikPojedynku b{g, {215, 0, 0, 0, false}, 2012, j["m"][1].n, j["w"][1].n, int(j["takty_do_pierwszego_ataku"][1].n)};
    PojedynekTitan p(a, b);
    const auto& pr = j["probki"].t;
    int rozne = 0, pierwszy = -1, por = 0;
    std::string opis;
    for (std::size_t k = 1; k < pr.size(); ++k) {
        p.takt(34);   // licznik +0x2A0 maleje o 34 ms na takt (int(1000·1,5/44)), niezależnie od zegara 34/35 ms [P]
        for (int i = 0; i < 2; ++i) {
            const Wartosc& g2 = pr[k][i == 0 ? "a" : "b"];
            const auto& u = p.uczestnik(i);
            const bool zg = u.s.hp == int(g2["hp"].n) && u.s.przeladowanie_ms == int(g2["r"].n) &&
                            (u.stan == int(g2["stan"].n) || (int(g2["stan"].n) == 6000 && u.stan == 6000));
            ++por;
            if (!zg) {
                ++rozne;
                if (pierwszy < 0) {
                    pierwszy = int(k);
                    char b2[200];
                    std::snprintf(b2, sizeof b2, "takt %zu jedn. %d: Core hp %d r %d stan %d | gra hp %d r %d stan %d", k, i, u.s.hp,
                                  u.s.przeladowanie_ms, u.stan, int(g2["hp"].n), int(g2["r"].n), int(g2["stan"].n));
                    opis = b2;
                }
            }
        }
    }
    std::printf("  pojedynek EE 564: %d porównań (HP, +0x2A0, stan), różnych %d%s%s\n", por, rozne, pierwszy < 0 ? "" : "; pierwszy: ",
                opis.c_str());
    sprawdz(rozne == 0, "pojedynek EE 564: HP, licznik przeładowania i stan co takt = gra");
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- test kroku (izolowane gałęzie)
int test_krok() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    MatematykaTitan mat(tab);
    TerenSiatka t = TerenSiatka::syntetyczny_etap27();
    t.ustaw_przejezdnosc(11, 10, false);   // ściana na prawo od (10,10)
    t.ustaw_przejezdnosc(11, 11, false);
    t.ustaw_przejezdnosc(10, 11, false);   // i nad
    KontekstFizyki k{mat, t, f32(1.5 / 44.0), 44.0 / 1.5};
    IdJednostki blok_w = 0;
    std::int64_t bx = -1, by = -1;
    k.srodek_w_polu = [&](std::int64_t ix, std::int64_t iy, IdJednostki) { return (ix == bx && iy == by) ? blok_w : 0; };
    auto u0 = [] { Jednostka u; u.id = 1; u.x = 10.9; u.y = 10.5; u.komorka_x = 10; u.komorka_y = 10; return u; };
    {   // 1. to samo pole
        Jednostka u = u0(); u.x = 10.95;
        sprawdz(FizykaLadowa::test_kroku(k, u, 10.9, 10.5) == WynikKroku::ok && u.x == 10.95, "to samo pole – OK");
    }
    {   // 2. pole przejezdne (w lewo)
        Jednostka u = u0(); u.komorka_x = 10; u.x = 9.95;
        sprawdz(FizykaLadowa::test_kroku(k, u, 10.05, 10.5) == WynikKroku::ok && u.x == 9.95, "pole przejezdne – OK");
    }
    {   // 3. pole (11,10) nieprzejezdne: cofnięcie x → ślizg wzdłuż y (zostaje na (10,10) z nowym y)
        Jednostka u = u0(); u.x = 11.05; u.y = 10.6;
        const auto w = FizykaLadowa::test_kroku(k, u, 10.95, 10.5);
        sprawdz(w == WynikKroku::slizg_wzdluz_y && u.x == 10.95 && u.y == 10.6, "ślizg wzdłuż y");
        sprawdz(u.licznik_blokady_ms > 0, "ślizg zwiększa +0x248");
    }
    {   // 4. ślizg wzdłuż x: (11,11) zablokowane, (10,11) zablokowane, (11,10) zablokowane → cofnięcie
        Jednostka u = u0(); u.x = 11.05; u.y = 11.05;
        const auto w = FizykaLadowa::test_kroku(k, u, 10.95, 10.95);
        sprawdz(w == WynikKroku::cofniety && u.x == 10.95 && u.y == 10.95, "wszystkie próby zawiodły – cofnięcie");
    }
    {   // 5. ślizg wzdłuż x: ruch w górę-lewo (9,11)? (9,11) wolne, (10,11) zablokowane → przekątna: boczne (10,11) ✗, (9,10) ✓ → OK
        Jednostka u = u0(); u.x = 9.95; u.y = 11.05;
        sprawdz(FizykaLadowa::test_kroku(k, u, 10.05, 10.95) == WynikKroku::ok, "przekątna z jedną komórką boczną wolną");
    }
    {   // 6. przekątna przez dwa zablokowane boczne: z (12,12) na (11,11)? użyj (12,10)/(12,11)… zbuduj: komórka (10,10)→(11,11) ✗
        TerenSiatka t2 = TerenSiatka::syntetyczny_etap27();
        t2.ustaw_przejezdnosc(11, 10, false);
        t2.ustaw_przejezdnosc(10, 11, false);
        KontekstFizyki k2{mat, t2, k.dt, k.tps};
        Jednostka u = u0(); u.x = 11.05; u.y = 11.05;
        const auto w = FizykaLadowa::test_kroku(k2, u, 10.95, 10.95);
        sprawdz(w != WynikKroku::ok && w != WynikKroku::slizg_wzdluz_x, "zakaz ścinania narożnika między dwiema przeszkodami");
        std::printf("  przekątna między przeszkodami: wynik %d, pozycja (%.3f, %.3f)\n", int(w), u.x, u.y);
    }
    {   // 7. środek innej jednostki w polu docelowym → +0x20C, +0x330 = 2, cofnięcie
        Jednostka u = u0(); u.x = 9.95;
        blok_w = 7; bx = 9; by = 10;
        const auto w = FizykaLadowa::test_kroku(k, u, 10.05, 10.5);
        sprawdz(w == WynikKroku::zablokowany_przez_jednostke && u.blokujacy == 7 && u.flaga_330 == 2 && u.x == 10.05,
                "jednostka blokująca: +0x20C, +0x330 = 2, cofnięcie");
        blok_w = 0;
    }
    {   // 8. poza mapą
        Jednostka u = u0(); u.x = -0.5; u.komorka_x = 0;
        sprawdz(FizykaLadowa::test_kroku(k, u, 0.2, 10.5) == WynikKroku::poza_mapa && u.x == 0.2, "brak komórki – cofnięcie");
    }
    {   // 9. linia brzegu rombu
        TerenSiatka t3 = TerenSiatka::syntetyczny_etap27();
        t3.ustaw_romb(21, 200, 200);  // x + y = 21
        KontekstFizyki k3{mat, t3, k.dt, k.tps};
        Jednostka u = u0(); u.x = 11.05; u.y = 10.5;  // (11,10): 11 + 10 = 21
        sprawdz(FizykaLadowa::test_kroku(k3, u, 10.95, 10.5) != WynikKroku::ok, "linia brzegu rombu nieprzejezdna");
    }
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- kolizje w takcie, kolejka, scenariusze
ParametryRuchu gwardia() { ParametryRuchu p; return p; }

int test_kolizje_takt() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    {   // ruchoma → stojąca tego samego rozmiaru: stojąca dostaje push i jest spychana, ruchoma dostaje budzik (ro ≤ ru)
        Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
        // stojąca większa (promień 0,55, jak Aleksander) tuż obok osi ruchu, środek w innym polu niż trasa
        ParametryRuchu duza = gwardia(); duza.promien_kolizji = 0.55; duza.rozmiar = 0.55;
        const auto a = s.dodaj_jednostke(gwardia(), 10.5, 10.5, 0.0);
        const auto b = s.dodaj_jednostke(duza, 11.0, 13.5, 0.0);
        s.rozkaz_ruchu(a, 10.5, 16.5);
        bool push_b = false, kontakt = false;
        double min_d = 1e9;
        for (int t = 0; t < 400; ++t) {
            s.takt();
            const auto* A = s.jednostka(a); const auto* B = s.jednostka(b);
            kontakt |= A->kontakty > 0;
            push_b |= (B->x != 11.0 || B->y != 13.5);
            min_d = std::min(min_d, std::hypot(A->x - B->x, A->y - B->y));
        }
        sprawdz(kontakt, "lista kontaktów odbudowana przy zmianie komórki");
        sprawdz(!push_b, "większa stojąca nie jest spychana (ro > ru → tylko budzik)");
        std::printf("  ruchoma→stojąca: min. odległość %.3f, kolizje %" PRIu64 ", kroki odpychania %" PRIu64 ", A koniec (%.3f, %.3f) stan %d, B (%.3f, %.3f)\n",
                    min_d, s.diagnostyka().kolizje, s.diagnostyka().kroki_odpychania, s.jednostka(a)->x, s.jednostka(a)->y,
                    s.jednostka(a)->stan, s.jednostka(b)->x, s.jednostka(b)->y);
        sprawdz(s.diagnostyka().kolizje > 0 && s.diagnostyka().kroki_odpychania > 0, "kolizje i odpychanie w takcie");
    }
    {   // reguła (a): cel na pozycji stojącej jednostki → v = 0, +0x330 = 8, koniec rozkazu
        Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
        const auto a = s.dodaj_jednostke(gwardia(), 10.5, 11.3, 0.0);
        s.dodaj_jednostke(gwardia(), 10.5, 12.0, 0.0);  // kontakt od startu (okno B obejmuje pole A)
        s.rozkaz_ruchu(a, 10.5, 12.0);
        int t_stop = -1;
        for (int t = 0; t < 300 && t_stop < 0; ++t) {
            s.takt();
            if (s.jednostka(a)->flaga_330 == 8) t_stop = t;
        }
        sprawdz(t_stop > 0 && s.diagnostyka().cele_zajete > 0, "reguła (a) „cel zajęty”");
        for (int t = 0; t < 20; ++t) s.takt();
        std::printf("  reguła (a): takt %d, pozycja (%.3f, %.3f), stan po 20 taktach %d\n", t_stop, s.jednostka(a)->x, s.jednostka(a)->y, s.jednostka(a)->stan);
        sprawdz(s.jednostka(a)->stan == 5000, "po regule (a) jednostka kończy rozkaz (9000 → 9006 → 5001 → 5000)");
    }
    {   // EE / AoC: ta sama sytuacja z odbudową kontaktów od nowej / starej pozycji [W]
        std::uint64_t h[2];
        for (int w = 0; w < 2; ++w) {
            Swiat s(tab, TerenSiatka::syntetyczny_etap27(), w ? WariantTitan::aoc() : WariantTitan::ee());
            const auto a = s.dodaj_jednostke(gwardia(), 10.5, 10.5, 0.0);
            const auto b = s.dodaj_jednostke(gwardia(), 10.5, 16.5, 3.14159265);
            s.rozkaz_ruchu(a, 10.5, 16.5);
            s.rozkaz_ruchu(b, 10.5, 10.5);
            std::vector<std::uint8_t> bytes;
            for (int t = 0; t < 300; ++t) {
                s.takt();
                for (const auto& m : s.migawka())
                    for (double v : {m.x, m.y}) { const auto u = bity_f32(v); for (int i = 0; i < 4; ++i) bytes.push_back(std::uint8_t(u >> (8 * i))); }
            }
            h[w] = fnv1a64(bytes.data(), bytes.size());
            std::printf("  czołowe %s: A (%.3f, %.3f) stan %d, B (%.3f, %.3f) stan %d, kolizje %" PRIu64 ", skrót %016" PRIx64 "\n",
                        w ? "AoC" : "EE", s.jednostka(a)->x, s.jednostka(a)->y, s.jednostka(a)->stan, s.jednostka(b)->x,
                        s.jednostka(b)->y, s.jednostka(b)->stan, s.diagnostyka().kolizje, h[w]);
        }
    }
    return bledy ? FAIL : PASS;
}

int test_kolejka() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
    const auto a = s.dodaj_jednostke(gwardia(), 10.5, 10.5, 0.0);
    sprawdz(s.rozkaz_ruchu(a, 10.5, 13.5), "rozkaz");
    sprawdz(s.jednostka(a)->stan == 8000 && s.jednostka(a)->kolejka_celow.size() == 1, "zwykły rozkaz → 8000, 1 cel");
    s.rozkaz_ruchu(a, 13.5, 13.5, std::nullopt, true);
    s.rozkaz_ruchu(a, 13.5, 10.5, std::nullopt, true);
    sprawdz(s.jednostka(a)->kolejka_celow.size() == 3 && s.jednostka(a)->stan == 8000, "Shift dopisuje na koniec, stan bez zmian");
    std::vector<std::pair<double, double>> konce;
    int poprz = 0;
    for (int t = 0; t < 2000; ++t) {
        s.takt();
        const auto* u = s.jednostka(a);
        if (u->stan == 5001 && poprz != 5001) konce.push_back({u->x, u->y});
        poprz = u->stan;
    }
    sprawdz(konce.size() == 3, "trzy cele wykonane po kolei");
    for (const auto& k : konce) std::printf("  koniec celu: (%.3f, %.3f)\n", k.first, k.second);
    if (konce.size() == 3)
        sprawdz(std::hypot(konce[0].first - 10.5, konce[0].second - 13.5) < 0.06 && std::hypot(konce[1].first - 13.5, konce[1].second - 13.5) < 0.06 &&
                std::hypot(konce[2].first - 13.5, konce[2].second - 10.5) < 0.06, "kolejność celów A → B → C");
    sprawdz(s.jednostka(a)->stan == 5000 && s.jednostka(a)->kolejka_celow.empty(), "pusta kolejka → Idle");
    // zwykły rozkaz w trakcie kolejki usuwa oczekujące (BO-4: aktywacja następnego przed wyczyszczeniem – nie odtwarzana)
    s.rozkaz_ruchu(a, 16.5, 16.5); s.rozkaz_ruchu(a, 17.5, 16.5, std::nullopt, true);
    s.rozkaz_ruchu(a, 12.5, 12.5);
    sprawdz(s.jednostka(a)->kolejka_celow.size() == 1, "zwykły PPM czyści kolejkę");
    // Shift bez celu = zwykły rozkaz
    Swiat s2(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
    const auto b = s2.dodaj_jednostke(gwardia(), 10.5, 10.5, 0.0);
    s2.rozkaz_ruchu(b, 12.5, 12.5, std::nullopt, true);
    sprawdz(s2.jednostka(b)->stan == 8000 && s2.jednostka(b)->kolejka_celow.size() == 1, "Shift bez celu = zwykły rozkaz");
    return bledy ? FAIL : PASS;
}

int test_scenariusze() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    struct Scen { const char* nazwa; std::vector<std::pair<int, int>> sciana; Punkt2 start, cel; };
    std::vector<std::pair<int, int>> mur, pulapka, zamkniety;
    for (int y = 6; y <= 14; ++y) mur.push_back({14, y});
    for (int x = 12; x <= 16; ++x) zamkniety.push_back({x, 30}), zamkniety.push_back({x, 34});
    for (int y = 30; y <= 34; ++y) zamkniety.push_back({12, y}), zamkniety.push_back({16, y});
    const Scen sc[] = {{"prosta trasa", {}, {10.5, 10.5}, {17.5, 10.5}},
                       {"przeszkoda – objazd ściany", mur, {10.5, 10.5}, {17.5, 10.5}},
                       {"zakręty (przekątna + prosta)", {}, {10.5, 10.5}, {18.5, 14.5}},
                       {"cel nieosiągalny (zamknięty)", zamkniety, {10.5, 25.5}, {14.5, 32.5}}};
    std::vector<std::uint8_t> wszystkie;
    for (const auto& c : sc) {
        TerenSiatka t = TerenSiatka::syntetyczny_etap27();
        for (const auto& [x, y] : c.sciana) t.ustaw_przejezdnosc(x, y, false);
        Swiat s(tab, t, WariantTitan::ee());
        const auto a = s.dodaj_jednostke(gwardia(), c.start.x, c.start.y, 0.0);
        s.rozkaz_ruchu(a, c.cel.x, c.cel.y);
        const auto trasa = s.jednostka(a)->trasa;
        bool przez_sciane = false;
        int koniec = -1;
        for (int k = 0; k < 3000 && koniec < 0; ++k) {
            s.takt();
            const auto* u = s.jednostka(a);
            for (const auto& [x, y] : c.sciana) przez_sciane |= (podloga(u->x) == x && podloga(u->y) == y);
            if (u->stan == 5000) koniec = k;
            const auto b = bity_f32(u->x) ^ (bity_f32(u->y) << 1);
            for (int i = 0; i < 4; ++i) wszystkie.push_back(std::uint8_t(b >> (8 * i)));
        }
        const auto* u = s.jednostka(a);
        std::printf("  %-30s trasa %zu pkt, A* %d it./%d wyw., koniec w takcie %d, pozycja (%.3f, %.3f), %s\n", c.nazwa, trasa.size(),
                    s.diagnostyka().ostatnia_trasa.iteracje, s.diagnostyka().ostatnia_trasa.wywolania, koniec, u->x, u->y,
                    przez_sciane ? "WESZŁA NA PRZESZKODĘ" : "bez wejścia na przeszkodę");
        sprawdz(!przez_sciane, std::string(c.nazwa) + ": bez wejścia na pola nieprzejezdne");
        sprawdz(koniec > 0, std::string(c.nazwa) + ": rozkaz zakończony");
    }
    {   // dwie jednostki do wspólnego celu
        Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
        const auto a = s.dodaj_jednostke(gwardia(), 10.5, 10.5, 0.0), b = s.dodaj_jednostke(gwardia(), 12.5, 10.5, 0.0);
        s.rozkaz_ruchu(a, 11.5, 15.5); s.rozkaz_ruchu(b, 11.5, 15.5);
        double min_d = 1e9;
        for (int k = 0; k < 600; ++k) { s.takt(); min_d = std::min(min_d, std::hypot(s.jednostka(a)->x - s.jednostka(b)->x, s.jednostka(a)->y - s.jednostka(b)->y)); }
        std::printf("  wspólny cel: A (%.3f, %.3f) stan %d, B (%.3f, %.3f) stan %d, min. odległość %.3f, cele zajęte %" PRIu64 "\n", s.jednostka(a)->x, s.jednostka(a)->y,
                    s.jednostka(a)->stan, s.jednostka(b)->x, s.jednostka(b)->y, s.jednostka(b)->stan, min_d, s.diagnostyka().cele_zajete);
        sprawdz(s.jednostka(b)->stan == 5000, "wspólny cel: pierwsza kończy rozkaz");
        // druga: brak kontaktu z jednostką na celu (lista budowana tylko przy zmianie komórki) → test kroku blokuje,
        // ObstacleDetected → 9002 (niezweryfikowany) w pętli. Zachowanie gry w tej sytuacji – [N], do pomiaru.
        std::printf("  wspólny cel – druga jednostka: stan %d, objazdy 9002: %" PRIu64 " (sytuacja [N])\n", s.jednostka(a)->stan,
                    s.diagnostyka().objazdy_niezweryfikowane);
    }
    std::printf("  skrót scenariuszy %016" PRIx64 " (regresja – nie porównanie z Titan)\n", fnv1a64(wszystkie.data(), wszystkie.size()));
    return bledy ? FAIL : PASS;
}

// --------------------------------------------------------------------------------------------- porównanie z pomiarami gry (lokalnie)
struct MetrykiPorownania {
    int n = 0, pierwszy = -1, rozne_stany = 0, porownane_stany = 0, rozne_punkty = 0, roznica_konca = 0;
    double ps = 0, pm = 0, vs = 0, vm = 0, ks = 0, km = 0;
};

int test_porownanie_gra() {
    auto tab = tablice_lub_skip();
    const std::string kat = katalog_lokalny();
    const std::string t = kat.empty() ? "" : czytaj(kat + "/serie_porownawcze.json");
    if (!tab || t.empty()) {
        if (t.empty()) std::printf("  SKIP: brak lokalnych serii pomiarowych (OPENEE_DANE_LOKALNE/serie_porownawcze.json – nie publikowane)\n");
        return SKIP;
    }
    const Wartosc j = json_mini::Parser(t).parsuj();
    // teren: wysokości wierzchołków z pamięci gry (EE, scenariusz testowy)
    int mx = 0, my = 0;
    for (const auto& [k, v] : j["teren"]["z"].o) {
        const auto p = k.find(',');
        mx = std::max(mx, std::stoi(k.substr(0, p)));
        my = std::max(my, std::stoi(k.substr(p + 1)));
    }
    std::vector<float> z(std::size_t(mx + 2) * std::size_t(my + 2), 0.0f);
    for (const auto& [k, v] : j["teren"]["z"].o) {
        const auto p = k.find(',');
        z[std::size_t(std::stoi(k.substr(p + 1))) * std::size_t(mx + 2) + std::size_t(std::stoi(k.substr(0, p)))] = float(v.n);
    }
    const TerenSiatka teren(mx + 2, my + 2, z);
    std::printf("  | Seria | Próbek | Pozycja śr / max | v śr / max | Kąt śr / max | Koniec ruchu | Pierwszy rozbieżny | Inny stan | Inny punkt | Core = model v4 |\n");
    for (const auto& c : j["serie"].t) {
        Swiat s(tab, teren, WariantTitan::z_nazwy(c["wariant"].s));
        const IdJednostki id = s.dodaj_jednostke(parametry_z_json(c["parametry"]), c["start"]["x"].n, c["start"]["y"].n, 0.0);
        Jednostka* u = s.jednostka(id);
        u->orientacja.m[1] = c["start"]["m01"].n;  // macierz startowa z pamięci (jak m0 w modelu v4)
        u->orientacja.m[4] = c["start"]["m11"].n;
        std::vector<Punkt2> pts;
        for (const auto& p : c["punkty"].t) pts.push_back({p["x"].n, p["y"].n});
        std::optional<double> kk;
        if (!c["kurs_koncowy"].null()) kk = c["kurs_koncowy"].n;
        s.nadaj_trase(id, pts, kk, StartTrasy::advance);
        std::map<int, Wiersz> mo;
        int ost_v = 0;
        for (int k = 1; k <= 4000; ++k) {
            s.takt();
            const auto m = s.migawka()[0];
            mo[k] = {k, m.x, m.y, m.v, m.omega, m.kurs, m.stan, m.zdjete_punkty};
            if (m.v > 0) ost_v = k;
            if (m.stan == 5001) break;
        }
        const std::size_t N = pts.size();
        MetrykiPorownania r;
        for (const auto& p : c["probki"].t) {
            const int m = int(p["takt"].n);
            auto it = mo.find(m);
            if (it == mo.end()) continue;
            const Wiersz& o = it->second;
            const double e = std::hypot(o.x - p["x"].n, o.y - p["y"].n), dv = std::fabs(o.v - p["v"].n);
            double dh = o.kurs - p["kurs"].n;
            while (dh > 3.14159265358979) dh -= 6.28318530717959;
            while (dh < -3.14159265358979) dh += 6.28318530717959;
            dh = std::fabs(dh) * 180.0 / 3.14159265358979;
            ++r.n; r.ps += e; r.pm = std::max(r.pm, e); r.vs += dv; r.vm = std::max(r.vm, dv); r.ks += dh; r.km = std::max(r.km, dh);
            if (!p["stan"].null()) { ++r.porownane_stany; r.rozne_stany += (int(p["stan"].n) != o.stan); }
            r.rozne_punkty += (std::size_t(p["punkt"].n) != std::min(o.punkt, N));
            if (r.pierwszy < 0 && (e > 1e-3 || dv > 1e-4)) r.pierwszy = m;
        }
        r.roznica_konca = ost_v - int(c["koniec_ruchu_takt"].n);
        const Wartosc& v4 = c["metryki_modelu_v4"];
        const bool zgodny = r.n == int(v4["n"].n) && std::fabs(r.ps / r.n - v4["ps"].n) < 1e-12 &&
                            std::fabs(r.pm - v4["pm"].n) < 1e-12 && r.roznica_konca == int(v4["dk"].n) &&
                            r.rozne_punkty == int(v4["rpk"].n);
        sprawdz(zgodny, c["nazwa"].s + ": metryki Core = metryki modelu v4 (ten sam algorytm)");
        std::printf("  | %s | %d | %.4f / %.4f | %.4f / %.3f | %.2f° / %.1f° | %+d | %s | %s | %d | %s |\n", c["nazwa"].s.c_str(), r.n,
                    r.ps / r.n, r.pm, r.vs / r.n, r.vm, r.ks / r.n, r.km, r.roznica_konca,
                    r.pierwszy < 0 ? "brak" : std::to_string(r.pierwszy).c_str(),
                    r.porownane_stany ? (std::to_string(r.rozne_stany) + "/" + std::to_string(r.porownane_stany)).c_str() : "–",
                    r.rozne_punkty, zgodny ? "tak" : "NIE");
    }
    if (const Wartosc* wj = j.znajdz("wielojednostkowe")) {
        for (const auto& c : wj->t) {
            Swiat s(tab, teren, WariantTitan::ee());
            std::vector<IdJednostki> ids;
            for (const auto& jj : c["jednostki"].t) {
                ids.push_back(s.dodaj_jednostke(parametry_z_json(c["parametry"]), jj["start"]["x"].n, jj["start"]["y"].n, 0.0));
                Jednostka* u = s.jednostka(ids.back());
                u->orientacja.m[1] = jj["start"]["m01"].n;
                u->orientacja.m[4] = jj["start"]["m11"].n;
            }
            const std::size_t T = c["jednostki"][0]["probki"].t.size();
            struct Akum { double ps = 0, pm = 0; int n = 0, pierwszy = -1, kont = 0, push = 0, stany = 0; };
            std::vector<Akum> ak(ids.size());
            std::uint64_t rng_gra = 0, rng_core0 = s.generator().liczba_losowan();
            for (std::size_t k = 1; k < T; ++k) {
                for (std::size_t i = 0; i < ids.size(); ++i) {
                    const Wartosc& jj = c["jednostki"][i];
                    if (!jj["takt_rozkazu"].null() && std::size_t(jj["takt_rozkazu"].n) == k) {
                        std::vector<Punkt2> pts;
                        for (const auto& p : jj["punkty"].t) pts.push_back({p["x"].n, p["y"].n});
                        s.nadaj_trase(ids[i], pts, std::nullopt, StartTrasy::rozkaz);
                    }
                }
                s.takt();
                const auto m = s.migawka();
                for (std::size_t i = 0; i < ids.size(); ++i) {
                    const Wartosc& p = c["jednostki"][i]["probki"][k];
                    const double e = std::hypot(m[i].x - p["x"].n, m[i].y - p["y"].n);
                    Akum& a = ak[i];
                    ++a.n; a.ps += e; a.pm = std::max(a.pm, e);
                    if (a.pierwszy < 0 && e > 1e-3) a.pierwszy = int(k);
                    if (std::getenv("OPENEE_DEBUG_POROWNANIE") && a.pierwszy >= 0 && int(k) < a.pierwszy + 40 && int(k) % 4 == 0) {
                        const auto* uu = s.jednostka(ids[i]);
                        std::printf("      [%zu] takt %zu core (%.3f,%.3f) v %.3f st %d kont %u 20C %u 248 %.0f pkt %zu | gra (%.3f,%.3f) v %.3f st %d kont %d\n", i, k, m[i].x, m[i].y, m[i].v, m[i].stan,
                                    uu->kontakty, uu->blokujacy, uu->licznik_blokady_ms, uu->zdjete_punkty, p["x"].n, p["y"].n, p["v"].n, int(p["stan"].n), int(p["kontakty"].n));
                    }
                    a.kont += ((s.jednostka(ids[i])->kontakty > 0) != (p["kontakty"].n > 0));
                    a.push += 0;  // push zerowany w tym samym takcie w Core – porównanie przez licznik +0x248
                    a.push += ((s.jednostka(ids[i])->licznik_blokady_ms > 0) != (p["k248"].n > 0));
                    a.stany += (m[i].stan != int(p["stan"].n));
                }
            }
            const auto& rr = c["rng"].t;
            for (std::size_t k = 1; k < rr.size(); ++k)
                rng_gra += std::uint64_t(std::max<std::int64_t>(0, GeneratorTitan::odleglosc(std::uint32_t(rr[k - 1].n), std::uint32_t(rr[k].n), 500)));
            std::printf("  %s (%zu taktów):\n", c["nazwa"].s.c_str(), T - 1);
            for (std::size_t i = 0; i < ids.size(); ++i)
                std::printf("    %s: pozycja śr %.4f / max %.4f, pierwszy rozbieżny takt %d, takty z inną obecnością kontaktów %d, z innym +0x248>0 %d, z innym stanem %d\n",
                            c["jednostki"][i]["id"].s.c_str(), ak[i].ps / ak[i].n, ak[i].pm, ak[i].pierwszy, ak[i].kont, ak[i].push, ak[i].stany);
            std::printf("    RNG: gra %" PRIu64 " kroków LCG, Core %" PRIu64 " (Core nie odtwarza losowań AI i innych systemów)\n", rng_gra,
                        s.generator().liczba_losowan() - rng_core0);
        }
    }
    std::printf("  (Zgodność z grą oceniana metrykami; PASS oznacza tylko, że porównanie wykonano i Core = model v4.)\n");
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
        {"odpychanie", test_odpychanie}, {"dll", test_dll}, {"tai", test_tai}, {"determinizm", test_determinizm}, {"astar", test_astar}, {"porownanie_gra", test_porownanie_gra}, {"krok", test_krok}, {"kolizje_takt", test_kolizje_takt}, {"kolejka", test_kolejka}, {"scenariusze", test_scenariusze}, {"astar_gra", test_astar_gra}, {"mapa", test_mapa}, {"walka", test_walka},
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
