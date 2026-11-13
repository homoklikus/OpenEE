# Eksperyment Fable 5.2: odbudowa list kontaktów przy zmianie pola – EE a AoC

Niezależny eksperyment badawczy (nie etap 53). Pytanie: czy różnica „EE odbudowuje kontakty po zapisie pozycji, AoC
przed zapisem” (`EE_AOC_POROWNANIE.md` § 2, dotąd [W]) jest prawdziwa i czy zmienia zachowanie.

Oznaczenia: [P] pomiar, [W] analiza statyczna, [H] hipoteza, [N] nieustalone.

## Wynik w skrócie

- **Różnica jest rzeczywista i algorytmiczna** [W + P]. Obie gry budują listę z pól w oknie ±R wokół pozycji z
  macierzy jednostki. EE robi to po zapisie nowej pozycji, AoC przed zapisem, więc AoC liczy okno od pozycji z
  poprzedniego taktu.
- Symulacja list z nagrań co takt: reguła „nowa pozycja” zgadza się z EE w 100 % próbek, a z AoC nie; reguła „stara
  pozycja” odwrotnie (7 nagrań rozróżniających, 0 niezgodności dla właściwej reguły).
- **Dla jednostek o rozmiarze < 1 różnica nie jest obserwowalna przy zwykłym przejściu granicy pola** (92 zmiany pola
  gwardii, 0 różnic okna). **Dla jednostek o rozmiarze całkowitym (1,0; 2,0; 3,0) różni się przy każdej zmianie pola**
  (153 zmiany pola tarana, 153 różnice okna; zmierzono rozmiar 1,0).
- **Skutek fizyczny potwierdzony** dla tarana jadącego na stojącą gwardię: w AoC kontakt powstaje później, taran
  zbliża się na 0,52 pola bez odpychania (próg 0,75), a gwardia kończy 0,2 pola dalej niż w EE.
- Core ma już obie reguły (`WariantTitan::kontakty`) i są one zgodne z pomiarem. Zmian w Core nie wykonano.

## 1. Repozytorium

- Lokalny HEAD: `630c2fa` (etap 52), zgodny z podanym zdalnym `main`.
- Drzewo robocze przed eksperymentem: tylko pliki użytkownika poza zakresem (`godot/project.godot`, pliki `.uid`,
  `konfiguracja/uzytkownik.cfg.przed_etapem11`).
- Zmiany eksperymentu (bez commitu): ten raport, `docs/titan/EE_AOC_POROWNANIE.md`, dwa skrypty diagnostyczne w
  `narzedzia/eksperymenty/`. Core, GDExtension, testy i wzorce bez zmian. Riverlands_MCP bez zmian.

## 2. Wersje EXE

| Gra | Plik | SHA-256 (początek) | Kopia testowa uruchamiana przez MCP |
|---|---|---|---|
| EE | `Empire Earth.exe` | `e352d7ae5ebc91f8` | `846350a85fd51330` |
| AoC | `EE-AOC.exe` | `db8fc5ceb85dbb9b` | `c636a2ab0a9c30d3` |

Każde zadanie zapisało kompilację w kroku `wariant` (zadania 681–689).

## 3. Odpowiadające sobie funkcje [W]

Dopasowanie po przepływie sterowania i danych (te same sekwencje instrukcji, różne przesunięcia pól typu).

| Rola | EE | AoC |
|---|---|---|
| zapis macierzy z kontrolą pola | 0x5F043B | 0x5FE7A8 (wołająca) + 0x5FE611 (wspólna część) |
| zapis x, y, z | 0x5F033A | 0x5FE76E + 0x5FE611 |
| zapis x, y | 0x5F0252 | 0x5FE73B + 0x5FE611 |
| zmiana pola (+0x1C/+0x20, listy pól, mgła, +0x248 → +0x24C) | 0x616F9D | 0x629AC3 |
| usunięcie wszystkich par jednostki | 0x5E960D (para: 0x5EF0AD) | 0x5F6F65 (para: 0x5FD2FF) |
| budowa listy z okna | 0x5E8F0E | 0x5F6817 |
| dopisanie pary (bez duplikatu, na początek listy) | 0x5E8B77 → 0x5F240E | 0x5F6226 → 0x600D8B |
| odbudowa po wczytaniu stanu | 0x53150C / 0x531513 | 0x53C57B / 0x53C582 |
| krok końcowy fizyki, kolizje, zastosowanie | 0x549E61, 0x5498C4, 0x549A08 | 0x556710, 0x5560CF, 0x556213 (`kolizje_objazdy.md`) |

Pola: lista kontaktów +0xC4 (głowa), +0xC8 (liczba) w obu grach; flaga kolizji EE +0x2D8, AoC +0x2DC; rozmiar
kolizji typu EE +0x474, AoC +0x178; grupa typu EE +0x4B4, AoC +0x1B8; flagi typu EE +0x5D4, AoC +0x2D0.

## 4. Przepływ sterowania

**EE 0x5F043B** (tak samo 0x5F033A i 0x5F0252):
1. nowe pole = floor(nowe x), floor(nowe y);
2. flaga zmiany: +0x2D8 ≠ 0 i pole ≠ (+0x1C, +0x20) – 0x5F0483…0x5F04A0;
3. `call 0x616F9D` – zmiana pola (0x5F04AD);
4. **zapis macierzy** +0x130 (0x5F04B9);
5. przy fladze: `call 0x5E960D`, `call 0x5E8F0E` (0x5F04C5, 0x5F04CC).

**AoC 0x5FE7A8 → 0x5FE611:**
1. `call 0x5FE611` z nowym x, y (0x5FE7C2);
2. w 0x5FE611: flaga zmiany (+0x2DC), `call 0x629AC3` (0x5FE671), przy fladze `call 0x5F6F65`, `call 0x5F6817`
   (0x5FE67C, 0x5FE683);
3. powrót i dopiero wtedy **zapis macierzy** (0x5FE7CE).

Budowa listy w obu grach czyta środek okna z macierzy jednostki: EE 0x5E8F58 (`fld [ebx+0x13C]`, `[ebx+0x14C]`), AoC
0x5F6860 (`[edi+0x13C]`, `[edi+0x14C]`). Funkcje zmiany pola (0x616F9D, 0x629AC3) nie zapisują macierzy. Wniosek: w EE
okno liczy się od nowej pozycji, w AoC od pozycji sprzed zapisu. To nie jest efekt inliningu ani przestawienia bez
skutku: AoC wydzielił wspólną część trzech funkcji zapisu do 0x5FE611 i wywołuje ją przed zapisem.

Reszta algorytmu jest wspólna:
- R = rozmiar, gdy rozmiar ≥ 1,0; inaczej max(0,5; rozmiar/2) (stałe 1,0 / 0,5 / 0,5 w obu grach);
- pola x od floor(x − R) do floor(x + R), w nich y od floor(y − R) do floor(y + R); kandydaci z list obiektów pól;
- filtr: nie on sam, flaga kolizji, HP > 0, vt+0x58 = 0, ta sama wartość vt+0x5C, ta sama przynależność grupy typu
  do {10, 27}, flagi typu;
- para dopisywana symetrycznie, na początek listy każdej strony.

**Druga różnica w filtrze** [W, nowa]: EE odrzuca parę, gdy (flagi_a XOR flagi_b) & 4 ≠ 0 (0x5E90D1). AoC używa maski
0xC i dodatkowo odrzuca parę, gdy jednostka ma bit 8 i którakolwiek strona ma grupę typu 0x22 (0x5F69CA…0x5F69DF).
Znaczenie bitu 8 i grupy 0x22 [N]; w pomiarach nie wystąpiły.
[Uzupełnienie – Fable 2: maska 8 = typy kosmiczne (grupy 31–34, tylko AoC), grupa 0x22 = `Sp15 - Space Fighter`;
`EKSPERYMENT_FABLE_DUZE_JEDNOSTKI.md` § 8 [W].]

AoC 0x5FE611 ma też na końcu przełączenie animacji 2 ↔ 0xD (0x5FE6EC…0x5FE72F), którego EE w tym miejscu nie ma [W];
bez związku z kontaktami.

### Kiedy okna się różnią [W]

Okna różnią się, gdy floor(x ± R) albo floor(y ± R) ma inną wartość dla starej i nowej pozycji.

| Rozmiar kolizji | R | Przejście granicy pola wzdłuż osi ruchu | Oś prostopadła |
|---|---|---|---|
| < 1 (piechota, obywatel) | 0,5 | okna równe | różne tylko, gdy w tym samym takcie pozycja mija linię połówkową pola |
| 1,0; 2,0; 3,0 | całkowite | **zawsze różne** – AoC obejmuje pole z tyłu, EE pole z przodu | jw. dla linii całkowitych |
| 1,5; 2,5; 3,5 | połówkowe | okna równe | jw. dla linii połówkowych |
| inne (1,1; 1,2; 1,3; 1,8…) | – | równe, chyba że x ± R mija liczbę całkowitą w tym takcie | jw. |

Ruchome typy z rozmiarem całkowitym (dbobjects „Size of collider”, Speed > 0): AoC 42 z 418 (1,0 – 31, m.in. taran,
czołgi, galera miedziana; 2,0 – 8; 3,0 – 3), EE 34 z 357.

Skutek dla R = 1 i ruchu w +x: przy wejściu na pole c EE widzi pola c−1…c+1, AoC c−2…c. Obiekt stojący na polu c+1
wchodzi do listy w EE o całe pole wcześniej. W AoC wchodzi dopiero przy wejściu na jego pole albo przy zmianie pola w
drugiej osi.

## 5. Eksperymenty

Mapy SCN 231 (wczytują obie gry) z generatora `scenariusz_testowy_kolizji.py zbuduj` na bazie
`e46_czysta_troja_bez_zwierzat.scn`; taran = rekord gwardii z polem `type` = 102. Wszystkie jednostki gracza 1.
Rejestrator `walka_rejestruj_start` (pełny: pole, pozycja, kurs, prędkość, push, lista kontaktów z identyfikatorami),
rozkazy `obs_rozkaz`. Narzędzia MCP bez zmian – istniejący rejestrator ma przesunięcia AoC i odczytał listy w obu
grach.

**Mapa `fable_kontakty`** (zadania 681–683):

| Tor | Ruchoma | Stojące | Cel |
|---|---|---|---|
| B | taran 0x…855 z (159,5; 105,5) w +x | gwardia 858 (165,5; 106,5) | dwa obiekty przy granicy pól |
| D | taran 856 z (159,5; 109,5) | gwardie 859 (164,5; 110,5), 85a (166,5; 108,5) | trzy jednostki |
| C | taran 857 z (159,5; 113,5) | dom 85b, pole (165, 114) | budynek |
| E | gwardia 85c z (159,5; 117,5) | gwardia 85d (165,5; 116,5) | kontrola: rozmiar < 1 |
| F | gwardia 85e (173,5; 110,9) | gwardia 85f (174,5; 109,5) | próba trafienia linii połówkowej |

**Mapa `fable_czolowe2`** (zadania 685–689): tarany 855 (161,5; 105,5) i 856 (161,5; 109,5), gwardie stojące 857
(165,1; 105,5) i 858 (165,5; 109,5), gwardia ruchoma 859 (161,5; 113,5), stojąca 85a (165,1; 113,5).

Eksperyment A (jedna jednostka przez granicę pola) jest częścią każdego toru: każda zmiana pola to osobny test reguły.

Analiza: `narzedzia/eksperymenty/fable_kontakty_okno.py NAGRANIE [--szczegoly]` symuluje listy wszystkich jednostek z
nagrania wg obu reguł (stan początkowy z pierwszej próbki, przy każdej zmianie pola: usunięcie par i budowa z okna) i
porównuje z listami gry w każdej próbce. `fable_kontakty_pary.py` podaje dla pary pierwszy kontakt, pierwszy push i
najmniejszą odległość.

Uwaga do sterowania: wysokość terenu w tym obszarze to 0,0–0,44, a jednostka przed pierwszym ruchem podaje z = 1,837
z zapisu scenariusza. Rozkazy z z = 1,837 trafiały o 1–2 pola obok celu. Nie wpływa to na test reguły (liczy się
faktyczny ruch), ale wymusiło powtórki eksperymentu czołowego (zadania 684–686).

## 6. Wyniki pomiarów [P]

**Reguła okna** – niezgodne pary (próbka, jednostka) między symulacją a grą:

| Nagranie | Gra | Próbek | Zmian pola: taran / gwardia | Reguła „nowa” (EE) | Reguła „stara” (AoC) |
|---|---|---|---|---|---|
| `fable_aoc_1` | AoC | 7891 | 28 / 21 | 17 876 | **0** |
| `fable_ee_1` | EE | 7847 | 28 / 24 | **0** | 17 704 |
| `fable_ee_3` | EE | 2502 | 13 / 7 | **0** | 146 |
| `fable_ee_4` | EE | 4299 | 14 / 8 | **0** | 8540 |
| `fable_aoc_4` | AoC | 4329 | 14 / 8 | 8586 | **0** |
| `fable_aoc_5` | AoC | 3305 | 16 / 0 | 4530 | **0** |
| `fable_ee_5` | EE | 3275 | 16 / 0 | **0** | 4480 |

`fable_ee_2` (5972 próbek): żadna jednostka nie minęła stojącej w zasięgu okna, obie reguły 0 – nie rozróżnia.

Okna obu reguł różniły się przy 153 ze 153 zmian pola tarana i przy 0 z 92 zmian pola gwardii (8 nagrań).

**Chwila powstania kontaktu** (mapa `fable_kontakty`, ten sam tor w obu grach):

| Tor | EE: wejście tarana na pole / odległość | AoC: wejście na pole / odległość |
|---|---|---|
| B taran–gwardia | x = 164 / 1,79 | x = 165 / 1,11 |
| D taran–gwardia 859 | x = 163 / 1,78 | x = 164 / 1,11 |
| C taran–dom | x = 164 / 1,80 | x = 165 / 1,11 |
| E gwardia–gwardia | x = 165 / 1,117 | x = 165 / 1,118 (to samo) |

Kontakt znika w EE przy wejściu na pole 167, w AoC w tym samym takcie dopiero powstaje ponownie (okno z tyłu) i trwa
do następnej zmiany pola. Dom tworzy parę w tym samym trybie co jednostka (różnica jednego pola).

W torach B–E pierwszy push pojawił się w obu grach przy tej samej odległości (taran–gwardia 0,7455 / 0,7465 = próg
(1,0 + 0,5)/2; dom: budzik 0,001 przy 1,0), bo kontakt w AoC powstał jeszcze przed progiem. Końcowe pozycje różniły się
tylko o różnicę kliknięć (≤ 0,02 pola).

**Skutek fizyczny** – taran czołowo na gwardię 857 (165,1; 105,5), nagrania `fable_ee_5` i `fable_aoc_5`; start ruchu
tarana w obu grach w tej samej próbce (t = 50147), tor tarana zgodny do 0,01 pola:

| | EE | AoC |
|---|---|---|
| kontakt | t = 55670, taran (164,005; 105,494), odległość 1,09 | t = 58431, taran (164,895; 106,004), odległość 0,54 (zmiana pola w osi y) |
| najmniejsza odległość bez kontaktu | 1,11 | **0,52** (próg odpychania 0,75) |
| pierwszy push gwardii | t = 56658, odległość 0,740, (0,028; −0,000) | t = 58431, odległość 0,545, (0,076; −0,456) |
| pierwsze przesunięcie gwardii | t = 56692 | t = 58465 (1,8 s później) |
| gwardia na końcu | (165,314; 105,372) | (165,110; 105,384) |

Pierwsza różniąca się próbka stanu: t = 55670 (lista kontaktów tarana i gwardii). Pierwsza różnica pozycji: t = 56692
(gwardia rusza w EE, w AoC stoi). Przyczyna: kod (kolejność zapisu i budowy listy), przy tych samych danych typu i tym
samym stanie początkowym. Dalsza symulacja: gwardia kończy 0,20 pola dalej w osi x w EE; taran w obu grach objeżdża
gwardię tym samym łukiem (do y ≈ 106,2) – także w AoC, gdy pary jeszcze nie było, więc objazd tarana nie wynika z
listy kontaktów [P]; mechanizm [N] (prawdopodobnie gałąź dużych jednostek 0x548A3C [H]).

**Korekta (eksperyment Fable 2):** hipoteza o 0x548A3C jest obalona. Objazd jest zapisany w trasie A\* już w chwili
przyjęcia rozkazu (kara kosztu kroku 0x41CFFF / AoC 0x419595 za stojącą jednostkę na polu) [P], a 0x548A3C nie jest
wołana dla pary taran–gwardia [W]. Patrz `EKSPERYMENT_FABLE_DUZE_JEDNOSTKI.md` § 3–4.

Tor 856 → 858 (gwardia w środku pola): w AoC para powstała przy zmianie pola w osi y przy odległości 0,752, tuż
przed progiem 0,75, więc push i końcowa pozycja gwardii (165,480; 109,313 / 109,303) wyszły prawie takie same.

Tor F i gwardia czołowa: tor nie przeciął linii połówkowej w takcie zmiany pola; przypadek dla rozmiaru < 1
niezmierzony.

## 7. Pierwsze rozbieżności

Zebrane w § 6: lista kontaktów od pierwszej zmiany pola tarana w zasięgu obiektu (t = 55670 w parze `_5`), pozycja
gwardii od t = 56692.

## 8. Klasyfikacja hipotez

- **H3 (błąd wcześniejszej analizy) – odrzucona.** Funkcje pomocnicze nie zapisują macierzy przed budową listy;
  kolejność z etapu 26 jest poprawna i potwierdzona pomiarem w obu grach.
- **H1 (różny kod, to samo zachowanie) – potwierdzona dla jednostek o rozmiarze < 1** przy zwykłym przejściu granicy
  pola: okna są identyczne, pierwszy kontakt w tej samej próbce (tor E). Nie dotyczy rzadkiego przypadku linii
  połówkowej [W, niezmierzony].
- **H2 (inny moment kontaktu, inny push) – potwierdzona dla rozmiaru całkowitego** (taran 1,0): kontakt o pole
  później w AoC, a gdy obiekt stoi blisko toru – późniejsze i gwałtowniejsze odepchnięcie i inna pozycja końcowa.

Liczba hipotez: 3 postawione, 2 potwierdzone w swoich zakresach, 1 odrzucona.

## 9. Ocena OpenEE Core (bez zmian w kodzie)

1. **Kolejność EE:** tak – `po_ruchu` przy `OdbudowaKontaktow::po_zapisie` woła `odbuduj_kontakty(u, u.x, u.y)`; okno
   i R jak w 0x5E8F0E.
2. **Kolejność AoC:** tak – `przed_zapisem` woła `odbuduj_kontakty(u, x0, y0)` z pozycją sprzed ruchu, z polem już
   nowym, tak jak 0x5FE611. Dotąd [W], teraz zgodne z pomiarem; symulacja w skrypcie stosuje tę samą regułę co Core.
3. **Parametr wariantu:** potrzebny i już istnieje (`WariantTitan::kontakty`). Nowego nie trzeba.
4. **Regresja:** brak ryzyka dla nagrań EE (wariant bez zmian). Cztery nagrania AoC z etapów 30–32 mają tylko
   jednostki o rozmiarze < 1, dla których okna są równe.
5. **Braki ujawnione przy okazji** (do etapu wdrożeniowego, nie zmieniano):
   - filtr AoC z maską 0xC i grupą 0x22 nie jest odwzorowany (Core nie odwzorowuje też maski 4 z EE);
   - Core dopisuje parę na koniec listy, gra na początek; kolejność uczestników przy kilku kontaktach nie była tu
     mierzona [N];
   - Core nie ma parametrów tarana ani gałęzi dużych jednostek (0x548A3C [H]), więc nagrań `_5` nie da się jeszcze
     odtworzyć w Core.

## 10. Czy potrzebny jest wariant Titan

Tak, ten, który już jest. Bez niego Core w trybie AoC dawałby kontakt o pole za wcześnie dla każdej jednostki o
rozmiarze 1,0 / 2,0 / 3,0. Dla piechoty wynik jest ten sam w obu trybach.

## 11. Nierozpoznane kwestie i dalsze eksperymenty

- Rozmiar < 1 i linia połówkowa: tor ukośny, który w jednym takcie mija granicę pola w x i linię y = m + 0,5, ze
  stojącą jednostką na polu (k, m ± 1). Przewidywanie [W]: kontakt tylko w jednej z gier. Wymaga celnego rozkazu
  (wysokość terenu z odczytu, nie z rekordu).
- Rozmiar 2,0 i 3,0 (okręty) oraz 1,5 (przewidywanie: brak różnicy wzdłuż osi ruchu) – niezmierzone.
- Kilka kontaktów naraz: kolejność listy i podział impulsów (tor D nie dał dwóch kontaktów jednocześnie).
- Objazd tarana wokół stojącej jednostki bez pary kontaktu – mechanizm [N]. [Rozstrzygnięte w Fable 2: kara A\* [P].]
- Znaczenie bitu 8 flag typu i grupy 0x22 w filtrze AoC [N]. [Rozstrzygnięte statycznie w Fable 2: typy kosmiczne AoC [W].]
- Odtworzenie pary `_5` w Core po dodaniu parametrów tarana i gałęzi dużych jednostek.

## 12. Podsumowanie dla Opusa

1. Różnica kolejności jest prawdziwa: EE 0x5F043B zapisuje macierz, potem buduje listę (0x5E8F0E); AoC 0x5FE611
   buduje listę (0x5F6817) przed zapisem macierzy przez wołającego. Obie funkcje czytają środek okna z macierzy.
2. Pomiar w obu grach: reguła właściwa dla gry daje 0 niezgodności list w każdym nagraniu, reguła drugiej gry tysiące.
3. Piechota (rozmiar < 1): brak różnicy przy przejściu granicy pola. Rozmiar całkowity (taran, czołgi, część
   okrętów): różnica przy każdej zmianie pola – AoC widzi pole z tyłu zamiast pola z przodu.
4. Skutek fizyczny istnieje: taran czołowo na gwardię – w AoC zbliżenie na 0,52 bez odpychania i inna pozycja końcowa
   gwardii.
5. `WariantTitan::kontakty` w Core jest poprawny dla obu gier; status w `EE_AOC_POROWNANIE.md` zmieniony z [W] na
   potwierdzony pomiarem.
6. Nowe [W]: filtr par w AoC ma maskę 0xC i wyjątek grupy 0x22 (EE: maska 4).
7. Pułapka narzędziowa: z = 1,837 w odczycie stojącej jednostki to wartość z rekordu, nie teren; do `obs_rozkaz`
   trzeba podać wysokość terenu.

## 13. Koszt eksperymentu

- Tokeny wejściowe, wyjściowe i cache: środowisko nie udostępnia statystyk – nie podaję.
- Wywołania REA/Ghidra: 0 (statyka na listingach liniowego deasemblera z etapu 52 – `~/e52/ee.asm`, `aoc.asm`).
- Riverlands_MCP: 9 zadań z gry (681–689), 9 wywołań `serwer_przeladuj` (zawsze między zadaniami); 8 nagrań co takt
  (5 EE, 3 AoC; 7 rozróżnia reguły).
- Uruchomienia gry: 5 × EE, 3 × AoC. Eksperymenty logiczne: A–E i czołowy (6); F bez wyniku.
- Czas: pomiary 681–689 trwały 26 min (znaczniki plików wyników 17:54–18:20 UTC); całość z analizą statyczną i
  raportem ok. 40 min zegarowo.
