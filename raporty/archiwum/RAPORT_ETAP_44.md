# Raport etapu 44 – graf nawigacji z samego SCN, śmierć jednostek z danych typu i kolejność taktu

Najważniejsze wyniki etapu:
- **Klasyfikacja pól z SCN zgadza się w całości** na dwóch różnych mapach: e35_a 39 480/39 480, e13_para 22 725/22 725.
  Mechanizm klifów odczytany z kodu to 0x51241D i 0x512FB0.
- **Graf podsektorów powstaje w Core wyłącznie z pliku SCN i baz gry**, bez żadnych danych z pamięci EE:
  - e35_a: 43/1135/1857 (obszary, regiony, podsektory), przydział pól, punkty i sąsiedzi 1857/1857;
  - e13_para: 1320/1320 podsektorów identycznych;
  - 619/620 są identyczne z grą.

  Zastrzeżenie: obszary +0xF4 pochodzą z modelu potwierdzonego pomiarem na trzech mapach, a nie z odtworzonego kodu.
- **Śmierć 6000–6003 wynika z danych typu**:
  - czas klatki sekwencji dbgraphics i „Rotting time” z dbobjects;
  - gwardia 72/1/1177 i obywatel 47/1/1177 taktów, zgodnie z pomiarami;
  - 631, 633 i 634 są zgodne co próbkę dla wszystkich jednostek, łącznie z rozkładem i stanem 6003.
- **Nowe nagranie kontaktu** (układ 590 G1 na czystej mapie):
  - zgodne co takt (2465/2465), gdy lista jednostek ma kolejność kolejki fizyki 0x918DDC (x, potem y rosnąco – odczyt w grze);
  - pierwsza rozbieżność wynikała z kolejności aktualizacji, nie z odpychania.
- Nadal [N]:
  - oryginalne 590 G1 (takt 95, ω) – brak odczytu kolejki fizyki dla tamtej mapy;
  - zachowanie obywatela po trafieniu – inny skrypt;
  - kod budowy obszarów.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.

## 1. HEAD początkowy i końcowy

- Początek: `4a2b90d` (lokalny etap 43; publiczny `main` bez zmian – `c776a61`).
- Koniec: jeden lokalny commit etapu 44. Bez push, pull, fetch, reset, rebase i clean.
- Poza commitem zostają pliki użytkownika: `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11`.
- Riverlands_MCP (lokalnie): odczyt kolejki fizyki w rejestratorze (`lista_fizyki`).

## 2. Ślad klasyfikacji klifów

Debuggera dla procesu gry nie ma: `ptrace` jest niedostępny, a MCP czyta tylko `/proc/pid/mem`. Ślad wykonano więc
statycznie na całej ścieżce ładowania mapy, a regułę potwierdzono porównaniem z pamięcią gry na dwóch mapach [W + P].

| Krok | Funkcja | Reguła |
|---|---|---|
| 1 | 0x51241D | każde pole: SetKind(rodzina tekstury); tekstura rodziny 9 → teren domyślny mapy (+0x181734, przez 0x513941) i SetKind(jego rodzina) |
| 2 | 0x512FB0, przebieg 1 | najwyższy narożnik ≥ H (map+0x1816D8 = 0,408248) i rozpiętość narożników ≥ 1,5·H − 0,0001 → SetKind(9); tekstury klifu malowane na pola (x−1..x, y−1..y) |
| 3 | 0x512FB0, przebieg 2 | rodzaj ≠ 9 i ≥ 3 z pól {(x, y), (x−1, y), (x, y−1), (x−1, y−1)} z teksturą klifu zestawu mapy (dbcliffterrain) lub nieistniejących → SetKind(9) |

Odpowiedzi na pytania A1:
1. Końcowy rodzaj zapisuje Tile::SetKind 0x516E8C, wywołany z 0x512FB0.
2. Jedno pole może być zapisane 3 razy.
3. Kolejność przetwarzania: x zewnętrznie, y wewnętrznie. Wynik od niej nie zależy.
4. Przesunięcie (1, 1) bierze się z malowania tekstur klifu na pola (x−1, y−1)…(x, y) wokół pola klifu – przykład z etapu 43:
   pole (206, 193) i tekstura na (205, 192).
5. Używane dane: rodzina, teren domyślny, wysokości narożników, tekstury sąsiadów.
6. Aktualizacja wierzchołka (UpdateTiles 0x51183B) klasyfikuje cztery sąsiednie pola. To ścieżka edytora; przy ładowaniu
   działa pętla.
7. Regiony czytają końcowe +0x04.

Teren domyślny: ogon kawałka 4 ma 0 (brak terenu o ID 0), więc obowiązuje [0x8D1FD0], czyli ID pierwszego ważnego rekordu
dbterrain (0x4D5662) – rodzina 0 [W; P: 86 pól tekstury klifu z rodzajem 0 na e35_a].

## 3. Porównanie wszystkich pól

| Mapa | Rodzaj +0x04 | Znak +0x14 wody | Wartość +0x14 wody |
|---|---|---|---|
| e35_a | **39 480/39 480** | 19 605/19 610 | 19 012 |
| czysta mapa e42 (ten sam teren) | 39 480/39 480 | 19 605/19 610 | 19 012 |
| e13_para (150 × 75, inna mapa) | **22 725/22 725** | 7421/7434 | 5975 |

Wysokości, tekstury i rodziny pól są zgodne z SCN od etapu 43. Obszary, regiony i podsektory omawia § 6.
Znak +0x14 poprawił się (19 595 → 19 605), bo zbiory S1/S2 zależą od rodzajów pól. Wartość +0x14 lądu nie jest potrzebna
regionom; pozostaje [N].

## 4. Listy obiektów pól

Rejestracja [P: e35_a 5335/5335 obiektów SCN na właściwych polach]:
- obiekt zajmuje pola X..X+n−1 × Y..Y+n−1 (n = dbobjects „Square occupied”);
- reguła jest wspólna dla jednostek, budynków jedno- i wielopolowych, domów, murów, bram, wież, zasobów i drzew;
- obiekt trafia na **początek** listy +0x08, w kolejności rekordów kawałka 5;
- rekordy z valid = 0 nie trafiają na pola. Gra tworzy w ich miejsce 41 obiektów z flagami 0, bez wpływu na regiony.

Flagi typów są zgodne co do wpisu: e35_a 5456/5456, e13_para 2281/2281.

| Mapa | Pola z identyczną listą | Uwagi |
|---|---|---|
| e35_a | 5402/5412 | 10 pól różni się, bo jednostki przeszły na inne pole przed odczytem |
| e13_para | 2226/2266 | 40 pól z przesuniętymi jednostkami gracza 2 |
| czysta mapa | 4122/4122 | |

Rozdział zachowany: obiekty statyczne budują graf raz, przy wczytaniu. Jednostki ruchome nie przebudowują grafu.

## 5. Flaga +0x612

**Ustalona** [W: 0x621EB4 → 0x4A7618(typ, 9) → 0x52BFA4; P: 70/70 typów]:
- +0x612 oznacza przynależność typu do zestawu dbunitset 9 „Walls 1”, z dołączonymi zestawami 10 → 71 → 68;
- zestaw zawiera mury, bramy i wieże;
- wieża brązowa 462 nie ma flagi, bo zestaw 68 wymienia dwa razy 461 (błąd danych gry odtworzony wiernie).

Pozostałe flagi typu:
- +0x568 = „Resource type”;
- +0x600 = „Is building?” – także dla testu pola A*. Potyczka zamiast reguły z etapu 30 używa teraz tej kolumny; obiekty
  kamery już nie blokują;
- +0x4B4 = „Unit type”.

W 0x52BFA4 rodziny zestawu są sprawdzane tylko przy fladze zestawu +0x38 [N]. Zestawy 9/10/71/68 nie mają rodzin.

## 6. Autonomiczny graf z SCN

Przepływ: SCN → teren, klasyfikacja i obiekty pól → obszary → regiony → podsektory → A* grafu → punkty pośrednie → A* po
polach → fizyka. Wszystkie kroki działają w Core. Do Core nie trafiają żadne dane z pamięci gry.

| Element | e35_a (gra) | e35_a Core | e13_para (gra) | e13_para Core |
|---|---|---|---|---|
| pola | 39 480 | 39 480 zgodne | 22 725 | 22 725 zgodne |
| obszary | 43 | 43, przydział 39 480/39 480 | 42 | 42, przydział 22 725/22 725 |
| regiony | 1135 | 1135, etykiety 39 480/39 480 | – | 658 |
| podsektory | 1857 | 1857 identycznych | 1320 | 1320 identycznych |
| sąsiedzi (kolejność) | 1857 | 1857/1857 | 1320 | 1320/1320 |
| punkty reprezentatywne | 1857 | 1857/1857 | 1320 | 1320/1320 |

Dwie poprawki z tego etapu:
- **Bok sektora** zależy od mapy: 0x42439A [W] z map+0x1816F4 daje e35_a 19 i e13_para 12, zgodnie z managerem +0xE0.
- **Obszary**: na e13_para model z etapu 42 dawał 43 zamiast 42. Klify (klasa 3) łączą się po przekątnej jak brzeg rombu –
  po tej zmianie wszystkie trzy mapy są zgodne. Kod budowy obszarów pozostaje [N].

**Wniosek: graf nie wymaga danych z uruchomionego EE.** Jedynym nieodtworzonym z kodu elementem jest reguła obszarów
(model z pomiaru).

## 7. Porównanie 619 i 620

Graf zbudowany w Core wyłącznie z SCN i baz gry: wyniki 619 (7300 taktów) i 620 (6450 taktów) są **identyczne** z etapem 43
we wszystkich polach – stanach, pozycjach, kursach, kolejkach z punktami pośrednimi, celach, czasach przejść, HP i zdarzeniach.

Względem gry (`porownaj_pelny.py`):

| Nagranie | Gwardia A | Pozostałe jednostki |
|---|---|---|
| 619 | 7270/7273 (3 próbki spóźnione) | bez różnic; bohater do stanu 5001 – skrypt leczenia poza Core, jak wcześniej |
| 620 | 6418/6419 (1 odczyt pośredni) | bez różnic |

Odtworzone argumenty narzędzia (619/620) zapisano lokalnie w `Testy_MCP/e44/odtworz_619_620.sh`.

## 8. Integracja grafu z potyczką Godot

**Graf włączony.** Scena buduje go przy wczytaniu scenariusza (`ObiektyScnCore.wejscie` → `zbuduj_graf_z_wejscia`) i przy
każdym restarcie: 43/1135/1857. Godot nie ma własnej nawigacji. Graf jest używany przez Core w rozkazach ataku (punkty
pośrednie). Rozkazy ruchu idą przez A* po polach, jak w grze (etap 40).

| Test | Wynik |
|---|---|
| 5 na 5 z restartem | wygrane w taktach 1219 i 1218; demo zależy od czasu rzeczywistego, więc takt nie jest regresją |
| 2 na 1 | wygrana w takcie 631, obie gwardie żywe |
| 5 na 1 z restartem | wygrane w taktach 472 i 470 |
| 1 na 5 | przegrana w takcie 757 |
| obejście przeszkód (narzędzie `odtworz_e35`) | ruch z (164,5; 118,5) za mur na (175,5; 120,5) i daleki cel (120,5; 150,5): dojście, stan Idle, bez zakleszczeń |

W żadnym przebiegu nie wystąpiły błędy skryptów ani zakleszczenia. Potyczka bierze też parametry śmierci z baz gry
i porządkuje listę jednostek jak kolejka fizyki EE.

## 9. Stany 6000–6003

Mechanizm ustalony z kodu – szczegóły w `walka.md` § 32.

| Stan | Zdarzenie | Warunek | Licznik |
|---|---|---|---|
| 6000 | DyingAnimationFinished (0x61B677, przypadek 0x1770) | +0x337 = koniec sekwencji | animacja 0x62462B: ms taktu sumowane; przy ≥ czasie klatki (typ +0x318[anim] = **„wartość” dbgraphics w ms na klatkę**) następna klatka, reszta zostaje |
| 6001 | ResourcesRottedAway | zasoby +0x40 = 0 | +0x2A8 rośnie; co 4000 ms −1 zasób |
| 6002 | UnitRottedAway | +0x2A8 = 0 | +0x2A8 = typ+0x548 (dbobjects „Rotting time”·1000), −34 ms na takt |
| 6003 | Dead | – | usunięcie z mapy [N] |

Czas 6000 zależy od animacji CEM i dbgraphics, a nie od stałej globalnej [P]:

| Typ | Sekwencja | 6000 | 6001 | 6002 |
|---|---|---|---|---|
| gwardia | 24 klatki × 102 ms | 72 takty | 1 takt | 1177 taktów |
| obywatel | 17 klatek × 94 ms | 47 taktów | 1 takt | 1177 taktów |

Przy okazji rozstrzygnięta została hipoteza tempa animacji z etapu 4: „wartość” to czas klatki w ms, a nie czas cyklu.
Bohatera nie zmierzono, bo nie było powtarzalnej śmierci [N]. Core nie ma stałej 2455 ms.

## 10. Nagrania 631, 633 i 634

| Nagranie | Jednostki (stan, HP, pozycja, kurs) | Etap 43 |
|---|---|---|
| 631 | 2808/2808 dla wszystkich | cel 2186 |
| 633 | 3697 (A_GRD1 – 2 próbki spóźnione), reszta 3697/3697 | cel 2084 |
| 634 | 6413/6413 dla wszystkich (z 6003 w t = 114992) | cel 2081 |

Pierwsze różnice 6000/6001 usunięte – kryterium etapu spełnione dla gwardii. Dla obywatela czas sprawdzono pomiarem 638
i testem syntetycznym; pełnej walki z obywatelem nie odtworzono (§ 14).

## 11. Kolizja 590 G1

1. **Nowe nagranie** 638 (`e44_kontakt_590`): dwie gwardie idą na siebie w walce, z rejestrem push i kontaktów, 2465 próbek.
   Zad. 639 powtórzyło układ z odczytem kolejki fizyki.
2. **Porównanie** (`kontakt.py`): do t = 47965 wszystko zgodne. Potem gwardia AI wylicza inny punkt podejścia,
   z czego wynika różnica kursu i stanów.
3. **Pierwszy rozbieżny etap obliczeń**: punkt przechwycenia 0x62C963 w PrepareToMove gwardii AI (t = 46363):
   - gra (164,563; 106,21433), Core (164,5621; 106,2186);
   - wzór z pozycją celu z **poprzedniego** taktu daje dokładnie punkt gry;
   - push = 0 i kontakty bez znaczenia w tym momencie.
4. **Wniosek: kolejność aktualizacji** (nie kolizja i nie integracja):
   - odczyt kolejki fizyki 0x918DDC pokazał kolejność pozycji (x, potem y rosnąco), stałą w czasie;
   - Core odtwarza ją (`uporzadkuj_wg_pozycji`) – 638 jest wtedy zgodne co takt, łącznie z kontaktem i walką;
   - 631/633/634 też są zgodne;
   - odrzucone warianty: dwufazowy (maszyny, potem fizyka) i kolejność wg bieżącego pola [P].

Dodatkowo nagranie z obywatelem ujawniło stały promień kolizji 0,5 w GDExtension. Poprawka: promień = rozmiar typu
(„Size of collider”) – obywatel nie jest odpychany, jak w grze.

**Oryginalne 590 G1 (CTest) bez zmian**: pozycja maks. 0,0094, pierwsza różnica ω w takcie 95. Kolejność z reguły
pozycji (e31_a) jest już taka jak w teście [N]. Brakujący pomiar: powtórzenie 590 na e31_a z nowym rejestratorem
(`lista_fizyki` i punkt trasy co takt). Rejestrator jest gotowy i bezpieczny (tylko odczyt).

## 12. Zmiany w Core, GDExtension i MCP

Core (0.18.0):
- `rodzaj_pol_titan`: teren domyślny i dwa przebiegi klifów;
- `komorka_sektora`;
- `zbuduj_obszary`: klify 8-spójne;
- `dodaj_obiekty_scn`, `zestaw_zawiera`, `ObiektScnPola`, `ZestawJednostek`;
- śmierć: liczniki 0x62462B i 0x5FB218, zdarzenia trzech stanów;
- `Swiat::uporzadkuj_wg_pozycji`.

GDExtension:
- `wejscie_regionow_z_scn` (+`komorka` w `wejscie_regionow_z_mapy`), `uporzadkuj_wg_pozycji`;
- parametry `smierc_klatki`, `smierc_ms_klatki`, `rozklad_ms`, `zasoby`;
- promień kolizji z rozmiaru typu;
- testy: 52.

Godot:
- `ObiektyScnCore` (obiekty, zestawy, parametry śmierci);
- potyczka: graf przy wczytaniu, +0x600 z „Is building?”, śmierć, kolejność;
- narzędzia: `porownaj_klasyfikacje.gd`, `porownaj_graf.gd --obiekty-scn`, `odtworz_e35.gd --graf-autonomiczny`;
- `odtworz_scenariusz.gd`: kolejność pozycji, śmierć, z.

Dane: warianty `e44_cit_1v1` i `e44_kontakt_590` w `e42_warianty.json`.

Riverlands_MCP (lokalnie): `lista_fizyki` w rejestratorze.

## 13. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | **52/52** (+3: śmierć gwardii i obywatela, obiekty SCN na polach z +0x612, graf e35_a z samego SCN) |
| Godot | 325/325 |
| Riverlands_MCP | 16/16 modułów (98 testów) |
| Narzędzia Titan | 20/20 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| skrót scenariuszy | `22b0f0cf4a1ec660` |
| EE 578 G1 | 986/986 |
| skrót mapy | `c8297c16f0d48b1a` |
| punkty / sąsiedzi | 1857/1857 i 1857/1857 (z samego SCN) |
| klasyfikacja | 39 480/39 480 |
| 619/620 | identyczne (graf z SCN) |
| 631/633/634 | zgodne do końca nagrań |

578 G3 (5 różnic stanu) i 590 G1 – bez zmian. Testy syntetyczne i porównania z grą są osobne. Dwie wartości wzorcowe
testu GDExtension zmieniono z uzasadnieniem w kodzie gry (0x512FB0):
- klasyfikacja e35_a: 39 341 → 39 480;
- syntetyczne pole brzegowe → klif.

## 14. Pierwsze pozostałe rozbieżne takty

| Przebieg | Pierwsza różnica |
|---|---|
| 631 / 634 / 638 (kontakt) | brak |
| 633 | brak (2 próbki spóźnione rejestratora) |
| 638 (obywatel) | t = 62215: obywatel po trafieniu przechodzi 5000 → 8000 (inny skrypt .tai – Core ma tylko skrypt gwardii) [N] |
| 619 / 620 | jak w grze (bohater 5001/16000 – skrypt leczenia poza Core) |
| 578 G3 | takt 169 (ω) |
| 590 G1 | takt 95 (ω) |

## 15. Nierozwiązane problemy

- Kod budowy obszarów +0xF4 (model z pomiaru, zgodny na 3 mapach).
- Rodziny w zestawach jednostek (flaga +0x38).
- Śmierć bohatera i stan 6003 (usunięcie z mapy).
- Skrypt obywatela.
- Kolejność obiektów dodanych w trakcie gry (kolejka fizyki po wczytaniu jest ustalona).
- 590 G1 i 578 G3 (powtórzenie z rejestratorem kolejki).
- Odtwarzacz animacji Godot wciąż używa hipotezy tempa z etapu 4.
- +0x14 lądu, vt+0x58 (+0x345), aktualizacja grafu po zmianie obiektów.

## 16. Prognoza i propozycja etapu 45

Nawigacja Titan w zakresie mapy statycznej jest w Core kompletna i niezależna od pamięci gry. Następny etap może dotyczyć
dynamiki i zachowań.

1. Powtórzyć 590 G1 i 578 G3 z rejestratorem `lista_fizyki` i punktami trasy. Ustalić kolejność obiektów dodawanych
   w trakcie gry, potem usunąć ostatnie różnice ω.
2. Skrypty .tai innych typów: obywatel (reakcja na trafienie, ucieczka) i bohater (leczenie 16000) – na czystej mapie,
   nagraniami jak 638.
3. Odtwarzacz animacji Godot: tempo „wartość” = ms na klatkę. Kod obszarów +0xF4 (0x427D42) i aktualizacja grafu
   po zniszczeniu budynku.
