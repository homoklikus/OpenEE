# Dziennik eksperymentów z oryginalną grą (od etapu 35)

Każdy wpis odpowiada na jedno pytanie badawcze. Nagrania i wyniki zadań są lokalne (`Testy_MCP/ee_obserwacja`,
`Testy_MCP/ee_zadania`), nie trafiają do repozytorium. Oznaczenia: [P] / [W] / [H] / [N].

**Scenariusz e35_a** (etap 35):
- kopia scenariusza kampanii EE „Wojna trojańska” (SCN 231) z jednostkami dopisanymi narzędziem
  `narzedzia/eksperymenty/scenariusz_testowy_kolizji.py zbuduj` według `dane/testy_walki/e35_a.uklad_wej.json`;
- gracz 1:
  - prorok-obserwator 0x1000855 (164,5; 111,5) – pole widzenia 8, atak 0, sam nie atakuje;
  - gwardia 0x1000856 (164,5; 118,5);
  - obywatel 0x1000857 (166,5; 118,5);
  - gwardia kontrolna 0x1000858 (162,5; 118,5);
- gracz 5 (wróg w obu kierunkach – odczyt 611):
  - obywatel 0x5000ad0 (160,5; 105,5);
  - gwardia 0x5000ad1 (168,5; 104,5) – poza polem widzenia proroka (8,06 > 8);
  - bohater Aleksander 0x5000ad2 (164,5; 104,5);
  - dom 0x5000ad3 (158,5; 112,5).
- Wszystkie cele są widoczne dla gracza 1 (poza 0x5000ad1), oddalone o ponad 4 pola od jednostek bojowych
  gracza 1. Na starcie nikt nie walczy.

| Nr | Gra | Scenariusz | Pytanie | Metoda | Oczekiwanie | Wynik | Wniosek |
|---|---|---|---|---|---|---|---|
| 602–604 | EE | e31_a | Czy cel PPM jest rysowany? | lista renderu kamery 0x9125D8+0x2A0 | – | cel spoza listy (mgła) | obiekt we mgle nie może być wybrany [P] |
| 605–610 | EE | e31_a | Dlaczego PPM daje EEUGLocation przy celu na liście renderu? | porównanie czasu PPM i śmierci celu w nagraniach | – | **każdy PPM po śmierci celu** (np. 605: śmierć t = 69874, PPM t = 78466) | zwłoki są na liście renderu, a HP ≤ 0 daje w 0x4044CD rozkaz ruchu EEMPathTo [P: kod i pomiar] |
| 611 | EE | e31_a | Czy gracz 1 uważa gracza 5 za wroga? (warunek 0x404395) | odczyt wiersza +0x9E4 graczy | gdy 0 – PPM nie tworzy ataku | gracz 1: [1,0,0,0,0,1,1,…] – wróg | hipoteza dyplomacji obalona [P] |
| 612 | EE | e35_a | Czy w czystej scenie (cel żywy, widoczny, samotny) PPM działa ze starym rzutem MCP? | `walka_atak_potwierdzony` | EEUGAttackUnit | EEUGLocation (3 próby); 0x5000ad1 poza listą renderu | przyczyna nie jest scenowa – zostaje rzut [P] |
| 613–614 | EE | e35_a | Czy model kamery MCP odpowiada kamerze gry? | zrzut okna + odczyt kamery gry (+0x104 macierz, +0x274 tg, +0x280 skala, +0x288/+0x28C środek) | – | gra: ogniskowa 1720 / 0,447405 = 3844 px, środek (1720, 672); MCP: 3650 px, (1720, 720) | model MCP ma błąd skali i środka pionowego [P] |
| 615 | EE | e35_a | (błąd narzędzia – złe pola środka) | – | – | wynik nieważny | – |
| 616 | EE | e35_a | Czy PPM w rzut z kamery gry tworzy atak? | `walka_atak_rzut_gry` | EEUGAttackUnit | **EEUGAttackUnit 0x5000ad0** (856, próba 3, h = 0,3); dom: obywatel dostał EEUGGather; bohater: kolejka pusta w chwili odczytu, cel przypisany później (t = 220671) | rozkaz ataku gracza przez MCP działa [P] |
| 617 | EE | e35_a | Powtarzalność i kontrola | kontrola LPM w rzut_gry własnej jednostki; ten sam atak; cel we mgle | LPM zaznacza; atak; brak PPM | LPM → [0x1000857]; **EEUGAttackUnit** w 1. próbie; 0x5000ad1 – odmowa (mgła); bohater – kolejka pusta | rzut z kamery gry potwierdzony zaznaczeniem; atak powtarzalny [P]; bohater [N] |

| 618 | EE | e35_a | Czy sama poprawka rzutu w `ee_kamera.rzut` naprawia dawną procedurę? | stara `walka_atak` (etap 32) i `obs_rozkaz` z rzutem z kamery gry | zaznaczenie i atak | zaznaczenie w 1. próbie; **EEUGAttackUnit 0x5000ad0 w 1. próbie** | błędny model rzutu był główną przyczyną niepowodzeń etapów 32–34 w widocznych, żywych celach [P] |

## Wnioski etapu 35 o rozkazie ataku

Trzy niezależne przyczyny dawały wcześniej EEUGLocation [P]:
1. cel we mgle – obiekt spoza listy renderu (602–604);
2. cel martwy – zwłoki na liście renderu, PPM na HP ≤ 0 daje ruch (605–610);
3. błędny rzut MCP – model kamery z etapu 7 (ogniskowa 3650, środek 720) zamiast pól kamery gry (612).

Ścieżka wejścia działa [P]: kursor gry, przyciski (PPM w teren daje ruch), wybór obiektu (LPM w rzut z kamery gry
zaznacza własną jednostkę), komunikat EEMAttackUnit (0x4C) → EEUGAttackUnit.

Otwarte [N]:
- PPM na wrogim bohaterze (kolejka pusta w chwili odczytu);
- obywatel na wrogim domu → EEUGGather (komunikat 0x51) – czy to zbiórka, czy zachowanie domu skopiowanego z gracza 1;
- AoC – nie badano.
