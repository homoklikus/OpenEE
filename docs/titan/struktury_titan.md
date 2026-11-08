# Struktury Titan – tabela generowana

Plik generowany przez `narzedzia/titan/struktury.py markdown` z `dane/titan/struktury_titan.json` (jedno źródło prawdy). Nie edytuj ręcznie – zmieniaj schemat.

## EEUnit

Jednostka (EEUnit / EEComplexUnit). Wspólne pola obiektów mapy i pola ruchu jednostki lądowej.

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| nast | ptr | 0x0C | 0x0C | [P] | – | ee_warianty J_NAST, etapy 12-29; następny obiekt na liście gracza |
| wlasciciel | ptr | 0x18 | 0x18 | [P] | – | ee_warianty J_WLASC; 0x60AD87 (gracz→vt+0x74); gracz-właściciel |
| pole_x | i32 | 0x1C | 0x1C | [P] | – | ruch_jednostki.md §3; 0x5F043B porównuje nowe pole z +0x1C/+0x20 i zapisuje je przez funkcję wołaną (etap 30: struktury.py waliduj); pole mapy floor(x) |
| pole_y | i32 | 0x20 | 0x20 | [P] | – | ruch_jednostki.md §3; 0x5F043B porównuje nowe pole z +0x1C/+0x20 i zapisuje je przez funkcję wołaną (etap 30: struktury.py waliduj); pole mapy floor(y) |
| id | u32 | 0x24 | 0x24 | [P] | – | ee_warianty J_ID; identyfikator obiektu (0x01xxxxxx) |
| typ | ptr | 0x2C | 0x2C | [P] | – | ee_warianty J_KLASA; EEUnitClass – typ jednostki |
| parametry | ptr | 0x34 | 0x34 | [P] | – | ruch_jednostki.md §3; EEUnitClassUpgrade – parametry ruchu i (etap 30) walki gracza |
| flagi | u32 | 0x44 | 0x44 | [W] | – | ee_warianty J_FLAGI; flagi obiektu |
| trasa_mapa | ptr | 0x80 | 0x80 | [P] | – | astar_wyniki.md §5; kolejka trasy (deque +0x7C): mapa bloków |
| trasa_bloki | u32 | 0x84 | 0x84 | [P] | – | astar_wyniki.md §5; liczba bloków mapy |
| trasa_start | u32 | 0x88 | 0x88 | [P] | – | astar_wyniki.md §5; indeks pierwszego punktu |
| trasa_n | u32 | 0x8C | 0x8C | [P] | – | astar_wyniki.md §5; liczba punktów trasy |
| poziomy_celow_pocz | ptr | 0x94 | 0x94 | [P] | – | kolejka_rozkazow.md; wektor poziomów celów (+0x90): początek; element 0x28 B |
| poziomy_celow_kon | ptr | 0x98 | 0x98 | [P] | – | kolejka_rozkazow.md; wektor poziomów celów: koniec |
| kontakty | u32 | 0xC8 | 0xC8 | [P] | – | etap 29 (ee_obserwacja); liczba kontaktów kolizyjnych |
| poz_rozkazu | f32[2] | 0x118 | 0x118 | [P] | – | ruch_jednostki.md §3; pozycja w chwili rozkazu |
| macierz | f32[16] | 0x130 | 0x130 | [P] | – | ruch_jednostki.md §3; orientacja; x +0x13C, y +0x14C, z +0x15C |
| omega | f32 | 0x17C | 0x17C | [P] | – | ruch_jednostki.md §3; prędkość kątowa [rad/s] |
| grupa | ptr | 0x1C8 | 0x1C8 | [W] | – | ruch_jednostki.md §3; grupa ruchu |
| stan | ptr | 0x1E8 | 0x1E8 | [P] | – | kolejka_rozkazow.md; EEUnitAction; numer stanu +0x24 |
| cel_rozkazu | ptr | 0x1EC | 0x1EC | [P] | – | kolejka_rozkazow.md; pierwszy cel bez flagi punktu trasy |
| cel | ptr | 0x1F0 | 0x1F0 | [P] | – | kolejka_rozkazow.md; cel bieżący (początek poziomu 0) |
| blokujacy | ptr | 0x20C | 0x20C | [P] | – | fizyka_terenu.md §4, walidacja_kolizji.md §10; obiekt blokujący krok |
| kurs_docelowy | f32 | 0x214 | 0x214 | [P] | – | ruch_jednostki.md §3; −10000 = brak |
| k21C | f32 | 0x21C | 0x21C | [W] | – | ruch_jednostki.md §3; max(v′, par+0xBC) |
| push | f32[2] | 0x230 | 0x230 | [W] | – | ruch_jednostki.md §3; wektor odpychania |
| v | f32 | 0x238 | 0x238 | [P] | – | ruch_jednostki.md §3; prędkość liniowa |
| skala | f32 | 0x240 | 0x240 | [P] | – | ruch_jednostki.md §3; skala |
| promien | f32 | 0x244 | 0x244 | [P] | – | ruch_jednostki.md §3; promień kolizji |
| k248 | f32 | 0x248 | 0x248 | [P] | 0x549A08, 0x54F05E | indeks_pe (fadd/fstp), fizyka_terenu.md §4; czas ślizgu/odpychania [ms] (float) |
| termin_idle | u32 | 0x254 | 0x258 | [W] | – | skrypty_stanow.md §3; termin oceny Idle (BO-8) |
| animacja | i32 | 0x260 | 0x264 | [P] | 0x5EFD6D | 0x5EFD6D (EE) – etap 30; pomiar 561/564 (EE) i 570 (AoC): 13 w ruchu → 0 w AttackEnemyUnit, 4/5 przy śmierci; bieżąca animacja (indeks), ustawiana przy wejściu w stany ataku |
| tryb | u32 | 0x264 | 0x268 | [P] | – | ruch_jednostki.md §3; tryb ruchu 0/1/3/4/5 |
| przeladowanie | i32 | 0x2A0 | 0x2A4 | [P] | – | etap 30: wejście w AttackEnemyUnit EE 0x60B343 (:= parametry+0x138), AoC 0x5FEA22 (:= fistp(los[a,b]·parametry+0x138)); zdarzenie Reloaded = 0 (EE 0x61B746); pomiar 561/564/570; licznik przeładowania [ms]: −34 co takt (także po śmierci), 0 = Reloaded |
| k330 | u16 | 0x330 | 0x33C | [P] | – | fizyka_terenu.md §4; znacznik blokady kroku (2 = zablokowany) |
| osiagniety_punkt | u8 | 0x33F | 0x34B | [W] | – | ruch_jednostki.md §3; osiągnięto bieżący punkt |
| hp | i32 | 0x3C | 0x3C | [W] | 0x616F30, 0x6172BC | etap 30: setter EE 0x616F30, TakeDamage EE 0x6172BC (vt+0x70), EEHitPointUpgrader EE 0x638CBF / AoC 0x64F18D; bieżące punkty życia (int); ≤ 0 = martwy |
| regeneracja_termin | i32 | 0x290 | – | [W] | – | etap 30: EE 0x625B47 (co 1000 ms + typ+0x578); termin następnej regeneracji HP |
| zabicia | u16 | 0x332 | – | [W] | – | etap 30: EE 0x61DDC7 (inc, gdy cel ma HP ≤ 0 po trafieniu); licznik zabitych celów |
| k2AC | i32 | 0x2AC | 0x2B0 | [H] | – | etap 30: zerowane w 0x60B35C i 0x6176C6; AoC +0x2B0 zerowane w 0x61D9AE; pole stanu ataku – znaczenie [N] |

## EEUnitClass

Typ jednostki (jeden obiekt na typ).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| rozmiar_kolizji | f32 | 0x474 | 0x178 | [P] | – | ruch_jednostki.md §3; rozmiar kolizji / próg zaliczenia punktu |
| nachylenie | f32 | 0x488 | 0x18C | [W] | – | ruch_jednostki.md §3; czułość na nachylenie |
| ogien_bratobojczy | f32 | 0x494 | – | [W] | – | etap 30: EE 0x61DD85; mnożnik obrażeń dla celu tego samego gracza |
| rodzaj_jednostki | u32 | 0x4B4 | – | [P] | – | etap 30: = dbobjects „Unit type” (71/71 typów, zad. 552); 1 zasoby, 2 budynki, 5 piechota… |
| typ_db | u32 | 0x4B8 | 0x1BC | [P] | – | ee_warianty K_TYP; numer typu w dbobjects |
| klasa_trafienia | i32 | 0x4C0 | – | [P] | – | etap 30: DealDamage EE 0x61DE61; odczyt 565: 0 (gwardia – atak „shock”); atakujący: rodzaj ataku (indeks pancerza 0–5); cel: wiersz tablicy mnożników 0x8D2050 (×6) |
| klasa_tablicy_trafien | i32 | 0x4C4 | – | [P] | – | etap 30: EE 0x4D5F2C; odczyt 565: 13 (gwardia); wiersz tablicy trafień (cel) |
| rodzina_ataku | i32 | 0x4C8 | – | [P] | – | etap 30: EE 0x61DE61 → 0x4D5F2C; rodzina ataku = dbobjects „Family attack type” (odczyt 565: 48 dla gwardii); kolumna tablicy trafień 0x4D5F2C |
| regeneracja | i32 | 0x578 | – | [W] | – | etap 30: EE 0x625B73; HP dodawane co 1000 ms |
| flagi_ruchu | u8 | 0x5D4 | – | [W] | – | nawigacja_wejscie.md (AoC testuje +0x2D0 & 0xC); flagi ruchu |
| teren_dozwolony | u8[] | 0x5D6 | – | [W] | – | astar_pola.md §7; bajt na typ terenu komórki; AoC – metoda typu |
| blokuje | u8 | 0x600 | – | [W] | – | astar_pola.md §7; obiekt blokuje pole |

## EEUnitClassUpgrade

Parametry jednostki dla gracza (ruch; etap 30: kandydaci pól walki).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| zasieg_max | f32 | 0x9C | 0x9C | [P] | – | etap 30: UnitInWeaponRange EE 0x5F0CE8; odczyt 565/570 = 0,5 (dbobjects Max range); maksymalny zasięg ataku |
| zasieg_obszaru | f32 | 0xA0 | 0xA0 | [P] | – | etap 30: EE 0x61DEF3; odczyt EE 565 i AoC 570: atak 15, pancerz 0/6/0/0/0/0, HP 215 (gwardia); promień obrażeń obszarowych (0 = brak) |
| pole_widzenia | f32 | 0xA4 | 0xA4 | [P] | – | etap 30: odczyt 565/570 = 4,0 (dbobjects Line of sight); zasięg widzenia |
| przyspieszenie | f32 | 0xA8 | 0xA8 | [P] | – | ruch_jednostki.md §3; a |
| vmax | f32 | 0xAC | 0xAC | [P] | – | ruch_jednostki.md §3; prędkość maksymalna |
| alfa | f32 | 0xB0 | 0xB0 | [P] | – | ruch_jednostki.md §3; przyspieszenie kątowe |
| omega_max | f32 | 0xB4 | 0xB4 | [P] | – | ruch_jednostki.md §3; ωmax |
| atak | f32 | 0xD8 | 0xD8 | [P] | – | etap 30: EE 0x61DEF9 (fld) – wartość ataku z ulepszeniami gracza; odczyt EE 565 i AoC 570: atak 15, pancerz 0/6/0/0/0/0, HP 215 (gwardia); atak |
| pancerz | f32[6] | 0xE0 | 0xE0 | [P] | – | etap 30: EE 0x61DFC0 – indeks = klasa_trafienia atakującego; odczyt EE 565 i AoC 570: atak 15, pancerz 0/6/0/0/0/0, HP 215 (gwardia); pancerz dla 6 rodzajów ataku |
| przeladowanie_ms | i32 | 0x138 | 0x138 | [P] | – | etap 30: odczyt 565/570 = 2000 (gwardia, reload 2,0 s); czas przeładowania [ms] (dbobjects „Attack reload time” · 1000) |
| hp_max | i32 | 0x144 | 0x144 | [P] | – | etap 30: EE 0x60D7CF, 0x625B7C, 0x617437; odczyt EE 565 i AoC 570: atak 15, pancerz 0/6/0/0/0/0, HP 215 (gwardia); maksymalne HP |

## EEUnitAction

Obiekt stanu maszyny .tai.

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| numer | u32 | 0x24 | 0x24 | [P] | – | ruch_jednostki.md §4; numer stanu (np. 5000 Idle, 2001 AttackEnemyUnit) |

## EEUnitGoal

Cel jednostki – klasa bazowa (konstruktor EE 0x6283AB).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| vtable | ptr | 0x00 | 0x00 | [P] | – | RTTI; klasa celu |
| rodzaj | u8 | 0x05 | 0x05 | [W] | – | 0x6283AB (EE); 1 Location, 2 AttackUnit, 3 AttackGround, 8 UnloadTransport, 9 Patrol, 10 Explore, 11 CastCalamity |
| k08 | u32 | 0x08 | 0x08 | [W] | – | 0x6283AB (EE); 5000 przy utworzeniu |
| czas_utworzenia | u32 | 0x10 | 0x10 | [W] | – | 0x6283AB (EE): EEPhysics+0xD0; czas gry utworzenia [ms] |
| numer_seryjny | u32 | 0x14 | 0x14 | [W] | – | 0x6283AB (EE): licznik globalny 0x9424D8; kolejny numer celu |
| proby | u32 | 0x18 | 0x18 | [W] | – | ruch_jednostki.md §4; licznik prób trasy (limit vtable +0x2C) |
| pochodzenie | u8 | 0x1C | 0x1C | [H] | – | 0x6283AB (EE), argument konstruktora; pochodzenie rozkazu (gracz/AI) – do potwierdzenia |
| aktywowany | u8 | 0x1D | 0x1D | [P] | – | kolejka_rozkazow.md; 1 dla celu bieżącego |

## EEUGLocation

Cel-punkt (0x38 B).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| punkt | f32[3] | 0x20 | 0x20 | [W] | – | 0x614D47 (EE); x, y, z |
| kat | f32 | 0x2C | 0x2C | [W] | – | 0x614D47 (EE); kąt szyku |
| obrot | u8 | 0x31 | 0x31 | [W] | – | kolejka_rozkazow.md; obrót do kąta celu po dojściu |
| punkt_trasy | u8 | 0x32 | 0x32 | [P] | – | kolejka_rozkazow.md; punkt pośredni trasy |
| k34 | u8 | 0x34 | 0x34 | [P] | – | nawigacja_wejscie.md; 1 świeży rozkaz, 2 prośba, 3/4 trasa grupowa |

## EEUGAttackUnit

Cel-atak na jednostkę (konstruktor EE 0x60AD45).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| punkt | f32[3] | 0x20 | 0x20 | [W] | – | 0x60AD45 (EE); środek pola celu |
| wlasciciel | ptr | 0x2C | 0x2C | [P] | – | 0x60AD45 (EE); pomiar 561: id = atakujący; jednostka atakująca |
| cel | ptr | 0x30 | 0x30 | [P] | – | 0x60ADEC (EE); pomiar 561/564/570: vtable EEComplexUnit, id celu +0x24; atakowana jednostka |
| cel_pole | i32[2] | 0x34 | 0x34 | [W] | – | 0x60ADFF (EE); pole celu przy utworzeniu (−10000 = brak) |

## EEGoalLevel

Poziom kolejki celów (0x28 B), element wektora jednostka+0x90.

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| mapa | ptr | 0x08 | 0x08 | [P] | – | kolejka_rozkazow.md; mapa bloków (1024 wskaźniki) |
| bloki | u32 | 0x0C | 0x0C | [P] | – | kolejka_rozkazow.md; liczba bloków |
| pierwszy | u32 | 0x10 | 0x10 | [P] | – | kolejka_rozkazow.md; indeks pierwszego elementu |
| liczba | u32 | 0x14 | 0x14 | [P] | – | kolejka_rozkazow.md; liczba celów |
| wlasciciel | ptr | 0x18 | 0x18 | [P] | – | kolejka_rozkazow.md; jednostka |

## PunktTrasy

Element kolejki trasy (20 B, blok 204 elementy).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| x | f32 | 0x00 | 0x00 | [P] | – | astar_wyniki.md §5;  |
| y | f32 | 0x04 | 0x04 | [P] | – | astar_wyniki.md §5;  |
| z | f32 | 0x08 | 0x08 | [P] | – | astar_wyniki.md §5;  |
| dl | f32 | 0x0C | 0x0C | [P] | – | astar_wyniki.md §5; długość narastająca |
| dl_poprz | f32 | 0x10 | 0x10 | [P] | – | astar_wyniki.md §5; długość narastająca poprzedniego |

## EEMap

Mapa pól. Wskaźnik globalny: GRA_STAT+0xBC (EE 0x9183BC, AoC 0x930DFC).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| mesh | obj | 0x1C | 0x1C | [W] | – | fizyka_terenu.md §1; GETerrainMesh |
| komorki | ptr | 0x1816D4 | 0x1955F0 | [P] | – | 0x4039AC (EE); AoC = EE + 0x13F1C (etap 30: rozkład dostępów indeks_pe – 270/279, 373/386 odwołań); odczyt AoC 570: W 280, brzegi 139/419/140; tablica wskaźników komórek, indeks y·W + x |
| brzeg_s1 | i32 | 0x1816EC | 0x195608 | [P] | – | astar_pola.md §7; AoC = EE + 0x13F1C (etap 30: rozkład dostępów indeks_pe – 270/279, 373/386 odwołań); odczyt AoC 570: W 280, brzegi 139/419/140; linia brzegu x + y = s1 |
| brzeg_s2 | i32 | 0x1816F0 | 0x19560C | [P] | – | astar_pola.md §7; AoC = EE + 0x13F1C (etap 30: rozkład dostępów indeks_pe – 270/279, 373/386 odwołań); odczyt AoC 570: W 280, brzegi 139/419/140; linia brzegu x + y = s2 |
| brzeg_d | i32 | 0x1816F4 | 0x195610 | [P] | – | astar_pola.md §7; AoC = EE + 0x13F1C (etap 30: rozkład dostępów indeks_pe – 270/279, 373/386 odwołań); odczyt AoC 570: W 280, brzegi 139/419/140; linia brzegu |y − x| = d |
| szerokosc | i32 | 0x1816FC | 0x195618 | [P] | – | 0x4039AC (EE); AoC = EE + 0x13F1C (etap 30: rozkład dostępów indeks_pe – 270/279, 373/386 odwołań); odczyt AoC 570: W 280, brzegi 139/419/140; W (wymiar porównywany dla x i y) |

## EEMapKomorka

Komórka mapy – obiekt EETile (RTTI, vtable EE 0x82C674), wskaźniki w tablicy EEMap+komorki.

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| teren | u32 | 0x04 | 0x04 | [P] | – | 0x41D3AB (EE); AoC – ta sama logika A* (astar_pola.md §1), do potwierdzenia odczytem; etap 30 (zad. 550): wartości 0,1,2,5,6,9,10,11 = rodzina terenu tekstury (dbterrain „Terrain family”), 1 woda głęboka, 10 płytka – tekstura_titan.md; zrzut AoC 570: 39 480 komórek, histogram terenu = EE; indeks terenu dla tablicy typ+0x5D6 |
| lista | ptr | 0x08 | 0x08 | [P] | – | 0x41D3BB (EE); AoC – ta sama logika A* (astar_pola.md §1), do potwierdzenia odczytem; zrzut AoC 570: 39 480 komórek, histogram terenu = EE; pierwszy węzeł listy obiektów |

## WezelObiektu

Węzeł listy obiektów komórki.

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| obiekt | ptr | 0x04 | 0x04 | [P] | – | 0x41D3C4 (EE); AoC – ta sama logika A* (astar_pola.md §1), do potwierdzenia odczytem; zrzut AoC 570: 39 480 komórek, histogram terenu = EE;  |
| nast | ptr | 0x08 | 0x08 | [P] | – | 0x41D3D6 (EE); AoC – ta sama logika A* (astar_pola.md §1), do potwierdzenia odczytem; zrzut AoC 570: 39 480 komórek, histogram terenu = EE;  |

## EEPhysics

Zegar i RNG symulacji. Wskaźnik: A_GRA (EE 0x919774, AoC 0x9318F0).

| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |
|---|---|---|---|---|---|---|
| rng | u32 | 0x18 | 0x18 | [P] | – | etap 27-29; stan LCG 214013/2531011 |
| czas | u32 | 0xD0 | 0xD0 | [P] | – | zegar_symulacji.md; czas gry [ms] |
