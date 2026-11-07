# Grupy ruchu po rozkazie `EEMPathTo` – Empire Earth / The Art of Conquest

Etap 17 OpenEE, czwarty wpis atlasu funkcji silnika Titan (`docs/titan/README.md`). Kontynuacja
`rozkazy_gracza.md`: co robi `EEMPathTo::Execute` z zaznaczonymi jednostkami, zanim zaczną się szyk, wyszukiwanie tras
i ruch.

**Oznaczenia:**
- **[P]** potwierdzone kodem w obu grach i pomiarem albo kodem jednoznacznym w obu plikach;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pliki jak w `rozkazy_gracza.md`. Metoda:
- analiza statyczna (pefile + capstone, RTTI);
- porównanie EE ↔ AoC instrukcja po instrukcji po normalizacji adresów;
- tabela `dbobjects` z danych gry, odczytana dekoderem OpenEE (`narzedzia/eeformaty`), tylko do odczytu;
- minimalne pomiary pamięci, tylko odczyt.

## Wynik w skrócie

1. **Podział na grupy według środowiska ruchu.** `EEMPathTo::Execute` wykonuje przebiegi k = 1…4 (EE) albo 1…5 (AoC).
   W każdym tworzy nową grupę `EEActiveGroup` i wypełnia ją jednostkami z zaznaczenia, które spełniają warunek
   przebiegu:

   | k | Grupa |
   |---|---|
   | 1 | jednostki powietrzne |
   | 2 | lądowe (i budynki) |
   | 3 | nawodne |
   | 4 | podwodne |
   | 5 | kosmiczne – **tylko AoC** |

   Dlatego AoC ma o jeden przebieg więcej [P: kod; pomiar – obywatel i galera w osobnych grupach, w EE i AoC].
2. **Warunek przypisania** wynika z bajtu flag obiektu typu jednostki (EE +0x5D4, AoC +0x2D0). Bajt jest liczony przy
   wczytaniu typu z pola `Unit type` w `dbobjects` (EE +0x4B4, AoC +0x1B8):
   - bit 1 – ląd;
   - bit 0 – powietrze;
   - bit 2 – woda;
   - bit 3 – kosmos, tylko AoC.

   Woda dzieli się dalej na „okręty podwodne” (`Unit type` 10) i „pozostałe” [P].
3. **Grupa** dostaje:
   - wspólny **cel `EEUGLocation`** (0x38 B) z punktem, kątem i flagami rozkazu;
   - flagę **Shift** (`EEMPathTo`+0x1E → grupa +0xB5) [P: pomiar];
   - **kod stanu 8000** w polu +0x6C.

   Funkcja stanów grupy (0x5DD463) od razu przetwarza kod 8000 w 0x5DB641. Tam cel grupy zamienia się na cele
   poszczególnych jednostek: szyk, kolejki celów, Shift. To jest granica etapu [P: kod].
4. **Wartość 8000 nie jest czasem ani limitem.** To kod polecenia grupy w maszynie stanów: 5000 = stan początkowy,
   8000 = „przydziel cel ruchu do lokacji”. Używają go też inne polecenia [P: kod; nazwa kodu – W].
5. **Zastępowanie i Shift.**
   - Execute zawsze tworzy nowe grupy i przenosi jednostki z poprzednich, także przy Shift [P: pomiar – nowe adresy grup].
   - Shift trafia do grupy jako +0xB5 = 1. O dopisaniu celu do kolejki jednostki (+0x90) albo jej wyczyszczeniu decyduje
     dopiero 0x5DB641, porównując +0xB5 i bieżący cel jednostki (+0x1F0) [W: kod, gałęzie poza zakresem].
   - [Etap 16 – zastąpione] Pole `EEMPathTo`+0x1C nie jest flagą Shift: przy Shift+PPM pozostało 1.
6. **EE ↔ AoC:** wszystkie opisane funkcje są zgodne po normalizacji, poza przesunięciami pól typu i gracza. AoC ma
   piąty przebieg (kosmos), bit 3 flag, dodatkowy wyjątek ID 0x2ED i dodatkowe pole grupy +0xB7 [P].

## Funkcje

| Funkcja | EE | AoC | Zgodność |
|---|---|---|---|
| `EEMPathTo::Execute` | 0x4B9D7B | 0x4C281C | zgodne; liczba przebiegów: warunek `< 5` / `< 6` |
| konstruktor `EEActiveGroup` (vtable EE 0x83141C) | 0x5DB37C | 0x5EBC86 | zgodne; AoC zeruje dodatkowo +0xB7 |
| wypełnienie grupy z zaznaczenia (przebieg k) | 0x5DD18B | 0x5ED9D4 | identyczne (82 instr.) |
| warunek przebiegu k (jednostka, k) | 0x5DD2D8 | 0x5EDB21 | zgodne; AoC: dodatkowy przypadek k = 5 (bit 3) |
| usunięcie z grupy jednostek nieruchomych i nieaktywnych | 0x5DEE09 | 0x5EF56D | zgodne poza przesunięciami (+0x335/+0x341, +0x4B8/+0x1BC) |
| konstruktor celu `EEUGLocation` (vtable EE 0x831E64) | 0x614D47 | 0x627742 | identyczne |
| konstruktor bazy celu (rodzaj, czas gry, numer) | 0x6283AB | 0x63C375 | identyczne |
| wyczyszczenie list jednostek grupy (dla każdej jednostki) | 0x5DD27C → 0x5E95D2 | 0x5EDAC5 | identyczne |
| usunięcie bieżącego celu grupy (+0x68) | 0x4C00C2 | 0x4BB02A | – |
| ustawienie celu grupy (+0x68, +0xB5, +0xB6) | 0x5DD436 | 0x5EDC93 | identyczne |
| maszyna stanów grupy (kod +0x6C) | 0x5DD463 | 0x5EDCC0 | te same kody stanów |
| obsługa kodu 8000: cele jednostek, szyk, Shift (granica) | 0x5DB641 | (z 0x5EDCC0, kod 8000) | – |
| rejestracja grupy u gracza | 0x4C210E (gracz +0x844) | 0x4C8F99 (gracz +0x854) | – |
| flagi środowiska w typie jednostki (przy wczytaniu typu) | 0x61CCEC…0x61CD8B (w 0x61C35B) | 0x62FD1C…0x62FDE5 | zgodne; AoC dodaje bit 3 i ID 0x2ED |
| fabryka klas typu według `Unit type` | 0x621974 (tablica skoków 0x621F9F) | – | – |
| losowanie jednostki potwierdzającej rozkaz (RNG `EEPhysics`) | 0x5531C2 | 0x5612D3 | – |

## Struktury

### Typ jednostki (obiekt klasy `EEUC*`, wskaźnik w jednostce +0x2C)

| Pole EE / AoC | Znaczenie | Pewność |
|---|---|---|
| +0x4B4 / +0x1B8 | `Unit type` z `dbobjects` (ID pola 36 w schemacie) | [P] – kod (+0x120 rekordu) i pomiar: obywatel 6, galera 4, gwardia 5, prorok 13, transportowiec 18 |
| +0x4B8 / +0x1BC | ID obiektu w `dbobjects` | [P] |
| +0x5D4 / +0x2D0 | flagi środowiska ruchu (tabela niżej) | [P] – kod i pomiar: obywatel, gwardia, prorok = 2; galera, transportowiec = 4 (EE i AoC) |
| vtable +0x54 | „budynek”: 1 dla `EEUCBuilding`, `EEUCGate`, `EEUCFortress`, `EEUCMiningBuilding`, 0 dla pozostałych klas (w tym `EEUCNavalBuilding`) | [P] – kod |

**Flagi środowiska** (EE 0x61CCEC, AoC 0x62FD1C). Najpierw bajt jest zerowany, potem ustawiane są bity:

| Bit | Warunek (`Unit type`) | Przykłady z `dbobjects` |
|---|---|---|
| 0x02 – ląd | 5, 6, 13, 16, 23; oraz `Unit type` 2 (budynek) o ID 0x43 („x Missile Base”), w AoC także 0x2ED („cp Missile Base”) | piechota, kawaleria, łucznicy (5), obywatele (6), kapłani i bohaterowie-uzdrowiciele (13), wieże oblężnicze i pojazdy (16), bohaterowie-strategowie (23) |
| 0x01 – powietrze | 3, 7, 17, 26, 28 | samoloty (3), śmigłowce i balon (7), śmigłowce transportowe (17), „Mech Apollo” (26), orzeł (28) |
| 0x04 – woda | 4, 8, 10, 14, 18, 21, 22, 27 | okręty (4), okręty podwodne (10), transportowce (18), lotniskowce (21), łodzie rybackie (22), rekin i delfin (27) |
| 0x08 – kosmos (AoC) | 31, 32, 33, 34 | statki kosmiczne „Sp15 …” |

Zbiory `Unit type` są rozłączne, więc jednostka ma najwyżej jeden bit środowiska [P].

Nazwy kategorii pochodzą z nazw obiektów w `dbobjects` [W]. Liczby i warunki są odczytane z kodu [P]. Typów 8 i 14 nie
ma w danych EE/AoC [N].

Obok tego bajtu kod ustawia pole +0x61E (EE) = 1 dla obiektów 0x2F i 0x1CD–0x1D2 (wieże strażnicze). Warunek „ląd dla ID
0x43” sprawdza +0x61E = 0, co dla ID 0x43 zawsze zachodzi. Warunek jest nadmiarowy i nie wpływa na zachowanie [P: kod].

### `EEActiveGroup` (grupa ruchu)

| Pole | Znaczenie | Pewność |
|---|---|---|
| +0x04 | licznik referencji | [P] |
| +0x34 | właściciel (gracz) – źródło domyślnych parametrów szyku | [W] |
| +0x48, +0x58 | listy wewnętrzne, czyszczone przy wypełnianiu | [N] znaczenie |
| +0x68 | bieżący cel (`EEUGLocation`) | [P] |
| +0x6C | **kod stanu / polecenia**: 5000 po utworzeniu i przy wypełnianiu, 8000 po `EEMPathTo` | [P] |
| +0x70…+0xAC | parametry szyku grupy, f32, w pomiarze 0,5 / 0,5 / 0,5 / 1,2 …; używane tylko przy +0xB6 = 1, inaczej pobierane z gracza (+0x34 → +0xA8…+0xD0) | [P] – kod; znaczenie [W] |
| +0xB4 | flaga ustawiana przez kod 7001 (rejestracja) | [N] |
| +0xB5 | **Shift** – z `EEMPathTo`+0x1E | [P] – pomiar: 0 bez Shift, 1 z Shift (AoC) |
| +0xB6 | „parametry szyku z celu”: 1, gdy cel ma rodzaj 1 i +0x33 ≠ 0 | [P] – kod |
| +0xB7 | tylko AoC, zerowane w konstruktorze | [N] |

Jednostka wskazuje swoją grupę polem +0x1C8 (EE i AoC). Przeniesienie jednostki: wypisanie z poprzedniej grupy
(vtable +0x28 starej grupy), ustawienie +0x1C8 i dopisanie do nowej (vtable +4) [P].

### `EEUGLocation` (cel ruchu, 0x38 B) i jego baza

| Pole | Źródło | Znaczenie | Pewność |
|---|---|---|---|
| +0x04 | 1 | – | [P] |
| +0x05 | argument bazy = 1 | rodzaj celu: 1 = lokacja; 8 to inny rodzaj obsługiwany w 0x5DB641 | [P] wartość; znaczenie [W] |
| +0x08 | 5000 | – | [N] |
| +0x10 | `A_GRA`+0xD0 | czas gry (ms) utworzenia celu | [P] – kod i pomiar |
| +0x14 | globalny licznik (EE 0x9424D8) + 1 | numer celu | [P] – pomiar: kolejne numery |
| +0x1C | argument = 1 | – | [N] |
| +0x20 / +0x24 / +0x28 | x, y, z | punkt celu. z = wysokość pola, gdy przekracza próg, inaczej 0 | [P] |
| +0x2C | `EEMPathTo`+0x10 | f32, kąt lub kierunek (w pomiarach −0,857; 1,608; 0,665) | [P] przepisanie; znaczenie [W] |
| +0x30 | `EEMPathTo`+0x1C | flaga z bitu 1 flag kliknięcia; przy Shift nadal 1 | [P] przepisanie; znaczenie [N] |
| +0x31 | `EEMPathTo`+0x1D | w pomiarach 1 | [N] |
| +0x32, +0x34 | 0 | – | [P] |
| +0x33 | `EEMPathTo`+0x1F | włącza parametry szyku grupy (+0xB6) | [P] – kod |

## Algorytm `EEMPathTo::Execute` (po sprawdzeniu pola celu, `rozkazy_gracza.md` § 6)

Dla k = 1…4 (AoC 1…5):

1. Nowa `EEActiveGroup` gracza (konstruktor: stan 5000, cel pusty).
2. **Wypełnienie** (0x5DD18B, zaznaczenie symulacji gracza, k):
   - wyczyszczenie celu i list grupy, stan 5000;
   - dla każdej zaznaczonej jednostki z +0x2B ≠ 0 i +0x3C > 0 (życie), dla której warunek(k) jest spełniony:
     wypisanie z dotychczasowej grupy, ustawienie +0x1C8 i dopisanie do nowej grupy.

   Warunek(k):

   | k | Warunek |
   |---|---|
   | 1 | bit 0 (powietrze) |
   | 2 | bit 1 (ląd) albo typ jest budynkiem (vtable +0x54) |
   | 3 | bit 2 (woda) i `Unit type` ≠ 10 |
   | 4 | bit 2 i `Unit type` = 10 (okręty podwodne) |
   | 5 (AoC) | bit 3 (kosmos) |
3. Jeśli grupa jest pusta, zostaje zwolniona. W przeciwnym razie:
   1. rejestracja grupy u gracza (+0x844 / +0x854);
   2. **usunięcie jednostek, które nie mogą ruszyć** (0x5DEE09). Zostają jednostki z +0x335 ≠ 0 (AoC +0x341), +0x3C > 0
      i prędkością ≠ 0 (obiekt cech jednostki +0x34 → +0xAC). Wyjątek: ID 0x42 („b Airport”) zostaje mimo prędkości 0.
      Budynki przyjęte w przebiegu 2 wypadają tutaj, poza lotniskiem [P: kod];
   3. **cel `EEUGLocation`**: punkt, rodzaj 1, +0x30 = `EEMPathTo`+0x1C, +0x31 = +0x1D, kąt = +0x10; potem
      +0x33 = +0x1F;
   4. dla każdej jednostki grupy wyczyszczenie jej listy +0x58 (licznik +0x68) [N: znaczenie listy];
   5. usunięcie dotychczasowego celu grupy i **ustawienie nowego**: +0x68 = cel, +0xB5 = `EEMPathTo`+0x1E (Shift),
      +0xB6 = (rodzaj celu = 1 i +0x33 ≠ 0);
   6. **+0x6C = 8000** i natychmiastowe wywołanie maszyny stanów (0x5DD463). Ta dla kodu 8000 woła 0x5DB641 (granica);
   7. wybór losowej jednostki grupy (RNG `EEPhysics`, deterministyczny w lockstep) i potwierdzenie rozkazu: dźwięk lub
      animacja, 0x4B12A2 [W].

Kody stanów obsługiwane przez 0x5DD463 (EE i AoC jednakowo):
- 2001, 2002, 4004, 4011, 7001 (rejestracja);
- 8000 (cel ruchu → 0x5DB641), 8013;
- 11002, 12001, 16001;
- 5000 – stan bez działania;
- stan 8009 pojawia się jako stan następny w obsłudze 4011.

Kod 8000 zapisują także inne funkcje (EE m.in. 0x4B92EA, 0x4BF978, 0x5B2DB3, 0x5DE74C) [P]. Znaczenie pozostałych kodów
leży poza zakresem [N].

## Weryfikacja

Zadania MCP, tylko odczyt pamięci (Riverlands_MCP: `jednostki`, `ruch_zaznacz`, `ruch_rozkaz`, `pamiec_u32`):
- 374–378 (EE) i 380–382 (AoC): scenariusz „Wojna trojańska”;
- pauza F3 po rozkazie, żeby zatrzymać stan grup do odczytu w kolejnych zadaniach;
- sprzątanie: 379, 383.

| Sprawdzenie | Oczekiwanie z kodu | Wynik | Status |
|---|---|---|---|
| flagi typów | obywatel/gwardia/prorok = 0x02, galera/transportowiec = 0x04; `Unit type` 6/5/13/4/18 | dokładnie tak (EE i AoC) | [P] |
| pojedyncza jednostka (obywatel) | 1 grupa `EEActiveGroup`, stan 8000, cel `EEUGLocation` rodzaju 1 | tak (EE); cel: czas gry 40 625 ms, numer 170, +0x30/+0x31 = 1/1 | [P] |
| jednostka niezaznaczona | brak grupy (+0x1C8 = 0) | tak | [P] |
| obywatel + galera | 2 osobne grupy (k = 2 i k = 3), oba cele z tym samym punktem i czasem | tak w EE (numery celów 183 i 185) i AoC (161 i 163) | [P] |
| luka w numeracji celów | między celami grup powstaje cel jednostki (0x5DB641) | numery 184 / 162 pominięte | [W] – zgodne z kodem |
| Shift + PPM (AoC) | nowe grupy, +0xB5 = 1 | nowe adresy grup; +0xB5 = 1; cel +0x30 = 1 | [P]; +0x1C ≠ Shift |

## Nierozpoznane zależności i granica

1. **0x5DB641**, czyli obsługa kodu 8000 (ok. 1900 instrukcji):
   - cele poszczególnych jednostek (nowe `EEUGLocation` w kolejce jednostki +0x90, 0x4A0131);
   - osobna gałąź dla samolotów (`Unit type` 3) i dla rodzaju celu 8;
   - szyk (parametry +0x70…+0xAC / gracza);
   - Shift (+0xB5 i bieżący cel jednostki +0x1F0 w około 10 miejscach);
   - czyszczenie kolejek (0x5E9664).

   To jest system szyku i kolejek celów, poza zakresem etapu.
2. Znaczenie list grupy +0x48/+0x58, listy jednostki +0x58/+0x68, pola jednostki +0x335 i bajtów
   `EEMPathTo` +0x1C/+0x1D (cel +0x30/+0x31) – [N].
3. Pozostałe kody stanów grupy i rodzaje celów (+0x05 ≠ 1) – [N].
4. Wpływ budynków w zaznaczeniu, np. lotnisko pozostawione w grupie lądowej – nie mierzono [N].

## Błędy oryginału

Nie znaleziono nowych błędów. Nadmiarowy warunek +0x61E przy ID 0x43 nie zmienia zachowania, więc nie trafił do
rejestru `BLEDY_ORYGINALU.md`.

## Konsekwencje dla OpenEE (bez zmian w kodzie)

Wierny model:
- rozkaz ruchu dzieli zaznaczenie na grupy środowiska: powietrze, ląd z budynkami, nawodne, podwodne, w AoC kosmos;
- każda grupa ma wspólny cel z czasem utworzenia i numerem;
- jednostki nieruchome są usuwane z grupy (wyjątek: lotnisko);
- Shift jest flagą grupy, a o kolejce celów decyduje dopiero etap szyku.

Obecne `Symulacja.rozkaz_grupy` traktuje zaznaczenie jako jedną grupę lądową.
