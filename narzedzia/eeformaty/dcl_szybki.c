/* OpenEE – szybka dekompresja PKWARE DCL "implode" (implementacja własna, wg publicznego opisu
 * algorytmu "blast"). Budowa: gcc -O2 -shared -fPIC -o libdcl.so dcl_szybki.c
 * API: long dcl_rozpakuj(const unsigned char *we, long n_we, unsigned char *wy, long n_wy)
 *      zwraca liczbę bajtów wyjścia lub wartość ujemną przy błędzie. */
#include <string.h>

#define MAXBITS 13

typedef struct { short count[MAXBITS + 1]; short symbol[256]; } huff_t;

static const unsigned char LIT_REP[] = {11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8, 9, 7, 6, 7, 8, 7, 6,
    55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5, 7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9,
    8, 25, 11, 8, 11, 9, 12, 8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
    44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45, 44, 173};
static const unsigned char LEN_REP[] = {2, 35, 36, 53, 38, 23};
static const unsigned char DIST_REP[] = {2, 20, 53, 230, 247, 151, 248};
static const short LEN_BASE[16] = {3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264};
static const char LEN_EXTRA[16] = {0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8};

static huff_t H_LIT, H_LEN, H_DIST;
static int gotowe = 0;

static void buduj(huff_t *h, const unsigned char *rep, int nrep) {
    short len[256]; int n = 0, i;
    short offs[MAXBITS + 2];
    for (i = 0; i < nrep; i++) { int k = (rep[i] >> 4) + 1; while (k--) len[n++] = rep[i] & 15; }
    memset(h->count, 0, sizeof h->count);
    for (i = 0; i < n; i++) h->count[len[i]]++;
    offs[1] = 0;
    for (i = 1; i < MAXBITS; i++) offs[i + 1] = offs[i] + h->count[i];
    for (i = 0; i < n; i++) if (len[i]) h->symbol[offs[len[i]]++] = (short)i;
}

typedef struct { const unsigned char *we; long n, pos; unsigned buf; int cnt; int blad; } st_t;

static int bity(st_t *s, int need) {
    unsigned v = s->buf;
    while (s->cnt < need) {
        if (s->pos >= s->n) { s->blad = 1; return 0; }
        v |= (unsigned)s->we[s->pos++] << s->cnt;
        s->cnt += 8;
    }
    s->buf = v >> need; s->cnt -= need;
    return (int)(v & ((1u << need) - 1));
}

static int dekoduj(st_t *s, const huff_t *h) {
    int code = 0, first = 0, index = 0, len;
    for (len = 1; len <= MAXBITS; len++) {
        code |= bity(s, 1) ^ 1;
        int c = h->count[len];
        if (code < first + c) return h->symbol[index + (code - first)];
        index += c; first += c; first <<= 1; code <<= 1;
    }
    return -1;
}

long dcl_rozpakuj(const unsigned char *we, long n_we, unsigned char *wy, long n_wy) {
    st_t s = {we, n_we, 0, 0, 0, 0};
    long n = 0;
    if (!gotowe) {
        buduj(&H_LIT, LIT_REP, sizeof LIT_REP); buduj(&H_LEN, LEN_REP, sizeof LEN_REP);
        buduj(&H_DIST, DIST_REP, sizeof DIST_REP); gotowe = 1;
    }
    int lit = bity(&s, 8), dict = bity(&s, 8);
    if (lit > 1 || dict < 4 || dict > 6) return -2;
    for (;;) {
        if (s.blad) return -3;
        if (bity(&s, 1)) {
            int sym = dekoduj(&s, &H_LEN);
            if (sym < 0) return -4;
            int len = LEN_BASE[sym] + bity(&s, LEN_EXTRA[sym]);
            if (len == 519) break;
            int db = len == 2 ? 2 : dict;
            int d = dekoduj(&s, &H_DIST);
            if (d < 0) return -4;
            long dist = ((long)d << db) + bity(&s, db) + 1;
            if (dist > n) return -5;
            if (n + len > n_wy) return -6;
            for (int i = 0; i < len; i++, n++) wy[n] = wy[n - dist];
        } else {
            int b = lit ? dekoduj(&s, &H_LIT) : bity(&s, 8);
            if (b < 0) return -4;
            if (n >= n_wy) return -6;
            wy[n++] = (unsigned char)b;
        }
    }
    return n;
}
