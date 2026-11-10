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

## Etap 36 – scenariusze walki C na e35_a i odtworzenie w Core

Odtwarzanie w Core: `godot/testy/eksperymenty/odtworz_e35.gd` (mapa z pliku SCN e35_a – interpretacja w Core,
obiekty blokujące jak w scenie potyczki; gwardia, obywatel, prorok; rozkazy w taktach z nagrania). Porównanie przejść
stanów (czas, stan, pozycja) z nagraniem – lokalny skrypt `Testy_MCP/e36/skrypty/porownaj_przejscia.py`.

| Nr | Gra | Scenariusz | Pytanie | Metoda | Oczekiwanie | Wynik | Wniosek |
|---|---|---|---|---|---|---|---|
| 619 | EE | e35_a | Atak gracza, dwóch na jeden cel, zmiana celu – sekwencje stanów co takt | `walka_atak_rzut_gry` ×4, `obs_rozkaz`, `obs_kolejka`, rejestracja 170 s | – | atak 856 → 0x5000ad0: **2012 → 2013 → 2024 → 8000 → 2015 → 10003** (próbki co takt, cel EEUGAttackUnit od pierwszej próbki); obywatel stoi na polu z drzewami – gwardia dochodzi do (161,50; 105,53), cykl 5002 → 2013 → 2024 → 10003 na ostatnim punkcie trasy; `obs_rozkaz` – odmowa (jednostka poza kadrem przy wyborze); 858 → bohater: brak celu (3 próby) | sekwencja wejścia rozkazu ataku [P]; przerwanie i „dwóch na jeden” – niewykonane w tym zadaniu |
| 620 | EE | e35_a | Przerwanie ataku rozkazem ruchu; dwie gwardie na bohatera | atak 856 → obywatel, po 2 s PPM w teren bez ponownego wyboru (`wybierz_najpierw` = false) | cel ataku zastąpiony | **EEUGAttackUnit zastąpiony EEUGLocation** (jedyny cel kolejki, w tym samym takcie 2015 → 10003, trasa 4 punkty do (163,74; 116,00)); 858 → bohater: EEUGLocation (163,5; 103,5) przed celem ataku, trasa 1 punkt, 9006 → 5002 → 2025 → 5000, powtarzane co ok. 27 s; drugie przejście 856: pierwsza próbka po rozkazie w stanie **2016** | zwykły PPM czyści kolejkę także przy celu ataku [P]; wejście rozkazu ataku = InitialAttackState 2016, krok maszyny w tym samym takcie → 2012 [P: 619 i 620 – widoczne oba warianty próbki]; bohater nieosiągalny dla 858 – przyczyna [N] |
| 616 (ponownie) | EE | e35_a | Co działo się po rozkazie w 616? | analiza nagrania co takt | – | cel 856 od t = 47306 do 77954: **EEUGLocation (159,24; 106,45)** (chybiony PPM), obywatel 0x5000ad0 cały czas w 5000 na (160,5; 105,5) – pole z drzewami; potem AI: cel–obywatel co 8–30 s (2013/2024/8000/9006 → 5000) bez ataku | *[Etap 36 – zastąpione: „pościg za uciekającym obywatelem” (RAPORT_ETAP_35 § 8) – obywatel nie uciekał; to cykl wyboru nieosiągalnego celu przez AI.]* [P] |

Odtworzenie w Core [P – porównanie co takt]:

| Przypadek | Zgodne przejścia od rozkazu | Pierwsza różnica | Opis różnicy |
|---|---|---|---|
| 619 (atak gracza, cel nieosiągalny) | 116 (t 40147–64113, ok. 24 s; pozycje bitowo do 3 miejsc) | t = 64147 (9006 TurnToUnitFacing) | gra: 9006 trwa 1 takt, pozycja zamrożona przy v = 0,259; Core: 4 takty, hamowanie z ruchem (0,007 pola) |
| 620 (atak → PPM w teren) | 37 (t 39636–59681) | t = 59783 (koniec 9006) | gra: 9006 trwa 3 takty; Core: 1 takt (kurs końcowy rozkazu PPM [N]) |
| 616 (PPM w teren, cel nieosiągalny obok) | do drugiego kliknięcia MCP (t = 47545) | – | drugie i trzecie kliknięcie próby nie jest odtwarzane |
| AI po utracie celu (616/619) | – | po 5000 | gra: ponowny wybór tego samego obywatela (2013 …) co 8–30 s; Core: brak ponownego wyboru (osiągalność 0x62D696 i liczniki prób [N]) |

Przed poprawką etapu 36 (wejście rozkazu w CheckRange [H]) Core był w 619 o jeden takt przed grą w przejściach i o jeden
takt za grą w kursie (obrót w trybie 1 zaczyna się w takcie rozkazu).
