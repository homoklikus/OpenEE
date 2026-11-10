# Raport – etap 39: walka grupowa, zajętość miejsc podejścia i odtwarzanie zachowania Titan

Etap 39 rozpoznał w kodzie EE, jak Titan wybiera miejsce podejścia przy kilku atakujących, i wdrożył w Core test
zajętości z 0x63234D. Reguła poprawia serie z dwoma atakującymi na jeden cel (578 G3: różnice stanu 75 → 5, HP
59 → 1, celu 8 → 0) i daje w 619 ten sam punkt ataku drugiej gwardii co gra. Pośrednie EEUGLocation okazało się
wynikiem etapu grafu podsektorów (0x4A26E3), którego Core jeszcze nie ma – to pierwszy brakujący warunek Titan
dla drugiej gwardii. Poprawiono też potwierdzanie rozkazów w Riverlands_MCP.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.

## 1. Commit początkowy i końcowy

- Początek: `09c633b` (lokalny etap 38). GitHub bez zmian (`c776a61`).
- Koniec: jeden lokalny commit etapu 39 (`git log -1`). Bez push, pull, fetch, reset i rebase.
- Poza commitem zostały pliki użytkownika `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11`.
- Zmiany w Riverlands_MCP (`ee_walka.py`) są lokalne i niezatwierdzone w jego repozytorium.

## 2. Zajętość miejsc podejścia

Łańcuch wywołań [W]: PrepareToMove 0x6222A8 → EEUGAttackUnit vt+0x08 (0x60AF05) → cel stojący 0x62CF6A →
w zasięgu (0x631935) własna pozycja, inaczej 0x632CF4 → przy ulepszeniu celu +0xAC > 0 funkcja 0x63234D.

Odpowiedzi na pytania A1:

1. **Osiem miejsc** [W]: R = 0,5·s_ja + 0,5·s_cel; kolejność wstawiania N, E, S, W, NE, SE, SW, NW (jak w Core).
2. **Sortowanie** [W]: według odległości od atakującego (0x63A48B); pierwszy wolny kandydat wygrywa.
3. **Promienie** [W]: miejsce zajęte, gdy (0,5·(s_obiektu + s_ja))² > d² + 0,1·s_ja; d² to kwadrat odległości
   miejsca od pozycji obiektu. Brane są tylko obiekty w promieniu R + 2,0 od celu (0x63603B).
4. **Punkt, nie pole** [W]: dla jednostek test jest geometryczny. Obiekty z typ+0x619 (zajmujące pole) blokują,
   gdy leżą w tym samym polu. Przejezdność pola miejsca sprawdza 0x62C7C8.
5. **Jednostka ruchoma blokuje** [W]: warunek nie zależy od v, liczą się HP > 0 i flagi typu +0x600/+0x606.
   Flag nie odczytano – Core przyjmuje je dla każdej jednostki bojowej [H].
6. **Nieosiągalność** [W]: brak wolnego kandydata → fałsz → wpis do mapy nieosiągalnych (0x62CD76).
   EnemyUnitReachable 0x62D696 opisuje § 3.
7. **Pośrednie EEUGLocation**: § 3.
8. **Powrót do EEUGAttackUnit** [W/P]: EEUGLocation jest wstawione przed celem ataku. Po jego zdjęciu (9000,
   koniec trasy) cel ataku znów jest na czele, więc InitialAttackState 2016.
9. **Usunięcie rozkazu ataku** [W, częściowo]: 9006 → 5001 → 5002 → `EnemyUnitReachable` fałsz → 2025 → 5000
   ze zdjęciem celu. Decyduje 0x62D696 (§ 3), w Core nadal prawda [N].

Grupa atakującego (+0x1C8) zapisuje wybrany punkt (0x5DF33D). Test punktów grupy 0x5DF185 jest wywoływany, ale
jego wynik jest ignorowany [W]. To nie jest system rezerwacji miejsc.

**Wdrożenie i pomiar** [P]:
- 619: Core wybiera dla 0x1000858 punkt (164,5; 105,025), tak jak gra. Wcześniej wybierał (163,975; 105,025),
  na którym stoi gwardia 0x1000856.
- 578 G3 (dwie gwardie na jeden cel), wcześniej → teraz: stan 75 → 5, HP 59 → 1, +0x2A0 117 → 118, cel 8 → 0,
  maks. pozycja 0,449 → 0,003.
- 589 G3: stan 84 → 65, HP 17 → 6, maks. pozycja 0,438 → 0,029.

## 3. Pośrednie EEUGLocation i osiągalność

- **0x4A26E3** [W kod, P pomiar 619/620]: prośba o trasę 0x4A1AFF uruchamia etap grafu podsektorów, gdy bajt +0x1C
  = 1. PrepareToMove ustawia go także dla celu ataku z +0x1D = 0 (0x622431).
  - Wynik grafu: cel bieżący dostaje +0x1D = 1.
  - Gdy ścieżka ma > 1 podsektor, dla podsektorów 0 … n − 3 powstaje EEUGLocation w punkcie reprezentatywnym
    (pole + 0,5, kurs 0) na czele kolejki (konstruktor 0x614C86, wstawienie 0x5F05BD).
  - Dlatego drugi PrepareToMove tego samego celu nie wstawia punktu.
  - Że punkt (163,5; 103,5) jest punktem reprezentatywnym podsektora: [H] – wymaga odczytu podsektorów z pamięci.
- **0x62D696** [W]: T = max(zasięg², 2,0). Prawda, gdy typ+0x430 = 0, gdy (typ+0x5D4 & 6) = 0 albo przy odległości
  ≤ T. Inaczej A* Bounded 0x4A189C w obwiedni pól obu jednostek powiększonej o 2·⌈max(LOS, T)⌉, z budżetem ≤ 0x23.
  Prawda, gdy pierwszy punkt wyniku leży w odległości pól ≤ T od celu. Nie wdrożone: metryka 0x409914 i wynik
  0x4A189C [N].

## 4. Nowe scenariusze i pomiary

- **e39_a** (narzędzie `scenariusz_testowy_kolizji.py zbuduj`, układ `Testy_MCP/e39/e39_a.uklad_wej.json`): cztery
  układy na kopii „Wojny trojańskiej” – S1 (2 gwardie z tej samej strony), S2 (z przeciwnych stron), S3 (3
  gwardie), C2 (gwardia AI i obywatel na polu z drzewami).
- **Zadanie 623** [P]:
  - S1 i S2: wybrane miejsca zgodne z sortowaniem – S1 (177,975; 102,025) i (179,025; 102,025), S2 (190,5; 102,025)
    i (190,5; 100,975). Zajętość w tych układach nie rozstrzygała.
  - S3 i C2 nieważne: w pobliżu stały jednostki kampanii gracza 1. Bohater S3 zginął przed rozkazami, a gwardia C2
    od startu atakowała jednostkę 0x10001d7. Obywatel C2 był też osiągalny wręcz z sąsiedniego pola.
- Dla Core w § 2 rozstrzygające są 619/620 i serie 578 G3/589 G3.

## 5. Niezawodność rozkazów MCP

- `walka_atak_rzut_gry` (Riverlands_MCP, lokalnie):
  - zapisuje zaznaczenie interfejsu (+0x9B0) i gry (+0x9AC) oraz czas gry PPM;
  - czyta pełną kolejkę celów w każdym takcie, aż minie 1000 ms czasu gry;
  - raportuje czas utworzenia celu, porzucenie w oknie i wszystkie migawki kolejki.
  - Bez stałych opóźnień i bez starego rzutu.
- Pomiar 623 [P]: 4/4 rozkazy potwierdzone. Cel powstaje 650–850 ms czasu gry po PPM. Zaznaczenie przed PPM w obu
  polach było tylko atakującym.
- Przyczyna „nieudanych” rozkazów 0x1000858 w 619/620 [H]: cele tworzone z tym opóźnieniem i porzucane po ~680 ms
  (2016 … 9006 → 5000). Trzy próby MCP odpowiadają trzem celom.
- EEUGLocation nie ukrywa EEUGAttackUnit: narzędzie i porównanie czytają całą kolejkę.

## 6. Dwóch atakujących i jeden cel

| Nagranie | Jednostka | Wynik |
|---|---|---|
| 619 | 0x1000856 | 7270/7273 taktów stanu |
| 619 | 0x1000858 | zgodna do 124117 (kolejka) / 124254 (stan); punkt ataku zgodny |
| 620 | 0x1000858 | zgodna do 109287 (kolejka) / 109423 (stan); punkt (163,975; 105,025) zgodny |

Pierwszy brakujący warunek Titan: EEUGLocation z etapu grafu podsektorów (0x4A26E3), bo Core nie ma grafu.
Drugi: 0x62D696 (porzucenie po drugim 9006).

Kryterium „przesunąć rozbieżność drugiej gwardii poza 124254/109423” **nie zostało osiągnięte**.

## 7. Mapy nieosiągalnych celów

- **C1** (dwie jednostki): bez nowego pomiaru. W Core mapa, terminy i licznik są polami jednostki (EEUnit +0xA0)
  [W: kod etapu 37]. Pomiar porównawczy dwóch gwardii z wpisem – [N].
- **C2** (przesunięcie celu): nieudane (§ 4).
- **C3** (zajętość a mapa) [W]: to dwa osobne zjawiska.
  - Wpis powstaje, gdy 0x632CF4 nie znajdzie miejsca (0x62CD76).
  - Brak blokującej jednostki zmienia tylko wynik 0x63234D przy następnym PrepareToMove.
  - Zwolnienie miejsca nie usuwa wpisu; wpis ważny jest dla tych samych pól (etap 37).
  - Pomiar – [N].

## 8. Fizyka 590 G1

Bez nowego pomiaru [N]. Potrzebny eksperyment:
- nagranie 590 G1 ponownie z zapisem wektora odpychania (push), liczby kontaktów i pozycji przed oraz po kolizji
  w taktach 95–98 dla obu jednostek;
- najlepiej minimalna scena: dwie gwardie w kontakcie, jedna stoi (2021), druga w trybie 1.

Kolejności jednostek nie zmieniano.

## 9. Healer.tai

[W: plik `.tai`; P: 619]:
- hero.tai = Land No Pursuit.tai + Idle (`AmIUnderAttack` → UnderAttack) + Healer.tai + Patrol.tai.
- Healer.tai: Idle `HealSearchTimeElapsed` → LookForHealee 16000. Bez celu leczenia i bez celu położenia →
  ShouldIReturnToInitialContactLocation 2025 → Idle.
- To tłumaczy cykl 5000 → 16000 → 2025 → 5000 w 619. Okres to 30 taktów [P].
- Licznik `HealSearchTimeElapsed` [N]: +0x2AC = 0 przez cały czas; spadki o 34 ms mają +0x290 (regeneracja) i
  +0x2CC (nie resetuje się przy 16000).
- Stan 5001 po trafieniu: wejście UnderAttack z hero.tai [H]; numer stanu nie potwierdzony.
- Leczenia sojusznika nie mierzono. Do Core nic nie dodano.

## 10. Zmiany w C++ Core i GDExtension

- `Swiat::punkt_podejscia`: test zajętości 0x63234D (§ 2).
- GDExtension 0.13.0: `walka(id)["kolejka"]` – pełna kolejka celów (rodzaj, punkt, cel, od gracza, próby).
- Test GDExtension: zajętość miejsca (34/34).
- `odtworz_e35.gd`:
  - zapis kolejek wszystkich jednostek;
  - `--mapa-pol=x0,x1,y0,y1` (podgląd przejezdności Core).
- Nowe porównanie kolejek: `Testy_MCP/e39/porownaj_kolejki.py` (lokalnie).

## 11. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | 34/34 |
| Godot | 325/325 |
| Riverlands_MCP | 16/16 |
| Narzędzia Titan | 20/20 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| 578 G1 | 986/986 |
| Mapa | `c8297c16f0d48b1a` |

Nagrania co takt (gwardia 0x1000856, pełny skład):

| | 616 | 619 | 620 | 622 |
|---|---|---|---|---|
| Stany | 6420/6423 | 7270/7273 | 6418/6419 | 6725/6728 |
| Pozycja, macierz, kurs, v | 0 rzeczywistych różnic | 0 | 0 | 0 |
| HP (wszystkie jednostki) | zgodne | zgodne | zgodne | zgodne |
| Kolejki celów (0x1000856) | – | bez różnicy | bez różnicy | bez różnicy |
| Próbki spóźnione | 5 | 14 | 4 (z odczytem 2016) | 8 |

## 12. Potyczka Godot

Test z renderem (demo 70 s, restart):
- bitwa 1 wygrana w takcie 1189, bitwa 2 w takcie 1234 (etap 38: 1301/1334);
- scena 1 na 5 przegrana w takcie 730;
- pięć jednostek atakuje jeden cel i otacza go bez blokowania się (zrzut `b1_06`).

Godot nadal tylko przedstawia stan Core.

## 13. Pierwsze rozbieżne takty

| Przypadek | Etap 38 | Etap 39 |
|---|---|---|
| EE 578 G1 | brak (986/986) | brak |
| EE 578 G3 | 169 (ω); stan 297 | 169 (ω); stan 301, pozycja 299 |
| EE 590 G1 | 97 (ω) | 97 (ω) |
| EE 589 G3 | 1 (kurs) | 1 (kurs, niepełny stan początkowy) |
| EE 580 G1 | 57 (stan) | 57 (stan) |
| AoC 505 | 803 | 803 |
| EE 500 | koniec +1 | koniec +1 |
| 619 0x1000858 | 124254 | 124254 (kolejka 124117 – EEUGLocation) |
| 620 0x1000858 | 109423 | 109423 (kolejka 109287) |

## 14. Niewyjaśnione

- Graf podsektorów: wydzielanie podsektorów, punkty reprezentatywne, A* grafu 0x4A5807 [N].
- 0x62D696 w Core (A* Bounded 0x4A189C, metryka 0x409914) [N].
- Flagi typu +0x600/+0x606/+0x619 [N].
- C1/C2/C3 bez pomiaru rozstrzygającego.
- 590 G1 i 578 G3 (ω) [N].
- Licznik HealSearchTimeElapsed i numer stanu UnderAttack [N].

## 15. Propozycja etapu 40

1. Odczyt grafu podsektorów z pamięci gry (EEAIContinentManager 0x917BC8: +0x5C podsektory, +0x3C/+0x40 punkty,
   +0x2C sąsiedzi) dla e35_a; sprawdzenie, czy (163,5; 103,5) leży na ścieżce 0x1000858.
2. Graf podsektorów w Core (budowa 0x42434F/0x41E990 albo dane z pamięci) i 0x4A26E3; potem 0x62D696.
3. Scena bez jednostek kampanii (inna mapa bazowa albo wycięcie obszaru) dla S3, C1, C2 i układu, w którym
   najbliższe miejsce drugiej gwardii jest zajęte.
4. Pomiar 590 G1 z zapisem pól kontaktu w taktach 95–98.
