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
| 621 | EE | e35_a | Parametry bohatera 0x5000ad2, dwie gwardie na jeden cel (B3) | odczyt typu/ulepszenia/tablic, `walka_atak_rzut_gry` ×2 | – | pełny zestaw parametrów bohatera (walka.md § 28); rozkaz 0x1000858 zgłoszony jako nieudany | parametry [P]; B3 – metoda wyboru drugiej gwardii nie działa |
| 622 | EE | e35_a | B1: zmiana pola atakującego przy celu nieosiągalnym | atak na obywatela, po 28 s PPM (162,5; 108,5), ponowne ataki (nieudane – cel poza kadrem) | AI wybiera obywatela ponownie z nowego pola przed upływem 30 s | 94524: wybór obywatela z pola (162,108), 22,8 s po ostatnim wpisie; obrót trybu 1 do punktu ruchu w 86682; Core zgodny co takt w całym zapisie (6725 taktów) | wpis mapy nieosiągalnych ważny tylko dla tego samego pola atakującego [P]; obrót do EEUGLocation [P] |
| 623 | EE | e39_a (nowy, 4 układy) | Zajętość miejsc przy 2–3 gwardiach; C2 – przesunięcie celu przy AI; potwierdzanie rozkazu MCP | `walka_atak_rzut_gry` z odczytem kolejki co takt, `walka_czekaj_na_stan`, `obs_rozkaz` | druga gwardia omija zajęte miejsce | S1 (ta sama strona): miejsca (177,975; 102,025) i (179,025; 102,025) – oba najbliższe, zajętość nie rozstrzyga; S2 (przeciwne strony): (190,5; 102,025) i (190,5; 100,975); cel tworzony 650–850 ms czasu gry po PPM (4/4); S3 i C2 nieważne – jednostki kampanii gracza 1 w pobliżu (bohater S3 zginął, gwardia C2 zaatakowała jednostkę 0x10001d7) | potwierdzanie rozkazu stanem gry działa [P]; wybór miejsc zgodny z sortowaniem [P]; układ rozstrzygający zajętość i C2 – do powtórzenia na mapie bez jednostek kampanii |
| 624 | EE | e35_a | Skąd punkt (163,5; 103,5)? Graf podsektorów | `podsektory` (nowy odczyt Riverlands_MCP), atak 856 → bohater, po 2021 atak 858 → bohater, odczyt kolejki co takt | punkt = punkt reprezentatywny podsektora na ścieżce grafu | 1858 podsektorów, siatka 19 / 15 × 15; pole celu (163,105) w podsektorze 472 o punkcie (163,103); gwardia 858 w 523 (rodzaj 4, nie sąsiaduje z 472), 856 w 469 (sąsiad 472); kolejka 858: Location (163,5; 103,5) + atak w takcie 8000, potem 2016, drugi 8000 bez punktu, 2025 → 5000 | pochodzenie punktu wyjaśnione [P]; graf niezmienny po rozkazach [P] |
| 625 | EE | e35_a | Dane do budowy podsektorów | `obszary` (siatki +0xF4/+0xF8, lista obszarów), `podsektory` (cała mapa) | – | 1858 podsektorów (1857 z polami, 39 480 pól), siatka +0xF4 w układzie x·H + y (podsektor ⊂ jeden obszar), +0xF8 pusta; pola struktury obszaru +0x78/+0x7C w wektorze +0x3C nie są id/rodzajem (inne obiekty niż mapa 0x917C48) | dane referencyjne budowy grafu [P] |
| 626 | EE | e42_c2_1v1 (SCN 250, Riverlands 64 × 64) | Czy EE wczyta czystą mapę 250 z gwardiami (rekord 231 → 250)? | `start_testowy` | gra | odprawa → inny ekran, limit czasu; etap 12 (zad. 197–199): komunikat „Plik z zapisaną grą jest nieprawidłowy” dla SCN 250 | Empire Earth.exe nie wczytuje SCN 250 (AoC) [P] – wariant A niemożliwy w EE |
| 627 | EE | e42_c2_1v1 (231, oczyszczona Troja) | Czy oczyszczona kopia 231 (bez jednostek graczy, obiekty Świata usunięte w prostokącie, pusty kawałek 6) działa? | start, `gracze`, `jednostki`, atak MCP | 2 jednostki testowe | gra wczytana; gracz 1: 1 jednostka, gracz 5: 1, Świat 4137; atak: „cel nie jest rysowany” (10 pól – poza polem widzenia 4) | czyszczenie 231 działa [P]; potrzebna widoczność celu |
| 629 | EE | e42_c2_1v1 (odległość 3) | Czy cel w polu widzenia gwardii daje się wskazać bez samoczynnej walki? | jak 627 | – | gwardia tworzy EEUGAttackUnit samoczynnie w 34 ms (pochodzenie 0), cel zabity przed PPM | cel w polu widzenia = walka bez rozkazu [P] |
| 630 | EE | e42_widocznosc (6 par) | Czy jest odległość „widoczny, ale bez samoczynnego ataku”? | pary w odległości 4; 4,12; 4,12; 4,24; 4,47; 5 | – | 4: walka samoczynna; ≥ 4,12: cel nierysowany | brak okna – potrzebny obserwator (prorok, atak 0) [P] |
| 628 | EE | e35_a | Wejście floodu regionów 0x4240D3 | `regiony_wejscie` (nowy odczyt), `obszary` | – | 78 400 pól: rodzaj pola +0x04, bajt +0x14, obiekty pól (5408 pól), typy (+0x568/+0x600/+0x4B4/+0x612), 43 obszary (+0xD8/+0xDA); siatka 0x917CB8 – brak | z tego wejścia Core odtwarza 39 480/39 480 etykiet regionów i 1857/1857 podsektorów [P] |
| 631 | EE | e42_1v1 (generator) | C2: czysta mapa 1:1 z działającym atakiem MCP | `walka_atak_rzut_gry`, nagranie 2808 próbek | EEUGAttackUnit | jednostki: gracz 1 – gwardia (164,118) i prorok (170,108), gracz 5 – gwardia (164,108); do PPM obie 5000 bez celu; PPM 47556 → EEUGAttackUnit 0x5000ad0 (pochodzenie 1) utworzony 48068, 2012 → 8000 → 10003, podejście, 2021 po 9,9 s; cel odpowiada w 60374 | **czysta mapa gotowa** [P] |
| 632 | EE | e42_2v1, 3v1, blokada_podejscia, cel_otoczony | Warianty z generatora | start + `jednostki` (+ atak w 2v1) | liczby i pozycje z opisu | patrz raport 42 § 9 | warianty z danych działają w EE [P] |
| 633 | EE | e42_2v1 | Dwie gwardie na jeden cel – przebieg do porównania z Core | `walka_atak_rzut_gry` ×2, nagranie 3697 próbek | – | ataki 45000 i 70567 (EEUGAttackUnit, pochodzenie 1) | Core: obie gwardie zgodne co próbkę (2 próbki spóźnione); cel do umierania [P] |
| 634 | EE | e42_3v1 | Trzy gwardie; kontakt jednostek | jak 633 + trzeci PPM (po śmierci celu – EEUGLocation, kurs 2,8799) | – | gwardia 857 zatrzymana regułą (a) przy stojącej 855: krok 0,0023 w takcie po regule, 9000 takt później | reguła (a) zalicza punkt w następnej fizyce (0x6213D8 +0x330 = 8) [P]; po poprawce 6413/6413 |
| 635 | EE | e35_a | Surowe obiekty pól (klasyfikacja +0x04/+0x14) | `pola_surowe` (nowy odczyt) | – | 39 480 pól, vtable pola 0x82C574, mapy 0x82C524 | wejście do analizy 0x516E8C [P] |
| 636 | EE | e35_a | Tablice wierszy mapy i G | `mapa_tablice` (nowy odczyt) | – | bajt +2 tablicy terenu = tekstura SCN, wysokości wierzchołków = SCN (40 041/40 041), G = 0,408248 | dane SCN są wejściem klasyfikacji bez zmian [P] |
| 637 | EE | czysta e42, e13_para | Klasyfikacja pól na drugiej mapie | `regiony_wejscie`, `mapa_tablice`, `pola_surowe` | – | e13: rodzaj 22 725/22 725 z SCN, obszary 42 (model 43 → klify 8-spójne), listy obiektów 2226/2266 (ruchome jednostki) | [P] |
| 638 | EE | e44_kontakt_590, e44_cit_1v1 | Kontakt gwardii w walce (układ 590 G1) i śmierć obywatela | `walka_rejestruj_*` z push/kontaktami, atak PPM | – | kontakt: 2465 próbek, po kolejności wg pozycji zgodne co takt; obywatel: 6000 – 47 taktów, 6001 – 1, 6002 – 1177; obywatel nieodpychany (promień 0,3) | [P] |
| 639 | EE | e44_kontakt_590, e42_1v1 | Kolejność kolejki fizyki 0x918DDC | rejestrator: `lista_fizyki` (nowy odczyt) | – | [A_GRD, T_GRD, OBS] i [T_GRD, A_GRD, OBS] – x rosnąco, potem y; stała w czasie nagrania | [P] |
| 640 | EE | e13_para | Graf podsektorów drugiej mapy | `podsektory` | – | bok sektora 12 (0x42439A), 1320 podsektorów – graf Core z SCN 1320/1320 identycznych, punkty i sąsiedzi 1320/1320 | [P] |
| 647 | EE | e47_dom1, e47_mur, e47_przejscie, e47_rng_bez_p5 (generator e42) | Budynek jako cel: obrażenia, śmierć, zmiana mapy; mur; przerwany atak; losowania bez gracza 5 | `mapa_obszar` przed/Dying/po/Dead, rejestrator z `mapa_pola`, `walka_parametry_typu`, `obs_rozkaz` | – | dom: 6 HP na trafienie co 60 taktów, śmierć 52261, +0xD4 = 52262, przebudowa w następnym takcie, gruz 0x24ac (HP 1) na polu; mur: gwardia w Idle (brak celu samoczynnego); przerwany atak: dom zostaje z HP 12; rng_bez_p5: dodatkowe losowania w tych samych czasach gry co 646 | przebudowa sektora 0x4278C3 zgodna z Core [P]; mury odrzucane 0x639AC3 [P]; losowania zależne od czasu, nie od jednostek [P] |
| 648 | EE | e47_przejscie2, e47_mur | Trasa w trakcie zniszczenia przeszkody; mur atakowany rozkazem | rejestrator 5 jednostek z `mapa_pola`, `obs_kolejka` przed/po, `walka_atak_rzut_gry` na mur | – | prorok zachowuje stary objazd (trasa bez zmian po przebudowie); mur: 4 HP na trafienie, śmierć 106502, +0xD4 = 106503 | trasy nie są unieważniane [P]; graf po zniszczeniu muru zgodny z Core [P] |
| 649 | – | – | Czy pulpit jest wolny (drugi agent na tym samym komputerze)? | `laboratorium` | – | „gotowe” (pulpit wolny) | start serii 650 [P] |
| 650 | EE | e48_prorok, e48_dom_t0, e48_dom_3v1, e48_koszary, e48_wieza, e48_mur_gruz, e48_kontakt3, e48_widzi, e48_widzi_ruch | Parametry ruchu proroka; ruch proroka bez zmiany mapy; atak na budynek od rozkazu; budynek 2×2; pozostałości; kontakt trzech gwardii; pierwsze CanISeeEnemy | `walka_parametry_typu` (ulepszenie +0x34), rejestrator z `mapa_pola`, `walka_atak_rzut_gry`, `obs_rozkaz` (`czasy_gry`), `mapa_obszar` | – | prorok: ×10/9 a, vmax, α, ωmax (ulepszenie gracza); dom_t0 – atak niewykonany (cel poza polem widzenia obserwatora 8,49 > 8 – błąd układu); koszary: graf przed/po = Core, gruz 362 na 4 polach; wieża, mur, dom: gruz 361; kontakt3 – kontakty bez odepchnięcia; widzi – cel wybrany w 34 ms (jak Core); widzi_ruch – brak wykrycia przy 4,09 | Prophet.tai i parametry z ulepszenia [P]; miejsce podejścia przy budynku [P/H]; 0x55C315 – czas kroku MCP (`czasy_gry`: start 7397, PPM 33375–38045, cel 38352) [P] |
| 651 | EE | e48_dom_t0 (obserwator przesunięty) | Atak jednej gwardii na dom od rozkazu | jak 650 | – | miejsce podejścia (164,75; 113,25), trafienia do śmierci domu | Core zgodny co próbkę od rozkazu do śmierci domu [P] |
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

## Etap 37 – 9006 i ponowny wybór celu nieosiągalnego (bez nowych uruchomień gry)

Metoda: ponowna analiza nagrań 616, 619 i 620 co takt (pola `tryb`, `v`, `kat`, `obrot`, licznik prób celu, czasy
utworzenia celów) i analiza statyczna kodu EE (capstone, adresy w `walka.md` § 27). Porównanie stanu co takt:
`narzedzia/eksperymenty/porownaj_takty.py` (próbki nieaktualne rejestratora – stan z poprzedniego taktu jeden raz –
liczone osobno: 616 → 3 takie próbki). Nowych zadań MCP nie uruchamiano – dane z etapu 36 rozstrzygnęły hipotezy.

| Pytanie | Dane | Wynik | Wniosek |
|---|---|---|---|
| Dlaczego w 619 9006 trwa 1 takt przy v = 0,259 i pozycja stoi? | 619 co takt: tryb 5, v = 0,2591 i pozycja niezmienne w 9006/5001/5002/2013/2024/8000/2015 | tryb 5 (0x54E0F1) działa tylko dla celu EEUGLocation; 9014 dla EEUGAttackUnit = prawda (0x62871E) | [P: kod + pomiar] |
| Dlaczego w 620 9006 trwa 3 takty? | 620: cel EEUGLocation `kat` = −0,36194, `obrot` = 1; obrót −0,27266 → −0,39040 → −0,40459 | kurs końcowy = kąt szyku z kliknięcia; z nim Core = gra (kurs do 4·10⁻⁵ rad) | [P] |
| Skąd kąt szyku? | 616: `kat` = 2,7300477, jednostka nieruchoma w (164,5; 118,5), punkt (159,2415; 106,4529) | UMArcTan2(−Δx, Δy) od środka zaznaczenia = 2,7300477 | [P: kod 0x64138B + pomiar] |
| Kiedy cel jest porzucany? | 619: 2013 przy liczniku prób 25, 2025 przy 26 | EnemyUnitReachable: licznik ≤ 25 | [P: kod 0x60B235 + pomiar] |
| Dlaczego AI wraca do celu po 30 s, a nie od razu? | 616: ponowne wybory 30,2–30,5 s po ostatnim PrepareToMove (3×); 619: od razu inny cel | mapa celów nieosiągalnych (+0xA0, 30 s, te same pola), wpis przy każdym PrepareToMove bez miejsca podejścia | [P: kod + pomiar] |
| Czy rozkaz gracza jest kontynuowany po porzuceniu? | 616/619: po 2025 kolejka pusta, następny cel z `pochodzenie_1C` = 0 | nie – dalej wybiera AI; ten sam licznik prób celu i ta sama mapa | [P] |

Odtworzenie w Core po zmianach etapu 37 (`odtworz_e35.gd`, kąt celu z nagrania):

| Nagranie | Przed (etap 36) | Po (etap 37) | Następna różnica |
|---|---|---|---|
| 619 | 116 przejść, t = 64147 (9006) | 345 przejść / 936 taktów do porzucenia (t = 71954) | t = 71988: AI wybiera bohatera 0x5000ad2 – w odtworzeniu brak bohatera (parametry [N]) |
| 620 | 37 przejść, t = 59783 (9006) | wszystkie 39 przejść / 4471 taktów do końca ruchu | t = 192032: kolejny rozkaz MCP (bohater), nieodtwarzany |
| 616 | 2 przejścia (drugie kliknięcie), brak wyboru AI | 5322 takty bez różnicy stanu, 4 wybory AI i 4 porzucenia w tych samych taktach | koniec zapisu |
| 616 (etap 38, pełny skład) | 2 rozkazy ruchu (47272, 47511) + atak 97388 | 6420 z 6423 taktów stanu zgodnych (3 próbki spóźnione), macierz/pozycja bitowo | obywatel gracza 1 (0x1000857) dostaje w 136289 cel MCP spoza odtworzenia; 0x1000858 – rozkaz 220637 nieodtwarzany |
| 619 (etap 38, pełny skład z bohaterem) | rozkazy 40113, 88694, 123981/152108/180236 (0x1000858), 204272 | gwardia A: 7270/7273 taktów stanu, 6375 taktów macierzy bez różnicy; HP bohatera zgodne w całym zapisie (79 trafień po 14, regeneracja +2 co 30 taktów) | 0x1000858 t = 124254 (EEUGLocation przed celem ataku – § 28 walka.md); stany bohatera 5001/16000 – skrypt leczenia poza Core |
| 620 (etap 38, pełny skład) | rozkazy 39602, 50852 (ruch), 109150/136766/164382 (0x1000858), 191998 | gwardia A: 6418/6419 taktów (1 odczyt pośredni 2016) | 0x1000858 t = 109423 (jak 619) |
