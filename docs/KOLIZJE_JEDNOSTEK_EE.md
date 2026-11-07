# Kolizje i mijanie się jednostek – Empire Earth 1 / The Art of Conquest

Etap 13 OpenEE. Kontrolowane eksperymenty w oryginalnych grach na specjalnym scenariuszu testowym. Trajektorie
pochodzą z pamięci procesu, z zegarem monotonicznym i licznikiem czasu gry w każdej próbce (30 Hz). Wszystkie
przypadki wykonano w **EE i w AoC** z tym samym plikiem scenariusza i tymi samymi rozkazami.

**Oznaczenia:**
- **[P]** potwierdzone powtarzalnym pomiarem (tu: EE i AoC z tym samym wynikiem);
- **[W]** wniosek z ograniczonego pomiaru;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Scenariusz testowy

`narzedzia/eksperymenty/scenariusz_testowy_kolizji.py` buduje scenariusz z **kopii** kampanii EE „Blitzkrieg” (SCN 231). Wybór ten
wynika z tego, że wersję 231 wczytują obie gry, a mapa ma duży płaski obszar: x ≈ 151–195, y ≈ 164–182,
wysokość 0,82, bez murów i drzew. Narzędzie klonuje rekordy obywateli gracza 1 i ustawia im dokładne położenia,
nowe identyfikatory od 0x100033b oraz liczniki obiektów. Oryginalnych plików scenariuszy nie zmieniano. Kopia trafia
do katalogu `Scenarios` gry jako `000_EETEST_e13_c_*.scn` i jest usuwana po zadaniu.

| Plik (`Testy_MCP/mapy/`) | Układ |
|---|---|
| `e13_para` | A1 (159,5; 169,5) i B1 (169,5; 179,5) – naprzeciw po przekątnej |
| `e13_5v5`, `e13_10v10` | grupy A i B o 5 / 10 obywatelach, środki jak wyżej |
| `e13_krzyz` | A5 w (159,5; 169,5) idzie w kierunku (1, 1); C5 w (161,5; 177,5) idzie w kierunku (1, −1) – przecięcie pod kątem prostym w (164,5; 174,5) |
| `e13_cel` | 4 obywateli w odległości 7 pól od wspólnego punktu (164,5; 174,5) z czterech stron |
| `e13_przesmyk` | rząd 16 domów (typ 37) w y = 174,5 z jedną luką szerokości 1 pola w x = 164; A5 przechodzi przez lukę |
| `e13_para` (przypadek „stoi”) | B1 stoi, A1 dostaje rozkaz, którego trasa oktylowa przechodzi przez pole B1 |

Jednostki: obywatel (`dbobjects` 32), `Size of collider` 0,3, `Size in formation` 0,625, `Speed` 0,5. W tym
scenariuszu prędkość wynosi 0,650 pola/s czasu gry (`docs/MECHANIKA_PREDKOSCI_EE.md` § 5).

## 2. Metoda

- Start: kopia testowa exe bez intra; Esc pomija przerywnik scenariusza tylko wtedy, gdy czas gry stoi.
- Zaznaczanie ramką (`ruch_zaznacz`) i grupy klawiszowe Ctrl+N / N. Rozkaz: PPM w punkcie mapy
  (`ruch_rozkaz`).
- Zapis: `ee_czas.ruch_czas` (`Testy_MCP/ee_ruch/e13_<gra>_kol_*.json`, lokalnie).
- Analiza: `ee_kolizje.analiza` (krok `ruch_analiza`) liczy:
  - najmniejszą odległość środków między grupami i w grupie oraz czas nakładania (odległość < 0,3);
  - zatrzymania w trakcie ruchu (prędkość < 0,08 pola/s przez ≥ 0,3 s);
  - odchylenie od odcinka start–koniec;
  - prędkość ustaloną i minimalną.
- Ograniczenie: punkt rozkazu ma błąd ok. ±0,5 pola, bo przeliczenie piksela na mapę ma błąd kamery 0,6 pola. Dlatego
  porównania dotyczą przebiegu ruchu, a nie dokładnego punktu docelowego.

## 3. Wyniki

| Przypadek | Zadania (EE / AoC) | Najmniejsza odległość między grupami | Nakładanie | Zatrzymania | Prędkość ustalona (pola/s rzecz.) | Wynik |
|---|---|---|---|---|---|---|
| 1 na 1 naprzeciw | 268 / 280 | 0,054 / 0,030 | 1 para, 0,35 s | 0 | 0,949–0,954 | przenikanie, bez zwalniania i objazdu |
| 5 na 5 naprzeciw | 270 / 282 | 0,021 / 0,015 | 5 / 4 par z 25 | 0 | 0,942–0,950 | przenikanie całych grup; każda jednostka przechodzi przez „swoją” z naprzeciwka |
| 10 na 10 naprzeciw | 272 / 284 | 0,017 / 0,024 | 16 / 15 par ze 100 | 0 | 0,935–0,957 | jak 5 na 5 |
| Skrzyżowanie pod kątem prostym, 5 + 5 | 325 / 327 | 0,131 / 0,152 | 5 / 3 par | 0 | 0,944–0,950 | przechodzą przez siebie w punkcie przecięcia |
| Przesmyk 1 pola, 5 jednostek | 278 / 290 | – | w grupie: 4 pary, d_min 0,184 | 0 | 0,940–0,957 | wszystkie przechodzą przez lukę (x = 164,38–164,65) w 0,9 s, nakładając się; bez kolejki i czekania |
| Jednostka stojąca na trasie | 329 / 331 | 0,660 / 0,666 | 0 | 0 | 0,952 | **objazd**: trasa skręca ok. 1,5 pola przed stojącą jednostką i obchodzi jej pole przez sąsiednie pola, bez zwalniania |
| Kilka jednostek do jednego punktu (2 z 4) | 333 / 335 | 0,297 / 0,295 (końcowe położenia) | – | 0 | 0,953–0,955 | druga jednostka zatrzymuje się 0,3 pola od pierwszej, która już stoi; pierwsza nie jest przesuwana |

Dodatkowo podczas pierwszej próby skrzyżowania (299 / 301) grupa A przeszła obok stojącej grupy C w odległości
2,12 pola. Trasa nie przecinała pól C, więc objazdu nie było.

### 3.1. Objazd jednostki stojącej (przypadek „stoi”)

Trajektoria A1, EE (AoC różni się o ≤ 0,01 pola):

| t (s) | x | y | odległość od B1 (169,5; 179,5) |
|---|---|---|---|
| 0,0 | 160,03 | 170,12 | 13,33 |
| 12,0 | 168,13 | 178,13 | 1,94 |
| 12,6 | 168,42 | 178,60 | 1,41 – początek skrętu na północ |
| 13,2 | 168,47 | 179,17 | 1,08 |
| 14,1 | 168,93 | 179,85 | 0,67 – najbliżej |
| 15,0 | 169,56 | 180,41 | 0,91 |
| 17,1 | 171,53 | 180,51 | 2,26 – cel |

Trasa oktylowa bez objazdu (najpierw przekątna, potem prosto – `MECHANIKA_RUCHU_EE.md` § 5) prowadziłaby przez pole
(169, 179), w którym stoi B1, i mijałaby jego środek o ok. 0,07 pola. Oryginał omija to pole po siatce: skręca
do pola (168, 179), potem idzie do (169, 180) i dalej prosto. Prędkość pozostaje stała, więc to zmiana trasy, a nie
hamowanie [P: EE i AoC]. Moment zmiany trasy, ok. 1,5 pola przed przeszkodą, wskazuje na ponowne wyznaczenie trasy
po wykryciu zajętego pola [W]. Jak daleko gra sprawdza zajęte pola, zmierzono w jednym układzie – [N].

## 4. Odpowiedzi na pytania etapu

| Pytanie | EE | AoC | Pewność |
|---|---|---|---|
| Przenikanie jednostek w ruchu | tak | tak | [P] |
| Zwalnianie przy spotkaniu | nie (prędkość ustalona bez zmian, brak zatrzymań) | nie | [P] |
| Zatrzymywanie się | nie | nie | [P] |
| Zmiana trasy wobec jednostki **w ruchu** | nie (odchylenia ≤ 1,4 pola wynikają z szyku na końcu trasy) | nie | [P] |
| Zmiana trasy wobec jednostki **stojącej** | tak – objazd jej pola | tak | [P] (1 układ, identyczny w obu grach) |
| Popychanie | nie zaobserwowano (stojąca B1 i pierwsza jednostka w punkcie docelowym nie zmieniły położenia) | nie | [P] |
| Wybór innego pola przy wspólnym celu | druga jednostka staje 0,3 pola od pierwszej (= `Size of collider`) | to samo | [W] (2 jednostki) |
| Kolejka w przesmyku | brak – jednostki przechodzą przez siebie | brak | [P] |
| Różnice EE ↔ AoC | żadnych: przebiegi zgodne do 0,01–0,03 pola | – | [P] |

Wyniki etapu 9 (AoC, Riverlands: przenikanie, bród bez kolejki) potwierdzono w EE. Etap 12 miał w EE niejasny wynik
przy grupach idących naprzeciw (odległość 0,99 pola, odchylenia przy murze). Możliwe wyjaśnienie tamtej próby to objazd
**stojących** jednostek, jeżeli część grupy jeszcze nie ruszyła [H]; grupy idące naprzeciw jednocześnie przenikają się w EE [P].

## 5. OpenEE

- Bez systemu fizyki, odpychania i unikania lokalnego jednostek w ruchu, zgodnie z pomiarami.
- Dodano jedną regułę, potwierdzoną w obu grach: **pole jednostki stojącej jest przeszkodą dla trasy innej
  jednostki**. Implementacja:
  - `Symulacja.OMIJANIE_STOJACYCH`, `Symulacja.zajete_komorki`;
  - `Sciezki.znajdz(..., zajete)` – komórki blokowane tylko w jednym zapytaniu; komórki startu i celu nigdy nie są
    blokowane;
  - jednostki, które w tym samym takcie dostały rozkaz, w tym cała grupa, nie blokują się nawzajem.
- Uproszczenia [H]:
  - OpenEE uwzględnia stojące jednostki przy wyznaczaniu trasy w chwili rozkazu, a nie po wykryciu przeszkody
    ok. 1,5 pola przed nią. Dla przeszkody stojącej od początku trasa geometrycznie zgadza się z oryginałem.
    Jednostki, które zatrzymają się później, nie wymuszają ponownego wyznaczenia trasy;
  - jeżeli stojące jednostki zamykają jedyne przejście, trasa jest liczona bez nich i jednostka przenika. Oryginału
    w tym przypadku nie mierzono;
  - odstępu 0,3 pola przy wspólnym celu nie odtworzono, bo pomiar objął 2 jednostki [W]. Szyk grupy daje odstęp
    `Size in formation` jak dotąd.
- Testy: `godot/testy/testy_etapu13.gd`, sekcja „E13 kolizje” (4 testy).

## 6. Nieustalone

1. Zasięg wykrywania stojącej przeszkody i reguła ponownego wyznaczania trasy (jeden układ geometryczny).
2. Zachowanie przy wspólnym celu dla więcej niż 2 jednostek: dwie dolne jednostki nie dały się zaznaczyć ramką,
   bo leżały przy dolnej krawędzi widoku 3D.
3. Jednostki różnych typów i rozmiarów (kawaleria, `Size of collider` ≠ 0,3), jednostki wroga, budynki w budowie.
4. Przejście zamknięte stojącymi jednostkami.
