# OpenEE — raport etapu 53: produkcja wojskowa, walidacja AoC i integracja odkryć Fable

Etap prowadził Claude Fable 5.2 (etapy 1–52: Claude Opus 5.5). Oznaczenia: [P] pomiar w grze, [W] analiza kodu albo
danych, [H] hipoteza, [N] nieustalone.

Najważniejsze wyniki:
- **Koszary produkują wojsko tym samym mechanizmem co Centrum Miasta** – zmierzone w AoC (główna wersja) i kontrolnie
  w EE. Jednostka 3011 „Inf03 - Maceman”: 30 żywności + 30 żelaza przy rozkazie, 32000 ms, 942 takty, wyjście przy
  krawędzi budynku, kurs −y, stan 5000, populacja +1. Core odtwarza 7 nagrań w całości (4 AoC, 3 EE).
- **Zagadka z etapu 52 rozwiązana:** losowanie przy starcie pozycji to wybór płci obywatela (wynik ≥ 0,5 →
  obywatelka). Kod obu gier i 7 z 7 zmierzonych startów. Produkcja wojskowa przy starcie nie losuje.
- **Anulowanie działa prawym przyciskiem myszy na przycisku jednostki.** Usuwa pierwszą pozycję tej technologii z
  kolejki, a gdy jej nie ma – bieżącą; zwraca cały koszt. Zmierzone w obu grach, odczytane w AoC, odtworzone w Core.
- **Punkt zbiórki zmierzony w obu grach, ale nieodwzorowany** – z jednego układu nie da się ustalić reguły miejsca
  powstania.
- **Budowa domu i zbieranie drewna w AoC zgadzają się z Core** (dom: obywatel 2580/2581 i fundament 1312/1312 próbek;
  drewno: 4783/4783, gospodarka 4782/4782). Przy okazji wyszedł mały błąd Core (prędkość niezerowana w stanie 4012).
- **Odkrycia Fable w Core:** nowa para kontaktu na początku listy, wybór gałęzi kolizji dla dużych jednostek,
  parametry tarana z bazy. Trzy układy taran–gwardia zgadzają się z grą co takt w EE i AoC (6 nagrań).
- **Dom nie podnosi limitu populacji** [P: AoC]. **Zegar gry powyżej 524 288 ms jest skwantowany** (34,0625 ms na
  takt) [P].
- Regresja wcześniejszych nagrań bez zmian. CTest 24/24, GDExtension 83/83, Godot 325/325, Riverlands_MCP 108/108.

## 1. HEAD

- Początkowy: `2865eff9daa38fcbb78498e521f1854f77a2daa8` („Eksperyment Fable 2…”), gałąź `main`; drzewo robocze tylko z
  plikami użytkownika (`godot/project.godot`, `*.uid` w `godot/testy/eksperymenty/`, `uzytkownik.cfg.przed_etapem11`).
- Końcowy: lokalny commit „Etap 53: produkcja wojskowa i walidacja mechanik AoC” (skrót w podsumowaniu sesji).
  Bez `push`.

## 2. Zmienione pliki

| Obszar | Pliki |
|---|---|
| Core | `cpp/core/include/openee/symulacja.hpp`, `cpp/core/src/symulacja.cpp` |
| GDExtension | `cpp/gdextension/src/openee_symulacja.cpp`, `.hpp` (wersja 0.26.0) |
| Testy | `cpp/tests/testy_core.cpp`, `cpp/tests/CMakeLists.txt`, `godot/testy/testy_gdextension.gd` |
| Godot | `godot/silnik/symulacja/parametry_typow_db.gd` (nowy), `godot/sceny/potyczka.gd`, `godot/testy/eksperymenty/odtworz_scenariusz.gd` |
| Dane | `dane/testy_walki/parametry_jednostek_ee.json`, `dane/testy_walki/e42_warianty.json`, `dane/potyczka/potyczka_e53_koszary.json` (nowy), `dane/launcher/aktualnosci.json` |
| Narzędzia | `narzedzia/titan/odtworzenie_nagrania.py` |
| Dokumentacja | `docs/titan/produkcja.md`, `budowa.md`, `zbieranie.md`, `kolizje_objazdy.md`, `precyzja_numeryczna.md`, `EE_AOC_POROWNANIE.md`, `EKSPERYMENT_FABLE_DUZE_JEDNOSTKI.md`, `POSTEP_REKONSTRUKCJI.md`, `dziennik_eksperymentow.md`, `README.md`; `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` |
| Raporty | `RAPORT_ETAP_53.md` (nowy), `RAPORT_ETAP_52.md` → `raporty/archiwum/` |

Poza repozytorium (lokalnie, bez commitu):
- Riverlands_MCP: `riverlands_mcp/ee_obserwacja.py`, `ee_walka.py`, `ee_budowa.py` – parametr rejestratora `nowe_gracza`
  (jednostki gracza utworzone w trakcie nagrania są dopisywane do rejestracji);
- nagrania, mapy `e42_e53_*.scn`, opisy odtworzeń (`Testy_MCP/e53`, `Testy_MCP/fable2`).

## 3. Produkcja wojskowa w AoC

Wersja: `EE-AOC.exe` db8fc5ce… (proces testowy c636a2ab…). Scenariusz `e42_e53_koszary`: ukończone koszary gracza 1,
obywatel, zasoby 1111 / 1222 / 1333 / 1444 / 1555, populacja 1.

- Jednostka ustalona z danych i pomiaru: pierwszy przycisk panelu koszar = technologia 3011 (obiekt 21), `dbtechtree`:
  30 żywności, 30 żelaza, 32000 ms.
- Jedna jednostka (704): koszt i licznik 32000 w próbce kliknięcia; 942 takty; utworzenie w (164,25; 111,75), kurs −y,
  stan 5000; populacja 1 → 2; losowania: start 0, utworzenie 1.
- Dwie w kolejce (704): druga opłacona przy kliknięciu, czeka; startuje w takcie utworzenia pierwszej; miejsca
  (164,75; 111,75) i (165,25; 111,75).
- Nowa jednostka w rejestratorze (709): typ 21, pozycja, kurs i stan od pierwszego taktu.

Szczegóły i tabela: `docs/titan/produkcja.md` § 5.1.

## 4. Pomiar porównawczy EE

`Empire Earth.exe` e352d7ae… (proces 846350a8…), zadania 706 i 710, ten sam plik scenariusza.

- Ten sam przycisk, ta sama technologia 3011, te same dane bazy.
- Koszt, czas, kolejność operacji, kolejka, miejsce, kurs, stan początkowy i populacja – jak w AoC.
- Różnica: 3 losowania przy utworzeniu (AoC 1) – znana z etapu 52, parametr wariantu.
- Różnica danych: drugi przycisk to 2024 Spearman (AoC: 3107 Gallic Warrior, jednostka dodatku).

## 5. Funkcje, adresy i struktury

| Element | AoC | EE | Źródło |
|---|---|---|---|
| start pozycji – losowanie płci | 0x5FDDED–0x5FDE6B (`cmp [typ+0x1BC], 0x20`, stała 0,5: 0x838AAC) | 0x5EFB91 (`cmp [typ+0x4B8], 0x20`, 0x824AD0) | [W] |
| czas pozycji | 0x5FDE78–0x5FDEC7: 1 ms (gracz +0xB45), 2 ms (flaga pozycji), round(czas × +0x94) | – | [W] |
| anulowanie technologii | 0x5FD984 (pierwsza pasująca z kolejki), 0x5FD8F3 (bieżąca), porównanie 0x6414D2 (para 1074/1451) | [N] | [W] |
| komunikat anulowania | 0x4C47B0–0x4C4850 | [N] | [W] |
| koszt kroku A\* | 0x419595 | 0x41CFFF | [W], Fable 2 |
| klasa celu budowy / zbierania | vtable 0x84740C / 0x8475A8 | 0x8319F0 / 0x831B80 | [P] |
| punkt zbiórki | EEUGLocation w 2. poziomie kolejki celów budynku | to samo | [P] |

## 6. Koszty, kolejka, czas, populacja

- Koszt pobierany przy rozkazie, niezależnie od miejsca w kolejce [P: obie gry].
- Czas = Build time z `dbtechtree` (mnożnik ulepszenia 1,0); licznik −34 ms na takt [P].
- Populacja rośnie przy utworzeniu, nie przy rozkazie ani starcie [P].
- Ukończenie i zniszczenie domu nie zmienia populacji ani składników limitu (+0xB20, +0xB24 pozostają 0) [P: AoC 707].
  Limit 101 = 1 + 0 + 0 + 100. Znaczenia pól +0xB0C i +0xB14 z etapu 51 nie rozszerzam.
- Próba produkcji przy osiągniętym limicie: niewykonana (limit globalny 100 wymaga 100 jednostek) [N].

## 7. Anulowanie i punkt zbiórki

Anulowanie – `produkcja.md` § 5.3:
- wskazanie: PPM na przycisku technologii (kolejka nie ma ikon);
- pozycja oczekująca: pierwsza pozycja tej technologii od początku kolejki [W + P: kolejka mieszana 709/710];
- bieżąca: tylko gdy w kolejce nie ma tej technologii i bieżąca jest tą technologią;
- zwrot: 100 % kosztu w takcie kliknięcia; populacja i generator bez zmian;
- EE = AoC we wszystkich zmierzonych krokach;
- niezmierzone: chwila startu następnej pozycji po anulowaniu bieżącej przy niepustej kolejce.

Punkt zbiórki – `produkcja.md` § 5.4:
- zapisywany od razu jako cel EEUGLocation w drugim poziomie kolejki budynku;
- obowiązuje dla kolejnych jednostek (2 z 2);
- jednostka powstaje przy narożniku od strony punktu, z kursem na punkt, w stanie 8000 z rozkazem ruchu do miejsca w
  polu punktu (druga jednostka o 0,5 pola dalej);
- miejsce powstania **nie** jest stałe: bez punktu (164,25; 111,75), z punktem (166,25; 114,25);
- stan: rozpoznany, zmierzony w jednym układzie na grę, **nie zaimplementowany** – nie deklaruję zgodności.

## 8. Budowanie i zbieranie w AoC

| Eksperyment | Wynik w grze | Core (`--wariant=aoc`) |
|---|---|---|
| C1 dom (707) | koszt 50 drewna + 40 kamienia przy rozkazie; HP 1 → 500, +15 co 29–30 taktów; 34 092 ms; ukończenie jak w EE | obywatel 2580/2581 (+1 próbka nieaktualna), fundament 1312/1312 |
| C2 drewno (708) | 8008 → 4004 → udźwig 15 → 8009 → 4005 (+15) → 8008; +5 co 22 059 ms | 4783/4783 od rozkazu zbierania; gospodarka 4782/4782 |

- Warunki początkowe równoważne EE (ten sam plik scenariusza, te same zasoby); kliknięcia różnią się o setne części pola.
- Różnica przebiegu [P]: AoC nie pokazuje próbki stanu 4028 po ukończeniu budynku (EE pokazuje jedną).
- Aktualizacja grafu przejezdności w AoC nieodczytana (narzędzie pól mapy działa tylko w EE) [N].
- Poprawka Core: stan 4012 zeruje prędkość (§ 11).

## 9. Integracja odkryć obu eksperymentów Fable

| Odkrycie | Stan w Core po etapie 53 |
|---|---|
| okno kontaktów: EE nowa pozycja, AoC stara | bez zmian (`WariantTitan::kontakty`), nowy wariant niepotrzebny |
| nowa para na początku listy | wdrożone; regresja bez zmiany wyników |
| wybór gałęzi (oba rozmiary ≥ 1,0, drugi ruchomy) | wdrożone: para poza odpychaniem małym |
| gałąź duża 0x548A3C / 0x555247 | **niezaimplementowana** – wzory skutków nieodczytane |
| przerwanie pętli po prawdzie metody, filtr +0x347 | niezaimplementowane [W] |
| kara A\* 50 za stojącą jednostkę | była w Core; potwierdzona nagraniami gwardii i taranów |
| kara 150, pominięcie własnej grupy, podwojenie kosztu | niezmierzone; bez zmian w Core |
| parametry tarana (102) | z `dbobjects` (a 1,0; vmax 0,5; α 1,745; ωmax 0,873; rozmiar 1,0) |

## 10. Status kolizji i dużych jednostek

Odtworzenia z macierzą kursu z nagrania (`--macierz=1`):

| Układ | EE | AoC |
|---|---|---|
| mijanie gwardii stojącej obok trasy | 5880/5880 (taran i gwardia) | 5923/5923 |
| taran między dwiema gwardiami (2 kontakty) | 3 × 4581/4581 | 3 × 4605/4605 |
| zderzenie: gwardia na trasie, objazd, push | 3275/3275 obu | 3305/3305 obu |
| taran bez przeszkód (wiersz ze stokiem) | do t = 55226 | do t = 54715 |
| objazd stojącego tarana | do t = 57749 (stok); w grze push gałęzi dużej od 69715 | do t = 76091 (oba tarany w ruchu) |

- Rozbieżności na stoku: reguła hamowania przy v równym progowi – `precyzja_numeryczna.md` § 10 pkt 3 [N].
- Objazd w EE: gra odpycha stojący taran gałęzią dużą, Core nie – ograniczenie udokumentowane.

## 11. Zmiany Core, GDExtension i Godot

Core:
- `ParametryProdukcji::losowy_zamiennik`; start losuje tylko dla technologii z zamiennikiem.
- `anuluj_technologie(budynek, tech)`.
- Lista kontaktów: wstawianie na początek.
- `krok_koncowy`: para dużych jednostek poza odpychaniem małym; licznik `pary_duze`.
- Stan 4012: tryb 3, v = 0, ω = 0; stan 4002: tryb 6 (mały błąd wykryty odtworzeniem 707; pierwsza rozbieżność przed
  poprawką t = 84273).
- `ustaw_kurs_macierzy(id, m01, m11)` – orientacja ze stanu początkowego nagrania.
- Bez nowego wariantu EE/AoC.

GDExtension: `anuluj_technologie`, `ustaw_kurs_macierzy`, pole `losowy_zamiennik`, `pary_duze` w diagnostyce, wersja
0.26.0 (etap 53).

Godot:
- `parametry_typow_db.gd` – parametry ruchu i walki typu z `dbobjects` według reguł, które dla typów zmierzonych dają
  wartości z pomiaru; używane przez odtwarzanie nagrań i potyczkę.
- Potyczka `dane/potyczka/potyczka_e53_koszary.json` (`demo_e53`): ukończone koszary, trzy pozycje 3011, anulowanie
  jednej (zwrot 30 + 30), dwie jednostki w taktach 942 i 1884, każda dostaje rozkaz ruchu i dochodzi w pobliże celu;
  raport co sekundę (bieżąca pozycja, licznik, kolejka, zasoby, populacja). Cała logika w Core, bez nowego interfejsu.
- `odtworz_scenariusz.gd`: rozkaz `anuluj`, `--macierz=1`, numer taktu rozkazu (`takt_przed`), typy bez pomiaru.

Narzędzia: `odtworzenie_nagrania.py` – `opis_produkcji` dla dowolnego budynku i technologii (rozkazy, anulowania,
nowe jednostki, jednostki dodatkowe), `porownaj_produkcje` po numerze taktu (próbki nieaktualne, nowe jednostki,
losowania), `opis_budowy` / `opis_zbierania` dla AoC, `porownaj_zbieranie`.

## 12. Regresja

| Zestaw | Etap 52 | Etap 53 |
|---|---|---|
| CTest Release | 22/22 | **24/24** (nowe grupy `produkcja_wojskowa`, `kontakty_duze`) |
| CTest Debug | 22/22 | **24/24** |
| GDExtension | 77/77 | **83/83** |
| Godot | 325/325 | 325/325 |
| Riverlands_MCP | 108/108 | 108/108 |
| `test_titan_narzedzia` | 20/20 | 20/20 |

Zmiany w istniejących testach (z powodem):
- CTest `produkcja`, przypadek 1: rozkaz zamawia teraz 1074 (jak przycisk), a oczekiwany typ wynika z losowania –
  wcześniej test zamawiał 1451 wprost i oczekiwał losowania przy każdym starcie, co pomiar 704/706 obalił.
- GDExtension etapu 52: napis wersji akceptuje „etap 5” (jak testy etapów 50 i 51).
- Tolerancji nie zmieniałem.

Nagrania (pierwsza rozbieżność):

| Nagranie | Etap 52 | Etap 53 |
|---|---|---|
| czyste 631 / 633 / 634 / 638k / 638c, e46 ×4, e48 a ×3 | w całości | w całości |
| 648 | prorok 3585/3585; gwardie od 6136 | bez zmian |
| 649 dom1 / dom3, 651 koszary | 74215 / 79432 / 76909 | bez zmian |
| 652 mur_rog; dom_*, kosz_* | 75034; gwardie 5318–6204 | bez zmian |
| 654 | 5 w całości; NE 42477; koszary W 50727 | bez zmian |
| 619 / 620 | 124254 / 109423 | bez zmian |
| 658_1 / 658_2 / 659 / 660 / 674 | w całości | w całości (2650 / 2649 / 3013 / 2411 / 3803) |
| 663 | A do 77216, B do 58465 | bez zmian |
| 673 od t = 80000 | 5069/5069, gospodarka 5069/5069 | bez zmian |
| 677 jeden / dwa, 679 | 1898 / 3101 / 2996 | 1897 / 3170 / 2995 w całości – porównanie po numerze taktu, płeć z generatora |
| gwardia wokół gwardii (Fable 2) | 4299/4299 EE, 4329/4329 AoC | bez zmian |
| **704 ×2, 705, 709 (AoC); 706 ×3 (EE)** | – | w całości (§ 5.6 `produkcja.md`) |
| **707 dom AoC, 708 drewno AoC** | – | w całości (708 od rozkazu zbierania) |
| **tarany, 5 układów × 2 gry** | – | 3 układy w całości, 2 z rozbieżnością (§ 10) |

- Determinizm: dwa odtworzenia 704 „dwa” i tarana między gwardiami – pliki wyników identyczne bajt po bajcie.
- Po zmianie kolejności listy kontaktów i wyboru gałęzi żadne wcześniejsze nagranie nie zmieniło wyniku.

## 13. Pierwsze rozbieżności w nowych nagraniach

| Nagranie | Pierwsza rozbieżność | Przyczyna |
|---|---|---|
| 704 jeden | brak; 1 próbka nieaktualna (t = 181133) | rejestrator zwrócił stan poprzedniego taktu |
| 707 (przed poprawką) | t = 84273, pozycja obywatela (164,1641 / 164,1581) | Core nie zerował prędkości w 4012 – poprawione |
| 708 od początku | t = 47045, pozycja 140,5322 / 140,5235 | koniec przypadkowego rozkazu ruchu pod drzewem – zatrzymanie w 9006 przy v ≠ 0 (otwarte od etapu 51) |
| taran bez przeszkód EE / AoC | t = 55226 / 54715, pozycja Δ 0,0023 | reguła stoku przy v równym progowi [N] |
| objazd tarana EE | t = 57749 (stok), taran 2: t = 69749 | gałąź duża nieodwzorowana |
| objazd tarana AoC | t = 76091, pozycja Δ 0,002 | oba tarany w ruchu; przyczyna [N] (stok albo gałąź duża) |
| 705 / 706 zbiórka | nieodtwarzane | punkt zbiórki poza Core |

## 14. Mapa postępu A/B/C

Pełna tabela: `docs/titan/POSTEP_REKONSTRUKCJI.md` (stan po etapie 53).

| Podsystem | Zmiana | Dowody |
|---|---|---|
| 18 Produkcja jednostek | A 3 → **4**, C 3 → **4** (B 3) | EE+AoC |
| 16 Zbieranie surowców | C 2 → **3** (A 3, B 2) | EE+AoC (drewno) |
| 8 Kolizje | C 3 → **4** (A 4, B 3) | EE+AoC |

| Wskaźnik (38 podsystemów) | Etap 52 | Etap 53 |
|---|---|---|
| A ≥ 3 / B ≥ 3 / C ≥ 3 | 21 / 19 / 17 | 21 / 19 / **18** |
| A = 0 | 5 | 5 |
| ocena 5 | brak | brak |
| kod Core | 5478 wierszy | 5536 |

Ocen nie podnosiłem za sam odczyt statyczny ani za jeden układ pomiarowy.

### Postęp rekonstrukcji Titan – ile zostało do końca?

- **Rozpoznanie EE (A):** bez nowych podsystemów. Rdzeń (ruch, trasy, kolizje, stany, walka wręcz, budynki, budowa,
  zbieranie drewna, produkcja) rozpoznany na poziomie 3–4; 12 podsystemów ma ocenę ≤ 1, 5 jest nietkniętych.
- **Zgodność AoC:** przybyły pierwsze pełne odtworzenia AoC poza produkcją obywatela – produkcja wojskowa z
  anulowaniem, budowa domu, zbieranie drewna, ruch tarana, kolizje taran–gwardia, objazd z kary A\*. Dla AoC nadal nie
  ma nagrań walki z budynkiem, śmierci, bohatera, proroka, grafu nawigacji ani koszar w budowie.
- **Implementacja (B):** bez zmiany liczby podsystemów ≥ 3. Doszły: anulowanie, płeć, dowolny typ jednostki z bazy,
  kolejność kontaktów, wybór gałęzi.
- **Największe blokery:** gałąź dużych jednostek (wzory), punkt zbiórki (reguła miejsc), technologie i epoki, jednostki
  dystansowe, AI komputera, widoczność.
- **Pierwsza grywalna wersja:** pętla „zbierz drewno → zbuduj → wyprodukuj obywatela albo wojsko → walcz wręcz” działa w
  Core z rozkazami z układu. Brakuje interfejsu produkcji i budowy, pozostałych surowców, technologii i przeciwnika.
- **Pełna rekonstrukcja Titan:** ponadto transport, lotnictwo, okręty, kalamity, wyzwalacze, zapis gry, multiplayer,
  edytor. Terminu nie podaję – tempo znamy tylko dla symulacji jednostek lądowych.
- Średnie ocen (2,29 / 2,00 / 1,97) są wskaźnikiem kierunku, nie procentem ukończenia.

## 15. Różnice EE/AoC

Nowe wpisy w `docs/titan/EE_AOC_POROWNANIE.md` § 2:
- WSPÓLNE [P]: produkcja wojskowa, anulowanie, punkt zbiórki (1 układ), zbieranie drewna, koszt / HP / rytm / czas
  budowy domu, tor tarana;
- WSPÓLNE [W + P]: losowanie płci;
- ZMIENIONE [P]: brak próbki stanu 4028 w AoC po ukończeniu budynku; zawartość panelu koszar (dane);
- zmierzone tylko w AoC: dom a limit populacji, kwant zegara gry;
- bez nowego wariantu w Core.

## 16. Otwarte problemy

1. Gałąź duża 0x548A3C / 0x555247 – wzory skutków, przypadek „w linii”.
2. Punkt zbiórki – reguła miejsca powstania i miejsc docelowych; drugi układ.
3. Reguła stoku przy v równym progowi (tarany); czułość +0x488 tarana.
4. Brak próbki 4028 w AoC – przyczyna w kodzie.
5. Limit populacji osiągnięty, zajęte miejsce wyjścia, Shift, najkrótsza kolejka.
6. Kara A\* 150, pominięcie własnej grupy, podwojenie kosztu dla dużych jednostek – bez pomiaru.
7. Funkcje anulowania w EE (adresy) – nieodczytane.
8. Pozycje otwarte z etapów 49–52 (D1–D3, 654, 649/651, 619/620, 673) – bez zmian.
9. Start gry przez MCP zawodzi, gdy ktoś używa pulpitu (zadanie 702) – kursor gry nie reaguje na ruch myszy.

## 17. Rekomendacje etapu 54

1. Punkt zbiórki: dwa kolejne układy (inna strona budynku, punkt daleko), reguła, implementacja i odtworzenie 705/706.
2. Gałąź duża: odczyt 0x548E58–0x549179, pomiar „w linii”, odtworzenie objazdu EE (zad. 700).
3. AoC: koszary w budowie (674), dwóch budowniczych (663), prorok (648) – kolejne nagrania EE powtórzone w AoC.
4. Drugi surowiec (kamień albo złoto) i dwóch zbieraczy w AoC.
5. Interfejs produkcji w potyczce OpenEE (przycisk, PPM anulowania) na istniejących rozkazach Core.
6. Reguła stoku: odczyt +0x488 tarana i dokładna kolejność zaokrągleń w 0x548645.

## 18. Koszt i przebieg prac

- Zadania MCP: 9 (702–710): 7 w AoC, 2 w EE (706, 710); 702 nieudane (start), powtórzone jako 703.
- Nagrania: 14 (`e53_704_jeden`, `_dwa`, `e53_705_anuluj`, `_zbiorka`, `e53_706_jeden`, `_dwa`, `_anuluj`, `_zbiorka`,
  `e53_707_ob`, `_bud`, `e53_708_zb`, `e53_709_nowa`, `_mieszana`, `e53_710_mieszana`); ponownie użyto 12 nagrań
  Fable i 8 nagrań etapów 50–52.
- Wywołania REA/Ghidra: 0 – analiza na własnych listingach liniowych obu plików exe.
- Odtworzenia w Core: ok. 90 uruchomień (nowe nagrania, tarany, pełna regresja).
- Czas: start 23:14, ostatnie zadanie MCP zakończone 00:01, koniec prac ok. 00:30 czasu lokalnego (ok. 1 h 15 min).
- Tokeny wejściowe, wyjściowe i pamięci podręcznej: brak danych w tym środowisku.
- Przebieg: rozpoznanie → pomiar AoC → pomiar EE → implementacja → odtworzenia → regresja → dokumentacja. Kolejność
  priorytetów z zadania zachowana; punkty 6 (limit populacji w produkcji) i 7 (pozostałe reguły A\*, gałąź duża)
  zostały otwarte.
