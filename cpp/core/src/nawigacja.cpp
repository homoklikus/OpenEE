#include "openee/nawigacja.hpp"

#include <algorithm>
#include <array>
#include <cstdlib>

namespace openee {

namespace {
constexpr int HASH = 53;
constexpr int NIC = -1;

struct Wezel {
    int parent = NIC, next = NIC, prev = NIC;
    std::uint32_t F = 0, G = 0, H = 0;
    int x = 0, y = 0;
};

class Pamiec {
public:
    Pamiec(int W, int H) : W_(W), H_(H), flagi_(std::size_t(W) * std::size_t(H), 0), cache_(flagi_.size(), 0) {
        oh_.fill(NIC);
        ch_.fill(NIC);
    }
    std::vector<Wezel> w;
    int head = NIC, tail = NIC;
    std::array<int, HASH> oh_{}, ch_{};

    int nowy(int x, int y) {
        Wezel n;
        n.x = x;
        n.y = y;
        w.push_back(n);
        return int(w.size()) - 1;
    }
    std::uint8_t& fl(int x, int y) { return flagi_[std::size_t(x) * std::size_t(H_) + std::size_t(y)]; }
    std::uint8_t& cache(int x, int y) { return cache_[std::size_t(x) * std::size_t(H_) + std::size_t(y)]; }

    void push_open(int n) {  // 0x41F876
        Wezel& N = w[n];
        if (tail != NIC && N.F <= w[tail].F && head != NIC) {
            int e = head;
            while (e != NIC && N.F > w[e].F) e = w[e].next;
            const int p = w[e].prev;
            if (p != NIC) {
                w[p].next = n; N.next = e; N.prev = p; w[e].prev = n;
            } else {
                N.next = e; w[e].prev = n; head = n;
            }
            if (w[e].next == NIC) tail = e;
        } else {
            const int b = AStarTitan::kubelek(N.x, N.y);
            if (oh_[b] != NIC) w[oh_[b]].prev = n;
            N.next = oh_[b];
            oh_[b] = n;
        }
        fl(N.x, N.y) |= 4;
    }

    void list_insert(int n) {  // 0x420385
        int e = head, last = NIC;
        while (e != NIC && w[n].F > w[e].F) { last = e; e = w[e].next; }
        if (head == NIC) {
            head = tail = n;
        } else if (e != NIC) {
            const int p = w[e].prev;
            if (p != NIC) {
                w[p].next = n; w[n].next = e; w[n].prev = w[e].prev; w[e].prev = n;
            } else {
                w[n].next = e; w[e].prev = n; head = n;
            }
        } else {
            w[n].prev = last; w[last].next = n; tail = n;
        }
    }

    int pop() {  // 0x420030
        if (head == NIC) {
            std::vector<int> arr;
            int seen = 0, imax = -1;
            std::uint32_t fmax = 0;
            for (int b = HASH - 1; b >= 0; --b) {
                for (int n = oh_[b]; n != NIC; n = w[n].next) {
                    if (seen >= 15) {
                        if (w[n].F < fmax) {
                            arr[std::size_t(imax)] = n;
                            imax = 0;
                            for (int k = 1; k < 15; ++k)
                                if (w[arr[std::size_t(k)]].F > w[arr[std::size_t(imax)]].F) imax = k;
                            fmax = w[arr[std::size_t(imax)]].F;
                            ++seen;
                        }
                    } else {
                        if (imax == -1) {
                            fmax = w[n].F; imax = 0; arr.push_back(n);
                        } else {
                            if (!(w[n].F < w[arr[std::size_t(imax)]].F)) { imax = int(arr.size()); fmax = w[n].F; }
                            arr.push_back(n);
                        }
                        ++seen;
                    }
                }
            }
            for (int k = int(std::min<std::size_t>(arr.size(), 15)) - 1; k >= 0; --k) {
                const int n = arr[std::size_t(k)];
                if (w[n].prev != NIC) {
                    w[w[n].prev].next = w[n].next;
                    if (w[n].next != NIC) w[w[n].next].prev = w[n].prev;
                } else {
                    const int b = AStarTitan::kubelek(w[n].x, w[n].y);
                    oh_[b] = w[n].next;
                    if (w[n].next != NIC) w[w[n].next].prev = NIC;
                }
                w[n].next = w[n].prev = NIC;
                list_insert(n);
            }
        }
        const int n = head;
        if (n == NIC) return NIC;
        head = w[n].next;
        if (head != NIC) w[head].prev = NIC;
        else tail = NIC;
        w[n].next = w[n].prev = NIC;
        fl(w[n].x, w[n].y) &= std::uint8_t(~4);
        return n;
    }

    int find_open(int x, int y) {
        if (!(fl(x, y) & 4)) return NIC;
        for (int e = head; e != NIC; e = w[e].next)
            if (w[e].x == x && w[e].y == y) return e;
        for (int e = oh_[AStarTitan::kubelek(x, y)]; e != NIC; e = w[e].next)
            if (w[e].x == x && w[e].y == y) return e;
        return NIC;
    }
    int find_closed(int x, int y) {
        if (!(fl(x, y) & 8)) return NIC;
        for (int e = ch_[AStarTitan::kubelek(x, y)]; e != NIC; e = w[e].next)
            if (w[e].x == x && w[e].y == y) return e;
        return NIC;
    }
    void close(int n) {
        const int b = AStarTitan::kubelek(w[n].x, w[n].y);
        if (ch_[b] != NIC) w[ch_[b]].prev = n;
        w[n].next = ch_[b];
        ch_[b] = n;
        fl(w[n].x, w[n].y) |= 8;
    }
    void remove_closed(int n) {
        if (w[n].prev != NIC) {
            w[w[n].prev].next = w[n].next;
            if (w[n].next != NIC) w[w[n].next].prev = w[n].prev;
        } else {
            const int b = AStarTitan::kubelek(w[n].x, w[n].y);
            ch_[b] = w[n].next;
            if (w[n].next != NIC) w[w[n].next].prev = NIC;
        }
        w[n].next = w[n].prev = NIC;
        fl(w[n].x, w[n].y) &= std::uint8_t(~8);
    }
    void unlink_open(int n) {  // wspólna część 0x41FC4E i usuwania z otwartej
        if (w[n].prev != NIC) {
            w[w[n].prev].next = w[n].next;
            if (w[n].next != NIC) w[w[n].next].prev = w[n].prev;
        } else {
            const int b = AStarTitan::kubelek(w[n].x, w[n].y);
            if (oh_[b] == n) {
                oh_[b] = w[n].next;
                if (w[n].next != NIC) w[w[n].next].prev = NIC;
            } else if (head == n) {
                head = w[n].next;
                if (w[n].next != NIC) w[w[n].next].prev = NIC;
            }
        }
        if (tail == n) tail = w[n].prev;
        w[n].next = w[n].prev = NIC;
    }
    void remove_open(int n) {
        unlink_open(n);
        fl(w[n].x, w[n].y) &= std::uint8_t(~4);
    }
    void reposition(int n) {  // 0x41FC4E
        unlink_open(n);
        if (head != NIC && tail != NIC && w[n].F <= w[tail].F) {
            int e = head;
            while (e != NIC && w[n].F > w[e].F) e = w[e].next;
            const int p = w[e].prev;
            if (p != NIC) {
                w[n].prev = p; w[n].next = e; w[p].next = n; w[e].prev = n;
            } else {
                w[e].prev = n; w[n].next = head; head = n;
            }
            if (w[n].next == NIC) tail = n;
        } else {
            const int b = AStarTitan::kubelek(w[n].x, w[n].y);
            if (oh_[b] != NIC) w[oh_[b]].prev = n;
            w[n].next = oh_[b];
            oh_[b] = n;
        }
    }
    std::vector<int> wszystkie_otwarte() {
        std::vector<int> r;
        for (int e = head; e != NIC; e = w[e].next) r.push_back(e);
        for (int b = HASH - 1; b >= 0; --b)
            for (int e = oh_[b]; e != NIC; e = w[e].next) r.push_back(e);
        return r;
    }
    std::vector<int> wszystkie_zamkniete() {
        std::vector<int> r;
        for (int b = HASH - 1; b >= 0; --b)
            for (int e = ch_[b]; e != NIC; e = w[e].next) r.push_back(e);
        return r;
    }

private:
    int W_, H_;
    std::vector<std::uint8_t> flagi_, cache_;
};
}  // namespace

int AStarTitan::kubelek(int x, int y) {
    std::int64_t h = (std::int64_t(x) << 4) + y;
    const std::int64_t hi = h & 0xF0000000LL;
    if (hi) h = ((hi >> 24) ^ hi) - ((hi & 0x80000000LL) ? (1LL << 32) : 0);
    const std::int64_t q = h / HASH;  // dzielenie ze znakiem, obcięcie do zera (idiv)
    return int(h - q * HASH);
}

WynikAStar AStarTitan::szukaj(Pole start, Pole cel, const Dostepnosc& dostepne, int W, int H,
                              const ParametryAStar& p) {
    Pamiec S(W, H);
    WynikAStar wynik;
    auto P = [&](int x, int y) -> bool {  // 0x4A5EF5: pamięć podręczna dostępności
        if (x < 0 || y < 0 || x >= W || y >= H) return false;
        std::uint8_t& c = S.cache(x, y);
        if (!c) c = dostepne(x, y) ? 1 : 2;
        return c == 1;
    };
    const int gx = cel.x, gy = cel.y;
    auto koszt = [&](int fx, int fy, int tx, int ty) -> std::uint32_t {
        std::uint32_t c = (fx == tx || fy == ty) ? 10u : 14u;
        if (p.kara && !(tx == gx && ty == gy)) c += std::uint32_t(p.kara(tx, ty));
        return c;
    };
    auto dodaj = [&](int cur, int x, int y) {  // 0x4A5E13
        const std::uint32_t g = S.w[cur].G + koszt(S.w[cur].x, S.w[cur].y, x, y);
        const int o = S.find_open(x, y);
        const int c = S.find_closed(x, y);
        if (o != NIC && S.w[o].G <= g) return;
        if (c != NIC) {
            if (S.w[c].G <= g) return;
            S.remove_closed(c);
        }
        if (o == NIC) {
            const int n = S.nowy(x, y);
            S.w[n].parent = cur;
            S.w[n].G = g;
            S.w[n].H = std::uint32_t((std::abs(x - gx) + std::abs(y - gy)) * 10);
            S.w[n].F = S.w[n].H + g;
            S.push_open(n);
        } else {
            S.w[o].G = g;
            S.w[o].parent = cur;
            const std::uint32_t nf = g + S.w[o].H;
            if (S.w[o].F != nf) {
                S.w[o].F = nf;
                S.reposition(o);
            }
        }
    };
    auto test_celu = [&](int n) -> bool {  // 0x41CCA8
        if (n == NIC) return true;
        const int x = S.w[n].x, y = S.w[n].y;
        if (std::abs(x - gx) > 1 || std::abs(y - gy) > 1) return false;
        if (x == gx && y == gy) return true;
        if (P(gx, gy)) return false;
        if (!p.reguly_naroznikow) return true;
        const int dx = x - gx, dy = y - gy;
        if (std::abs(dx) != 1 || std::abs(dy) != 1) return true;
        return P(gx, y) && P(x, gy);
    };

    P(start.x, start.y);
    const int n0 = S.nowy(start.x, start.y);
    S.w[n0].H = std::uint32_t((std::abs(start.x - gx) + std::abs(start.y - gy)) * 10);
    S.w[n0].F = S.w[n0].H;
    S.push_open(n0);
    int total = 0, calls = 0, cur = NIC;
    int limit_w = p.limit_wywolania;
    bool pending = true;
    while (pending) {
        int sl = 0;
        ++calls;
        ++total;
        cur = S.pop();
        for (;;) {
            if (test_celu(cur)) { wynik.zakonczenie = "test celu"; pending = false; break; }
            const int x = S.w[cur].x, y = S.w[cur].y;
            int px = 0, py = 0;
            if (S.w[cur].parent != NIC) { px = S.w[S.w[cur].parent].x; py = S.w[S.w[cur].parent].y; }
            if (p.zapisz_przebieg) wynik.przebieg.push_back({x, y, S.w[cur].G, S.w[cur].F});
            const bool pN = P(x, y - 1), pW = P(x - 1, y), pE = P(x + 1, y), pS = P(x, y + 1);
            const struct { bool ok; int nx, ny; } proste[4] = {{pN, x, y - 1}, {pW, x - 1, y}, {pE, x + 1, y}, {pS, x, y + 1}};
            for (const auto& s : proste)
                if (s.ok && !(s.nx == px && s.ny == py)) dodaj(cur, s.nx, s.ny);
            const bool n = p.reguly_naroznikow;
            const struct { bool ok; int nx, ny; } skos[4] = {{!n || pW || pN, x - 1, y - 1},
                                                            {!n || pN || pE, x + 1, y - 1},
                                                            {!n || pE || pS, x + 1, y + 1},
                                                            {!n || pS || pW, x - 1, y + 1}};
            for (const auto& s : skos)
                if (s.ok && !(s.nx == px && s.ny == py) && P(s.nx, s.ny)) dodaj(cur, s.nx, s.ny);
            S.close(cur);
            if (limit_w != -1 && sl >= limit_w) { cur = NIC; break; }
            if (p.limit_calkowity != -1 && total >= p.limit_calkowity) {
                cur = NIC; pending = false; wynik.zakonczenie = "limit"; break;
            }
            ++sl;
            ++total;
            cur = S.pop();
        }
        if (pending && limit_w >= 0 && limit_w < 32) limit_w = std::min(limit_w + 1, 32);
    }
    // 0x41CC0F
    bool f28;
    if (cur == NIC) f28 = (wynik.zakonczenie == "test celu");
    else f28 = (std::abs(S.w[cur].x - gx) <= 1 && std::abs(S.w[cur].y - gy) <= 1) && !P(gx, gy);
    if (!f28) f28 = (p.limit_calkowity == -1 || total >= p.limit_calkowity);
    int koniec = cur;
    if (f28) {  // 0x4A5D16 → 0x4A6339
        if (cur != NIC) S.close(cur);
        wynik.koniec_najblizszy = true;
        koniec = NIC;
        for (;;) {
            auto najlepszy = [&](const std::vector<int>& l) {
                int b = NIC, bd = -1;
                for (int e : l) {
                    const int d = std::abs(S.w[e].x - gx) + std::abs(S.w[e].y - gy);
                    if (bd == -1 || d < bd) { b = e; bd = d; }
                }
                return b;
            };
            const int ob = najlepszy(S.wszystkie_otwarte());
            const int cb = najlepszy(S.wszystkie_zamkniete());
            int n;
            if (ob == NIC && cb == NIC) {
                koniec = S.nowy(start.x, start.y);
                break;
            }
            if (ob == NIC) { n = cb; S.remove_closed(cb); }
            else if (cb == NIC) { n = ob; S.remove_open(ob); }
            else if (S.w[ob].F > S.w[cb].F) { n = cb; S.remove_closed(cb); }
            else { n = ob; S.remove_open(ob); }
            if (p.koniec_bez_testu_dostepnosci || P(S.w[n].x, S.w[n].y)) { koniec = n; break; }
        }
    }
    for (int n = koniec; n != NIC; n = S.w[n].parent) wynik.trasa_od_celu.push_back({S.w[n].x, S.w[n].y});
    wynik.iteracje = total;
    wynik.wywolania = calls;
    wynik.szukaj_najblizszego = f28;
    if (!wynik.trasa_od_celu.empty()) wynik.koniec = wynik.trasa_od_celu.front();
    return wynik;
}

}  // namespace openee
