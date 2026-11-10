# Raport etapu 42 – regiony Titan, reguła przekątnej floodu i czysta mapa testowa EE

Etap miał dwa główne cele: wyjaśnić budowę regionów i podsektorów oraz dostarczyć czystą, powtarzalną mapę z rozkazem
ataku potwierdzonym w oryginalnym EE. Oba zrealizowano. **Graf Core nie jest jeszcze w pełni autonomiczny**: Core buduje
regiony, podsektory i graf z danych pól mapy, ale te dane (klasyfikacja obiektów pól) nadal pochodzą z odczytu gry.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.

## 1. HEAD początkowy i końcowy

- Początek: `66a5f1e` (lokalny etap 41; publiczny `main` bez zmian – `c776a61`).
- Koniec: jeden lokalny commit etapu 42 (`git log -1`). Bez push, pull, fetch, reset, rebase i clean.
- Poza commitem: `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11` użytkownika.
- Riverlands_MCP (lokalnie, niezatwierdzone): `regiony_wejscie` w `ee_podsektory.py`.

## 2. Analiza 0x423E3F i 0x4240D3 [W]

Kolejność (0x427D5D → 0x427D79/0x427D83):
1. **0x4240D3 – regiony.** Maszyna floodu 0x8262C4 (cel +0x20, siatka etykiet goal+0x60 u16, x·H + y). Start: pola od
   (N−1, N−1), x malejąco, y malejąco, pole z obszarem (0x41C537) i bez etykiety; etykiety kolejne od 1. Wyniki trafiają do
   wektora managera +0x7C (indeks = etykieta, odczyt `+0x80[+0x4E podsektora]` w 0x425F16). Na końcu 0x4240D3 wywołuje
   **0x42434F** (podsektory), przekazując siatkę regionów.
2. **Flood 0x42A66D** (przez 0x429AEA, 0x42A5F6): cztery boki z dostępnością 0x42B96A (pamięć podręczna bit 1 / bit 2,
   czyszczona przy każdym starcie – bez historii), przekątne: przy fladze maszyny +0x1C = 1 tylko z co najmniej jednym
   dostępnym bokiem, przy 0 bez warunku. Relaksacja 0x42B907 dodaje węzeł spoza list otwartej i zamkniętej.
3. **Dostępność 0x41B9C9** (obiekt wyszukiwania 0x825F88). Pierwsze pole (0x41BF51) ustala klasę regionu: obszar (+0xDA),
   rodzaj obszaru (+0xD8) i tryb +0x94 (= rodzaj regionu +0x7C):
   - obszar 1: tryb 1, a na polu rodzaju 0xA – 7 / 8 / 9 (wysokość 0 / < 0 / > 0); obiekt typu z +0x568 = 3 na polu ≠ 1
     (0x42CA21) → 4; pierwsza jednostka blokująca (+0x600 lub klasa 0x19, żywa) → 0xC (0xE dla klasy 0x19, 0xD dla +0x612);
   - obszar 2: 2 / 0xA / 0xB według znaku wysokości; obszar 3: 3; obszar 4: 6;
   - flaga przekątnej 1, a 0 dla trybów 3, 4, 6, 0xC–0xE.
   Kolejne pola: ten sam obszar i warunek trybu (tabela 0x41C235); pole na brzegu rombu (x + y = E0 / E1, |y − x| = E2,
   map+0x1816EC/F0/F4) dozwolone tylko w obszarze rodzaju 4. Wysokość: siatka 0x917CB8 albo bajt +0x14 pola (0x425632).
4. **0x423E3F** (wywoływana dwukrotnie po 0x4240D3) – kontynenty regionów: flood po tablicy regionów pól (0x42301D),
   tryb lądowy (rodzaje 2, 7–11, 12 z warunkiem jednostki) i wodny; znaczniki regionu +0x84 / +0x86, liczniki +0x118 / +0x114.
   **Nie tworzy siatki regionów** (etap 41 błędnie przypisywał jej tę rolę).

Odpowiedzi na pytania A1: obiekty i pola klasyfikuje rodzaj pola (+0x04), wysokość, obiekty klasy 3 i jednostki blokujące;
jeden region = jeden obszar i jeden tryb; granice – zmiana obszaru, trybu lub (dla 0xC) jednostki; przekątne – zależnie od
flagi; kontynenty powstają po regionach; numeracja – kolejność skanu; aktualizacja po zmianie obiektów – [N] (nie badana).

## 3. Odtworzona siatka regionów [P]

Nowy odczyt `regiony_wejscie` (zad. 628, e35_a): na pole rodzaj obiektu pola +0x04, bajt +0x14, obiekty z listy pola
(id, HP, gracz, typ: +0x568/+0x600/+0x4B4/+0x612), siatka obszarów i rodzaje obszarów. Wskaźniki, wymiary i długości list są
walidowane.

| Wariant | Pola zgodne | Różne | Regiony | Rodzaje regionów |
|---|---|---|---|---|
| prototyp `narzedzia/titan/regiony_porownanie.py` | **39 480/39 480** | 0 | 1135 = 1135 | 1135/1135 |
| Core `zbuduj_siatke_regionow` (test GDExtension) | 39 480/39 480 | 0 | 1135 | – |

Pierwsze uruchomienie miało etykiety przesunięte o 1 (start od 2) – po poprawce zgodność pełna. Plik etapu 41
`region_siatka_xH.json` zawierał `w4c[1] + 1`, a więc ten sam podział z inną numeracją.

**Obszary +0xF4**: funkcji budującej nie znaleziono [N]. Model z pomiaru [P]: klasa pola 4 (brzeg rombu), 2 (rodzaj pola 1),
3 (rodzaj 9), inaczej 1; składowe – brzeg 8-spójnie, pozostałe 4-spójnie (wariant „jeden bok” daje ten sam wynik);
skan x↓, y↓, id od 1 – 39 480/39 480 pól i identyczne id 43 obszarów.

Minimalne mapy rozstrzygające (A4) nie były potrzebne – pełna zgodność na dużej mapie.

## 4. Przypadki przekątnych 63 i 95 [P]

0x41EAE7 przy pierwszym polu floodu podsektora odczytuje region pola startowego i ustawia flagę przekątnej maszyny
(+0x1C) **według rodzaju regionu**: 0 (przekątna bez warunku boku) dla rodzajów 3, 5, 6, 12, 13, 14; 1 dla pozostałych.
- Podsektor 63 – rodzaj 13 → flaga 0 → pozostaje połączony mimo dwóch obcych pól bocznych.
- Podsektor 95 – rodzaj 4 → flaga 1 → rozdzielony.
Historia algorytmu, kolejność relaksacji i pamięć podręczna nie mają wpływu (pamięć czyszczona przy starcie, dostępność bez
historii). Bez wyjątków dla identyfikatorów.

## 5. Zmiany w budowie podsektorów

- Core: `zbuduj_przydzial_podsektorow` (0x42434F/0x42AA10, prostokąt sektora, ta sama etykieta regionu, flaga z rodzaju),
  `zbuduj_obszary`, `zbuduj_siatke_regionow`, `zbuduj_graf_z_wejscia` (ustawia też rodzaje podsektorów).
- Prototyp `podsektory_porownanie.py`: wariant `rodzaj`.

## 6. Porównanie grafu Core i Titan (e35_a)

| Metryka | Etap 41 | Etap 42 (Core z wejścia mapy) |
|---|---|---|
| Liczba podsektorów z polami | 1899 (prototyp) zamiast 1857 | **1857 = 1857** |
| Identyczne podsektory (pola i id) | 82 | **1857/1857** |
| Punkty reprezentatywne | 1851/1857 | 1851/1857 (bez zmian) |
| Sąsiedzi (zbiór i kolejność) | 1857/1857 | 1857/1857 |

Gra ma 1858 podsektorów – jeden bez pól (jak w etapie 41).

Trasy (zgodność przebiegu jednostek – osobno od struktury):

| Graf | 619 | 620 |
|---|---|---|
| referencyjny (odczyt z gry) | co takt (etap 40) | co takt (etap 40) |
| Core z przydziału pól z gry (etap 41) | obie gwardie 7273/7273, kolejki zgodne | 6419/6419 i 6418/6419 |
| **Core z wejścia mapy (etap 42)** – bez przydziału pól i bez siatki regionów z gry | wynik identyczny z etapem 41 we wszystkich polach | identyczny z etapem 41 |

## 7. Status autonomicznego generowania grafu

**Częściowy, eksperymentalny.** Core wyznacza obszary, regiony, przydział podsektorów, punkty i sąsiedztwo. Wejście –
rodzaj obiektu pola (+0x04), bajt +0x14 i obiekty pól – pochodzi z odczytu gry.

Pierwsza przyczyna rozbieżności przy wejściu z SCN: **klasyfikacja obiektów pól nie jest funkcją samej tekstury** [P]
(np. tekstura 26: rodzaj 1 – 17 239 pól, 10 – 686, 0 – 4; tekstura 31: 1 / 10 / 11). Funkcja klasyfikująca nie została
znaleziona [N].

Dwa źródła grafu są jawne w `diagnostyka()["graf_zrodlo"]`: „gra (odczyt)”, „Core z przydziału pól”, „Core z wejścia
mapy”. Normalna nawigacja potyczki nadal nie używa grafu.

## 8. SCN 231/250

**Wariant A niemożliwy** [P]: Empire Earth.exe odrzuca SCN 250 (AoC) – „Plik z zapisaną grą jest nieprawidłowy”
(zad. 197–199 etapu 12; zad. 626: limit czasu po odprawie). Wcześniej przygotowano jednak konwersję rekordu 231 → 250
(`konwertuj_rekord`: pola c328, c355, c358, c35c, c250, c32c = 0 jak w rodzimych rekordach 250, kontrola ponownym
odczytem) – przydatna dla AoC.

**Wariant B** – `narzedzia/eksperymenty/scenariusz_czysty.py`: kopia „Wojny trojańskiej” (231), usunięcie wszystkich
jednostek graczy 1–16 (685), obiektów Świata w prostokącie (140–190, 85–135) (546), pusty kawałek 6 (wyzwalacze, opis,
cele; 115 B jak w scenariuszu bez wyzwalaczy). Rekordy dopisuje istniejące `scenariusz_testowy_kolizji.py` (ta sama wersja).
Kontrola: odczyt całego kawałka 5, ramek pliku i kompresji.

## 9. Walidacja czystej mapy [P]

Generator `narzedzia/eksperymenty/scenariusze_czyste.py` z opisem `dane/testy_walki/e42_warianty.json` (bez ręcznych zmian):

| Wariant | Jednostki (odczyt pamięci po starcie w EE) | Wynik |
|---|---|---|
| 1v1 (zad. 631) | gr. 1: gwardia (164,118), prorok (170,108); gr. 5: gwardia (164,108) | atak MCP – § 10 |
| 2v1 (632) | 2 gwardie + prorok; cel (164,108) | EEUGAttackUnit z PPM |
| 3v1 (632) | 3 gwardie + prorok; cel | wczytany, pozycje zgodne |
| blokada_podejscia (632) | gwardia, obywatel gr. 1 na polu (164,109), prorok; obywatel gr. 5 (164,108) | wczytany |
| cel_otoczony (632) | gwardia, prorok; obywatel gr. 5 i 4 domy gr. 5 dookoła | wczytany (gra dodaje 4 obiekty typu 223 przy domach) |
| cel zmieniający pole | – | **niezrealizowany**: MCP wydaje rozkazy tylko graczowi 1, trasy rekordów nieobsługiwane |

**Odstępstwo od wymagania „brak innych jednostek”**: w każdym wariancie jest prorok-obserwator gracza 1 (pole widzenia 8,
atak 0, sam nie atakuje), poza polem widzenia celu (4). Powód [P]: cel jest rysowany (warunek PPM) tylko w polu widzenia
jednostki gracza 1. Gwardia widzi na 4 pola, a cel w jej polu widzenia jest atakowany samoczynnie po 34 ms (zad. 629,
pochodzenie 0). Zad. 630 (6 par, odległości 4–5) nie wykazało okna „widoczny, ale bez walki”. Dyplomacja: gracz 1 i
gracz 5 – wrogowie (odczyt 611). Gracz 2 scenariusza jest sojusznikiem gracza 1, dlatego celem jest gracz 5. Na starcie
gracze 2–4 i 6 mają 0 jednostek.

## 10. Rozkaz ataku przez MCP (631) [P]

- Do PPM obie gwardie w stanie 5000, bez celów (t = 3749–47556).
- PPM (`walka_atak_rzut_gry`, próba 1, h = 0,3) o 47556; **EEUGAttackUnit 0x5000ad0, pochodzenie 1** utworzony o 48068.
- Przebieg: 2012 → 2013 → 2024 → 8000 → 2015 → 10003 (podejście co ~1,7 s), stan 2021 po 9,9 s, cel reaguje o 60374.
- Nagranie: 2808 próbek (lokalnie, `ee_obserwacja/e42_631_1v1.json`).

**Czysta mapa jest gotowa**: uruchomiona w EE, sprawdzona odczytem pamięci, z potwierdzonym rozkazem ataku.

## 11. 590 G1

Brak nowego pomiaru [N]. Analiza statyczna: 0x5EB1D5 leży w środku funkcji (nie jest jej początkiem), 0x549E61 jest
wywoływana z 0x54CAC3 i z tablicy 0x82D058. Blokada: brak nagrania kontaktu dwóch jednostek na czystej mapie. Wariant 2v1
generatora zapewnia teraz taki układ (dwie gwardie na jeden cel) do nagrania w etapie 43. Fizyka bez zmian; różnica w
takcie 97 (pozycja maks. 0,0094) bez zmian.

## 12. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | **44/44** (+4: regiony i przekątna – syntetycznie, e35_a z wejścia mapy, obszary z modelu) |
| Godot | 325/325 |
| Riverlands_MCP | 16/16 |
| Narzędzia Titan | 20/20 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| EE 578 G1 | 986/986 |
| Skrót mapy | `c8297c16f0d48b1a` |
| Struktura grafu e35_a | 1857/1857 podsektorów, 39 480/39 480 regionów, przekątne zgodne |
| 619/620 z grafem referencyjnym / z Core | jak w etapach 40/41 / identyczne z etapem 41 |
| `git diff --check` | czysto |

578 G3 (5 różnic stanu, ω), 590 G1 – bez zmian.

## 13. Pierwsze rozbieżne takty

- 619/620 (graf z wejścia mapy): brak różnic względem etapu 41 (porównanie wszystkich pól wyniku odtworzenia).
- 578 G1: brak. 578 G3: takt 169 (ω), bez zmian. 590 G1: takt 97, bez zmian.
- Nagrania czystej mapy (631) nie są jeszcze odtwarzane w Core – narzędzie odtworzenia zna tylko układ e35_a.

## 14. Potyczka Godot

Ruch, atak i zwycięstwo w obu bitwach (takty 1232 i 1174), restart działa, scena 1 na 5 – przegrana w takcie 761.
Potyczka nadal działa bez grafu podsektorów (D – niewykonane). Liczby taktów różnią się między uruchomieniami
z renderem [H].

## 15. Otwarte problemy

- Klasyfikacja obiektów pól (+0x04, +0x14) – brak autonomii z samego SCN [N].
- Kod budowy obszarów +0xF4 (jest tylko model z pomiaru) [N].
- vt+0x58 jednostki złożonej (bajt +0x345) przyjęty jako 0 [H].
- Aktualizacja regionów po zmianie obiektów mapy [N].
- 6 rozbieżnych punktów reprezentatywnych.
- Wariant „cel zmieniający pole”; obserwator w scenariuszach czystej mapy.
- 590 G1, 578 G3 ω, 0x5ECAD0, Healer.tai, remisy A* grafu.

## 16. Propozycja etapu 43

1. Klasyfikacja obiektów pól: znaleźć zapis +0x04 i +0x14 przy wczytywaniu mapy (EEMap) i odtworzyć ją w Core z SCN.
   Test: rodzaj pola dla 39 480 pól, potem graf w pełni autonomiczny i 619/620 bez danych z gry.
2. Kod budowy obszarów +0xF4 (potwierdzić model pomiarowy).
3. Na czystej mapie: odtworzenie 631 w Core (uogólnić narzędzie odtworzenia na układy z generatora), 2v1/3v1 –
   zajętość miejsc podejścia, i nagranie kontaktu dwóch jednostek do 590 G1.
