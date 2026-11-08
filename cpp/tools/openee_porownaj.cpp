// openee_porownaj – powtarzalne porównanie serii pomiarowej oryginału (Riverlands_MCP → narzedzia/titan/pomiar_core.py)
// z OpenEE Core (etap 30). Wejście: seria wielojednostkowa (format openee_seria_v1), opcjonalnie mapa z eksportu SCN.
// Wyjście (stdout, JSON): metryki na jednostkę, pierwszy rozbieżny takt z wartościami Core i gry, liczniki RNG.
// Użycie: openee_porownaj --seria S.json --instalacja KATALOG_GRY [--mapa M.json] [--tolerancja 1e-3]
#include <cinttypes>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <map>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

#include "json_mini.hpp"
#include "openee/mapa.hpp"
#include "openee/symulacja.hpp"
#include "openee/tablice_dll.hpp"

using namespace openee;
using json_mini::Wartosc;

namespace {
std::string czytaj(const std::string& p) {
    std::ifstream f(p, std::ios::binary);
    std::stringstream s;
    s << f.rdbuf();
    return s.str();
}
ParametryRuchu parametry(const Wartosc& p) {
    ParametryRuchu r;
    r.a = p["a"].n; r.vmax = p["vmax"].n; r.alfa = p["alfa"].n; r.wmax = p["wmax"].n;
    r.rozmiar = p["rozmiar"].n; r.c4 = p["c4"].n; r.c8 = p["c8"].n; r.t488 = p["t488"].n;
    return r;
}
std::string esc(const std::string& s) {
    std::string o;
    for (char c : s) o += (c == '"' || c == '\\') ? std::string("\\") + c : std::string(1, c);
    return o;
}
TerenSiatka teren_z_mapy(const Wartosc& j, const std::string& typ) {
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
}  // namespace

int main(int argc, char** argv) {
    std::map<std::string, std::string> a;
    for (int i = 1; i + 1 < argc; i += 2) a[argv[i]] = argv[i + 1];
    if (!a.count("--seria") || !a.count("--instalacja")) {
        std::fprintf(stderr, "użycie: openee_porownaj --seria S.json --instalacja KATALOG [--mapa M.json] [--tolerancja T]\n");
        return 2;
    }
    const double tol = a.count("--tolerancja") ? std::atof(a["--tolerancja"].c_str()) : 1e-3;
    const Wartosc s = json_mini::Parser(czytaj(a["--seria"])).parsuj();
    if (s["format"].s != "openee_seria_v1") { std::fprintf(stderr, "nieznany format serii\n"); return 2; }
    const std::string war = s["wariant"].s;
    const auto t = zaladuj_tablice_dll(a["--instalacja"] + (war == "aoc" ? "/Empire Earth - The Art of Conquest/Low-Level Engine.dll"
                                                                         : "/Empire Earth/Low-Level Engine.dll"));
    if (!t.ok()) { std::fprintf(stderr, "tablice: %s\n", t.komunikat.c_str()); return 3; }
    TerenSiatka teren = TerenSiatka::syntetyczny_etap27();
    std::string zrodlo_terenu = "syntetyczny";
    if (a.count("--mapa")) {
        teren = teren_z_mapy(json_mini::Parser(czytaj(a["--mapa"])).parsuj(), s["jednostki"][0]["typ"].s);
        zrodlo_terenu = "mapa SCN (MapaTitan)";
    } else if (const Wartosc* tz = s.znajdz("teren_z")) {
        int mx = 0, my = 0;
        for (const auto& [k, v] : tz->o) { const auto p = k.find(','); mx = std::max(mx, std::stoi(k.substr(0, p))); my = std::max(my, std::stoi(k.substr(p + 1))); }
        std::vector<float> z(std::size_t(mx + 2) * std::size_t(my + 2), 0.0f);
        for (const auto& [k, v] : tz->o) { const auto p = k.find(','); z[std::size_t(std::stoi(k.substr(p + 1))) * std::size_t(mx + 2) + std::size_t(std::stoi(k.substr(0, p)))] = float(v.n); }
        teren = TerenSiatka(mx + 2, my + 2, z);
        zrodlo_terenu = "wysokości z pamięci (seria)";
    }
    Swiat sw(t.tablice, teren, WariantTitan::z_nazwy(war));
    std::vector<IdJednostki> ids;
    for (const auto& j : s["jednostki"].t) {
        ids.push_back(sw.dodaj_jednostke(parametry(s["parametry"][j["typ"].s]), j["start"]["x"].n, j["start"]["y"].n, 0.0));
        Jednostka* u = sw.jednostka(ids.back());
        u->orientacja.m[1] = j["start"]["m01"].n;
        u->orientacja.m[4] = j["start"]["m11"].n;
    }
    std::size_t T = 0;
    for (const auto& j : s["jednostki"].t) T = std::max(T, j["probki"].t.size());
    struct M { double ps = 0, pm = 0, vs = 0; int n = 0, pierwszy = -1, kont = 0, stany = 0; std::string opis; };
    std::vector<M> mt(ids.size());
    const std::uint64_t rng0 = sw.generator().liczba_losowan();
    for (std::size_t k = 1; k < T; ++k) {
        for (std::size_t i = 0; i < ids.size(); ++i)
            for (const auto& r : s["jednostki"][i]["rozkazy"].t) {
                if (std::size_t(r["takt"].n) != k) continue;
                if (r["tryb"].s == "trasa") {
                    std::vector<Punkt2> pts;
                    for (const auto& p : r["punkty"].t) pts.push_back({p[0].n, p[1].n});
                    sw.nadaj_trase(ids[i], pts, std::nullopt, StartTrasy::rozkaz);
                } else {
                    sw.rozkaz_ruchu(ids[i], r["x"].n, r["y"].n, std::nullopt, r["tryb"].s == "rozkaz_shift");
                }
            }
        sw.takt();
        const auto m = sw.migawka();
        for (std::size_t i = 0; i < ids.size(); ++i) {
            const Wartosc& pr = s["jednostki"][i]["probki"];
            if (k >= pr.t.size()) continue;
            const Wartosc& p = pr[k];
            const double e = std::hypot(m[i].x - p["x"].n, m[i].y - p["y"].n);
            M& q = mt[i];
            ++q.n; q.ps += e; q.pm = std::max(q.pm, e); q.vs += std::fabs(m[i].v - p["v"].n);
            const Jednostka* u = sw.jednostka(ids[i]);
            q.kont += ((u->kontakty > 0) != (p["kontakty"].n > 0));
            q.stany += (m[i].stan != int(p["stan"].n));
            if (q.pierwszy < 0 && (e > tol || m[i].stan != int(p["stan"].n))) {
                q.pierwszy = int(k);
                char b[400];
                std::snprintf(b, sizeof b, "Core (%.4f, %.4f) v %.4f stan %d kontakty %u | gra (%.4f, %.4f) v %.4f stan %d kontakty %d",
                              m[i].x, m[i].y, m[i].v, m[i].stan, u->kontakty, p["x"].n, p["y"].n, p["v"].n, int(p["stan"].n), int(p["kontakty"].n));
                q.opis = b;
            }
        }
    }
    std::uint64_t rng_gra = 0;
    const auto& rr = s["rng"].t;
    for (std::size_t k = 1; k < rr.size(); ++k)
        rng_gra += std::uint64_t(std::max<std::int64_t>(0, GeneratorTitan::odleglosc(std::uint32_t(rr[k - 1].n), std::uint32_t(rr[k].n), 500)));
    std::printf("{\"nazwa\": \"%s\", \"wariant\": \"%s\", \"teren\": \"%s\", \"taktow\": %zu, \"tolerancja\": %g, \"jednostki\": [", esc(s["nazwa"].s).c_str(),
                war.c_str(), zrodlo_terenu.c_str(), T - 1, tol);
    for (std::size_t i = 0; i < ids.size(); ++i)
        std::printf("%s{\"id\": \"%s\", \"probek\": %d, \"pozycja_sr\": %.6f, \"pozycja_max\": %.6f, \"v_sr\": %.6f, \"pierwszy_rozbiezny\": %d, "
                    "\"opis_rozbieznosci\": \"%s\", \"takty_inne_kontakty\": %d, \"takty_inny_stan\": %d}",
                    i ? ", " : "", s["jednostki"][i]["id"].s.c_str(), mt[i].n, mt[i].ps / std::max(1, mt[i].n), mt[i].pm,
                    mt[i].vs / std::max(1, mt[i].n), mt[i].pierwszy, esc(mt[i].opis).c_str(), mt[i].kont, mt[i].stany);
    std::printf("], \"rng_kroki_gra\": %" PRIu64 ", \"rng_losowania_core\": %" PRIu64 "}\n", rng_gra, sw.generator().liczba_losowan() - rng0);
    return 0;
}
