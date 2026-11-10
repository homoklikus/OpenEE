# Raport etapu 37 – stan 9006 i ponowny wybór nieosiągalnego celu

Etap 37 wyjaśnia dwie rozbieżności z etapu 36: czas trwania stanu 9006 TurnToUnitFacing oraz powrót AI do celu,
którego nie da się osiągnąć. Obie przyczyny ustalono w kodzie Empire Earth i potwierdzono na istniejących nagraniach
616, 619 i 620. Po zmianach OpenEE Core odtwarza te nagrania takt po takcie dużo dalej niż wcześniej.
Oznaczenia: [P] potwierdzone, [W] wniosek, [H] hipoteza, [N] nieustalone.

Uwaga o położeniu raportu: zadanie wskazywało `docs/RAPORT_ETAP_37.md`. Zgodnie z zasadą repozytorium
(`CLAUDE.md`, testy launchera „L aktualności”) aktualny raport leży w katalogu głównym, a poprzedni (etap 36)
przeniesiono do `raporty/archiwum/`.

## 1. Stan lokalnego Git

- Gałąź `main`; na starcie HEAD `966be8e` (etap 36), przed nim `a1c28e5` (etap 36) i `c776a61` (etap 35 – ostatni
  commit na GitHubie). Drzewo czyste poza lokalnym `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11`
  (nietykane, niecommitowane).
- Praca wyłącznie lokalna: bez `push`, `pull`, `reset`, rebase. Etap kończy jeden lokalny commit.

## 2. Dane wejściowe z etapu 36

| Nagranie | Zgodność na końcu etapu 36 | Pierwsza różnica |
|---|---|---|
| 619 (atak gracza na obywatela na polu z drzewami) | 116 przejść stanu | t = 64147: 9006 – gra 1 takt, pozycja i v = 0,259 zamrożone; Core 4 takty z hamowaniem |
| 620 (atak przerwany PPM w teren) | 37 przejść | t = 59783: 9006 – gra 3 takty, Core 1 |
| 616 (PPM w teren, potem AI) | do drugiego kliknięcia | Core nie wybierał ponownie celu po 5000 |

## 3. Przyczyna rozbieżności 9006

Trzy niezależne elementy [P: kod EE + nagrania]:

1. **Tryb fizyki 5 (EE 0x54E0F1)** robi `dynamic_cast` celu bieżącego (+0x1F0) na EEUGLocation. Przy celu ataku
   (EEUGAttackUnit) albo bez celu funkcja **kończy się bez żadnej zmiany**: bez ruchu, bez hamowania, bez zmiany ω,
   bez zapisu transformacji. Stąd w 619 pozycja i v = 0,2591 stoją przez 9006, 5001, 5002, 2013, 2024, 8000, 2015.
   Dokumentacja mówiła ogólnie „tryb 5: jeśli v ≠ 0, jak tryb 4” – to prawda tylko dla EEUGLocation.
2. **Zdarzenie 9014 UnitFacingNotRequired** obsługuje cel bieżący (vt+0x64). EEUGAttackUnit (0x60B5CB) przekazuje je
   do bazy 0x62871E, która zwraca prawdę zawsze. EEUGLocation (0x6153CA): prawda, gdy cel+0x31 = 0 albo w poziomie
   kolejki jest więcej niż 1 cel. Core wymagał v = ω = 0 dla każdego celu – stąd 4 takty w 619.
3. **Kurs końcowy celu EEUGLocation** (+0x2C) to kąt szyku z interfejsu (EEUICCommandUnits 0x641B53 → 0x64138B):
   UMArcTan2(−Δx, Δy) od środka prostokąta zaznaczonych jednostek (0x5F6377) do punktu kliknięcia, liczony w chwili
   kliknięcia. Nagrania MCP zawierają go w kolejce celów (pole `kat`): 620 – −0,36194, 616 – 2,7300477. Odtworzenie
   w etapie 36 podawało rozkaz ruchu bez kursu, więc Core kończył 9006 od razu. Z kursem z nagrania 620 obraca się
   w 3 taktach jak gra.

Przy okazji z kodu: wejście w InitialAttackState i reguła „pole startu pomijane tylko przy trasie > 1 pola”
(0x5EE4E6) – druga była potrzebna, żeby 619 przeszedł przez kolejne próby PrepareToMove (gra tworzy trasę 1 punktu
(161,5; 105,5), gdy jednostka stoi w polu najbliższym celowi).

## 4. Nowe pomiary oryginału

Nowych uruchomień gry nie było potrzeba. Hipotezy rozstrzygnęły istniejące nagrania odczytane dokładniej (pola
`tryb`, `v`, `kat`, `obrot`, licznik prób celu, czasy utworzenia celów) oraz analiza kodu. Dziennik:
`docs/titan/dziennik_eksperymentow.md` („Etap 37”). Nagrania zostały lokalnie w `Testy_MCP/ee_obserwacja`, wyniki
odtworzeń w `Testy_MCP/e37`.

Rejestrator czasem zapisuje próbkę z poprzedniego taktu (stan albo pozycja jak w próbce wcześniejszej, następna
znów poprawna). Porównanie liczy je osobno: 616 – 3 takie próbki, 619 – 1, 620 – 1 [W: odczyt pamięci w trakcie taktu].

## 5. Zmiany w Core

| Zmiana | Kod EE | Pewność |
|---|---|---|
| 9014 dla celu innego niż miejsce = prawda; dla miejsca dodatkowo „> 1 cel w kolejce” | 0x62871E, 0x6153CA | [P]; reszta warunku dla miejsca bez kursu (v = ω = 0) zostaje z modelu v4 [W] |
| tryb 5 bez celu EEUGLocation – nic | 0x54E0F1 | [P] |
| pole startu pomijane tylko przy trasie > 1 pola | 0x5EE4E6 | [P] |
| EnemyUnitReachable: licznik prób ≤ 25 (było < 25) | 0x60B235 | [P] |
| mapa celów nieosiągalnych: 30 s, pola atakującego i celu; wpis przy braku miejsca podejścia i przy fałszu EnemyUnitReachable; filtr kandydatów w wyborze celu | 0x5E8651, 0x5EC9BB, 0x62CD76, 0x60B241, 0x639B61 | [P]; „brak miejsca” jako jedyny powód fałszu 0x632CF4 [W] |
| `Swiat::kat_rozkazu` – kąt szyku PPM; GDExtension `kat_rozkazu` | 0x64138B, 0x5F6377 | [P]; środek prostokąta [W] |

Wersja: OpenEE Core 0.11.0. Pliki: `cpp/core/src/symulacja.cpp`, `fizyka.cpp`, `include/openee/jednostka.hpp`,
`symulacja.hpp`, `cpp/gdextension/src/openee_symulacja.*`; struktura: `dane/titan/struktury_titan.json`
(EEUnit +0xA0). Wyjątków dla konkretnych jednostek, tolerancji, przesunięć RNG ani opóźnień nie dodano.

## 6. Wyniki 619 i 620 przed i po

Porównanie stanu co takt (`narzedzia/eksperymenty/porownaj_takty.py`) i pozycji/kursu co takt
(`Testy_MCP/e37/porownaj_probki.py`, lokalnie):

| Nagranie | Przed | Po | Pozycja i kurs co takt (po) |
|---|---|---|---|
| 619 | 116 przejść, pierwsza różnica t = 64147 | 345 przejść, 936 taktów bez różnicy stanu do porzucenia celu (t = 71954); **pierwsza różnica t = 71988** | 935 taktów: pozycja ≤ 0,001 pola poza 1 próbką nieaktualną; kurs ≤ 3,1·10⁻⁴ rad |
| 620 | 37 przejść, t = 59783 | 39/39 przejść, 4471 taktów do końca zapisu ruchu; **pierwsza różnica t = 192032** (kolejny rozkaz MCP, nieodtwarzany) | 600 taktów: pozycja ≤ 0,001 pola poza 1 próbką nieaktualną; kurs ≤ 3,1·10⁻⁴ rad (w 9006: −0,39044 / −0,39040, −0,40462 / −0,40459) |

W 619 przesunięcie pierwszej rozbieżności: z t = 64147 na t = 71988 (+230 taktów, 7,8 s; obejmuje 26 prób podejścia
i porzucenie). Pozostała różnica nie dotyczy 9006 ani ponownego wyboru: AI wybiera bohatera 0x5000ad2, którego nie ma
w odtworzeniu (parametry walki bohatera [N]).

## 7. Osiągalność i ponowny wybór celu

Mechanizm [P: kod; pomiar 616 i 619]:
- każda próba ataku (gracza i AI) to 26 × PrepareToMove co 9 taktów; przy celu na polu nieprzejezdnym żadne z 8 miejsc
  podejścia nie jest przejezdne, więc każde PrepareToMove wpisuje albo odświeża cel w mapie nieosiągalnych
  (termin = czas + 30 s);
- po 26. próbie EnemyUnitReachable daje fałsz (licznik > 25) → 2025 → 5000; kolejka celów pusta – **rozkaz gracza nie
  jest kontynuowany**;
- wybór celu odrzuca kandydata z ważnym wpisem (termin nieminiony, te same pola atakującego i celu); po upływie
  terminu wpis jest usuwany i AI wybiera ten cel ponownie przy najbliższym przeglądzie (616: 30,2–30,5 s po ostatnim
  PrepareToMove);
- w 619 po porzuceniu AI od razu wybiera innego widocznego wroga (bohatera).

Rozdzielenie zjawisk: (1) rozkaz gracza nie ma osobnego „ponawiania” – po porzuceniu kończy się; (2) samodzielny
wybór AI jest blokowany mapą nieosiągalnych. Oba korzystają z tego samego licznika prób celu (+0x18, osobny dla
każdego obiektu celu) i tej samej mapy (należy do atakującego).

Nie wprowadzono timera: odstępy wynikają z terminu 30000 ms z kodu i z cyklu przeglądu (Idle co 350 ms, szukanie
co 2000 ms), który Core już miał.

## 8. Porównanie 616 i 619

| | 616 (gra) | 616 (Core) | 619 (gra) | 619 (Core) |
|---|---|---|---|---|
| dotarcie do punktu PPM | t = 77954 | 77954 | – | – |
| wybór AI obywatela | 77989 | 77988* | – | – |
| porzucenie (AI) | 88046 | 88045* | – | – |
| atak gracza → porzucenie | 97422 → 105468 | 97420 → 105466* | 40147 → 71954 | 40147 → 71954 |
| ponowne wybory AI | 135675, 173894, 212113 | 135670, 173886, 212102* | 71988 (bohater) | – (brak bohatera) |

\* Czasy Core liczone jako t₀ + k · 34,0909 ms; gra zaokrągla czas do ms, różnica rośnie do 12 ms po 200 s – to ten sam
takt (porównanie stanu co takt: 616 – 5322 takty bez różnicy).

## 9. Pierwsze pozostałe rozbieżne takty

| Przypadek | Etap 36 | Etap 37 |
|---|---|---|
| 619 | 64147 (9006) | 71988 (wybór bohatera – brak w odtworzeniu) |
| 620 | 59783 (9006) | 192032 (kolejny rozkaz MCP – nieodtwarzany) |
| 616 | 47545 / brak wyboru AI | brak w zapisie (5322 takty) |
| 578 G1 | brak w oknie | brak w oknie (986/986) |
| 578 G3 | 169 (ω) | 169 (ω) |
| 590 G1 | 97 (kurs) | 97 (kurs) |
| 589 G3 | 1 (kurs) | 1 (kurs); mniej różnic: stan 118 → 84, HP 38 → 17, +0x2A0 821 → 468 |
| 580 G1 (AoC) | 57 (stan) | 57 (stan) |
| AoC 505 | 803 | 803 |
| EE 500 | koniec +1 | koniec +1 |

## 10. Testy regresyjne

- CTest Release 20/20, Debug 20/20.
- GDExtension 30/30 (+2: kąt szyku z pomiaru 616 – 2,7300477; cel nieosiągalny – porzucenie i ponowny wybór
  30,48 s po ostatnim PrepareToMove).
- Godot 325/325, Riverlands_MCP 16/16 (bez zmian w MCP), narzędzia Titan 20/20.
- S1–S7 `68b0c69ecb8b0cbc`, 578 G1 986/986, skrót mapy `c8297c16f0d48b1a`. Oczekiwanych wyników nie zmieniano.

## 11. Potyczka Godota

Rzeczywisty przebieg sceny (xvfb, launcher `--uruchom=4`, wejście przez zdarzenia myszy i klawiatury): ramka
(5 jednostek), PPM w teren z Shift, PPM na wrogu (5/5 celów w Core), zwycięstwo w taktach 1412 i 1509 (restart R),
porażka w układzie 1 na 5 (takt 726). Animacje, paski HP, wybór celu przez AI (21 wyborów), obrażenia – bez zmian
w działaniu. Przerwanie ataku ruchem i determinizm – testy GDExtension. Nowość: rozkaz ruchu w scenie podaje kurs
końcowy z `kat_rozkazu`, więc jednostki obracają się na końcu ruchu jak w EE. Scena nadal czyta wyłącznie stan Core.

## 12. Otwarte hipotezy

1. Osiągalność 0x62D696 (lokalne A* w oknie do 35 pól) i warunek 0x5ECAD0 – w Core nadal prawda [N].
2. Czy 0x632CF4 zwraca fałsz także z innych powodów niż brak przejezdnego miejsca (ulepszenie +0xAC = 0) [W].
3. Wpis do mapy nieosiągalnych w RepathAroundObstacle (0x622776) i odwecie (0x623717) – nieodtworzone [N].
4. Usuwanie wpisu przy zmianie pola atakującego albo celu – z kodu, bez pomiaru [W].
5. Środek zaznaczenia jako środek prostokąta (import 0xB2FBF4) – przy jednej jednostce nieodróżnialny od średniej [W].
6. Warunek 9014 dla EEUGLocation bez kursu (v = ω = 0) – model v4 zamiast cel+0x31 [W].
7. Różnice kursu do 3,1·10⁻⁴ rad w taktach zwrotu na punktach trasy (619, 620; podobnie 590 G1) [N].

## 13. Rekomendacja na etap 38

1. Pomiar kontrolny na e35_a: gwardia i cel nieosiągalny, po porzuceniu przesunięcie atakującego o jedno pole – czy
   AI wybiera cel przed upływem 30 s (pkt 12.4); ta sama próba z dwiema gwardiami (wspólny cel, osobne mapy).
2. Parametry bohatera z pamięci (walka_parametry_typu) i odtworzenie 619 dalej (wybór bohatera, walka).
3. Różnica kursu 3·10⁻⁴ rad na zwrotach (590 G1, 619, 620) – wspólna przyczyna w obrocie trybu 0.
4. Następnie pościg za ruchomym celem (578 G3 / 590 G1).
