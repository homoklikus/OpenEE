# Raport etapu 47 – niszczalne budynki, przyrostowy graf Titan i cykl zmian świata

Najważniejsze wyniki etapu:
- **Budynek jest obiektem symulacji Core.** Ma HP, otrzymuje obrażenia przez zwykły cel EEUGAttackUnit, umiera
  według reguł EEPMBuilding (zapadanie się z drganiem x/y) i zwalnia pola w chwili wejścia w Dying (6000).
- **Przyrostowa przebudowa grafu 0x4278C3 jest odtworzona.** Jeden sektor na przebieg, zwalnianie i ponowne użycie id
  podsektorów. W 4 odczytach gry (647, 648) Core daje te same id, pola, punkty reprezentatywne, kolejność sąsiadów,
  listę wolnych id i największe id [P].
- **Titan nie przelicza istniejących tras po zmianie mapy** [P: 648]. Nowy rozkaz przechodzi przez zwolnione pole
  [P: 647]. Core zachowuje się tak samo (test CTest).
- **Potyczka `potyczka_e47`:** trzy gwardie niszczą dom (150 → 0 HP), dom zapada się, Core przebudowuje 1 sektor,
  gwardie przechodzą przez zwolnione pole, restart przywraca dom. Dwa przebiegi w jednym uruchomieniu dają ten sam
  wynik (zniszczenie w takcie 1593).
- **Próg leczenia wyjaśniony** [W]: 0x5EDC82 wymaga HP < HPmax przed porównaniem progu. Rozbieżność z etapu 46 usunięta
  bez zmiany kierunku porównania.
- **Opóźnienia rozkazów MCP** [P]: krok `obs_rozkaz` (wybór, przesunięcie kamery, PPM) trwa 20–29 s, a czas gry płynie
  1,46 raza szybciej. To wyjaśnia przesunięcie rozkazu w 647 bez udziału gry. `obs_rozkaz` zapisuje teraz czasy gry
  etapów (`czasy_gry`).

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.
Statusy podawane osobno: mechanizm Titan / implementacja Core / test syntetyczny / pomiar EE / zgodność co takt /
integracja Godot.

## 1. HEAD początkowy i końcowy

- Początek: `1f35238` (etap 46).
- Koniec: jeden lokalny commit etapu 47 (hash w podsumowaniu sesji / `git log -1`). Bez push, pull, fetch, reset,
  rebase i clean.
- Poza commitem: `godot/project.godot`, `konfiguracja/uzytkownik.cfg.przed_etapem11` (pliki użytkownika), pliki `.uid`
  starszych skryptów eksperymentów oraz Riverlands_MCP (osobne lokalne repozytorium).

## 2. Model budynków Titan

| Element | Wynik | Źródło |
|---|---|---|
| Klasa obiektu | `EEUnit` (vtable 0x831494 – ta sama co gwardia) | [P: odczyt 647] |
| Klasa EEUC | z „Unit type” przez fabrykę 0x62188D: 2/0x13 Building 0x8335A8, 0x19 Gate, 0x1d Fortress, 0x18 Mining, 6 Citizen, 5/8/15 Land, 0 Ambient | [W] |
| Fizyka | EEPMBuilding 0x82CCC0 | [W] |
| Kolejka fizyki | żywy budynek **poza** kolejką 0x918DDC; Kill dopisuje go na koniec, zatwierdzenie w następnym takcie | [P: 645/647 – liczba kontaktów gwardii, kolejka] |
| Skrypt | „Simple Building.tai” = tylko Generic Death | [W: plik .tai] |
| Rozmiar / pola | „Square occupied” (kwadrat pól), „Size of collider” (typ +0x474) | [W; P] |
| Dom 37 (pamięć typu) | HP 500, pancerz 0, LOS 2, +0x4C0 = 3, rodzina +0x4C4 = 3, +0x4C8 = 9, +0x612 = 0, +0x600 = 1, +0x4B4 = 2 | [P: 647] |
| Mur 467 | rodzina 44, +0x474 = 0,9, +0x612 = 1 | [P: 647] |
| Zapis SCN | u3c rekordu = ułamek HP | [P] |

Budynek wielopolowy zajmuje kwadrat `Square occupied` × `Square occupied` pól [W]; w grze mierzony był tylko dom 1×1
i mur 1×1 [N dla 2×2].

## 3. Model budynków Core

- `Swiat::dodaj_obiekt_budynku(gracz, typ_db, X, Y, n, x, y, z, p, hp, blokuje, id_mapy, w_siatce)`: jednostka
  z flagą `budynek`, kwadratem pól i identyfikatorem obiektu mapy; poza kolejką fizyki do śmierci.
- Skrypt `SkryptStanow::wbudowany_budynek()`: Idle bez przejść + Dying/ResourcesRotting/UnitRotting/Dead.
- Kontakty i punkty podejścia pomijają budynki [P: 645 – 2 kontakty, nie 3].
- Blokady pól: licznik `Teren::blokady` (u16 na pole). `pole_przejezdne` wymaga też blokady = 0, więc dwa obiekty
  na jednym polu blokują je, dopóki oba nie znikną. `mapa.cpp` dodaje blokady zamiast zerować przejezdność.
- GDExtension 0.20.0: `dodaj_budynek(dict)`, `ustaw_przebudowe_pelna`, `stan_grafu`, `graf_okno`, `blokady_pola`;
  `jednostka()` i `stan_jednostek()` z polami budynku.
- Statusy: implementacja Core – tak; test syntetyczny – CTest `budynki` (22 sprawdzenia), GDExtension (+3);
  integracja Godot – tak (potyczka_e47, `odtworz_scenariusz.gd`).

## 4. Mechanizm zadawania obrażeń

- Zwykła ścieżka EEUGAttackUnit → TakeDamage, z tablicami trafień rodziny celu [W; P].
- Gwardia → dom: 6 na trafienie. Wynika z modyfikatora wysokości: z rekordu domu 1,0206 przy z gwardii 0 daje
  r = 0,8, min(0,8·6,93; 5,93) → 6 [P: 647].
- Gwardia → mur: 4 (m = 0,35, tablica 0x10, rodzina 44) [P: 648].
- Wiersze tablicy trafień: rodzina 3 – 0x08 0,23562, 0x0C 0,33, 0x10 0,462; rodzina 44 – 0,1785 / 0,25 / 0,35
  (`dane/testy_walki/parametry_jednostek_ee.json`).
- Mury nie są celem samoczynnym: 0x639AC3 odrzuca kandydata z typem +0x612, chyba że szukający ma +0x61E
  [W; P: 647 – gwardia stoi przy murze w Idle 150 s]. Core: `ParametryWalki::atakuje_mury`.
- Atak przerwany rozkazem ruchu [P: 647 `dom1_przerwany`]: cykl 2012 → 2001 → 2021, trafienie co 2045 ms; po rozkazie
  2015 → 10003, dom zostaje z HP 12, gwardia po dojściu wraca do 5000 bez ponownego wyboru domu (poza LOS).
- Zgodność co takt: 647 dom1 – trafienia po 6 co 60 taktów zgodne co do wartości, ale faza przesunięta o jedno
  trafienie (nagranie zaczęte w trakcie ataku: Core startuje od 2013, gra była w 2021). 648 przejscie2 – dom w Core
  o jedno trafienie później. Pełnej zgodności co takt dla walki z budynkiem nie deklaruję [N: faza z nagrania].

## 5. Stany śmierci budynków

| Stan | Titan | Pomiar | Core |
|---|---|---|---|
| 6000 Dying | EEPMBuilding tryb 2 (0x54BF34): x += (0,5 − r1)·0,01f, y += (0,5 − r2)·0,01f (2 losowania), z −= dt·0,13f; zmiana tylko gdy floor(x), floor(y) bez zmian | 682/682 próbek (645), 674/676 (647) [P] | `krok_budynku` |
| koniec 6000 | DyingAnimationFinished – EEUCBuilding vt[39] 0x601A4B: z < −2,0 ([0x83166C]) | 645: 683 takty, z = −2,00189 [P] | `f32(z) < −2,0` |
| 6001 / 6002 | jak Generic Death | 6002: 59 taktów (645) [P] | wspólne z jednostkami |
| 6003 Dead | usunięcie z kolejki i mapy; bez nowej rejestracji w grafie | [P: 647] | usunięcie z `wejscie_` bez zgłoszenia |
| gruz | obiekt na polu (np. 0x24ac, HP 1), nie blokuje | [P: `mapa_obszar` 647] | nieodwzorowany (bez wpływu na przejezdność) |

Godot przesuwa model budynku o (z − z0)·skala wysokości – widoczne zapadanie się – i ukrywa go przy 6003.
Animacji „smierc” dla bld_house_04 w danych gry nie ma (diagnostyka widoku).

## 6. Moment zwalniania zajętych pól

- Zgłoszenie mapy (0x4288A7 → 0x422DB6 → 0x4A36F3) następuje przy wejściu w 6000 [P: 645, 647].
- 647: śmierć 52261, +0xD4 = 52262, przebudowa w pierwszym takcie po terminie (+0xD8 = 0 w odczycie 52295) [P].
- 648 mur: +0xD4 = 106503 (śmierć 106502) [P].
- Core: `smierc_budynku` – kolejka dodań do fizyki, zdjęcie blokady pól, HP obiektu wejścia = 0, `zglos_zmiane_mapy`
  natychmiast. Test CTest: pole wolne w takcie śmierci, D4 = t + 1, budynek w kolejce fizyki w następnym takcie,
  przebudowa w następnym takcie.

## 7. Nowe dane diagnostyczne MCP

Riverlands_MCP (osobne repozytorium, lokalnie):
- `ee_mapa_zmiany.py`:
  - `mapa_obszar(x0, x1, y0, y1)` – pola prostokąta (rodzaj, bajt +0x14, obiekty z id/HP/stanem, obszar +0xF4),
    stan menedżerów, podsektory okna z punktami i sąsiadami;
  - `graf_stan` – +0xD4/+0xD8, kolejka +0x80, mapa zmienionych sektorów (+0x10/+0x18), wolne id (+0xBC), największe id
    (+0x10E);
  - `pola_szybkie` – na takt rejestratora (`mapa_pola`).
- Rejestrator `walka_rejestruj_*`: parametr `mapa_pola`.
- `obs_rozkaz`: `czasy_gry` (start kroku, przed PPM, po PPM, czas trwania).
- Testy: nowy moduł `test_ee_mapa_zmiany.py` (sztuczna pamięć; 4 testy).
- Siatka podsektorów +0xF8 jest w grze pusta (wskaźnik 0). Podsektor pola pochodzi z list sektora.

## 8. Mechanizm przyrostowej przebudowy grafu

| Krok | EE | Core |
|---|---|---|
| kolejka zmian | std::map menedżera +0x10, klucz = id sektora, +0x18 = liczba | `zmienione_sektory_` (pola grupowane x/K, y/K) |
| przebieg | 0x4278C3: jeden wpis na wywołanie; zostały wpisy → +0xD4 = teraz + 100 (0x4A367A); pusto → +0xD8 := 0 | `krok_przebudowy` |
| zwolnienie | 0x42809D: podsektory sektora w kolejności listy sektora, id na koniec wektora wolnych (+0xBC) | `przebuduj_sektor` |
| nowe id | 0x425E8D: ostatni wolny, inaczej ++ +0x10E | `wolne_id`, `maks_id` |
| regiony / podsektory | 0x4290A2 / 0x429B6D – flood w prostokącie sektora (x malejąco, y malejąco), nowe punkty | jak budowa początkowa w oknie sektora |
| sąsiedzi | 0x424DDD – okno sektora ±1, (x+1, y−1) ograniczone końcem okna | jak w grze |

Pełna przebudowa pozostaje jawnym wariantem (`ustaw_przebudowe_pelna`, `--przebudowa-pelna`). Statusy: mechanizm [W],
Core – tak, testy (CTest: id i lista wolnych, dwa sektory w jednym takcie – 2 przebiegi, 4 takty), pomiar EE –
4 przypadki [P], integracja Godot – potyczka i `odtworz_scenariusz.gd`.

## 9. Porównanie grafu przed i po zniszczeniu

`godot/testy/eksperymenty/porownaj_zmiane_grafu.gd` (graf Core z SCN, śmierć obiektu, przebudowa) kontra
`mapa_obszar` przed i po:

| Przypadek | Podsektory okna | Id / pola / punkty / sąsiedzi | Wolne id, największe id |
|---|---|---|---|
| 647 dom1 | 3 → 2 | identyczne [P] | identyczne |
| 647 przejscie_a | 7 → 6 | identyczne [P] | identyczne |
| 648 przejscie2 | 7 → 6 | identyczne [P] | wolne [428], identyczne |
| 648 mur | 3 → 2 | identyczne [P] | identyczne |

## 10. Wynik trasowania jednostek

Rozróżnienia z pakietu E2:

| Pytanie | Odpowiedź |
|---|---|
| Czy Titan przelicza istniejącą trasę? | **Nie** [P: 648 – prorok 0x1000858 kończy stary objazd po przebudowie; trasa z `obs_kolejka` identyczna przed i po; W: brak odwołań do tras w 0x4278C3] |
| Czy wymaga nowego rozkazu? | tak – nowy rozkaz idzie przez zwolnione pole [P: 647 S5] |
| Czy przelicza po wykryciu przeszkody? | nie dotyczy (stara trasa omija dom, przeszkody brak) [N dla trasy przez zniszczony obiekt] |
| Czy reaguje natychmiast po aktualizacji grafu? | nie [P: 648] |
| Czy zachowuje stare punkty pośrednie? | tak [P: 648 – 4 punkty bez zmian] |
| Czy odrzuca nieosiągalny cel / ponawia po zmianie mapy? | [N] – nieosiągalny cel przed zniszczeniem nie był mierzony |

Core: trasy nie są unieważniane (test CTest: trasa 18 punktów bez zmian po przebudowie; nowy rozkaz 6 punktów przez
pole domu).

Pełny przebieg (kryterium E) porównany z grą: 648 przejscie2, prorok 0x1000858 – 1241 próbek zgodnych do rozkazu MCP;
pierwsza różnica t = 48170 (kurs po rozkazie) i stan t = 50624. Przyczyny: Prophet.tai nie jest modelowany (dodatkowe
stany 2015) i trasa A* różni się od gry [N]. Pozycja końcowa nie jest więc zgodna co takt. Testy E3: dwa sektory
w jednym takcie (CTest), mur (648), kilka jednostek przez nowe przejście (potyczka, 3 gwardie) – tak; jednostka na
granicy podsektorów, cel zniszczony w trakcie podejścia, ponowne zablokowanie – niewykonane [N].

## 11. Status demonstratora Godot

- `godot/sceny/potyczka.gd`: budynki z układu (`uklad.budynki`) trafiają do obiektów mapy, wejścia grafu i Core.
  Wizualizacja przez WidokJednostek (pasek HP, zaznaczenie, zapadanie się). Budynek znika przy stanie ≥ 6003.
- Godot nie liczy obrażeń ani przejezdności – tylko pokazuje stan Core.
- Poprawka w tym etapie: `widok_jednostek.gd` czyta autoload `Konfiguracja` z drzewa. Bezpośredni identyfikator
  psuł kompilację w testach Godota (E5).

## 12. Wyniki scenariusza `potyczka_e47`

`dane/potyczka/potyczka_e47.json`: 3 gwardie gracza 1 (y = 117,5), dom 37 gracza 5 na (167, 111) z HP 150,
mury 467 gracza 1 na y = 111, x = 162…172. Demonstracja (`--potyczka-demo`, render, wejście jak gracz):

| Krok | Bitwa 1 | Bitwa 2 (po restarcie R) |
|---|---|---|
| rozkaz ataku (ramka + PPM na domu) | 3 jednostki | 3 jednostki |
| HP domu | 150 → 0 (22 trafienia po 7 – dom w potyczce stoi na wysokości terenu, więc bez modyfikatora wysokości z § 4) | identycznie |
| zniszczenie / wynik | takt 1593 | takt 1593 |
| przebudowa grafu | 1 sektor, wolne id [473, 474] | identycznie |
| przejście przez (167, 111) | 3 gwardie, 5,1 s | 3 gwardie |
| po 6003 | dom ukryty, poza fizyką | identycznie |

Wariant grupowy: trzy atakujące gwardie zajmują miejsca podejścia bez zakleszczeń, kolejki celów puste po śmierci.
Wcześniejsze uruchomienie (przed poprawką widoku) dało takt 1594 w obu bitwach. Różnica 1 takt między uruchomieniami
wynika z wejścia w czasie rzeczywistym [H]. Zrzuty i raport demonstracji są lokalne.

## 13. Wyniki badań fizyki i obywatela (G1)

644 pościg, pierwsza różnica t = 63817 (pozycja obywatela 0,002):
- Gra: pierwsze odepchnięcie obywatela w takcie kończącym się 63783 (licznik +0x248 rośnie od tego taktu).
  Core odpycha takt wcześniej (63749) [P: nagranie co takt].
- Odległość jednostek przed taktem: 0,3907 (bez odepchnięcia w grze) i 0,3820 (z odepchnięciem); suma połówek
  „Size of collider” 0,4 (0,5 + 0,3). Kolejność kolejki fizyki: obywatel, gwardia [P].
- Wielkość odepchnięcia w grze (|vx| + |vy|): 0,030, 0,038, 0,045, 0,051 w kolejnych taktach. Liniowa w S² − d² ze
  współczynnikiem ≈ 1,45. Model Core: własne −2p (·0,6) i p od gwardii (·5/3) w jednym takcie. Ani samo „własne”,
  ani „własne + gwardia z poprzedniego taktu” nie odtwarza wartości gry [N].
- 0x5498C4 (pętla kontaktów) wybiera wariant małej kolizji (vt+0x3C) przy +0x244 < 1,0 – dotyczy obu jednostek [W].
- Odczyt push gwardii w grze stale (0,001; 0,001) – wartość budzika z kontaktu obywatela, zapisywana po kroku
  gwardii [H].
- Wniosek: różnica dotyczy chwili wykrycia kontaktu i składania wektora push przy obracającej się gwardii (ω ≠ 0).
  Wymaga śledzenia vt+0x3C/0x549A08 w debugerze. Pozycji nie poprawiano ręcznie.

## 14. Wyniki badań progu leczenia (G2)

- 0x5EDC82 (kwalifikacja celu leczenia): HP > 0 **i** HP < HPmax **i** +0x340; dopiero potem 0x630E07/18001 porównuje
  HP/HPmax z progiem +0x49C instrukcją „≤” (fcompp, jb) [W].
- Przy progu 1,0 jednostka z pełnym HP nie kwalifikuje się przez warunek HP < HPmax. Tłumaczy to pomiar 644 bez
  zmiany kierunku porównania. Rozbieżność etapu 46 wynikała z pominięcia tego warunku, nie z kierunku porównania ani
  kolejności aktualizacji HP.
- Core: `potrzebuje_leczenia` = HP > 0 ∧ HP < HPmax ∧ ¬(próg < HP/HPmax) ∧ ten sam gracz. 619/620 i testy GDExtension
  leczenia bez zmian.

## 15. Wyniki badań opóźnień rozkazów MCP (G4)

- Krok `obs_rozkaz` w 647/648 trwa 20,4–29,0 s (wybór jednostki, przesunięcie kamery, kontrola rzutu, PPM) [P: wyniki
  zadań]. Rozkaz trafia do gry na końcu kroku.
- Czas gry płynie 1,46 raza szybciej niż rzeczywisty (etap 15). 647 `dom1_przerwany`: rejestrator od t = 4772,
  10 s czekania i krok 20,4 s → rozkaz w t = 49124 (2015). To odpowiada czasowi samego kroku [P].
- Wcześniejsze „opóźnienia” (644 pościg 24,7 s, 578 – 84 s) są zgodne z tym mechanizmem co do rzędu wielkości
  [H dla 578: tamtego kroku nie da się już zmierzyć].
- Nowa diagnostyka: `obs_rozkaz` zwraca `czasy_gry` (start, przed PPM, po PPM, trwanie). Eksperyment, w którym rozkaz
  wymaga ustalonej chwili, porównuje czas utworzenia celu z `przed_klikiem`. Kolejki zdarzeń Wine nie
  badano; krok `laboratorium` przed i po starcie każdego scenariusza przechodził bez błędu.
- Mechaniki Core nie zmieniano.

## 16. Wyniki badań RNG (H)

- e47_rng_bez_p5 (647): mapa bez zwierząt i bez jednostek gracza 5. Dodatkowe losowania występują w tych samych czasach
  gry co w 646 (10261, 12068, 19227, 19568, 26386, 38454) [P]. Są więc harmonogramowane czasem, a nie wywoływane przez
  jednostki.
- Przypisanie do AI gracza komputera (klasy EECP*, wywołania 0xB2FBC8 z zakresu 0x44–0x4A) [W/H]. Wariant bez
  aktywnego AI komputera nie był wykonany [N].
- Zwierzęta Świata mają w dbobjects skrypt „Land” (nie „Land Animal”) [P: dbobjects]. Mechanizm ich losowań – [N].
- Core nie symuluje AI graczy. Diagnostyka `rng_n` w odtworzeniach rozróżnia losowania Core w takcie.

## 17. Pełna regresja

Testy syntetyczne:

| Zestaw | Etap 46 | Etap 47 |
|---|---|---|
| CTest Release | 20/20 | **21/21** (+ `budynki`) |
| CTest Debug | 20/20 | **21/21** |
| GDExtension | 60/60 | **63/63** (+3 testy etapu 47: budynek, śmierć i przebudowa grafu) |
| Godot | 325/325 | 325/325 |
| Riverlands_MCP | 17/17 modułów, 104 testy | **18/18 modułów, 108 testów** (+ `test_ee_mapa_zmiany`) |
| Narzędzia Titan | 20/20 | OK |
| S1–S7 | `68b0c69ecb8b0cbc` | `68b0c69ecb8b0cbc` |
| skrót mapy | `c8297c16f0d48b1a` | `c8297c16f0d48b1a` |
| skrót scenariuszy | `22b0f0cf4a1ec660` | `22b0f0cf4a1ec660` |

Uruchomienie wszystkich modułów Riverlands_MCP w jednym procesie daje błędy wzajemnego wpływu modułów. Występowały
już przed tym etapem, także bez nowego modułu. Każdy moduł osobno przechodzi.

Porównania z grą (co próbkę):

| Przebieg | Wynik |
|---|---|
| EE 578 G1 | 986/986 |
| e45 578 G3 / 590 G1 | bez rozbieżności w oknie (CTest) |
| 619 | wszystkie 7 jednostek zgodne; 0x1000858 do 124254 jak w etapie 46 |
| 620 | wszystkie jednostki zgodne; 0x1000858 do 109423 jak w etapie 46 |
| 631 / 633 / 634 / 638k | bez rozbieżności (633: 2 próbki spóźnione) |
| 638c obywatel | 4264/4264 (RNG z nagrania co takt) |
| 644 sojusz blisko / daleko | 4426/4426 (1 spóźniona) / 4412/4412 |
| 644 pościg | do t = 63817 (jak etap 46) |
| 646 bez zwierząt | 4643/4643 (stan startowy RNG z nagrania) |
| 647 dom1 / 648 przejscie2 | obrażenia i śmierć zgodne co do wartości; faza o 1 trafienie [N]; prorok 648 – 1241 próbek do rozkazu |
| 645/647 śmierć domu | zapadanie co próbkę 682/682 i 674/676 |

Wzorców i tolerancji nie zmieniano.

## 18. Wydajność grafu

`godot/testy/eksperymenty/wydajnosc_grafu.gd` (Core, Release GDExtension, 10 obiektów mapy usuwanych kolejno,
pomiar całego taktu z przebudową, bez jednostek):

| Mapa | Budowa początkowa | Przyrostowa (na zmianę) | Pełna (na zmianę) | Zapytanie grafu przed / po |
|---|---|---|---|---|
| e35_a (1857 podsektorów) | 22 ms | 5,7 ms | 13,0 ms | 0,10 / 0,10 ms (9 podsektorów) |
| e13_para (1320) | 14 ms | 3,6 ms | 8,1 ms | – (punkty testowe poza grafem) |

Po 10 zmianach podział pól na podsektory (pola, punkty, rodzaj) jest identyczny w obu trybach. Różni się tylko
numeracja id, bo tryb przyrostowy używa listy wolnych id jak gra.

## 19. Pierwsze pozostałe rozbieżności

| Przebieg | Pierwsza różnica |
|---|---|
| 644 pościg | t = 63817 – odepchnięcie obywatela takt wcześniej w Core (§ 13) |
| 644 bohater | od startu – pierwsze CanISeeEnemy po wczytaniu (G3 nie badane) [N] |
| 646 RNG | t = 10260 – losowanie spoza jednostek (AI komputera [H]) |
| 647 dom1 / 648 dom | faza ataku z nagrania (start w środku cyklu) |
| 648 prorok | t = 48170 – trasa po rozkazie; Prophet.tai [N] |
| 619/620 0x1000858 | 124254 / 109423 (EEUGLocation przed celem ataku) |
| e31 590 G1 / 578 G3 | 98 / 190 (kurs) |

## 20. Otwarte problemy

1. Składanie push przy ω ≠ 0 (§ 13) – śledzenie vt+0x3C i 0x549A08 w debugerze.
2. G3: opóźnienie pierwszego CanISeeEnemy po wczytaniu (644 bohater) – niezbadane w tym etapie.
3. Prophet.tai i trasa A* proroka po rozkazie (648).
4. Losowania AI gracza komputera i zwierząt Świata – mechanizm [N].
5. Budynek 2×2 w grze (Core – test syntetyczny), gruz po zniszczeniu, budynek zniszczony w czasie podejścia
   jednostki, ponowne zablokowanie przejścia.
6. Faza ataku przy odtwarzaniu nagrań zaczętych w trakcie walki.
7. Wzajemny wpływ modułów testów Riverlands_MCP w jednym procesie.

## 21. Propozycja etapu 48

1. Debuger: kontakt obywatela z obracającą się gwardią (vt+0x3C, 0x549A08) – rozstrzygnięcie G1.
2. Prophet.tai i trasa po rozkazie (648), potem pełny przebieg E zgodny co takt.
3. Nagranie startu scenariusza z bohaterem (G3), dwa układy jednostek.
4. Budynki: 2×2, gruz, ponowne zablokowanie, cel zniszczony w czasie podejścia – pomiary MCP z nowymi narzędziami.
5. AI komputera: lokalizacja harmonogramu losowań (EECP*), wariant bez AI.
