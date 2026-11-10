# Raport etapu 45 – kolejność symulacji Titan, skrypt obywatela i stan generatora

Najważniejsze wyniki etapu:
- **Kolejka fizyki 0x918DDC odtworzona z kodu i potwierdzona nowym pomiarem.** Dodanie trafia na koniec kolejki,
  usunięcie jest zatwierdzane na początku następnego taktu, kolejność pozostałych obiektów nigdy się nie zmienia.
  Nowe nagrania 590 i 578 (zad. 641, 8 jednostek, lista fizyki w każdej próbce) pokazują tylko trzy usunięcia
  i ani jednej zmiany kolejności, mimo że siedem jednostek zmieniało pola.
- **Nowe pomiary 590 G1 i 578 G3 są zgodne z Core.** 590 G1: 1108 porównań, stan, HP, +0x2A0, cel i pozycja bez różnic.
  578 G3: pełna zgodność do taktu 414, gdzie gra wydaje gwardii 0x1000858 cel spoza Core.
  Dawne rozbieżności (578 G3 takt 169, 590 G1 takt 97) w nowych pomiarach nie występują.
- **Obywatel: skrypt `citizen.tai` i FleeDanger 0x620687 w Core.** Nagranie 638 (obywatel trafiony w Idle) jest
  zgodne co próbkę dla wszystkich trzech jednostek (4264/4264), gdy generator Core dostaje stan generatora gry przed
  każdym taktem. Wcześniej pierwsza różnica wypadała na t = 62215 (5000 → 8000).
- **Kolejność losowań w takcie potwierdzona pomiarem:** oba losowania globalne (0x546CE9 i 0x547C09 w 0x547B6B)
  poprzedzają pętlę jednostek 0x547AAD. Losowania ucieczki to 3. i 4. losowanie taktu 62215 (n = 3, b = 0 → kierunek 7).
- **Tryb ruchu 2 (0x54DDFF) przy śmierci:** v = 0, ω = 0, bez kroku końcowego. Obywatel ginący w ruchu (638, t = 66988)
  stoi w miejscu w takcie śmierci, tak jak w grze.
- Odtwarzacz animacji Godot liczy „wartość” sekwencji jako ms na klatkę.
- Healer.tai i graf dynamiczny: analiza statyczna [W]. Eksperymenty w grze (zad. 642) nie wykonały się, bo
  automatyzacja gry przestała reagować na kliknięcia (odprawa scenariusza nie znika) – opis w p. 15.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.

## 1. HEAD początkowy i końcowy

- Początek: `0b8cba4` (etap 44, zsynchronizowany z GitHub).
- Koniec: jeden lokalny commit etapu 45. Bez push, pull, fetch, reset, rebase i clean.
- Poza commitem zostają pliki użytkownika: `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11`.

## 2. Analiza kolejki fizyki [W, P]

Obiekt stanu gry 0x918300. Kolejka fizyki to `std::deque` w +0xADC (0x918DDC): +4 mapa bloków, +8 rozmiar mapy,
+0xC początek, +0x10 liczba, bloki po 1024 wskaźniki. Obok: +0xAD0 mapa identyfikatorów obecnych w kolejce,
+0xAF0 kolejka dodań, +0xB04 kolejka usunięć (konstruktor 0x52CCC9).

| Funkcja | EE | Działanie |
|---|---|---|
| Dodaj | 0x530896 | pomija id −1 i typ +0x4B8 = 0xDF; obiekt na koniec kolejki dodań (bez duplikatów) |
| Usuń | 0x530913 | pomija typ 0xDF; obiekt na koniec kolejki usunięć (bez duplikatów) |
| Zatwierdź | 0x53066A ← 0x546D35 (takt), 0x5B40B4 | dodania nieobecne w mapie → `push_back` + mapa; usunięcia obecne → wyszukanie w kolejce, `erase`, usunięcie z mapy |
| Pętla | 0x547AAD ← 0x546D6B | od końca kolejki; dla każdej jednostki 0x547E0E: krok maszyny stanów, potem fizyka |

Wywołujący Dodaj: 0x554A25 (w 0x55495E), 0x5ED494 (Kill 0x5ED43F), 0x5EED8D (0x5EED30), 0x616F5E, 0x617225
(zmiana pola 0x616F9D – tylko dopisanie nieobecnego). Usuń: 0x5EED94, 0x5EF968, 0x5F120A, 0x6163E3.

Kolejność w takcie 0x546C63: losowanie 0x546CE9 → zatwierdzenie kolejek 0x546D35 → 0x547B6B (losowanie 0x547C09)
→ pętla jednostek 0x547AAD → pozostałe systemy.

**Kryterium kolejności: kolejność wstawienia.** Nie ma sortowania po (x, y). Po wczytaniu scenariusza kolejność
jest zgodna z (x, y) rosnąco, bo w takiej kolejności obiekty są wstawiane przy wczytaniu [P: pozycje startowe 590,
578, 638; H: dlaczego wczytanie idzie w tej kolejności].

Odpowiedzi A2 (nagrania 641 – 590 i 578, 8 jednostek, lista w każdej próbce):

| Pytanie | Odpowiedź |
|---|---|
| 1. Ta sama kolejność co w Core? | tak – Core: `uporzadkuj_wg_pozycji` po wczytaniu, potem vector w kolejności dodania [P] |
| 2. Zmienia się przy zmianie pola? | nie – 7 jednostek zmieniało pola, kolejność bez zmian [P] |
| 3. Ustalana przy utworzeniu? | przy wstawieniu do kolejki (zatwierdzenie dodania) [W]; po wczytaniu (x, y) [P] |
| 4. Zależy od listy obiektów pola? | nie przy zmianie pola (0x617225 tylko dopisuje nieobecny obiekt) [W/P]; kolejność wczytania [H] |
| 5. Ruch aktualizuje pozycję w liście? | nie [P] |
| 6. Nowe obiekty zmieniają kolejność starszych? | nie – nowe idą na koniec, czyli są przetwarzane jako pierwsze [W]; brak nagrania tworzenia jednostek w tym etapie [N] |
| 7. Kolejność maszyny stanów = kolejność fizyki? | tak – jedna pętla, krok maszyny przed fizyką każdej jednostki (0x547E0E) [W]; zgodne z kolejnością losowań w 638 [P] |

Usunięcia w pomiarze: 578 – 0x5000ad0 stan 6003 w t = 105945, poza kolejką od t = 105979; 0x5000ad3 138164 → 138198;
590 – trzy usunięcia z tym samym opóźnieniem jednego taktu [P]. Którzy z wywołujących Usuń działają przy 6003 – [N].

**Core (A4).** Jedna deterministyczna kolejka: `jednostki_` w kolejności dodania, bez sortowania w taktach. Nowe
pola `Jednostka::w_fizyce` i `usun_z_fizyki`: wejście w Dead (6003) zgłasza usunięcie, a początek następnego taktu je
zatwierdza. Jednostka poza kolejką nie wykonuje maszyny stanów ani fizyki. GDExtension: `kolejka_fizyki()`.
Bez wyjątków dla 590 i 578.

## 3. Nowe pomiary 590 G1 i 578 G3 [P]

Zadanie 641 powtórzyło kroki oryginalnych 590 i 578 na e31_a nowym rejestratorem (lista fizyki, pozycje, prędkość,
obrót, cele, punkty przechwycenia, stany `.tai`, kolejki rozkazów, kontakty, push, chwile dodania i usunięcia).
Nagrania: `e45_590_ee_a` (7268 próbek) i `e45_578_ee_a` (4708 próbek), lokalnie w `Testy_MCP/ee_obserwacja`.

Gra nie powtarza poprzedniego przebiegu bit w bit: rozkazy MCP wchodzą w innych taktach (578: pierwsza różnica
względem e31 w t = 38613), a stan generatora jest inny. Okna porównania wybrano po tym samym zdarzeniu co w e31:
- 578 G3: wejście 0x5000ad3 w 2013 w t = 78398 (próbki 2067–2497, 430);
- 590 G1: wejście 0x5000ad0 w 2013 (próbki 1086–1642, 556).

Pliki `walka_578_g3_e45.json` i `walka_590_g1_e45.json` (`pomiar_core.py walka`; tablice obrażeń skopiowane z e31 –
dane statyczne gry) są w CTest `walka_swiat` obok dotychczasowych.

Test porównania wykrywał dotąd próbkę spóźnioną o takt (wyścig odczytu) tylko po pozycji. Dla jednostki stojącej
ten sam wyścig daje próbkę równą poprzedniej (stan, HP, +0x2A0), a następna próbka przeskakuje dwa takty
(578 G3 takt 111: r 130, 130, 62; 590 G1 takt 328: r 402, 402, 334). Test pomija teraz także taki przypadek, gdy
wartości Core z poprzedniego taktu równają się próbce gry. Tolerancji nie zmieniono.

| Pomiar | Porównań | Różne (stan / HP / +0x2A0 / cel / poz. > 0,001) | Pierwszy rozbieżny takt |
|---|---|---|---|
| 590 G1 e45 | 1108 | 0 / 0 / 0 / 0 / 0 | 115 – ω w próbce spóźnionej (kurs i pozycja identyczne) |
| 578 G3 e45 | 1286 | 16 / 0 / 0 / 0 / 15 | 414 – 0x1000858 5000 → 2015 (cel spoza Core) |
| 590 G1 e31 (dawny) | 1107 | 0 / 0 / 0 / 0 / 916 | 97 (ω, kurs do 0,005 rad) |
| 578 G3 e31 (dawny) | 1286 | 4 / 1 / 117 / 0 / 130 | 169 (ω) |
| 578 G1 e31 | 986 | 0 | brak w oknie |

## 4. Pierwsze rzeczywiste rozbieżne takty

- **578 G3 e45, takt 414 (t = 94354):** gwardia 0x1000858 (gracz 1, Idle, pełne HP, bez wroga w polu widzenia)
  przechodzi 5000 → 2015 (LookForEnemies) i rusza w stronę walczącej 0x1000857, której HP spadło 150 → 137 w takcie
  411. Przejście 5000 → 2015 w jednym takcie oznacza cel ruchu wstawiony z zewnątrz przed taktem. Cel nie pochodzi ani
  z rozkazu MCP, ani z `.tai` jednostki. Kandydat: reakcja sojuszników na trafienie (TakeDamage 0x6172BC) [H].
  Funkcja odpowiedzialna – [N]; rozstrzygnie odczyt kolejki celów 0x1000858 w takcie 413–414.
- **590 G1 e45:** brak rzeczywistej rozbieżności. Osiem różnic ω to wyścig odczytu: ω = 0,4165 w dwóch kolejnych
  próbkach przy niezmienionym kursie.
- **638 (obywatel):** brak rozbieżności przy stanie generatora z nagrania.
- **Dawne e31 590 G1 / 578 G3 (takty 97 i 169):** w nowych pomiarach tych samych układów rozbieżności nie ma. Dawne
  nagrania nie mają listy fizyki, więc przyczyny różnicy nie da się już ustalić [N].

## 5. Mechanizm obywatela [W, P]

`citizen.tai` dołącza `Gather.tai` (Idle `{TakingLightDamage true(FleeDanger)}`). Własne Idle to
`{BuildingInBuildQueue true(MoveToRepairSite); TakingLightDamage true(FleeDanger)}`, dalej Generic Attack / Movement /
Death. dbobjects „TAI Script”: 32 → Citizen, 173 → Military Healer Prophet, 216 → Prophet, 422 → Land Patrolling.

- TakingLightDamage (0x1388, ocena 0x61BA3A): +0x29C > HP. +0x29C = HP ustawiane na początku aktualizacji typu
  (0x600664, 0x6054D6, 0x6256FB) – w Core po kroku maszyny (`hp_29c`).
- Wejście FleeDanger (0x1F53 = 8019) w 0x61B2D5 woła vt+0x40 obiektu EEUC (EEUCLand 0x832194 i EEUCLandCitizen
  0x833308 → 0x620687):
  1. atakujący 0x62FE01 (Core: ostatni trafiający [H]); brak → Idle;
  2. odległość: gracz ≠ 0 → fistp(f32(LOS · 1,5)) (obywatel 3 → 4); gracz 0 → losowanie 1..2 (0x5531C2);
  3. oktant 0x62F451 z pól (+0x1C/+0x20), θ = UMArcTan2(ux − ax, ay − uy); te same pola → (0, 0) → +π/2 → oktant 1;
  4. 0x632FFC: n = losuj(0, 3) + 3, b = losuj(0, 1) ≠ 0, n obrotów tablicą 0x637AB9;
  5. do 8 prób: pole + krok 0x632E7C × odległość, test 0x62C7C8, inaczej kierunek + 1;
  6. cel EEUGLocation (pole + część ułamkowa pozycji), pochodzenie 1, stan 8000.
- 0x5531C2: f z generatora RTSPhysics ([0x919774]+0x18) = `rng_` Core; v = f32(f · (hi + 1 − lo) + lo), fistp, hi + 1 → hi.

Core: `SkryptStanow::wbudowany_obywatel()`, skrypty przypisane jednostkom (`ustaw_skrypt_jednostki`, nazwy
z dbobjects), wspólne zdarzenia i maszyna – bez drugiego AI. Parametry ruchu obywatela z dbobjects: a 1,2, vmax 0,5
(wcześniej skopiowane z gwardii); prorok 0,45.

Odtworzenie 638 (`odtworz_scenariusz.gd --rng-nagranie=…`): 4264/4264 próbek zgodnych dla gwardii, obserwatora
i obywatela – ucieczka do (168,5; 104,5), trasa, śmierć w ruchu (p. 12) i rozkład. Bez stanu generatora z nagrania
pierwsza różnica wypada na t = 62556 (kurs ucieczki). Gra wykonuje dodatkowe losowania w 332 z 2676 porównanych
taktów (3–7 zamiast 2) w systemach spoza Core (AI graczy, otoczenie) [N]. Stan generatora Core nie może więc biec
sam od ziarna – przy porównaniu podaje się stan z nagrania.

## 6. Eksperymenty ucieczki i reakcji

- Wykonane [P]: obywatel stojący, trafiony (638) – zgodny w całości.
- Przygotowane, niewykonane: zad. 642 (`Testy_MCP/ee_zadania/642_e45_obywatel_bohater.json`), mapy z
  `e42_warianty.json`:
  - `e45_cit_poscig` – pościg przerwany rozkazem odejścia gwardii;
  - `e45_cit_ruch` – obywatel gracza 1 trafiony w trakcie ruchu (TakingLightDamage tylko w Idle – przewidywanie: brak
    ucieczki w ruchu, ucieczka po dojściu) [H];
  - `e45_bohater` – patrz p. 8.

  Wszystkie trzy wczytania zatrzymały się na ekranie odprawy (p. 15). Zbieranie surowców i budowa są poza zakresem
  etapu (ekonomia).
- Test syntetyczny GDExtension: obywatel na polu atakującego, stan generatora 132607946 → cel (+4, −4) jak w 638.

## 7. Analiza Healer.tai [W]

Skrypt 173: `Military Healer Prophet.tai` = Healer.tai + Military Prophet.tai (+ Generic Attack/Movement/Death).
Idle `{HealSearchTimeElapsed true(LookForHealee)}`; LookForHealee
`{GoalIsHeal true(TurnToFaceHealee); GoalIsLocation true(Advance) false(ShouldIReturnToInitialContactLocation)}`;
TurnToFaceHealee / HealUnit z HealeeInHealingRange, FacingHealee, TargetNeedsHealing.

- **HealSearchTimeElapsed (18000)** – gałąź 0x61BF25 w 0x61B677 (EEUCLand vt+0x9C): prawda, gdy EEUC+0x4A4 ≠ 0
  i licznik jednostki +0x22C (f32) = 0.
- **Licznik +0x22C** – 0x600822 (z aktualizacji typu 0x6006F7/0x605469): gdy > 0: c −= f32(PH+0x98 · 0,001), poniżej
  zera → 0. Zegar w sekundach.
- **Wejście LookForHealee (16000)** – 0x61B57A: wyszukanie 0x620A68 w promieniu LOS (ulepszenie +0xA4). Znaleziony
  cel → cel EEUGHeal (0x612A8A, 0x40 B) przez 0x5F05BD. Zawsze potem +0x22C = EEUC+0x4A4 (to samo w 0x62113B).
- **Wybór celu 0x620A68**: zapytanie przestrzenne 0x635F39 (pozycja, promień), lista przeglądana OD KOŃCA.
  Pierwszy kandydat spełniający 0x630E07 i osiągalność 0x5ECAD0 wygrywa. Kolejność zapytania – [N].
- **0x630E07 (czy leczyć)**:
  - ulepszenie leczącego +0x10C > 0, cel żyje (0x5EDC82);
  - HP/HPmax celu ≤ próg typu leczącego +0x49C;
  - cel ≠ leczący, ten sam gracz albo gracz bez wrogości (tablica +0x9E4);
  - klasa celu (+0x4B8) w masce leczenia (0x4A7618).
- Zdarzenia celu leczenia 18001–18006 – 0x612E0E (EEUGHeal), reszta → 0x6153A3.
- Cykl 619 (5000 → 16000 → 2025 → 5000 co ok. 1023 ms = 30 taktów) jest zgodny z +0x4A4 ≈ 1,0 s [H: wartość
  typu nieodczytana].
- Ilość i częstotliwość leczenia (efekt 138 – „leczenie innych 50 w promieniu 4,0”) – [N] do pomiaru.
- 5001 (ReacquireGoal) przez 2 takty po trafieniu bohatera – pochodzi z TakeDamage (0x6172BC → vt+0x74/0x8C/0x84 obiektu
  EEUC), nie z Healer.tai [W częściowo, N mechanizm].

Core: Healer.tai **nie został wdrożony**. Okres +0x4A4 jest hipotezą, wybór celu zależy od nieznanej kolejności
zapytania 0x635F39, a pierwsza różnica 619 (t = 79045, 5001) nie jest związana z leczeniem. Zgodnie z poleceniem
wdrażamy tylko reguły potwierdzone.

## 8. Eksperyment leczenia

Przygotowany (zad. 642, wariant `e45_bohater`): bohater 173 (wzór 0x100055c z e35_a) przy gwardii gracza 1, która
walczy z gwardią komputera – najpierw leczenie z atakującym, po zwycięstwie bez atakującego. Niewykonany (p. 15).
Pierwsza różnica stanu bohatera 619 pozostaje w t = 79045 (5001).

## 9. Animacje Godot

`SekwencjeAnimacji`: „wartość” = ms na klatkę (`CZAS_JEDNOSTKA` = 0,001 s na klatkę), czyli
`czas_klatki` = wartość / 1000, `czas_cyklu` = klatki · czas klatki, `klatki_na_s` = 1000 / wartość.
`OdtwarzaczAnimacji` liczy fazę z czasu (delta), więc tempo nie zależy od FPS. Pętle (bajt 0 pola „pętla”)
i sekwencje jednorazowe (śmierć – zatrzymanie na ostatniej klatce) bez zmian. Przejście = nowa sekwencja od fazy 0.
Gra przełącza klatki skokowo (0x62462B: +0x2FC += ms taktu, przy ≥ czasie klatki następna klatka, reszta zostaje),
a odtwarzacz interpoluje między klatkami (prezentacja). Test E4 zaktualizowany; FORMATY_ETAP4 § 2.3 z adnotacją.

## 10. Graf dynamiczny [W]

- 0x4288A7 (EEAIContinentManager; wywołania 0x555DFF, 0x55C38C, 0x55C539 – postawienie / usunięcie obiektu):
  - działa, gdy menedżer zbudowany (+0xC > 0), nie trwa przebudowa (+0x130 = 0), mapa istnieje,
    obiekt nie vt+0x58 i (typ +0x600 ≠ 0 albo klasa +0x4B4 = 0x19);
  - pola obiektu 0x635629 → posortowana lista bez powtórzeń (0x422DB6) do przebudowy;
  - na końcu zleca przebudowę 0x4A36F3(1, natychmiast).
- 0x4A36F3 (EEPathManager): jeśli przebudowa już zlecona (+0xD8 = 1) – nic (termin się nie przesuwa). Inaczej
  +0xD4 = teraz + 1 ms (natychmiast) albo teraz + fistp(f32(*0x9183C0 · 10000)); +0xD8 = 1. Wartość 0x9183C0 w pliku
  wynosi 0 (ustawiana w czasie gry) [N].
- 0x4A3641 → 0x4278C3: przebudowa tylko pól z listy, gdy kolejka grafu pusta i minął termin +0xD4.
  Niedokończona → ponowna próba za 100 ms (`architektura_nawigacji.md` § 7).

Wniosek dla Core: przebudowa przyrostowa po zmianie obiektu, nie co takt. Wdrożenie wymaga pomiaru, którego nie
udało się wykonać. Rozstrzygający pomiar (opis w `architektura_nawigacji.md`, sekcja „Etap 45”):
- dom (wzór BLD) zamyka przejście między dwiema częściami czystej mapy;
- trzy gwardie niszczą dom, rejestrator odczytuje +0xD4/+0xD8 menedżera i podsektory pól domu co takt;
- jednostka z rozkazem przez przejście dostaje trasę przed i po zniszczeniu.

## 11. Algorytm obszarów 0x427D42

Bez zmian w kodzie – działający model (8-spójne klify, zgodny na trzech mapach) zostaje, brak nowego dowodu [N].

## 12. Zmiany w Core, GDExtension i MCP

Core (0.19.0):
- skrypty `.tai` per jednostka (`Jednostka::skrypt`, `skrypty_`, `ustaw_skrypt_jednostki`), skrypt obywatela,
  stany FleeDanger 8019 i MoveToRepairSite 8018;
- zdarzenia TakingLightDamage (+0x29C) i BuildingInBuildQueue (fałsz – budowa poza Core);
- FleeDanger 0x620687 z losowaniami 0x5531C2 (`losuj_zakres`), `ostatni_atakujacy`;
- tryb ruchu 2 (`TrybRuchu::zatrzymanie`, 0x54DDFF) przy wejściu w Dying, bez kroku końcowego;
- kolejka fizyki: `w_fizyce`, `usun_z_fizyki`, zatwierdzanie na początku taktu, Dead → usunięcie;
- komentarze kolejności losowań w takcie (0x546CE9, 0x547C09 przed pętlą).

GDExtension:
- `ustaw_skrypt_jednostki`, `ustaw_stan_rng`, `kolejka_fizyki`;
- testy: kolejka fizyki + tryb śmierci, ucieczka obywatela (54 testy).

Godot:
- `odtworz_scenariusz.gd`: `--skrypty`, `--rng`, `--rng-nagranie`;
- `SekwencjeAnimacji` (ms na klatkę), test E4.

Dane i testy:
- `parametry_jednostek_ee.json` (obywatel, prorok);
- warianty `e45_*` w `e42_warianty.json`;
- CTest `walka_swiat`: pomiary e45 i wykrywanie próbek spóźnionych dla jednostek stojących.

Riverlands_MCP (lokalnie, z etapu 44): lista fizyki w rejestratorze. Zadania 641 (wykonane) i 642 (nieudane
wczytanie).

## 13. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | **54/54** (+2: kolejka fizyki i tryb śmierci, ucieczka obywatela) |
| Godot | 325/325 |
| Riverlands_MCP | 16/16 modułów (98 testów) |
| Narzędzia Titan | 20/20 |
| EE 578 G1 | 986/986 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| skrót mapy | `c8297c16f0d48b1a` |
| skrót scenariuszy | `22b0f0cf4a1ec660` |

Porównania z grą (osobno od testów syntetycznych):

| Przebieg | Wynik |
|---|---|
| 619/620 (graf autonomiczny) | identyczne z etapem 44 (bohater: pierwsza różnica 79045, 5001) |
| 631 / 633 / 634 / 638k | zgodne do końca nagrań (2808 / 3697 / 6413 / 2465) |
| 638c obywatel | 4264/4264 z generatorem z nagrania; bez niego od 62556 (kurs) |
| 590 G1 e45 / 578 G3 e45 | p. 3 |
| 590 G1 / 578 G3 e31 | bez zmian względem etapu 44 |

Wartości wzorcowe zmienione z uzasadnieniem: test E4 animacji (czas klatki w ms – kod 0x62462B i pomiary śmierci).

## 14. Potyczka

`potyczka.tscn --potyczka-demo=70` działa (Core 0.19.0, mapa `c8297c16f0d48b1a`, 10 jednostek, walka do śmierci
i rozkładu). Dla obywatela potyczka nie przypisuje skryptu `.tai` – do dodania razem z typami jednostek potyczki.

## 15. Problemy nierozwiązane

1. **Automatyzacja gry przestała działać w trakcie etapu.** Po zadaniu 641 każde wczytanie scenariusza (także
   e31_a, który wcześniej działał) zatrzymuje się na ekranie odprawy. Kliknięcia nie dochodzą do gry (zrzut ekranu ma
   wiek 15 s, kursor się nie rusza). Zadanie 642 jest gotowe do ponownego uruchomienia: skopiować jako
   `643_….json` po sprawdzeniu pulpitu.
2. 578 G3 e45 takt 414 – źródło celu gwardii 0x1000858 [N] (p. 4).
3. Losowania gry spoza Core (332/2676 taktów 638) – porównania z grą wymagają stanu generatora z nagrania [N].
4. Atakujący dla FleeDanger (0x62FE01) – w Core ostatni trafiający [H].
5. Test pola 0x62C7C8 – w Core tylko przejezdność terenu (bez obiektów vt+0x48 i regionu +0x2E0) [N].
6. Healer.tai: +0x4A4, kolejność zapytania 0x635F39, leczenie efektu 138 [N]; 5001 po trafieniu bohatera [N].
7. Tryb 6 jednostek martwych (6001+) – w Core tryb 2 (oba bez ruchu; skutek ten sam) [N: kto ustawia 6].
8. Graf dynamiczny – bez pomiaru, Core bez przebudowy [N].

## 16. Propozycja etapu 46

1. Przywrócenie automatyzacji gry, wykonanie 642: pościg przerwany, trafienie w ruchu, leczenie z atakującym i bez.
2. Pomiar 578 G3 z odczytem kolejki celów 0x1000858 w taktach 410–415 i analiza TakeDamage 0x6172BC
   (vt+0x74/+0x84/+0x8C) – źródło celu sojusznika i stanu 5001 bohatera.
3. Healer.tai w Core po pomiarze: +0x4A4, próg +0x49C, maska, ilość leczenia; zgodność cyklu 16000 w 619.
4. Rozstrzygający pomiar grafu dynamicznego (p. 10) i przyrostowa przebudowa w Core.
5. Skrypty `.tai` w potyczce dla wszystkich typów (Citizen, Land Patrolling, Prophet).
