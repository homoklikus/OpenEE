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
#include "openee/ulepszenia.hpp"
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

// --------------------------------------------------------------------------------------------- walka w Swiat (etap 31)
TerenSiatka teren_z_mapy_json(const Wartosc& j, const std::string& typ) {
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
    if (const Wartosc* pm = j.znajdz("pamiec"))
        for (const auto& [k, v] : (*pm)["teren"].o) {
            const auto p = k.find(',');
            m.ustaw_teren_z_pamieci(std::stoi(k.substr(0, p)), std::stoi(k.substr(p + 1)), int(v.n));
        }
    for (const auto& o : j["obiekty"].t) {
        const Wartosc* ty = j["typy"].znajdz(std::to_string(int(o["typ"].n)));
        const Wartosc* tp = j.znajdz("pamiec") ? j["pamiec"]["typy"].znajdz(std::to_string(int(o["typ"].n))) : nullptr;
        ObiektMapy ob;
        ob.id = std::uint32_t(o["id"].n); ob.typ_db = int(o["typ"].n);
        ob.pole_x = int(o["X"].n); ob.pole_y = int(o["Y"].n);
        ob.kwadrat = ty ? int((*ty)["kwadrat"].n) : 1;
        ob.blokuje = tp && int((*tp)["blokuje"].n) != 0;
        m.obiekty().push_back(ob);
    }
    std::array<std::uint8_t, 16> dz{};
    dz.fill(1);
    if (const Wartosc* td = j.znajdz("teren_dozwolony"))
        if (const Wartosc* t = td->znajdz(typ))
            for (std::size_t i = 0; i < 16 && i < t->t.size(); ++i) dz[i] = std::uint8_t((*t)[i].n);
    return m.siatka(dz);
}
ParametryWalki gwardia_ee_pelna() {   // + pola typu z odczytu 575/578 [P]
    ParametryWalki p = gwardia_ee();
    p.luk_ataku = 0.3490658700466156f; p.kat_broni = 0.0f; p.rozmiar = 0.5f; p.punktowy = true; p.szukanie_ms = 2000;
    p.zasieg_min = 0.0f; p.pole_ac = 0.6000000238418579f; p.typ_bazy = 422;
    p.typ_jednostki = 5;   // typ +0x4B4 [P: odczyt 575/587]
    return p;
}
std::array<WagiCelu, 3> wagi_ee_575() {   // [0x8CFA28] → 3 rekordy, odczyt 575/578 [P]
    return {WagiCelu::z_rekordu({2, 1, 50, 1, 1, 0, 1, 50, -500, 50}), WagiCelu::z_rekordu({15, 20, 30, 6, 6, 0, 1, 2, -500, 15}),
            WagiCelu::z_rekordu({10, 15, 50, 4, 4, 0, 1, 0, -500, 15})};
}
TabliceObrazen tablice_syntetyczne() {   // wartości gwardii z odczytu 566 (klasa 13, rodzina 48) – reszta pominięta
    TabliceObrazen t;
    t.mnozniki.assign(16, {1, 1, 1, 1, 1, 1});
    std::vector<float> w(64, 0.0f);
    w[48] = 1.071f; t.trafienie[0][13] = w;
    w[48] = 1.5f; t.trafienie[1][13] = w;
    w[48] = 2.1f; t.trafienie[2][13] = w;
    return t;
}
void stan_jednostki_z_json(Swiat& sw, IdJednostki id, const Wartosc& j, const Wartosc& pw,
                           const std::map<std::string, IdJednostki>& mapa_id) {
    Jednostka& u = *sw.jednostka(id);
    // orientacja: wartości m01/m11 z pamięci gry bitowo (macierz obrotu wokół z: m00 = m11, m10 = −m01) – odtworzenie
    // przez kurs zmieniało ostatnie bity i rozstrzygnięcie |Δkurs| = π (578 G1, takt 38)
    u.orientacja.m = {j["m11"].n, j["m01"].n, 0.0, -j["m01"].n, j["m11"].n, 0.0, 0.0, 0.0, 1.0};
    u.x = j["x"].n; u.y = j["y"].n;
    u.komorka_x = int(j["X"].n); u.komorka_y = int(j["Y"].n);
    u.v = j["v"].n; u.omega = j["w"].n;
    u.tryb = TrybRuchu(int(j["tryb"].n));
    u.stan = int(j["stan"].n);
    u.trasa.clear(); u.dl_przed.clear(); u.dl_po.clear(); u.zdjete_punkty = 0;
    double c = 0.0, px = u.x, py = u.y;
    for (const auto& q0 : j["trasa"].t) {
        const Punkt2 q{f32(q0[0].n), f32(q0[1].n)};
        u.dl_przed.push_back(f32(c));
        c += std::hypot(q.x - px, q.y - py);
        u.dl_po.push_back(f32(c));
        px = q.x; py = q.y;
        u.trasa.push_back(q);
    }
    u.trasa_gotowa = !u.trasa.empty();
    u.kolejka_celow.clear();
    for (const auto& c0 : j["cele"].t) {
        CelRuchu cr;
        cr.od_gracza = c0["od_gracza"].b;
        cr.x = c0["x"].n; cr.y = c0["y"].n;
        if (c0["rodzaj"].s == "jednostka") {
            cr.typ = TypCelu::jednostka;
            auto it = mapa_id.find(c0["cel_id"].s);
            cr.cel_jednostka = it == mapa_id.end() ? 0 : it->second;
            cr.pole_x = std::int64_t(c0["pole"][0].n); cr.pole_y = std::int64_t(c0["pole"][1].n);
        } else {
            cr.typ = TypCelu::miejsce;
            if (const Wartosc* o = c0.znajdz("obrot"); o && o->b) cr.kurs_koncowy = c0["kat"].n;
        }
        u.kolejka_celow.push_back(cr);
    }
    if (!u.kolejka_celow.empty()) {
        u.cel = u.kolejka_celow.front().typ;
        u.cel_od_gracza = u.kolejka_celow.front().od_gracza;
        u.kurs_koncowy = u.kolejka_celow.front().kurs_koncowy;
    } else {
        u.cel = TypCelu::brak;
    }
    ParametryWalki p;
    p.hp_max = int(pw["hp"].n); p.atak = float(pw["atak"].n);
    for (std::size_t i = 0; i < 6; ++i) p.pancerz[i] = float(pw["pancerz"][i].n);
    p.zasieg_max = float(pw["zasieg_max"].n); p.pole_widzenia = float(pw["pole_widzenia"].n); p.obszar = float(pw["obszar"].n);
    p.przeladowanie_ms = int(pw["przeladowanie_ms"].n); p.rodzaj_ataku = int(pw["rodzaj_ataku"].n);
    p.wiersz_celu = int(pw["wiersz_celu"].n); p.klasa_trafienia = int(pw["klasa_trafienia"].n);
    p.rodzina_ataku = int(pw["rodzina_ataku"].n); p.opoznienie_trafienia_ms = int(pw["opoznienie_trafienia_ms"].n);
    p.luk_ataku = float(pw["luk_ataku"].n); p.kat_broni = float(pw["kat_broni"].n); p.rozmiar = float(pw["rozmiar"].n);
    p.rozmiar_jeden = pw["rozmiar_jeden"].b; p.punktowy = pw["punktowy"].b; p.szukanie_ms = int(pw["szukanie_ms"].n);
    p.zasieg_min = float(pw["zasieg_min"].n); p.pole_ac = float(pw["pole_ac"].n); p.typ_bazy = int(pw["typ_bazy"].n);
    if (const Wartosc* tj = pw.znajdz("typ_jednostki")) p.typ_jednostki = int(tj->n);   // typ +0x4B4 (etap 32)
    p.reszta_przeladowania_bez_spoczynku = pw["reszta_przeladowania_bez_spoczynku"].b;
    sw.ustaw_walke(id, int(j["gracz"].n), j["czlowiek"].b, p, int(j["hp"].n));
    u.boj->s.przeladowanie_ms = int(j["r"].n);
    u.boj->szukanie_ms = int(j["szuk"].n);
    u.boj->animacja = int(j["anim"].n);
}

// Etap 34: szablony efektów i budynki z pliku narzędzia narzedzia/titan/efekty_obszaru.py (dane/testy_walki).
static void wczytaj_efekty(Swiat& sw, const Wartosc& j, int przesuniecie_x = 0, int przesuniecie_y = 0,
                           int tylko_gracz = -1) {
    for (const auto& t : j["szablony"].t) {
        SzablonEfektu s;
        s.id = int(t["id"].n); s.typ = int(t["typ"].n); s.ksztalt = int(t["ksztalt"].n); s.relacja = int(t["relacja"].n);
        s.rozmiar = float(t["rozmiar"].n); s.maks_morale = int(t["maks_morale"].n); s.wartosc_40 = int(t["wartosc_40"].n);
        for (const auto& z : t["zestaw"].t) s.zestaw.push_back(int(z.n));
        sw.dodaj_szablon_efektu(std::move(s));
    }
    if (const Wartosc* bud = j.znajdz("budynki"))
        for (const auto& b : bud->t) {
            if (tylko_gracz >= 0 && int(b["gracz"].n) != tylko_gracz) continue;
            Budynek x;
            x.typ_db = int(b["typ"].n); x.gracz = int(b["gracz"].n);
            x.pole_x = int(b["pole"][0].n) + przesuniecie_x; x.pole_y = int(b["pole"][1].n) + przesuniecie_y;
            x.rozmiar_pol = int(b["rozmiar"].n);
            x.x = float(b["srodek"][0].n + przesuniecie_x); x.y = float(b["srodek"][1].n + przesuniecie_y);
            std::vector<int> ef;
            for (const auto& e : b["efekty"].t) ef.push_back(int(e.n));
            sw.dodaj_budynek(x, ef);
        }
}

int test_morale() {
    // 1. elementy z kodu (EE 0x664214, 0x664BE9, 0x664E0B) – bez danych gry
    const ProstokatPol p0 = prostokat_zliczania(185.0f, 110.0f, 10.0f);
    const ProstokatPol p1 = prostokat_zliczania(185.5f, 110.5f, 10.0f);
    const ProstokatPol p2 = prostokat_zliczania(185.5f, 110.0f, 10.0f);
    const ProstokatPol p3 = prostokat_zliczania(185.25f, 110.5f, 10.0f);
    std::printf("  prostokąt domów: (185,110) x %d…%d y %d…%d; (185,5;110,5) x %d…%d; (185,5;110) x %d…%d; (185,25;110,5) x %d…%d\n",
                p0.x0, p0.x1, p0.y0, p0.y1, p1.x0, p1.x1, p2.x0, p2.x1, p3.x0, p3.x1);
    sprawdz(p0.x0 == 175 && p0.x1 == 194 && p0.y0 == 100 && p0.y1 == 119, "środek na rogu pola: [i − r, i + r − 1] (20 pól)");
    sprawdz(p1.x0 == 175 && p1.x1 == 195 && p1.y1 == 120, "środek w połowie pola (0,25 < u < 0,75 obu osi): [i − r, i + r] (21 pól)");
    sprawdz(p2.x1 == 194 && p3.x1 == 194, "warunek obu osi i ostre nierówności 0,25/0,75 (0x66429B…0x6642C8)");
    sprawdz(w_obszarze(1, 10.0f, 185.0f, 110.0f, 175.0f, 100.0f) && !w_obszarze(1, 10.0f, 185.0f, 110.0f, 174.99f, 110.0f) &&
                !w_obszarze(1, 10.0f, 185.0f, 110.0f, 185.0f, 120.01f) && w_obszarze(1, 10.0f, 185.0f, 110.0f, 194.0f, 119.0f),
            "kwadrat 0x664C00: |dx| ≤ r i |dy| ≤ r (granica włącznie)");
    sprawdz(efekty_rownowazne(5, 2) && efekty_rownowazne(6, 5) && efekty_rownowazne(5, 5) && !efekty_rownowazne(5, 1) &&
                !efekty_rownowazne(1, 3), "równoważne przy usuwaniu nadmiarowych: {2, 5, 6} i ten sam typ");

    auto tab = tablice_lub_skip();
    if (!tab) return bledy ? FAIL : SKIP;
    const Wartosc je = json_z_pliku("dane/testy_walki/efekty_e31_a_ee.json");
    const Wartosc ja = json_z_pliku("dane/testy_walki/efekty_e31_a_aoc.json");
    if (je.typ != Wartosc::Typ::obiekt || ja.typ != Wartosc::Typ::obiekt) {
        std::printf("  FAIL: brak dane/testy_walki/efekty_e31_a_*.json\n");
        return FAIL;
    }
    // 2. świat: budynki gracza 1 ze scenariusza e31_a (przesunięte o (−150, −90) na teren syntetyczny 60 × 60).
    //    Town Center (184,109) 2 × 2 → środek (185,110) = odczyt EEAEMoraleFromBuildings +0x08/+0x0C [P]; domy
    //    (182,113), (182,111), (181,112) w kwadracie TC; Capitol (177,127) z 4 domami (180–183, 128–129).
    const int DX = -150, DY = -90;
    const ParametryWalki g = gwardia_ee_pelna();   // typ 422 (Royal Guard) – w zestawie „People Morale 1”
    struct Swiatek {
        std::unique_ptr<Swiat> sw;
        IdJednostki w, poza, wrog, kap, granica;
    };
    auto zbuduj = [&](const Wartosc& j, int premia) {
        Swiatek s{std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27()), 0, 0, 0, 0, 0};
        s.sw->ustaw_premie_morale_wariantu(premia);
        wczytaj_efekty(*s.sw, j, DX, DY, 1);
        ParametryRuchu pr;
        UstawieniaAI ai;
        ai.szuka_wrogow = false;
        auto dodaj = [&](double x, double y, int gracz) {
            const IdJednostki id = s.sw->dodaj_jednostke(pr, x + DX, y + DY, 0.0);
            s.sw->ustaw_walke(id, gracz, gracz == 1, g, 215, ai);
            return id;
        };
        s.w = dodaj(176.4, 107.6, 1);        // 857 z 578: |dx| = 8,6 → w kwadracie TC
        s.poza = dodaj(164.5, 107.5, 1);     // 855: |dx| = 20,5 → poza
        s.wrog = dodaj(176.8, 106.1, 5);     // wróg w kwadracie TC – relacja 2 (sojusznik) → bez morale
        s.kap = dodaj(179.0, 119.5, 1);      // w kwadracie TC (|dy| = 9,5) i Capitolu (|dy| = 8,5 od 128)
        s.granica = dodaj(175.0, 110.0, 1);  // |dx| = 10 – granica włącznie
        return s;
    };
    {
        Swiatek s = zbuduj(je, 0);
        Swiat& sw = *s.sw;
        int pierwszy = -1;
        bool wczesniej_brak = true;
        for (int k = 1; k <= 60 && pierwszy < 0; ++k) {
            sw.takt();
            if (sw.diagnostyka().przebiegi_efektow > 0) pierwszy = k;
            if (pierwszy < 0) wczesniej_brak &= sw.poziomy_morale(*sw.jednostka(s.w)).empty();
        }
        std::printf("  pierwszy przebieg menedżera efektów: takt %d (akumulator f32 +0x9C += 34,0909 ≥ 2000)\n", pierwszy);
        sprawdz(pierwszy == 59 && wczesniej_brak, "przebieg efektów co 2000 ms: pierwszy w takcie 59 (58,67 taktu), przed nim brak morale");
        const auto pw = sw.poziomy_morale(*sw.jednostka(s.w));
        const auto pk = sw.poziomy_morale(*sw.jednostka(s.kap));
        const auto pg = sw.poziomy_morale(*sw.jednostka(s.granica));
        std::printf("  poziomy: 857 %s, 855 %zu efektów, wróg %zu, TC∩Capitol %s, granica %s\n",
                    pw.empty() ? "-" : std::to_string(pw[0]).c_str(), sw.poziomy_morale(*sw.jednostka(s.poza)).size(),
                    sw.poziomy_morale(*sw.jednostka(s.wrog)).size(), pk.empty() ? "-" : std::to_string(pk[0]).c_str(),
                    pg.empty() ? "-" : std::to_string(pg[0]).c_str());
        sprawdz(pw == std::vector<int>{2}, "TC: 3 domy w prostokącie, Max morale 2 (Scenarios +0) → poziom 2 = odczyt 857/858 [P]");
        sprawdz(sw.poziomy_morale(*sw.jednostka(s.poza)).empty(), "poza kwadratem TC (855, |dx| 20,5) – brak efektu = odczyt [P]");
        sprawdz(sw.poziomy_morale(*sw.jednostka(s.wrog)).empty(), "wróg w obszarze – relacja 2 (IsAlly) → brak = odczyt 0x5000ad3 [P]");
        // Capitol: w pierwszym przebiegu poziomy przed zliczeniem = 0 → zostaje pierwszy (TC); od drugiego – max(2, 4)
        sprawdz(pk.size() == 1, "dwa źródła morale → jeden efekt po usunięciu nadmiarowych (poziomy się nie sumują)");
        sprawdz(pg == std::vector<int>{2}, "granica kwadratu |dx| = 10 – w obszarze");
        for (int k = 0; k < 59; ++k) sw.takt();
        const auto pk2 = sw.poziomy_morale(*sw.jednostka(s.kap));
        std::printf("  drugi przebieg (przebiegi %" PRIu64 "): TC∩Capitol %s\n", sw.diagnostyka().przebiegi_efektow,
                    pk2.empty() ? "-" : std::to_string(pk2[0]).c_str());
        sprawdz(sw.diagnostyka().przebiegi_efektow == 2 && pk2 == std::vector<int>{4},
                "drugi przebieg: Capitol (4 domy, max 4) silniejszy od TC (2) → zostaje poziom 4");
        sprawdz(obrazenia_po_modyfikatorach(16, pw) == 13 && obrazenia_po_modyfikatorach(16, pk2) == 10,
                "obrażenia 16: poziom 2 → 13, poziom 4 → 16 − fistp(6,4) = 10");
        // przekroczenie granicy: jednostka wychodzi z obszaru – efekt zostaje do następnego przebiegu
        Jednostka* u = sw.jednostka(s.granica);
        u->x = f32(174.5 + DX);
        sw.takt();
        const bool nadal = sw.poziomy_morale(*u).size() == 1;
        while (sw.diagnostyka().przebiegi_efektow < 3) sw.takt();
        sprawdz(nadal && sw.poziomy_morale(*u).empty(), "wyjście z obszaru: efekt do najbliższego przebiegu, potem brak");
        // zniszczenie domów: przeliczenie gracza (vt[47]) przy usunięciu domu, nowy poziom po przebiegu
        std::vector<IdJednostki> domy;
        for (const auto& b : sw.budynki())
            if (b.typ_db == 37 && b.pole_y + 90 < 120) domy.push_back(b.id);
        sprawdz(domy.size() == 3, "3 domy przy TC");
        sw.usun_budynek(domy[0]);
        sw.usun_budynek(domy[1]);
        sprawdz(sw.poziomy_morale(*sw.jednostka(s.w)) == std::vector<int>{2}, "po zniszczeniu domów poziom bez zmian do przebiegu");
        while (sw.diagnostyka().przebiegi_efektow < 4) sw.takt();
        const auto pz = sw.poziomy_morale(*sw.jednostka(s.w));
        sprawdz(pz == std::vector<int>{1} && obrazenia_po_modyfikatorach(16, pz) == 14,
                "po przebiegu: 1 dom → poziom 1, obrażenia 16 → 14");
        // zmiana właściciela ostatniego domu → 0 domów gracza 1
        sw.zmien_wlasciciela_budynku(domy[2], 5);
        while (sw.diagnostyka().przebiegi_efektow < 5) sw.takt();
        const auto pzero = sw.poziomy_morale(*sw.jednostka(s.w));
        sprawdz(pzero == std::vector<int>{0} && obrazenia_po_modyfikatorach(16, pzero) == 16,
                "dom przejęty przez gracza 5: TC liczy domy swojego gracza (+0x18) → poziom 0 (efekt zostaje, bez redukcji)");
    }
    {   // 3. wariant gry Standard (+2): Max morale TC 2 + 2 = 4, 3 domy → 3
        Swiatek s = zbuduj(je, 2);
        for (int k = 0; k < 59; ++k) s.sw->takt();
        sprawdz(s.sw->poziomy_morale(*s.sw->jednostka(s.w)) == std::vector<int>{3},
                "„Alter max morale” wariantu Standard: max 4, 3 domy → poziom 3");
    }
    {   // 4. AoC: te same szablony i reguły (zestawy jednostek AoC zawierają dodatkowe typy) – ten sam wynik
        Swiatek s = zbuduj(ja, 0);
        for (int k = 0; k < 59; ++k) s.sw->takt();
        sprawdz(s.sw->poziomy_morale(*s.sw->jednostka(s.w)) == std::vector<int>{2} &&
                    s.sw->poziomy_morale(*s.sw->jednostka(s.poza)).empty(),
                "AoC (0x67B95B, 0x67C651, 0x553C59 – kod jak w EE): poziom 2 dla 857, brak dla 855 = odczyt 580 [P]");
    }
    {   // 5. świat bez budynków: brak efektów, przebiegi nie zmieniają stanu (regresja przypadków bez morale)
        Swiat sw(tab, TerenSiatka::syntetyczny_etap27());
        ParametryRuchu pr;
        const IdJednostki a = sw.dodaj_jednostke(pr, 10.5, 10.5, 0.0);
        sw.ustaw_walke(a, 1, true, g, 215);
        for (int k = 0; k < 200; ++k) sw.takt();
        sprawdz(sw.diagnostyka().przebiegi_efektow == 3 && sw.poziomy_morale(*sw.jednostka(a)).empty(),
                "bez budynków: 3 przebiegi w 200 taktach, żadnego efektu");
    }
    return bledy ? FAIL : PASS;
}

int test_walka_swiat() {
    // etap 33: morale z budynków w TakeDamage (0x6640BA) – wartości z gry [P]
    sprawdz(obrazenia_po_modyfikatorach(16, {2}) == 13 && obrazenia_po_modyfikatorach(15, {2}) == 12 &&
                obrazenia_po_modyfikatorach(42, {5}) == 21 && obrazenia_po_modyfikatorach(16, {}) == 16 &&
                obrazenia_po_modyfikatorach(16, {2, 0}) == 16 && obrazenia_po_modyfikatorach(16, {12}) == 0,
            "morale: 16→13, 15→12 (poziom 2), 42→21 (5); bez modyfikatora bez zmian; ostatni modyfikator wygrywa; poziom ≤ 10");

    // 1. elementy (wartości z kodu, bez gry): ocena celu, zasięg wręcz typów punktowych, przeładowanie AoC
    const ParametryWalki g = gwardia_ee_pelna();
    const auto w = wagi_ee_575();
    bool spec = false;
    const int o4 = ocena_celu(g, g, 0.5, 4.0, 2.1, false, w[0], spec);
    std::printf("  ocena celu gwardia→gwardia, d² = 4, m = 2,1: %d (fistp(50/4) = 12, fistp(2,1) = 2)\n", o4);
    sprawdz(o4 == 14 && !spec, "ocena 0x6399CA: 12 + 2 = 14 (zaokrąglenie do parzystej 12,5 → 12)");
    sprawdz(ocena_celu(g, g, 0.5, 0.2, 2.1, true, w[0], spec) == 2 + 50 + 250 + 2, "w zasięgu i atakuje mnie: 2 + 50 + 250 + 2");
    sprawdz(w_zasiegu_punktowy(0.7604 * 0.7604, 0.5, 0.5) && !w_zasiegu_punktowy(0.7605 * 0.7605, 0.5, 0.5),
            "zasięg wręcz 0x631501: próg (0,071 + 0,5 + 0,5)·1,42/2 = 0,7604");
    sprawdz(w_zasiegu_punktowy(0.6533 * 0.6533, 0.5, 0.5) && !w_zasiegu_punktowy(0.8017 * 0.8017, 0.5, 0.5),
            "zasięg wręcz zgodny z 564: wejście w 2012 przy 0,6533, brak przy 0,8017");
    sprawdz(przeladowanie_aoc(0.0, 0.8, 1.2, 2000) == 1600 && przeladowanie_aoc(0.5, 0.8, 1.2, 2000) == 2000,
            "przeładowanie AoC 0x5FEA22: lo·2000 przy r = 0, środek przedziału przy r = 0,5");
    // 2. świat syntetyczny: dwie gwardie (gracze 1 i 5), wykrycie, wybór celu, podejście, obrót, ataki, śmierć
    auto tab = tablice_lub_skip();
    if (!tab) return bledy ? FAIL : SKIP;
    auto pojedynek = [&](bool dwie_na_jedna) {
        Swiat sw(tab, TerenSiatka::syntetyczny_etap27());
        sw.ustaw_tablice_walki(tablice_syntetyczne(), wagi_ee_575());
        ParametryRuchu pr;
        const IdJednostki a = sw.dodaj_jednostke(pr, 10.5, 10.5, 0.0);
        const IdJednostki b = sw.dodaj_jednostke(pr, 13.5, 11.0, 0.0);
        sw.ustaw_walke(a, 1, true, g, 215);
        sw.ustaw_walke(b, 5, false, g, 215);
        IdJednostki c = 0;
        if (dwie_na_jedna) {
            c = sw.dodaj_jednostke(pr, 10.5, 12.0, 0.0);
            sw.ustaw_walke(c, 1, true, g, 215);
        }
        for (int k = 0; k < 1400; ++k) sw.takt();
        return std::make_tuple(std::move(sw), a, b, c);
    };
    {
        auto [sw, a, b, c] = pojedynek(false);
        (void)c;
        int wybory = 0, ataki = 0, trafienia = 0, zgony = 0;
        std::uint64_t h = 1469598103934665603ull;
        for (const auto& e : sw.zdarzenia_walki()) {
            wybory += e.rodzaj == "wybor_celu"; ataki += e.rodzaj == "atak"; trafienia += e.rodzaj == "trafienie";
            zgony += e.rodzaj == "smierc";
            h = (h ^ (e.takt * 31 + e.kto * 7 + std::uint64_t(e.wartosc))) * 1099511628211ull;
        }
        const auto* ua = sw.jednostka(a);
        const auto* ub = sw.jednostka(b);
        std::printf("  pojedynek syntetyczny: wybory %d, ataki %d, trafienia %d, zgony %d; HP %d / %d; skrót %016" PRIx64 "\n",
                    wybory, ataki, trafienia, zgony, ua->boj->s.hp, ub->boj->s.hp, h);
        sprawdz(wybory == 2 && zgony == 1 && ub->boj->s.hp == 0 && ub->stan == 6000 && ua->boj->s.hp == 215 - 7 * 16,
                "pojedynek w Swiat (model): obie jednostki wybierają cel same, 7 × 31 zabija B, A traci 7 × 16");
        sprawdz(h == 0x9ddaf83720646edbull, "pojedynek w Swiat: skrót zdarzeń stały (regresja modelu, Debug = Release)");
    }
    {
        auto [sw, a, b, c] = pojedynek(true);
        int wybory = 0;
        for (const auto& e : sw.zdarzenia_walki()) wybory += e.rodzaj == "wybor_celu";
        std::printf("  2 na 1 syntetyczne: wybory %d, HP A %d, B %d, C %d, takt śmierci B %" PRIu64 "\n", wybory,
                    sw.jednostka(a)->boj->s.hp, sw.jednostka(b)->boj->s.hp, sw.jednostka(c)->boj->s.hp,
                    [&] { for (const auto& e : sw.zdarzenia_walki()) if (e.rodzaj == "smierc") return e.takt; return std::uint64_t(0); }());
        sprawdz(wybory >= 3 && sw.jednostka(b)->boj->s.hp == 0, "2 na 1: obie gwardie gracza 1 wybierają B, B ginie");
    }
    // 3. dane lokalne: walka z gry (578, okna G1 i G3) – stan startowy z próbki, dalej Core sam
    const std::string kat = katalog_lokalny();
    const std::string tm = kat.empty() ? "" : czytaj(kat + "/mapa_troja_ee.json");
    if (tm.empty()) {
        std::printf("  SKIP części lokalnej: brak OPENEE_DANE_LOKALNE/mapa_troja_ee.json i walka_578_*.json (pomiar gry)\n");
        return bledy ? FAIL : PASS;
    }
    const Wartosc jm = json_mini::Parser(tm).parsuj();
    {   // etap 32: CompletedUnitFacing (0x614F52) na taktach 9006 z pomiarów EE/AoC (e30/e31): reguła |Δ| ≤ 1° f32 bez v, ω
        const std::string tp = czytaj(kat + "/e32_przejscia_9006.json");
        if (tp.empty()) {
            std::printf("  SKIP przejść 9006: brak e32_przejscia_9006.json (pomiar gry)\n");
        } else {
            const Wartosc jp = json_mini::Parser(tp).parsuj();
            MatematykaTitan mat(tab);
            int n = 0, zg = 0, zg_stara = 0;
            std::string wyjatki;
            for (const auto& c : jp["przypadki"].t) {
                Macierz3 o;
                o.m = {c["m11"].n, c["m01"].n, 0.0, -c["m01"].n, c["m11"].n, 0.0, 0.0, 0.0, 1.0};
                const bool nowa = Swiat::ukonczony_obrot(mat, o, c["kat"].n);
                const bool stara = c["v"].n == 0.0 && c["omega"].n == 0.0 &&
                                   std::fabs(c["kat"].n - mat.kurs_z_macierzy(o)) < 0.0175;   // reguła modelu v4 (etap 31)
                ++n;
                zg += nowa == c["przeszla"].b;
                zg_stara += stara == c["przeszla"].b;
                if (nowa != c["przeszla"].b) wyjatki += " " + c["plik"].s + ":" + c["id"].s + "@" + std::to_string(int(c["probka"].n));
            }
            std::printf("  CompletedUnitFacing na %d taktach 9006 z gry (EE/AoC): reguła 0x614F52 zgodna %d, reguła modelu v4 %d; wyjątki:%s\n",
                        n, zg, zg_stara, wyjatki.empty() ? " brak" : wyjatki.c_str());
            sprawdz(n > 0 && zg >= n - 1, "CompletedUnitFacing = |Δkurs| ≤ 1° (0x614F52) na pomiarach gry (≤ 1 wyjątek z innym przejściem)");
        }
    }
    for (const char* plik : {"walka_578_g1.json", "walka_578_g3.json", "walka_580_g1.json", "walka_590_g1.json", "walka_589_g3.json",
                             "walka_578_g3_e45.json", "walka_590_g1_e45.json"}) {
        const std::string tw = czytaj(kat + "/" + plik);
        if (tw.empty()) {
            std::printf("  SKIP %s: brak pliku\n", plik);
            continue;
        }
        const Wartosc j = json_mini::Parser(tw).parsuj();
        const bool aoc = j["wariant"].s == "aoc";
        // przeładowanie AoC 0x5FEA22 na prawdziwym ciągu LCG: wartość z gry musi powstać ze stanu generatora osiągalnego
        // w tym takcie (kroki od stanu z poprzedniej próbki do stanu z bieżącej)
        if (aoc) {
            const Wartosc* pa = j.znajdz("przeladowanie_aoc");
            const double lo = pa ? (*pa)["lo"].n : 0.8, hi = pa ? (*pa)["hi"].n : 1.2;
            int zg = 0, n = 0;
            for (const auto& e : j["wejscia_ataku"].t) {
                ++n;
                GeneratorTitan gl(std::uint32_t(e["rng_przed"].n));
                bool ok = false;
                for (int k = 0; k < 400 && !ok; ++k) {
                    const double r = gl.losuj();
                    ok = przeladowanie_aoc(r, lo, hi, 2000) == int(e["przeladowanie"].n);
                    if (gl.stan() == std::uint32_t(e["rng_po"].n)) break;
                }
                zg += ok;
            }
            std::printf("  %s: przeładowania AoC z ciągu LCG gry: %d / %d wejść w atak odtworzonych wzorem 0x5FEA22 (lo %.1f, hi %.1f)\n",
                        plik, zg, n, lo, hi);
            sprawdz(n > 0 && zg == n, "przeładowanie AoC = fistp(f32((lo + r·(hi − lo))·2000)) dla każdego ataku w pomiarze");
        }
        if (j["tabele"].typ != Wartosc::Typ::obiekt) {
            std::printf("  SKIP symulacji %s: pomiar bez tablic obrażeń wariantu %s (brak odczytu walka_tabele)\n", plik,
                        aoc ? "AoC" : "EE");
            continue;
        }
        const TerenSiatka ter = teren_z_mapy_json(jm, "422");
        Swiat sw(tab, ter, aoc ? WariantTitan::aoc() : WariantTitan::ee());
        TabliceObrazen to;
        to.trudnosc = int(j["tabele"]["trudnosc"].n);
        for (const auto& r : j["tabele"]["mnozniki"].t) {
            std::array<float, 6> a{};
            for (std::size_t i = 0; i < 6; ++i) a[i] = float(r[i].n);
            to.mnozniki.push_back(a);
        }
        const char* kl[3] = {"08", "0C", "10"};
        for (int t = 0; t < 3; ++t)
            for (const auto& [k, v] : j["tabele"]["trafienie"][kl[t]].o) {
                std::vector<float> f;
                for (const auto& x : v.t) f.push_back(float(x.n));
                to.trafienie[std::size_t(t)][std::stoi(k)] = f;
            }
        std::array<WagiCelu, 3> wg;
        for (int t = 0; t < 3; ++t) {
            std::vector<int> r;
            for (const auto& x : j["wagi"][std::size_t(t)].t) r.push_back(int(x.n));
            wg[std::size_t(t)] = WagiCelu::z_rekordu(r);
        }
        sw.ustaw_tablice_walki(to, wg);
        sw.ustaw_modyfikator_wysokosci(ModyfikatorWysokosci::z_gry(aoc));   // cfg z odczytu 587/588 [P]
        if (aoc) {   // granice losowania przeładowania [[0x92FCA8]+0x984/0x988] z pomiaru (odczyt 580/588 [P])
            const Wartosc* pa = j.znajdz("przeladowanie_aoc");
            sw.ustaw_przeladowanie_aoc(pa ? (*pa)["lo"].n : 0.8, pa ? (*pa)["hi"].n : 1.2);
        }
        std::map<std::string, IdJednostki> mid;
        for (const auto& u : j["start"].t) {
            const Wartosc& pr = j["parametry_ruchu"][u["typ"].s];
            ParametryRuchu p;
            p.a = pr["a"].n; p.vmax = pr["vmax"].n; p.alfa = pr["alfa"].n; p.wmax = pr["wmax"].n; p.rozmiar = pr["rozmiar"].n;
            p.c4 = pr["c4"].n; p.c8 = pr["c8"].n; p.t488 = pr["t488"].n;
            mid[u["id"].s] = sw.dodaj_jednostke(p, u["x"].n, u["y"].n, 0.0);
        }
        for (const auto& u : j["start"].t) stan_jednostki_z_json(sw, mid[u["id"].s], u, j["parametry_walki"][u["typ"].s], mid);
        // etap 34: morale liczone w Core z budynków scenariusza e31_a (TC, Capitol, domy – narzędzie
        // efekty_obszaru.py); wynik porównany z odczytem modyfikatorów (591/593, pole „morale” startu) [P]
        {
            wczytaj_efekty(sw, json_z_pliku(aoc ? "dane/testy_walki/efekty_e31_a_aoc.json" : "dane/testy_walki/efekty_e31_a_ee.json"));
            sw.odtworz_efekty_obszaru();
            int zg = 0, n = 0;
            std::string opis;
            for (const auto& u : j["start"].t) {
                std::vector<int> odczyt;
                if (const Wartosc* mo = u.znajdz("morale"))
                    for (const auto& x : mo->t) odczyt.push_back(int(x.n));
                const auto core = sw.poziomy_morale(*sw.jednostka(mid[u["id"].s]));
                ++n;
                zg += core == odczyt;
                opis += " " + u["id"].s + ":" + (core.empty() ? std::string("-") : std::to_string(core[0])) + "/" +
                        (odczyt.empty() ? std::string("-") : std::to_string(odczyt[0]));
            }
            std::printf("  %s: morale Core/gra%s\n", plik, opis.c_str());
            sprawdz(zg == n, std::string("morale z budynków w Core = odczyt modyfikatorów gry (") + plik + ")");
        }
        sw.generator().ustaw_ziarno(std::uint32_t(j["probki"][0]["rng"].n));
        const auto& pr = j["probki"].t;
        int por = 0, r_stan = 0, r_hp = 0, r_r = 0, r_cel = 0, r_kurs = 0, r_w = 0, r_poz = 0;
        double emax = 0, esum = 0, kmax = 0;
        std::string pierwszy;
        std::map<std::string, std::string> pierwsze;
        std::map<std::string, std::size_t> takt_pierwszej;
        std::map<std::string, std::pair<double, double>> poprz;   // pozycja Core z poprzedniego taktu
        std::map<std::string, std::array<int, 3>> poprz_l;
        std::map<std::string, double> poprz_w;                    // ω Core z poprzedniego taktu (etap 46)
        int spoznione_w = 0;        // stan, HP, +0x2A0 Core z poprzedniego taktu
        int spoznione = 0;
        // etap 46: rozkazy gracza z pomiaru (cel EEUGLocation z pochodzeniem 1 pojawiający się w oknie) – przed taktem
        std::multimap<std::size_t, const Wartosc*> rozk;
        if (const Wartosc* rz = j.znajdz("rozkazy"))
            for (const auto& r : rz->t) rozk.emplace(std::size_t(r["takt"].n), &r);
        for (std::size_t k = 1; k < pr.size(); ++k) {
            for (auto [it, kon] = rozk.equal_range(k); it != kon; ++it) {
                const Wartosc& r = *it->second;
                for (const auto& [ids, gid] : mid)
                    if (ids == r["id"].s) {
                        std::optional<double> kat;
                        if (const Wartosc* kw = r.znajdz("kat"); kw && kw->typ == Wartosc::Typ::liczba && r.znajdz("obrot") && r["obrot"].b) kat = kw->n;
                        sw.rozkaz_ruchu(gid, r["x"].n, r["y"].n, kat, false);
                    }
            }
            sw.takt();
            for (const auto& [ids, gid] : mid) {
                const Wartosc& g2 = pr[k]["j"][ids];
                const Jednostka& u = *sw.jednostka(gid);
                // etap 32: próbka spóźniona o takt (zegar gry odczytany po takcie, pola jednostki sprzed taktu – wyścig
                // odczytu z pamięci; 580 takt 35, 590 takty 8–9): pozycja gry = pozycja Core z poprzedniego taktu
                const auto pp = poprz.count(ids) ? poprz[ids] : std::make_pair(u.x, u.y);
                poprz[ids] = {u.x, u.y};
                if ((u.x != g2["x"].n || u.y != g2["y"].n) && std::fabs(pp.first - g2["x"].n) < 1e-6 &&
                    std::fabs(pp.second - g2["y"].n) < 1e-6) {
                    ++spoznione;
                    poprz_l[ids] = {u.stan, u.boj->s.hp, u.boj->s.przeladowanie_ms};
                    continue;
                }
                // etap 45: ten sam wyścig odczytu dla jednostki stojącej – próbka gry = próbka poprzednia (stan, HP, +0x2A0
                // bez zmian), a wartości Core z poprzedniego taktu = próbka gry; następna próbka gry „przeskakuje” 2 takty
                // [P: 641 – 578 G3 takt 111 (r 130, 130, 62), 590 G1 takt 328 (r 402, 402, 334)]
                {
                    const std::array<int, 3> lc{u.stan, u.boj->s.hp, u.boj->s.przeladowanie_ms};
                    const std::array<int, 3> lg{int(g2["stan"].n), int(g2["hp"].n), int(g2["r"].n)};
                    const auto pl = poprz_l.count(ids) ? poprz_l[ids] : lc;
                    poprz_l[ids] = lc;
                    const Wartosc& gp = pr[k - 1]["j"][ids];
                    const std::array<int, 3> lgp{int(gp["stan"].n), int(gp["hp"].n), int(gp["r"].n)};
                    if (lc != lg && pl == lg && lgp == lg && pl != lc) {
                        ++spoznione;
                        continue;
                    }
                }
                ++por;
                const double e = std::hypot(u.x - g2["x"].n, u.y - g2["y"].n);
                emax = std::max(emax, e);
                esum += e;
                std::string cel_core = "-";
                if (!u.kolejka_celow.empty() && u.kolejka_celow.front().typ == TypCelu::jednostka)
                    for (const auto& [s2, i2] : mid) if (i2 == u.kolejka_celow.front().cel_jednostka) cel_core = s2;
                const std::string cel_gry = g2["cel"].s.empty() ? "-" : g2["cel"].s;
                auto zap = [&](const char* co, bool roz, int& licz) {
                    if (!roz) return;
                    ++licz;
                    if (!pierwsze.count(co)) {
                        char b2[260];
                        std::snprintf(b2, sizeof b2, "takt %zu %s: Core stan %d hp %d r %d szuk %d cel %s (%.4f,%.4f) | gra stan %d hp %d r %d szuk %d cel %s (%.4f,%.4f)",
                                      k, ids.c_str(), u.stan, u.boj->s.hp, u.boj->s.przeladowanie_ms, u.boj->szukanie_ms, cel_core.c_str(), u.x, u.y,
                                      int(g2["stan"].n), int(g2["hp"].n), int(g2["r"].n), int(g2["szuk"].n), cel_gry.c_str(), g2["x"].n, g2["y"].n);
                        pierwsze[co] = b2;
                        takt_pierwszej[co] = k;
                    }
                };
                if (const char* dbg = std::getenv("OPENEE_DEBUG_WALKA"); dbg && ids == dbg && k < 400)
                    std::printf("    D %zu Core %d t%d (%.4f,%.4f) v %.4f k %.5f w %.4f tr %zu cel (%.4f,%.4f) | gra %d t%d (%.4f,%.4f) v %.4f k %.5f w %.4f\n", k, u.stan,
                                int(u.tryb), u.x, u.y, u.v, sw.matematyka().kurs_z_macierzy(u.orientacja), u.omega, u.pozostalo_punktow(),
                                u.kolejka_celow.empty() ? 0.0 : u.kolejka_celow.front().x,
                                u.kolejka_celow.empty() ? 0.0 : u.kolejka_celow.front().y, int(g2["stan"].n),
                                g2.znajdz("tryb") ? int(g2["tryb"].n) : -1, g2["x"].n, g2["y"].n, g2["v"].n,
                                g2.znajdz("kurs") ? g2["kurs"].n : 0.0, g2.znajdz("w") ? g2["w"].n : 0.0);
                zap("stan", u.stan != int(g2["stan"].n), r_stan);
                zap("hp", u.boj->s.hp != int(g2["hp"].n), r_hp);
                zap("przeladowanie", u.boj->s.przeladowanie_ms != int(g2["r"].n), r_r);
                zap("cel", cel_core != cel_gry, r_cel);
                zap("pozycja > 0,001", e > 1e-3, r_poz);
                if (const Wartosc* gk = g2.znajdz("kurs")) {   // etap 32: orientacja i ω (pomiar_core walka ≥ etap 32)
                    // etap 38: kurs gry w serii = math.atan2(−m01, m11) w f64 (pomiar_core.py) – porównanie z tą samą funkcją
                    // macierzy Core (std::atan2), nie z tablicowym UMArcTan2 (błąd tablic do 4,9·10⁻⁴ rad dawał pozorne
                    // „kurs > 0,0002” przy identycznych macierzach – dowód: 619/620 bitowo zgodne w m01/m11)
                    const double kc = std::atan2(-double(u.orientacja.m01()), double(u.orientacja.m11()));
                    const double dk = std::fabs(std::remainder(kc - gk->n, 2.0 * 3.14159265358979323846));
                    kmax = std::max(kmax, dk);
                    zap("kurs > 0,0002", dk > 2e-4, r_kurs);
                    // etap 46: wyścig odczytu tylko w ω (jednostka stoi, kurs bez zmian): ω gry = ω gry z poprzedniej próbki
                    // = ω Core z poprzedniego taktu, a ω Core bieżące inne – próbka spóźniona (to samo kryterium co wyżej)
                    const double wprev = poprz_w.count(ids) ? poprz_w[ids] : u.omega;
                    poprz_w[ids] = u.omega;
                    const Wartosc& gpw = pr[k - 1]["j"][ids];
                    const bool w_spozn = std::fabs(u.omega - g2["w"].n) > 1e-4 && gpw.znajdz("w") &&
                                         std::fabs(gpw["w"].n - g2["w"].n) <= 1e-4 && std::fabs(wprev - g2["w"].n) <= 1e-4;
                    if (w_spozn) ++spoznione_w;
                    else zap("omega", std::fabs(u.omega - g2["w"].n) > 1e-4, r_w);
                }
            }
        }
        std::printf("  %s: %d porównań; różne: stan %d, HP %d, +0x2A0 %d, cel %d; pozycja śr. %.4f maks. %.4f; trafień Core %" PRIu64 ", założeń [N] %" PRIu64 " (%s)\n",
                    plik, por, r_stan, r_hp, r_r, r_cel, esum / std::max(1, por), emax, sw.diagnostyka().trafienia,
                    sw.diagnostyka().zalozenia_walki, sw.diagnostyka().ostatnie_zalozenie.c_str());
        std::printf("    kurs: różnych %d (maks. %.5f rad), ω: różnych %d, pozycja > 0,001: %d; próbek gry spóźnionych o takt (pominięte): %d\n",
                    r_kurs, kmax, r_w, r_poz, spoznione);
        std::printf("    próbek ze spóźnionym tylko ω (pominięte w porównaniu ω): %d\n", spoznione_w);
        std::string naj;
        std::size_t tnaj = 0;
        for (const auto& [co, t] : takt_pierwszej)
            if (naj.empty() || t < tnaj) { naj = co; tnaj = t; }
        if (!naj.empty()) std::printf("    PIERWSZY ROZBIEŻNY TAKT: %zu (%s)\n", tnaj, naj.c_str());
        else std::printf("    PIERWSZY ROZBIEŻNY TAKT: brak w oknie\n");
        for (const auto& [co, opis] : pierwsze) std::printf("    pierwsza różnica (%s): %s\n", co.c_str(), opis.c_str());
    }
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
    std::printf("  | Seria | Próbek | Pozycja śr / max | v śr / max | Kąt śr / max | Koniec ruchu | Pierwszy rozbieżny | Inny stan | Inny punkt | Core wobec v4 |\n");
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
        // etap 32: Core ma korekty z kodu Titan (przycięcie obrotu 0x548477, CompletedUnitFacing 0x614F52, tryb 4
        // 0x54DE35) – zamiast równości z modelem v4 wymagane: błąd pozycji i prędkości względem gry nie większy niż v4
        // etap 33: kryterium = pierwszy rozbieżny takt względem gry nie wcześniejszy niż w modelu v4 (metryki po pierwszej
        // rozbieżności są chaotyczne – AoC 525 1,9: +0,00002 pola po takcie 68, w którym rozjeżdżają się oba)
        const Wartosc& v4p = v4["first"];
        const bool pierwszy_ok = v4p.null() ? r.pierwszy < 0 : (r.pierwszy < 0 || r.pierwszy >= int(v4p.n));
        const bool nie_gorszy = r.n == int(v4["n"].n) && pierwszy_ok && r.rozne_punkty <= int(v4["rpk"].n);
        if (!(zgodny || nie_gorszy))
            std::printf("    %s: Core ps %.9f pm %.9f rpk %d | v4 ps %.9f pm %.9f rpk %d\n", c["nazwa"].s.c_str(), r.ps / r.n, r.pm,
                        r.rozne_punkty, v4["ps"].n, v4["pm"].n, int(v4["rpk"].n));
        sprawdz(zgodny || nie_gorszy, c["nazwa"].s + ": pierwszy rozbieżny takt względem gry nie wcześniejszy niż w modelu v4");
        std::printf("  | %s | %d | %.4f / %.4f | %.4f / %.3f | %.2f° / %.1f° | %+d | %s | %s | %d | %s |\n", c["nazwa"].s.c_str(), r.n,
                    r.ps / r.n, r.pm, r.vs / r.n, r.vm, r.ks / r.n, r.km, r.roznica_konca,
                    r.pierwszy < 0 ? "brak" : std::to_string(r.pierwszy).c_str(),
                    r.porownane_stany ? (std::to_string(r.rozne_stany) + "/" + std::to_string(r.porownane_stany)).c_str() : "–",
                    r.rozne_punkty, zgodny ? "tak" : (nie_gorszy ? "nie wcześniej" : "NIE"));
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

// Etap 47 – budynki jako obiekty Core, śmierć budynku, zmiana mapy i przyrostowa przebudowa grafu (0x4278C3).
namespace {
WejscieRegionow wejscie_syntetyczne(int N, const std::vector<std::array<int, 4>>& obiekty) {   // {id, x, y, n}
    WejscieRegionow w;
    w.N = N;
    w.rodzaj_pola.assign(std::size_t(N) * N, 0);
    w.wysokosc.assign(std::size_t(N) * N, 0);
    w.brzeg_e0 = w.brzeg_e1 = w.brzeg_e2 = -1000;
    for (const auto& o : obiekty)
        for (int dx = 0; dx < o[3]; ++dx)
            for (int dy = 0; dy < o[3]; ++dy) {
                ObiektPolaRegionu q;
                q.id = std::uint32_t(o[0]); q.hp = 500; q.gracz = 5; q.flaga600 = 1; q.klasa4b4 = 2;
                auto& l = w.obiekty[(o[1] + dx) * N + (o[2] + dy)];
                l.insert(l.begin(), q);
            }
    zbuduj_obszary(w);
    return w;
}
ParametryWalki dom_37() {   // odczyt pamięci domu gracza 5, zad. 647 [P]
    ParametryWalki p;
    p.hp_max = 500; p.pole_widzenia = 2.0f; p.wiersz_celu = 3; p.rodzaj_ataku = 3; p.klasa_trafienia = 3;
    p.rodzina_ataku = 9; p.rozmiar = 1.0f; p.typ_jednostki = 2; p.typ_bazy = 37; p.rozklad_ms = 2000;
    return p;
}
}  // namespace

int test_budynki() {
    // 1. przyrostowa przebudowa sektora bez świata: dom (pole (10,10)) dzieli sektor (1,1) na dwa podsektory (ląd + tryb 0xC)
    {
        WejscieRegionow w = wejscie_syntetyczne(21, {{0x500, 10, 10, 1}});
        GrafPodsektorow G = zbuduj_graf_z_wejscia(w, 7);
        const std::size_t n0 = G.podsektory.size();
        const auto lista = G.sektory[{1, 1}];
        std::printf("  graf: %zu podsektorów, sektor (1,1): %zu, maks id %d\n", n0, lista.size(), G.maks_id);
        sprawdz(n0 == 10 && lista.size() == 2, "9 sektorów lądu + pole domu jako osobny podsektor (region trybu 0xC)");
        for (auto& [i, l] : w.obiekty) for (auto& o : l) o.hp = 0;   // śmierć: HP = 0 (regiony – tylko HP > 0)
        const auto nowe = przebuduj_sektor(G, w, 7, 1, 1);
        std::printf("  po przebudowie: %zu podsektorów, nowe %zu (id %d), wolne %zu (id %d)\n", G.podsektory.size(), nowe.size(),
                    nowe.empty() ? -1 : nowe[0], G.wolne_id.size(), G.wolne_id.empty() ? -1 : G.wolne_id[0]);
        sprawdz(G.podsektory.size() == 9 && nowe.size() == 1 && nowe[0] == lista.back() && G.wolne_id.size() == 1 &&
                    G.wolne_id[0] == lista.front(), "0x42809D/0x425E8D: id zwolnione w kolejności listy sektora, nowe z końca listy wolnych");
        const GrafPodsektorow P = zbuduj_graf_z_wejscia(w, 7);
        bool rowny = true;
        for (const auto& [k, id] : P.pole_podsektor)
            if (G.podsektor_pola(k >> 32, k & 0xffffffff) < 0) { rowny = false; break; }
        int sas = 0, sas_p = 0;
        for (const auto& [id, p] : G.podsektory) sas += int(p.sasiedzi.size());
        for (const auto& [id, p] : P.podsektory) sas_p += int(p.sasiedzi.size());
        sprawdz(rowny && G.pole_podsektor.size() == P.pole_podsektor.size() && sas == sas_p,
                "podział pól i liczba krawędzi jak po pełnej przebudowie");
        bool stale = true;
        const GrafPodsektorow G0 = zbuduj_graf_z_wejscia(wejscie_syntetyczne(21, {{0x500, 10, 10, 1}}), 7);
        for (const auto& [id, p] : G0.podsektory)
            if (!(p.sektor_i == 1 && p.sektor_j == 1) && (!G.podsektory.count(id) || G.podsektory.at(id).punkt_x != p.punkt_x)) stale = false;
        sprawdz(stale, "podsektory innych sektorów: te same id i punkty reprezentatywne");
    }
    // 2. świat: gwardia niszczy dom (cel EEUGAttackUnit, obrażenia, Dying, kolejka fizyki, pola, termin i przebudowa)
    auto tab = tablice_lub_skip();
    if (!tab) return bledy ? FAIL : SKIP;
    auto tablice = [] {
        TabliceObrazen t = tablice_syntetyczne();
        std::vector<float> w(64, 0.0f);
        w[48] = 0.23562f; t.trafienie[0][3] = w;
        w[48] = 0.33f; t.trafienie[1][3] = w;
        w[48] = 0.462f; t.trafienie[2][3] = w;   // człowiek → komputer, klasa 3, rodzina 48 [P: walka_tabele]
        return t;
    };
    const ParametryWalki g = gwardia_ee_pelna();
    auto swiat = [&](int liczba_gwardii, int hp_domu, std::vector<IdJednostki>& gw, IdJednostki& dom) {
        auto sw = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        sw->ustaw_tablice_walki(tablice(), wagi_ee_575());
        ParametryRuchu pr;
        for (int i = 0; i < liczba_gwardii; ++i) {
            const IdJednostki a = sw->dodaj_jednostke(pr, 9.5 + i, 12.5, 3.14159265);
            sw->ustaw_walke(a, 1, true, g, 215);
            gw.push_back(a);
        }
        dom = sw->dodaj_obiekt_budynku(5, 37, 10, 10, 1, 10.5, 10.5, 0.0, dom_37(), hp_domu, true, 0x500, false);
        sw->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {{0x500, 10, 10, 1}}), 7);
        return sw;
    };
    std::vector<IdJednostki> gw;
    IdJednostki dom = 0;
    auto sw = swiat(1, 30, gw, dom);
    sprawdz(!sw->teren().pole_przejezdne(10, 10) && sw->teren().blokady(10, 10) == 1, "dom blokuje swoje pole (licznik blokad)");
    sprawdz(!sw->jednostka(dom)->w_fizyce, "żywy budynek poza kolejką fizyki [P: 645]");
    std::uint64_t t_smierci = 0, t_6001 = 0, t_6002 = 0, t_6003 = 0;
    std::vector<int> obrazenia;
    bool w_fizyce_po = false, przejezdne_przy_smierci = false, d8_przy_smierci = false, przebudowa_nast = false;
    std::uint32_t d4 = 0, zegar_smierci = 0;
    double z_po_1 = 0.0;
    for (int k = 0; k < 2000 && !t_6003; ++k) {
        const auto n0 = sw->zdarzenia_walki().size();
        sw->takt();
        for (std::size_t i = n0; i < sw->zdarzenia_walki().size(); ++i)
            if (sw->zdarzenia_walki()[i].rodzaj == "trafienie" && sw->zdarzenia_walki()[i].cel == dom)
                obrazenia.push_back(sw->zdarzenia_walki()[i].wartosc);
        const Jednostka* d = sw->jednostka(dom);
        if (!t_smierci && d->stan == 6000) {
            t_smierci = sw->takty(); zegar_smierci = sw->zegar_ms();
            przejezdne_przy_smierci = sw->teren().pole_przejezdne(10, 10);
            d8_przy_smierci = sw->przebudowa_zaplanowana(); d4 = sw->termin_przebudowy();
        } else if (t_smierci && sw->takty() == t_smierci + 1) {
            w_fizyce_po = d->w_fizyce && sw->jednostki().back().id == dom;
            przebudowa_nast = !sw->przebudowa_zaplanowana() && sw->przebudowy_sektorow() == 1;
            z_po_1 = d->z;
        }
        if (!t_6001 && d->stan == 6001) t_6001 = sw->takty();
        if (!t_6002 && d->stan == 6002) t_6002 = sw->takty();
        if (!t_6003 && d->stan == 6003) t_6003 = sw->takty();
    }
    sw->takt();
    std::printf("  obrażenia %zu × %d, śmierć w takcie %llu, 6001 +%llu, 6002 +%llu, 6003 +%llu, z po 1 takcie %.7f\n",
                obrazenia.size(), obrazenia.empty() ? -1 : obrazenia[0], (unsigned long long)t_smierci,
                (unsigned long long)(t_6001 - t_smierci), (unsigned long long)(t_6002 - t_6001), (unsigned long long)(t_6003 - t_6002), z_po_1);
    sprawdz(!obrazenia.empty() && obrazenia[0] == 7 && obrazenia.size() == 5, "gwardia sama wybiera dom; 15 · 0,462 = 6,93 → 7 HP (30 HP → 5 trafień)");
    sprawdz(przejezdne_przy_smierci && sw->teren().blokady(10, 10) == 0, "HP = 0 zwalnia pole od razu (martwy obiekt nie blokuje)");
    sprawdz(d8_przy_smierci && d4 == zegar_smierci + 1, "zgłoszenie zmiany mapy przy śmierci: +0xD4 = czas + 1 ms [P: 645/647]");
    sprawdz(w_fizyce_po, "budynek dodany do kolejki fizyki w następnym takcie, na koniec (przetwarzany pierwszy)");
    sprawdz(przebudowa_nast, "przebudowa jednego sektora w pierwszym takcie po terminie [P: 647 – +0xD8 = 0 w 52295]");
    sprawdz(std::fabs(z_po_1 - double(f32(0.0 - double(f32(1.5 / 44.0)) * double(f32(0.13))))) < 1e-9, "zapadanie się: z −= dt · 0,13 (0x54BF34)");
    sprawdz(t_6001 - t_smierci == 453 && t_6002 - t_6001 == 1 && t_6003 - t_6002 == 59,
            "Dying do z < −2,0 (0x601A4B: 452 kroki od z = 0, zdarzenie w kolejnym takcie), ResourcesRotting 1 takt, rozkład 2000 ms (59 taktów)");
    sprawdz(!sw->jednostka(dom)->w_fizyce, "Dead: poza kolejką fizyki w następnym takcie");
    sprawdz(sw->jednostka(gw[0])->stan == 5000 && sw->jednostka(gw[0])->kolejka_celow.empty(), "gwardia bez celu wraca do Idle (2025 → 5000)");
    // 3. atak grupowy: trzy gwardie, bez zakleszczeń, wszystkie w Idle po zniszczeniu
    {
        std::vector<IdJednostki> g3;
        IdJednostki d3 = 0;
        auto s3 = swiat(3, 60, g3, d3);
        int k = 0;
        for (; k < 3000 && s3->jednostka(d3)->stan != 6003; ++k) s3->takt();
        for (int i = 0; i < 5; ++i) s3->takt();
        bool idle = true;
        for (auto a : g3) idle = idle && s3->jednostka(a)->stan == 5000;
        int traf = 0;
        for (const auto& z : s3->zdarzenia_walki()) traf += z.rodzaj == "trafienie" && z.cel == d3;
        std::printf("  trzy gwardie: %d trafień, Dead po %d taktach\n", traf, k);
        sprawdz(idle && traf == 9 && k < 3000, "trzy gwardie: 60 HP / 7 = 9 trafień, po śmierci wszystkie w Idle");
    }
    // 4. dwa zgłoszenia w jednym takcie (dwa sektory): jeden sektor na przebieg, kolejny po 100 ms
    {
        auto s4 = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        s4->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {{0x500, 10, 10, 1}, {0x501, 3, 3, 2}}), 7);
        s4->takt();
        sprawdz(s4->usun_obiekt_mapy(0x500) && s4->usun_obiekt_mapy(0x501), "dwa obiekty usunięte w jednym takcie");
        const std::uint32_t t0 = s4->zegar_ms();
        const auto d4a = s4->termin_przebudowy();
        int k = 0;
        std::vector<std::uint64_t> przebiegi;
        for (; k < 20 && s4->przebudowa_zaplanowana(); ++k) { s4->takt(); przebiegi.push_back(s4->przebudowy_sektorow()); }
        std::printf("  dwa sektory: termin %u (t %u), %d taktów do końca\n", d4a, t0, k);
        sprawdz(d4a == t0 + 1 && s4->przebudowy_sektorow() == 2 && s4->przebudowy_grafu() == 1 && k == 4 && przebiegi[0] == 1,
                "jeden termin dla obu zgłoszeń, 2 przebiegi sektorów (drugi po +100 ms – 3 takty później), jedna zakończona przebudowa");
        s4->usun_obiekt_mapy(0x999);
        sprawdz(!s4->przebudowa_zaplanowana(), "brak obiektu – bez zgłoszenia");
    }
    // 5. budynek 2 × 2: śmierć zwalnia wszystkie 4 pola; ponowny start (nowy świat) przywraca blokady i graf
    {
        auto s5 = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        s5->ustaw_tablice_walki(tablice(), wagi_ee_575());
        ParametryWalki b = dom_37();
        b.hp_max = 1500;
        b.rozmiar = 2.0f;   // koszary 34: „Size of collider” 2,0 (+0x474) – miejsca podejścia poza obrysem 2 × 2
        ParametryRuchu pr;
        const IdJednostki a = s5->dodaj_jednostke(pr, 10.5, 13.5, 3.14159265);
        s5->ustaw_walke(a, 1, true, g, 215);
        const IdJednostki bar = s5->dodaj_obiekt_budynku(5, 34, 10, 10, 2, 11.0, 11.0, 0.0, b, 14, true, 0x600, false);
        s5->ustaw_gruz_budynku(bar, 362, 2);   // etap 48: koszary – „Debris on death#2” = 362 („Amb - Debris 2x”, 2 × 2)
        s5->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {{0x600, 10, 10, 2}}), 7);
        int bl0 = 0;
        for (int x = 10; x < 12; ++x) for (int y = 10; y < 12; ++y) bl0 += s5->teren().blokady(x, y);
        for (int k = 0; k < 600 && s5->jednostka(bar)->stan == 5000; ++k) s5->takt();
        int bl1 = 0;
        for (int x = 10; x < 12; ++x) for (int y = 10; y < 12; ++y) bl1 += s5->teren().blokady(x, y);
        sprawdz(bl0 == 4 && bl1 == 0 && s5->jednostka(bar)->stan == 6000, "2 × 2: 4 pola zablokowane, po śmierci wszystkie wolne");
        // etap 48 – pozostałość: obiekt mapy w takcie śmierci na 4 polach, na początku list pól, bez blokady i bez zgłoszenia
        {
            const auto& gz = s5->gruz();
            const auto* w = s5->wejscie_mapy();
            bool na_polach = w != nullptr;
            for (int x = 10; x < 12 && na_polach; ++x)
                for (int y = 10; y < 12 && na_polach; ++y) {
                    auto it = w->obiekty.find(x * w->N + y);
                    na_polach = it != w->obiekty.end() && !it->second.empty() && it->second.front().hp == 1 &&
                                gz.size() == 1 && it->second.front().id == gz[0].id;
                }
            const auto d4 = s5->termin_przebudowy();
            for (int k = 0; k < 10; ++k) s5->takt();
            sprawdz(gz.size() == 1 && gz[0].typ == 362 && gz[0].X == 10 && gz[0].Y == 10 && gz[0].kwadrat == 2 && na_polach &&
                        s5->teren().pole_przejezdne(10, 10) && s5->termin_przebudowy() == d4,
                    "gruz 362 (2 × 2) na polach budynku od taktu śmierci, przejezdny, bez dodatkowej przebudowy");
        }
        auto s6 = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        s6->dodaj_obiekt_budynku(5, 34, 10, 10, 2, 11.0, 11.0, 0.0, b, 14, true, 0x600, false);
        s6->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {{0x600, 10, 10, 2}}), 7);
        sprawdz(s6->teren().blokady(10, 10) == 1 && s6->graf_podsektorow().podsektory.size() == 10, "restart: blokady i graf jak przed zniszczeniem");
    }
    // 6. trasa: rozkaz przez pole domu – przed zniszczeniem objazd, po zniszczeniu (nowy rozkaz) przez zwolnione pole
    {
        auto s7 = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        for (int x = 3; x <= 17; ++x) if (x != 10) s7->teren_edycja().ustaw_przejezdnosc(x, 10, false);   // mur w y = 10
        ParametryRuchu pr;
        const IdJednostki a = s7->dodaj_jednostke(pr, 10.5, 13.5, 0.0);
        s7->ustaw_walke(a, 1, true, g, 215);
        const IdJednostki d7 = s7->dodaj_obiekt_budynku(5, 37, 10, 10, 1, 10.5, 10.5, 0.0, dom_37(), 7, true, 0x500, false);
        s7->rozkaz_ruchu(a, 10.5, 7.5);
        s7->takt();
        const auto przed = s7->jednostka(a)->trasa;
        bool przez = false;
        for (const auto& p : przed) przez = przez || (podloga(p.x) == 10 && podloga(p.y) == 10);
        s7->jednostka(d7)->boj->s.hp = 0;   // śmierć poza walką – tylko do testu trasy
        s7->teren_edycja().zdejmij_blokade(10, 10);
        s7->takt();
        const auto przed2 = s7->jednostka(a)->trasa;
        s7->rozkaz_ruchu(a, 10.5, 7.5);
        s7->takt();
        bool przez2 = false;
        for (const auto& p : s7->jednostka(a)->trasa) przez2 = przez2 || (podloga(p.x) == 10 && podloga(p.y) == 10);
        std::printf("  trasa przed: %zu punktów (przez pole domu: %d), po nowym rozkazie: %zu (przez pole: %d)\n", przed.size(),
                    int(przez), s7->jednostka(a)->trasa.size(), int(przez2));
        sprawdz(!przez && przez2 && przed2.size() == przed.size(), "stara trasa bez zmian po zmianie mapy; nowy rozkaz – przez zwolnione pole");
    }
    // 7. etap 48 – budynek postawiony w trakcie gry zamyka przejście: blokada od razu, zgłoszenie z terminem zwykłym,
    //    przebudowa sektora po terminie, nowy rozkaz omija pole; stara trasa bez zmian
    {
        auto s8 = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        s8->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {}), 7);
        const auto n0 = s8->graf_podsektorow().podsektory.size();
        s8->opoznienie_przebudowy_s = 0.0f;
        const std::uint32_t t0 = s8->termin_przebudowy();
        const IdJednostki d8 = s8->postaw_budynek(5, 37, 10, 10, 1, 10.5, 10.5, 0.0, dom_37(), 500, 0x700, 1, 2, 0);
        const bool blok = !s8->teren().pole_przejezdne(10, 10) && s8->przebudowa_zaplanowana();
        int k = 0;
        while (s8->przebudowa_zaplanowana() && k < 20) { s8->takt(); ++k; }
        const auto& G = s8->graf_podsektorow();
        std::printf("  postawiony: d8 %u blok %d plan %d przebiegi %llu podsektor(10,10) %d n0 %zu n %zu t0 %u k %d\n", unsigned(d8), int(blok),
                    int(s8->przebudowa_zaplanowana()), (unsigned long long)s8->przebudowy_sektorow(), G.podsektor_pola(10, 10), n0,
                    G.podsektory.size(), unsigned(t0), k);
        sprawdz(d8 > 0 && blok && !s8->przebudowa_zaplanowana() && s8->przebudowy_sektorow() == 1 &&
                    G.podsektor_pola(10, 10) != G.podsektor_pola(10, 11) && G.podsektory.size() == n0 + 1 && t0 == 0,
                "postawiony budynek: pole zablokowane od razu, zgłoszenie, jeden przebieg sektora, pole budynku – osobny podsektor (jak dom w 647 przed zniszczeniem)");
    }
    // 8. etap 49 – budynek (+0x2D8) na liście kontaktów: jednostka mijająca mur (rozmiar 0,9) w odległości < 0,7 jest
    //    odpychana (u.push −= 2·p, mur nieruchomy – bez przesunięcia); mur bez +0x2D8 („Collidable” 0) – brak kontaktu
    for (int wariant = 0; wariant < 2; ++wariant) {
        auto s9 = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        ParametryRuchu pr;
        pr.vmax = 0.5;
        ParametryWalki pm = dom_37();
        pm.rozmiar = 0.9f;
        pm.typ_bazy = 467;
        const IdJednostki mur = s9->dodaj_obiekt_budynku(1, 467, 10, 10, 1, 10.5, 10.5, 0.0, pm, 7000, true, 0x600, false,
                                                          wariant == 0);
        const IdJednostki a = s9->dodaj_jednostke(pr, 9.9, 12.5, 3.14159265);
        s9->rozkaz_ruchu(a, 9.9, 10.5);
        bool kontakt = false;
        double xmin = 9.9;
        for (int k = 0; k < 600; ++k) {
            s9->takt();
            const Jednostka* u = s9->jednostka(a);
            for (IdJednostki o : u->lista_kontaktow) kontakt |= (o == mur);
            xmin = std::min(xmin, u->x);
        }
        const Jednostka* m = s9->jednostka(mur);
        std::printf("  mur (+0x2D8 = %d): kontakt %d, kroki odpychania %llu, x min %.4f, mur (%.3f, %.3f)\n", int(wariant == 0),
                    int(kontakt), (unsigned long long)s9->diagnostyka().kroki_odpychania, xmin, m->x, m->y);
        if (wariant == 0)
            sprawdz(kontakt && s9->diagnostyka().kroki_odpychania > 0 && xmin < 9.899 && m->x == 10.5 && m->y == 10.5,
                    "budynek z +0x2D8 na liście kontaktów: odepchnięcie jednostki, budynek nieruchomy");
        else
            sprawdz(!kontakt && s9->diagnostyka().kroki_odpychania == 0, "budynek bez +0x2D8 („Collidable” 0) – poza listą kontaktów");
    }
    // 9. etap 49 – premia prędkości gracza (0x627030 + SetSpeed 0x628051) – prorok gracza 1 w 648–650 [P]
    {
        ParametryRuchu b;
        b.a = 2.0; b.vmax = 0.45; b.alfa = 12.21731; b.wmax = 13.96264;
        const ParametryRuchu r = z_premia_predkosci(b, PremiaAtrybutu{1, 0.1});
        const ParametryRuchu r0 = z_premia_predkosci(b, PremiaAtrybutu{0, 0.1});
        std::printf("  premia prędkości: vmax %.5f a %.5f α %.5f ωmax %.5f c4 %.5f c8 %.5f\n", r.vmax, r.a, r.alfa, r.wmax, r.c4, r.c8);
        auto blisko = [](double x, double y) { return std::fabs(x - y) < 2e-5; };
        sprawdz(blisko(r.vmax, 0.5) && blisko(r.a, 2.22222) && blisko(r.alfa, 13.57478) && blisko(r.wmax, 15.51404) &&
                    blisko(r.c4, 0.45) && blisko(r.c8, 0.07367) && r0.vmax == b.vmax,
                "1 poziom prędkości: 0,45 + max(0,045; 0,05) = 0,5; a, α, ωmax ×10/9; c4 = 1/a, c8 = 1/α (odczyt pamięci 648)");
    }
    // 10. etap 50 – rozkaz budowy obywatela (658/659 [P]): fundament HP 1 bez zgłoszenia mapy; trasa na narożnik obwodu;
    //     stany CheckRepairSiteAccessibility 4017 → WaitForBuildSiteToClear 4012 → RepairBuilding 4002; +15 HP w odstępach
    //     29, 29, 30, 29, 30, … taktów; przy HP maks. – ukończenie (+0x340), zgłoszenie z terminem zwykłym, 4028 → 5000
    {
        auto sb = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        sb->ustaw_tablice_walki(tablice(), wagi_ee_575());
        sb->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {}), 7);
        ParametryRuchu pr;
        pr.vmax = 0.6; pr.rozmiar = 0.3;
        const IdJednostki c = sb->dodaj_jednostke(pr, 11.65, 12.46, 0.0);
        ParametryWalki pc = g;
        pc.pole_widzenia = 6.0f;
        sb->ustaw_walke(c, 1, true, pc, 25);
        sb->ustaw_skrypt_jednostki(c, "obywatel");
        sb->jednostka(c)->przyrost_budowy = 15;
        const IdJednostki f = sb->postaw_fundament(1, 37, 10, 10, 1, 10.5, 10.5, 0.0, dom_37(), 0x700, 1, 2, 0);
        const bool fund = sb->jednostka(f)->boj->s.hp == 1 && !sb->jednostka(f)->ukonczony && !sb->przebudowa_zaplanowana();
        const Punkt2 m = sb->miejsce_budowy(*sb->jednostka(c), *sb->jednostka(f));
        sb->rozkaz_budowy(c, f);
        std::vector<int> stany{sb->jednostka(c)->stan}, odstepy;
        int hp = 1, t_hp = -1, t_4002 = -1, przyrosty = 0;
        std::uint32_t t_ukon = 0;
        for (int k = 0; k < 3000; ++k) {
            sb->takt();
            const Jednostka* u = sb->jednostka(c);
            if (stany.empty() || stany.back() != u->stan) stany.push_back(u->stan);
            if (u->stan == 4002 && t_4002 < 0) { t_4002 = k; t_hp = k; }
            const int h = sb->jednostka(f)->boj->s.hp;
            if (h != hp) { odstepy.push_back(k - t_hp); t_hp = k; hp = h; ++przyrosty; }
            if (sb->jednostka(f)->ukonczony && t_ukon == 0) t_ukon = sb->zegar_ms();
            if (u->stan == 5000 && sb->jednostka(f)->ukonczony) break;
        }
        auto pozycja = [&](int st) { for (std::size_t i = 0; i < stany.size(); ++i) if (stany[i] == st) return int(i); return -1; };
        const int i17 = pozycja(4017), i12 = pozycja(4012), i02 = pozycja(4002), i28 = pozycja(4028), i00 = pozycja(5000);
        std::string od;
        for (std::size_t i = 0; i < std::min<std::size_t>(odstepy.size(), 12); ++i) od += std::to_string(odstepy[i]) + " ";
        std::printf("  budowa: miejsce (%.3f, %.3f), przyrosty %d, HP %d, odstępy %s, ukończenie %u, termin %u, stany:", m.x, m.y,
                    przyrosty, hp, od.c_str(), unsigned(t_ukon), unsigned(sb->termin_przebudowy()));
        for (int st : stany) std::printf(" %d", st);
        std::printf("\n");
        const std::vector<int> wzor = {29, 29, 30, 29, 30, 29, 29, 30, 29, 30, 29, 29};
        const bool rytm = odstepy.size() >= wzor.size() && std::equal(wzor.begin(), wzor.end(), odstepy.begin());
        sprawdz(fund, "fundament: HP 1, +0x340 = 0, bez zgłoszenia zmiany mapy (658/659)");
        sprawdz(std::fabs(m.x - 11.15) < 1e-5 && std::fabs(m.y - 11.15) < 1e-5, "miejsce pracy: narożnik obwodu (X+1+r, Y+1+r), r = 0,15 (658)");
        sprawdz(!stany.empty() && stany[0] == 8017 && pozycja(8000) == 1 && i17 >= 0 && i17 < i12 && i12 < i02 && i02 < i28 &&
                    i28 < i00, "stany 8017 → 8000 → … → 4017 → 4012 → 4002 → 4028 → 5000 (658)");
        {
            const Jednostka* u = sb->jednostka(c);
            const Jednostka* b = sb->jednostka(f);
            const double kurs = std::atan2(-u->orientacja.m01(), u->orientacja.m11());
            const double oczek = std::atan2(-(b->x - u->x), b->y - u->y);
            std::printf("  kurs po budowie %.4f, na środek budynku %.4f\n", kurs, oczek);
            sprawdz(std::fabs(std::remainder(kurs - oczek, 2 * 3.14159265358979)) < 1e-3, "RepairBuilding: kurs na środek budynku (658: 2,3761)");
        }
        sprawdz(rytm && przyrosty == 34 && hp == 500, "33 × 15 HP + przycięty ostatni (496 → 500), odstępy 29, 29, 30, … (658/659)");
        sprawdz(sb->jednostka(f)->ukonczony && sb->przebudowa_zaplanowana() && sb->termin_przebudowy() == t_ukon + 15000,
                "ukończenie: +0x340 = 1, zgłoszenie zmiany mapy z terminem ukończenie + 15000 ms (658: 88705 + 15000)");
    }
    // 11. etap 51 – wzór przyrostu 0x60BF56 i dwóch budowniczych [W; P: 663]: obywatel A sam: +15 (n = 1), po dołączeniu
    //     B (n = 2): oba +10 na cykl; ostatni przycięty; budynek +0x274 = 2 w trakcie, 0 po zejściu obu z celu
    {
        auto sb = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        sb->ustaw_tablice_walki(tablice(), wagi_ee_575());
        sb->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {}), 7);
        ParametryRuchu pr;
        pr.vmax = 0.5; pr.rozmiar = 0.3; pr.a = 1.2; pr.c4 = 1.0 / 1.2;
        ParametryWalki pc = g;
        pc.pole_widzenia = 6.0f;
        pc.tempo_budowy_ms = 1000;
        const IdJednostki a = sb->dodaj_jednostke(pr, 11.65, 12.46, 0.0), bb = sb->dodaj_jednostke(pr, 13.5, 12.5, 0.0);
        for (IdJednostki c : {a, bb}) { sb->ustaw_walke(c, 1, true, pc, 25); sb->ustaw_skrypt_jednostki(c, "obywatel"); }
        ParametryWalki dom = dom_37();
        dom.czas_budowy_s = 1.0f;     // ulepszenie +0x94 [P: 672]
        dom.czas_budowy_ms = 35000;   // K [P: 660 – +0x27c]
        const IdJednostki f = sb->postaw_fundament(1, 37, 10, 10, 1, 10.5, 10.5, 0.0, dom, 0x700, 1, 2, 0);
        sb->rozkaz_budowy(a, f);
        std::vector<int> przyrosty;
        int hp = 1, n_maks = 0, k_b = -1;
        bool b_wydany = false;
        for (int k = 0; k < 3000; ++k) {
            if (!b_wydany && sb->jednostka(f)->boj->s.hp >= 100) { sb->rozkaz_budowy(bb, f); b_wydany = true; k_b = k; }
            sb->takt();
            const int h = sb->jednostka(f)->boj->s.hp;
            if (h != hp) { przyrosty.push_back(h - hp); hp = h; }
            n_maks = std::max(n_maks, sb->jednostka(f)->budowniczowie);
            if (sb->jednostka(f)->ukonczony && sb->jednostka(a)->stan == 5000 && sb->jednostka(bb)->stan == 5000) break;
        }
        std::string s;
        for (int x : przyrosty) s += std::to_string(x) + " ";
        std::printf("  dwóch budowniczych: przyrosty %s| n maks %d, n po %d, HP %d, B od taktu %d\n", s.c_str(), n_maks,
                    sb->jednostka(f)->budowniczowie, hp, k_b);
        bool ok15 = przyrosty.size() > 6, ok10 = false;
        for (std::size_t i = 0; i < 6 && i < przyrosty.size(); ++i) ok15 = ok15 && przyrosty[i] == 15;
        int dziesiatki = 0;
        for (int x : przyrosty) dziesiatki += (x == 10);
        ok10 = dziesiatki >= 20;
        sprawdz(ok15 && ok10 && n_maks == 2 && sb->jednostka(f)->budowniczowie == 0 && hp == 500,
                "0x60BF56: n = 1 → +15, n = 2 → +10 na budowniczego (3 / (n + 2)), +0x274 2 → 0 (663)");
    }
    // 12. etap 51 – koszt domu (660/663 [P]: drewno −50, kamień −40 przy fundamencie; 661 – po 20: odmowa bez zmian)
    {
        auto sb = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        const std::array<int, 5> dom{0, 50, 40, 0, 0};
        sb->ustaw_zasoby(1, {1111, 1222, 1333, 1444, 1555});
        const bool ok1 = sb->oplac(1, dom);
        const auto z1 = sb->zasoby(1);
        sb->ustaw_zasoby(1, {20, 20, 20, 20, 20});
        const bool ok2 = sb->oplac(1, dom);
        const auto z2 = sb->zasoby(1);
        std::printf("  koszt domu: %d (%d %d %d %d %d), przy 20: %d (%d %d)\n", int(ok1), z1[0], z1[1], z1[2], z1[3], z1[4], int(ok2), z2[1], z2[2]);
        sprawdz(ok1 && z1 == std::array<int, 5>{1111, 1172, 1293, 1444, 1555} && !ok2 && z2 == std::array<int, 5>{20, 20, 20, 20, 20},
                "koszt domu 50 drewna i 40 kamienia (660/663); brak zasobów – odmowa bez zmian (661)");
    }
    // 13. etap 51 – zbieranie drewna (673 [P]): 8008 → GatherResource 4004 (pierwszy cykl ścina drzewo, potem +1 co
    //     4400 ms) → pełne 15 → 4024 → FindNewStorage 4007 → MoveToStorage 8009 → AddResourceToStorage 4005 (drewno +15)
    //     → 4016 → 4023 → 8008 (powrót)
    {
        auto sb = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27());
        sb->ustaw_tablice_walki(tablice(), wagi_ee_575());
        sb->ustaw_wejscie_mapy(wejscie_syntetyczne(21, {}), 7);
        ParametryRuchu pr;
        pr.vmax = 0.5; pr.rozmiar = 0.3; pr.a = 1.2; pr.c4 = 1.0 / 1.2;
        ParametryWalki pc = g;
        pc.pole_widzenia = 3.0f; pc.atak = 5.0f; pc.udzwig = 15;
        pc.tempo_zbierania = {4400, 8926, 6000, 6000, 3500, 5200, 4600};
        const IdJednostki c = sb->dodaj_jednostke(pr, 11.5, 12.5, 0.0);
        sb->ustaw_walke(c, 1, true, pc, 65);
        sb->ustaw_skrypt_jednostki(c, "obywatel");
        const IdJednostki drz = sb->dodaj_zrodlo(0, 339, 10, 10, 10.5, 10.5, 0.0, 1, 400, 3, 1, 0, 0x1a4c);
        ParametryWalki tc = dom_37();
        tc.hp_max = 4000;
        const IdJednostki m = sb->dodaj_obiekt_budynku(1, 35, 15, 10, 2, 16.0, 11.0, 0.0, tc, 4000, true, 0x701, false);
        sb->ustaw_magazyn(m, true);
        sb->ustaw_zasoby(1, {1111, 1222, 1333, 1444, 1555});
        sb->rozkaz_zbierania(c, drz, 11.15, 11.15);
        std::vector<int> stany{sb->jednostka(c)->stan};
        int maks_niesie = 0, k_scinka = -1, k_dostawa = -1;
        for (int k = 0; k < 12000; ++k) {
            sb->takt();
            const Jednostka* u = sb->jednostka(c);
            if (u->stan != stany.back()) stany.push_back(u->stan);
            maks_niesie = std::max(maks_niesie, u->ilosc_40);
            if (k_scinka < 0 && sb->jednostka(drz)->boj->s.hp == 0) k_scinka = k;
            if (k_dostawa < 0 && sb->zasoby(1)[1] == 1237) k_dostawa = k;
            if (k_dostawa >= 0 && u->stan == 4004) break;
        }
        auto ma = [&](int st) { return std::find(stany.begin(), stany.end(), st) != stany.end(); };
        std::printf("  zbieranie: ścięcie w takcie %d, dostawa %d, niesione maks %d, drzewo %d, drewno %d, stany:", k_scinka, k_dostawa,
                    maks_niesie, sb->jednostka(drz)->ilosc_40, sb->zasoby(1)[1]);
        for (int st : stany) std::printf(" %d", st);
        std::printf("\n");
        sprawdz(stany.front() == 8008 && ma(4004) && ma(4024) && ma(4007) && ma(8009) && ma(4005) && ma(4016) && ma(4023) &&
                    maks_niesie == 15 && sb->jednostka(drz)->ilosc_40 == 385 && sb->zasoby(1)[1] == 1237 && k_scinka > 0,
                "Gather.tai: ścięcie drzewa, 15 × 1 drewna co 4400 ms, oddanie w magazynie (+15), powrót do źródła (673)");
    }
    return bledy ? FAIL : PASS;
}

// Etap 52 – produkcja jednostek w budynkach (docs/titan/produkcja.md): dopisanie z opłatą, start w tym samym takcie, licznik
// −34 ms/takt, utworzenie na krawędzi budynku, natychmiastowy start następnej pozycji, limit populacji, zwrot przy
// anulowaniu, losowania (EE 3 / AoC 1 przy utworzeniu). Dane: dbtechtree 1451/1074 (50 żywności, 28000 ms) [P: odczyt
// bazy], pomiary AoC 677/678, EE 679 [P].
int test_produkcja() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    auto przygotuj = [&](WariantTitan w) {
        auto sb = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27(), w);
        ParametryWalki tc = dom_37();
        tc.hp_max = 4000;
        sb->dodaj_obiekt_budynku(1, 35, 14, 10, 2, 15.0, 11.0, 0.0, tc, 4000, true, 0x701, false);
        sb->ustaw_zasoby(1, {1111, 1222, 1333, 1444, 1555});
        sb->ustaw_populacje(1, 1, 100);
        ParametryProdukcji p;
        p.tech_id = 1451; p.typ_db = 480; p.koszt = {50, 0, 0, 0, 0}; p.czas_ms = 28000; p.mnoznik_czasu = 1.0; p.populacja = 1;
        p.ruch.vmax = 0.5; p.ruch.rozmiar = 0.3; p.ruch.a = 1.2; p.ruch.c4 = 1.0 / 1.2;
        p.walka = gwardia_ee(); p.hp = 25;
        sb->ustaw_produkcje(p);
        p.tech_id = 1074; p.typ_db = 32;
        p.losowy_zamiennik = 1451;   // etap 53: wybór płci przy starcie (AoC 0x5FDDED, EE 0x5EFB91)
        sb->ustaw_produkcje(p);
        return sb;
    };
    auto losowania = [](std::uint32_t a, std::uint32_t b) {
        for (int n = 0; n < 64; ++n) { if (a == b) return n; a = (214013u * a + 2531011u) & 0x7FFFFFFFu; }
        return -1;
    };
    // 1. jedna pozycja (AoC 677 / EE 679 [P]): opłata i start w takcie rozkazu, 824 takty, jednostka na (X + r; Y − r)
    for (WariantTitan w : {WariantTitan::ee(), WariantTitan::aoc()}) {
        auto sb = przygotuj(w);
        IdJednostki b = sb->jednostki().front().id;
        const std::uint32_t r0 = sb->generator().stan();
        // etap 53: przycisk zamawia Citizen 1074; start losuje (wynik ≥ 0,5 → Female Citizen 1451, obiekt 480)
        const int typ_oczekiwany = double((214013u * r0 + 2531011u) & 0x7FFFFFFFu) / 2147483648.0 >= 0.5 ? 480 : 32;
        const bool ok = sb->rozkaz_produkcji(b, 1074);
        const int l_start = losowania(r0, sb->generator().stan());
        const auto z = sb->zasoby(1);
        const int ms0 = sb->jednostka(b)->prod_ms;
        int takt_konca = -1, l_konca = -1;
        for (int k = 1; k <= 900; ++k) {
            const std::uint32_t ra = sb->generator().stan();
            sb->takt();
            if (!sb->nowe_jednostki().empty()) { takt_konca = k; l_konca = losowania(ra, sb->generator().stan()) - 2; break; }
        }
        const Jednostka* n = sb->nowe_jednostki().empty() ? nullptr : sb->jednostka(sb->nowe_jednostki()[0]);
        std::printf("  %s: rozkaz %d, żywność %d, licznik %d, losowania startu %d, koniec w takcie %d (+%d los.), nowa (%.3f, %.3f) typ %d,"
                    " m01 %.3f m11 %.3f, populacja %d, bieżąca %d\n", w.nazwa, int(ok), z[0], ms0, l_start, takt_konca, l_konca,
                    n ? n->x : 0.0, n ? n->y : 0.0, n ? n->typ_db : -1, n ? n->orientacja.m01() : 0.0, n ? n->orientacja.m11() : 0.0,
                    sb->populacja(1), sb->jednostka(b)->prod_biezaca);
        sprawdz(ok && z[0] == 1061 && ms0 == 28000 && l_start == 1 && takt_konca == 824 && n && std::abs(n->x - 14.15) < 1e-5 &&
                    std::abs(n->y - 9.85) < 1e-5 && n->typ_db == typ_oczekiwany && n->stan == 5000 && sb->populacja(1) == 2 &&
                    sb->jednostka(b)->prod_biezaca == -1 && l_konca == w.losowania_utworzenia,
                std::string(w.nazwa) + ": koszt przy rozkazie, start 28000, 824 takty, wyjście (X + r; Y − r), populacja +1, losowania (677/679)");
    }
    // 2. dwie pozycje (677 „dwa”, 679 [P]): druga opłacona od razu, czeka; po zakończeniu pierwszej start drugiej w tym
    //    samym takcie (licznik 28000), druga jednostka o 2r dalej
    {
        auto sb = przygotuj(WariantTitan::ee());
        IdJednostki b = sb->jednostki().front().id;
        sb->rozkaz_produkcji(b, 1451);
        sb->takt();
        sb->rozkaz_produkcji(b, 1074);
        const int zyw = sb->zasoby(1)[0];
        const std::size_t kol = sb->jednostki().front().prod_kolejka.size();
        std::vector<int> konce;
        std::vector<std::pair<double, double>> poz;
        int ms_po = -1;
        for (int k = 2; k <= 1700; ++k) {
            sb->takt();
            for (IdJednostki id : sb->nowe_jednostki()) {
                konce.push_back(k); poz.push_back({sb->jednostka(id)->x, sb->jednostka(id)->y});
                if (konce.size() == 1) ms_po = sb->jednostka(b)->prod_ms;
            }
        }
        std::printf("  dwie pozycje: żywność %d, kolejka %zu, końce", zyw, kol);
        for (std::size_t i = 0; i < konce.size(); ++i) std::printf(" %d (%.3f, %.3f)", konce[i], poz[i].first, poz[i].second);
        std::printf(", licznik po pierwszej %d\n", ms_po);
        sprawdz(zyw == 1011 && kol == 1 && konce.size() == 2 && konce[0] == 824 && konce[1] == 1648 && ms_po == 28000 &&
                    std::abs(poz[1].first - 14.45) < 1e-5 && std::abs(poz[1].second - 9.85) < 1e-5,
                "druga pozycja: opłata przy rozkazie, start bez przerwy, wyjście o 2r dalej (677/679)");
    }
    // 3. brak zasobów (678 [P]) i limit populacji (0x563A25 [W]): odmowa bez zmian; pozycja opłacona czeka na miejsce
    {
        auto sb = przygotuj(WariantTitan::aoc());
        IdJednostki b = sb->jednostki().front().id;
        sb->ustaw_zasoby(1, {20, 20, 20, 20, 20});
        const bool brak = sb->rozkaz_produkcji(b, 1451);
        const bool bez_zmian = sb->zasoby(1) == std::array<int, 5>{20, 20, 20, 20, 20} && sb->jednostki().front().prod_kolejka.empty();
        sb->ustaw_zasoby(1, {1111, 1222, 1333, 1444, 1555});
        sb->ustaw_populacje(1, 101, 100);   // populacja = limit 101
        const bool ok = sb->rozkaz_produkcji(b, 1451);
        const bool czeka = sb->jednostka(b)->prod_biezaca == -1 && sb->jednostka(b)->prod_kolejka.size() == 1 && sb->zasoby(1)[0] == 1061;
        sb->ustaw_populacje(1, 100, 100);
        sb->takt();
        const bool start = sb->jednostka(b)->prod_biezaca == 1451 && sb->jednostka(b)->prod_ms == 28000;
        // anulowanie bieżącej (0x5FD8F3 [W]): zwrot 1,0, licznik 0
        const bool an = sb->anuluj_produkcje(b, 0);
        std::printf("  brak zasobów: %d (bez zmian %d); limit: rozkaz %d, czeka %d, start po zwolnieniu %d; anulowanie %d, żywność %d\n",
                    int(brak), int(bez_zmian), int(ok), int(czeka), int(start), int(an), sb->zasoby(1)[0]);
        sprawdz(!brak && bez_zmian && ok && czeka && start && an && sb->zasoby(1)[0] == 1111 && sb->jednostka(b)->prod_biezaca == -1,
                "brak zasobów – odmowa (678); populacja = limit – pozycja czeka; anulowanie – pełny zwrot (0x5FD8F3)");
    }
    // 4. etap 53 – wybór płci (AoC 0x5FDDED / EE 0x5EFB91 [W]; 7/7 startów 677–679 [P]): wynik losowania ≥ 0,5 → 1451;
    //    technologia bez zamiennika (1451 zamówiona wprost) nie losuje
    {
        int zgodne = 0, kobiety = 0;
        for (std::uint32_t ziarno = 1; ziarno <= 40; ++ziarno) {
            auto sb = przygotuj(WariantTitan::aoc());
            IdJednostki b = sb->jednostki().front().id;
            sb->generator().ustaw_ziarno(ziarno * 7919u);
            const std::uint32_t r0 = sb->generator().stan();
            const bool k = double((214013u * r0 + 2531011u) & 0x7FFFFFFFu) / 2147483648.0 >= 0.5;
            sb->rozkaz_produkcji(b, 1074);
            if (sb->jednostka(b)->prod_biezaca == (k ? 1451 : 1074)) ++zgodne;
            kobiety += k;
        }
        auto sb = przygotuj(WariantTitan::aoc());
        IdJednostki b = sb->jednostki().front().id;
        const std::uint32_t r0 = sb->generator().stan();
        sb->rozkaz_produkcji(b, 1451);
        std::printf("  płeć: zgodne z losowaniem %d/40 (kobiet %d); 1451 wprost – losowań %d\n", zgodne, kobiety,
                    losowania(r0, sb->generator().stan()));
        sprawdz(zgodne == 40 && kobiety > 5 && kobiety < 35 && losowania(r0, sb->generator().stan()) == 0,
                "start obywatela losuje płeć (≥ 0,5 → 1451); technologia bez zamiennika nie losuje");
    }
    return bledy ? FAIL : PASS;
}

// Etap 53 – produkcja wojskowa w koszarach (docs/titan/produkcja.md § 5): ten sam mechanizm co obywatel, dane z dbtechtree
// (Inf03 - Maceman 3011: obiekt 21, 30 żywności + 30 żelaza, 32000 ms – jednakowe w EE i AoC [P: odczyt bazy]). Pomiary
// AoC 704/705, EE 706 [P]: koszt przy rozkazie, brak losowania przy starcie, 942 takty, wyjście (X + r; Y − r) z r = 0,25,
// kurs −y, populacja +1, losowania utworzenia EE 3 / AoC 1; anulowanie PPM – kolejka od początku, potem bieżąca, zwrot 1,0.
int test_produkcja_wojskowa() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    auto przygotuj = [&](WariantTitan w) {
        auto sb = std::make_unique<Swiat>(tab, TerenSiatka::syntetyczny_etap27(), w);
        ParametryWalki kb = dom_37();
        kb.hp_max = 1500;
        sb->dodaj_obiekt_budynku(1, 34, 14, 10, 2, 15.0, 11.0, 0.0, kb, 1500, true, 0x701, false);
        sb->ustaw_zasoby(1, {1111, 1222, 1333, 1444, 1555});
        sb->ustaw_populacje(1, 1, 100);
        ParametryProdukcji p;
        p.tech_id = 3011; p.typ_db = 21; p.koszt = {30, 0, 0, 0, 30}; p.czas_ms = 32000; p.populacja = 1;
        p.ruch.vmax = 0.6; p.ruch.rozmiar = 0.5; p.ruch.a = 2.0; p.ruch.c4 = 0.5;
        p.walka = gwardia_ee(); p.hp = 150; p.skrypt = "piechota";
        sb->ustaw_produkcje(p);
        p.tech_id = 2024; p.typ_db = 24;   // Inf02 - Spearman: ten sam koszt i czas [W: dbtechtree]
        sb->ustaw_produkcje(p);
        return sb;
    };
    auto losowania = [](std::uint32_t a, std::uint32_t b) {
        for (int n = 0; n < 64; ++n) { if (a == b) return n; a = (214013u * a + 2531011u) & 0x7FFFFFFFu; }
        return -1;
    };
    // 1. jedna i dwie pozycje w obu wariantach
    for (WariantTitan w : {WariantTitan::ee(), WariantTitan::aoc()}) {
        auto sb = przygotuj(w);
        IdJednostki b = sb->jednostki().front().id;
        const std::uint32_t r0 = sb->generator().stan();
        const bool ok = sb->rozkaz_produkcji(b, 3011);
        const int l_start = losowania(r0, sb->generator().stan());
        const auto z = sb->zasoby(1);
        const int ms0 = sb->jednostka(b)->prod_ms;
        sb->takt();
        sb->rozkaz_produkcji(b, 3011);
        const auto z2 = sb->zasoby(1);
        std::vector<int> konce, los;
        std::vector<std::pair<double, double>> poz;
        const Jednostka* n1 = nullptr;
        for (int k = 2; k <= 1900; ++k) {
            const std::uint32_t ra = sb->generator().stan();
            sb->takt();
            for (IdJednostki id : sb->nowe_jednostki()) {
                konce.push_back(k); los.push_back(losowania(ra, sb->generator().stan()) - 2);   // 2 losowania taktu (0x546CE9, 0x547C09)
                poz.push_back({sb->jednostka(id)->x, sb->jednostka(id)->y});
                if (!n1) n1 = sb->jednostka(id);
            }
        }
        std::printf("  %s: rozkaz %d, zasoby %d/%d → %d/%d, licznik %d, losowania startu %d, końce", w.nazwa, int(ok), z[0], z[4], z2[0],
                    z2[4], ms0, l_start);
        for (std::size_t i = 0; i < konce.size(); ++i) std::printf(" %d (%.3f, %.3f; +%d los.)", konce[i], poz[i].first, poz[i].second, los[i]);
        std::printf(", populacja %d\n", sb->populacja(1));
        sprawdz(ok && z[0] == 1081 && z[4] == 1525 && z[1] == 1222 && z2[0] == 1051 && z2[4] == 1495 && ms0 == 32000 && l_start == 0 &&
                    konce.size() == 2 && konce[0] == 942 && konce[1] == 1884 && std::abs(poz[0].first - 14.25) < 1e-5 &&
                    std::abs(poz[0].second - 9.75) < 1e-5 && std::abs(poz[1].first - 14.75) < 1e-5 && los[0] == w.losowania_utworzenia &&
                    los[1] == w.losowania_utworzenia && sb->populacja(1) == 3,
                std::string(w.nazwa) + ": Maceman – koszt 30 + 30 przy rozkazie, 32000 ms bez losowania startu, 942 takty na pozycję, wyjście co 2r (704/706)");
    }
    // 2. anulowanie z interfejsu (0x5FD984 / 0x5FD8F3; 705/706 [P])
    {
        auto sb = przygotuj(WariantTitan::aoc());
        IdJednostki b = sb->jednostki().front().id;
        for (int i = 0; i < 3; ++i) sb->rozkaz_produkcji(b, 3011);
        for (int k = 0; k < 300; ++k) sb->takt();
        const std::uint32_t r0 = sb->generator().stan();
        std::vector<std::array<int, 4>> kroki;   // {wynik, kolejka, bieżąca, żywność}
        for (int i = 0; i < 4; ++i) {
            const bool a = sb->anuluj_technologie(b, 3011);
            kroki.push_back({int(a), int(sb->jednostka(b)->prod_kolejka.size()), sb->jednostka(b)->prod_biezaca, sb->zasoby(1)[0]});
        }
        std::printf("  anulowanie:");
        for (const auto& k : kroki) std::printf(" [%d kolejka %d bieżąca %d żywność %d]", k[0], k[1], k[2], k[3]);
        std::printf(", licznik %d, żelazo %d, populacja %d\n", sb->jednostka(b)->prod_ms, sb->zasoby(1)[4], sb->populacja(1));
        sprawdz(kroki[0] == std::array<int, 4>{1, 1, 3011, 1051} && kroki[1] == std::array<int, 4>{1, 0, 3011, 1081} &&
                    kroki[2] == std::array<int, 4>{1, 0, -1, 1111} && kroki[3] == std::array<int, 4>{0, 0, -1, 1111} &&
                    sb->jednostka(b)->prod_ms == 0 && sb->zasoby(1)[4] == 1555 && sb->populacja(1) == 1 && sb->generator().stan() == r0,
                "anulowanie PPM: kolejka 2 → 1 → 0, potem bieżąca; pełny zwrot; populacja i generator bez zmian (705/706)");
    }
    // 3. kolejka mieszana [W: 0x5FD984]: usuwana jest pierwsza pozycja danej technologii, pozostałe zachowują kolejność;
    //    bieżąca tylko wtedy, gdy w kolejce nie ma tej technologii; następna pozycja startuje w kolejnym takcie
    {
        auto sb = przygotuj(WariantTitan::ee());
        IdJednostki b = sb->jednostki().front().id;
        sb->rozkaz_produkcji(b, 3011); sb->rozkaz_produkcji(b, 2024); sb->rozkaz_produkcji(b, 3011); sb->rozkaz_produkcji(b, 2024);
        const bool a1 = sb->anuluj_technologie(b, 3011);     // z kolejki [2024, 3011, 2024] → [2024, 2024]
        const auto k1 = sb->jednostka(b)->prod_kolejka;
        const bool a2 = sb->anuluj_technologie(b, 3011);     // w kolejce brak 3011 → bieżąca
        const int cur2 = sb->jednostka(b)->prod_biezaca;
        sb->takt();
        const int cur3 = sb->jednostka(b)->prod_biezaca, ms3 = sb->jednostka(b)->prod_ms;
        std::printf("  kolejka mieszana: %d kolejka %zu [%d, %d]; %d bieżąca %d; po takcie bieżąca %d licznik %d kolejka %zu\n", int(a1),
                    k1.size(), k1.size() > 0 ? k1[0] : -1, k1.size() > 1 ? k1[1] : -1, int(a2), cur2, cur3, ms3,
                    sb->jednostka(b)->prod_kolejka.size());
        sprawdz(a1 && k1.size() == 2 && k1[0] == 2024 && k1[1] == 2024 && a2 && cur2 == -1 && cur3 == 2024 && ms3 == 32000 &&
                    sb->jednostka(b)->prod_kolejka.size() == 1,
                "kolejka mieszana: pierwsza pozycja technologii z kolejki, potem bieżąca; następna startuje w kolejnym takcie [W]");
    }
    return bledy ? FAIL : PASS;
}

// Etap 53 – integracja eksperymentów Fable (docs/titan/EKSPERYMENT_FABLE_DUZE_JEDNOSTKI.md § 3, § 9):
// (1) nowa para kontaktu trafia na początek listy [P: zad. 691/693, 696/697]; (2) para dwóch obiektów o rozmiarze ≥ 1,0
// z ruchomym drugim uczestnikiem nie przechodzi przez odpychanie małe 0x549179 [W: pętla 0x5498C4; P: 698–701].
int test_kontakty_duze() {
    auto tab = tablice_lub_skip();
    if (!tab) return SKIP;
    ParametryRuchu taran = gwardia();
    taran.a = 1.0; taran.vmax = 0.5; taran.alfa = 1.74533; taran.wmax = 0.87266; taran.rozmiar = 1.0; taran.promien_kolizji = 1.0;
    taran.c4 = 1.0; taran.c8 = 1.0 / 1.74533;
    {   // kolejność listy: trzy jednostki w jednym oknie, pary dopisywane kolejno przy tworzeniu
        Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
        const auto a = s.dodaj_jednostke(gwardia(), 10.5, 10.5, 0.0);
        const auto b = s.dodaj_jednostke(gwardia(), 10.6, 10.9, 0.0);   // to samo pole co a
        const auto c = s.dodaj_jednostke(gwardia(), 10.9, 10.6, 0.0);
        const auto& la = s.jednostka(a)->lista_kontaktow;
        const auto& lb = s.jednostka(b)->lista_kontaktow;
        const auto& lc = s.jednostka(c)->lista_kontaktow;
        std::printf("  listy: a [%zu:", la.size());
        for (auto x : la) std::printf(" %u", unsigned(x));
        std::printf("] b [%zu] c [%zu]\n", lb.size(), lc.size());
        sprawdz(la.size() == 2 && la[0] == c && la[1] == b, "nowa para na początku listy: a ma [c, b] (c dopisane później)");
        sprawdz(lb.size() == 2 && lb[0] == c && lb[1] == a && lc.size() == 2 && lc[0] == b && lc[1] == a,
                "listy b i c: nowsza para przed starszą; para c dopisana w kolejności przeglądu (a, potem b → [b, a])");
        // przebudowa okna jednostki a (zmiana pola) usuwa ją z cudzych list i dopisuje ponownie na ich początek
        s.odbuduj_kontakty_wszystkich();
        const auto& la2 = s.jednostka(a)->lista_kontaktow;
        sprawdz(la2.size() == 2 && s.jednostka(b)->lista_kontaktow.size() == 2 && s.jednostka(c)->lista_kontaktow.size() == 2,
                "pełna odbudowa zachowuje symetrię list (po 2 kontakty)");
    }
    {   // dwa tarany (1,0 / 1,0, ruchome): gałąź duża – bez odpychania małego; taran i gwardia: odpychanie małe działa
        Swiat s(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
        const auto a = s.dodaj_jednostke(taran, 10.5, 10.5, 0.0);
        const auto b = s.dodaj_jednostke(taran, 10.5, 12.5, 0.0);     // stoi na trasie a
        s.rozkaz_ruchu(a, 10.5, 15.5);
        double min_d = 1e9;
        for (int t = 0; t < 900; ++t) {
            s.takt();
            min_d = std::min(min_d, std::hypot(s.jednostka(a)->x - s.jednostka(b)->x, s.jednostka(a)->y - s.jednostka(b)->y));
        }
        const auto& d = s.diagnostyka();
        std::printf("  taran–taran: pary duże %" PRIu64 ", kolizje małe %" PRIu64 ", min. odległość %.3f, b (%.4f, %.4f), a koniec (%.3f, %.3f)\n",
                    d.pary_duze, d.kolizje, min_d, s.jednostka(b)->x, s.jednostka(b)->y, s.jednostka(a)->x, s.jednostka(a)->y);
        sprawdz(d.pary_duze > 0 && d.kolizje == 0 && s.jednostka(b)->x == 10.5 && s.jednostka(b)->y == 12.5,
                "para taran–taran idzie do gałęzi dużej: brak odpychania małego, stojący taran nieruszony");
        sprawdz(min_d < 1.0 && std::abs(s.jednostka(a)->y - 15.5) < 0.2,
                "taran objeżdża stojący taran trasą A* (kara pola) i dojeżdża do celu mimo zbliżenia poniżej sumy promieni");
        Swiat s2(tab, TerenSiatka::syntetyczny_etap27(), WariantTitan::ee());
        const auto a2 = s2.dodaj_jednostke(taran, 10.5, 10.5, 0.0);
        const auto g2 = s2.dodaj_jednostke(gwardia(), 11.1, 12.5, 0.0);   // gwardia w sąsiednim polu, 0,6 od osi trasy: S = 0,75
        s2.rozkaz_ruchu(a2, 10.5, 15.5);
        for (int t = 0; t < 900; ++t) s2.takt();
        std::printf("  taran–gwardia: pary duże %" PRIu64 ", kolizje małe %" PRIu64 ", gwardia (%.4f, %.4f)\n", s2.diagnostyka().pary_duze,
                    s2.diagnostyka().kolizje, s2.jednostka(g2)->x, s2.jednostka(g2)->y);
        sprawdz(s2.diagnostyka().pary_duze == 0 && s2.diagnostyka().kolizje > 0 && s2.jednostka(g2)->x > 11.1,
                "para taran–gwardia: odpychanie małe, gwardia zepchnięta z drogi (jak w nagraniach fable_*_5)");
    }
    return bledy ? FAIL : PASS;
}

int main(int argc, char** argv) {
    const std::map<std::string, std::function<int()>> grupy = {
        {"trygonometria", test_trygonometria}, {"rng", test_rng}, {"teren", test_teren}, {"ruch", test_ruch},
        {"odpychanie", test_odpychanie}, {"dll", test_dll}, {"tai", test_tai}, {"determinizm", test_determinizm}, {"astar", test_astar}, {"porownanie_gra", test_porownanie_gra}, {"krok", test_krok}, {"kolizje_takt", test_kolizje_takt}, {"kolejka", test_kolejka}, {"scenariusze", test_scenariusze}, {"astar_gra", test_astar_gra}, {"mapa", test_mapa}, {"walka", test_walka}, {"walka_swiat", test_walka_swiat}, {"morale", test_morale}, {"budynki", test_budynki}, {"produkcja", test_produkcja},
        {"podsystemy", test_podsystemy}, {"produkcja_wojskowa", test_produkcja_wojskowa}, {"kontakty_duze", test_kontakty_duze}};
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
