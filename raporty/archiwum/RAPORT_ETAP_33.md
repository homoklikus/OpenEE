# OpenEE – raport etapu 33: dokładne obrażenia (morale z budynków), obrót AoC i automatyzacja eksperymentów walki

Etap 33 wyjaśnił współczynnik obrażeń 0,8 z etapu 32 – to **morale z budynków**: modyfikator
`EEAEMoraleFromBuildings` na celu, stosowany w TakeDamage. Reguła została odczytana z kodu, potwierdzona w EE i AoC
i wdrożona w OpenEE Core. Obrót AoC dostał dokładne gałęzie z kodu 0x554738. Rozkazu ataku przez MCP nie udało
się uzyskać; zmierzono za to wycofanie w trakcie walki i pościg AI.

Szczegóły: `docs/titan/walka.md` § 20–24, `docs/cpp/ARCHITEKTURA_CORE.md` § 15,
`docs/titan/testy_referencyjne_ruchu.md` (etap 33), `docs/PLAN_REKONSTRUKCJI_TITAN.md` § 4.10.

**Oznaczenia:** [P] pomiar i kod; [W] wniosek ze statyki; [H] hipoteza; [N] nieustalone.
**Środowisko:** komputer główny użytkownika (sesja KDE Wayland), polecenia w maszynie roboczej Ubuntu 22.04
(GCC 11.4), kontrole także w kontenerze Ubuntu 24.04 (GCC 13.3) – wyniki identyczne. Proxmox – poza zakresem.

## 1. Stan początkowy i końcowy

| | Etap 32 (`0dfcfa5`) | Etap 33 |
|---|---|---|
| CTest | 19/19 | 19/19 |
| GDExtension | 23/23 | 23/23 |
| Godot | 324/324 | 324/324 |
| Riverlands_MCP | 13 plików | 14 plików (`test_ee_etap33.py`) |
| narzędzia Titan | 17/17 | 17/17 |
| S1–S7 | 9/9, 13b25b683deb815f | 9/9, **68b0c69ecb8b0cbc** (S5a przeliczony – obrót AoC) |
| 578 G1 | 986/986 | 986/986 (bez zmian) |
| 578 G3 | pierwsza różnica 102 (HP) | **169** (ω); różnice HP 384 → **59** |
| 580 G1 (AoC) | 36 (ω) | kurs i ω zgodne; 57 – spóźniona próbka stanu, 146 – przeładowanie (ciąg LCG) |
| 590 G1 | 97 | 97 (przyczyna zawężona, § 7) |
| AoC 505 (ruch) | pierwszy rozbieżny 224 | **803**, kąt śr. 0,12° → 0,00° |
| EE 500 (ruch) | koniec +1 takt | bez zmian [N] |

## 2. Nowe ustalenia z kodu Titan

1. **Pełna ścieżka trafienia** DealDamage 0x61DE61 → TakeDamage 0x6172BC (`walka.md` § 20) [W]: typ ataku z
   +0x1C0 albo this, parametry z gracza, wzór m·w·atak − pancerz, modyfikator wysokości, min 1, ogień do sojusznika
   (ceil(·0,1) albo 0), potem TakeDamage z listą modyfikatorów celu (+0xF8) i licznikami +0x2C4/+0x2C8.
2. **EEAEMoraleFromBuildings** (vtable 0x835CA8): vt+0x30 0x6640BA – wynik = obr − fistp(f32(n·0,1f·obr)),
   n = min(+0x24, +0x20) obcięte do 0…10; kilka modyfikatorów **nie kumuluje się** (każdy liczy z tego samego
   wejścia, ostatni wygrywa) [W].
3. **Obrót AoC** 0x554738: przycięcie kroku jak EE; inne gałęzie zmiany ω w kodach 3 i 4 (przy Δ = 0 kod 3
   przyspiesza w +, kod 4 przy ω = 0 i Δ ≠ 0 daje ±ad, zerowanie |ω′| < 0,001) [W, P].
4. **Wybór celu 0x6399CA**: osiągalność 0x62D696 tylko dla kandydata lepszego od dotychczasowego; nieosiągalny →
   rejestr 0x5E8651; wynik ≥ W+0x24 kończy przegląd [W].
5. Klucz permutacji [0x919774]+0xB0 – wartości 0/1 zgodne z parzystością licznika taktów +0xB4 [H, odczyt 595].

## 3. Wyniki eksperymentów EE i AoC

| Zadanie | Cel | Wynik |
|---|---|---|
| 591 (EE a), 596 (AoC a), 593 (EE b) | modyfikatory obrażeń (`walka_modyfikatory`) | 857 i 858: jeden `EEAEMoraleFromBuildings`, budynek (185, 110), poziom 2 – w EE i AoC; pozostałe jednostki – brak [P] |
| 592 (AoC a) | jw. | start nieudany (wczytanie scenariusza), powtórzony jako 596 |
| 595 (EE) | EEPhysics +0x80…+0xDF | +0xB0 = 0/1, +0xB4 – licznik taktów, +0x88 = 29,33 taktu/s [P] |
| 594, 597, 598 | rozkaz ataku gracza | nieudany (§ 6) |
| 599, 600 | wycofanie w trakcie walki | rozkaz po zakończeniu walki (wyzwalacz czasowy – za późno) |
| 601 | wycofanie, wyzwalacz zdarzeniem | **udane**: wycofanie w stanie 2021, pościg AI przez ok. 10 pól, ponowny wybór celu przez wycofanego po dojściu [P] |

Analiza zapisów 578, 579, 580, 581, 587, 589 (surowe bajty jednostek): każde zmniejszone trafienie (poza 2 [N])
przypada na cel z niepustym wektorem modyfikatorów, każde pełne – na cel bez modyfikatora.

## 4. Współczynnik 0,8 – wyjaśnienie

- EE 578 G3: 16 → 13 = 16 − fistp(2·0,1·16 = 3,2) – morale poziom 2 [P].
- AoC 580: 15 → 12 = 15 − fistp(3,0) – morale poziom 2 [P] (odczyt 596).
- EE 579 / 587: obywatel 42 → 21 – trafienie w (164,5; 101,5) przy budynku Troi z niepustym wektorem modyfikatorów;
  poziom 5 daje dokładnie 21 [W – poziomu w chwili trafienia nie odczytano].
- Modyfikator wysokości w tych trafieniach zwraca 1 – hipoteza etapów 31–32 obalona.
- Niewyjaśnione [N]: 856 w 589 otrzymuje 18 bez modyfikatora (kilku atakujących – nieustalony); AoC obywatel 36 → 23;
  późne trafienia 857 w 589 = 14.
- Core: `BojJednostki::morale`, `obrazenia_po_modyfikatorach`, `Swiat::ustaw_morale`; poziomy w testach z odczytu
  (`pomiar_core walka --morale`). Źródło morale (budynki, zasięg, maksimum) – poza Core [N]. Bez arbitralnego mnożnika.

## 5. Obrót AoC

Gałęzie kodów 3 i 4 dokładnie jak 0x554980 / 0x5548D6 (ad jako f32, próg 0,001 f32). AoC 505: pierwszy rozbieżny
takt względem gry 224 → **803**, błąd pozycji śr. 0,0016 → 0,0000; 580 G1: kurs i ω zgodne w całym oknie poza
taktami po śmierci; AoC 525 1,9 pola: pierwszy rozbieżny bez zmian (68), metryki po nim +0,00002 pola. EE – bez
zmian (inne gałęzie, 0x54880E). EE 500 +1 takt końca ruchu – nie powiązany z tą fizyką [N]. Kryterium
`core_porownanie_gra` zmienione na „pierwszy rozbieżny takt nie wcześniejszy niż w modelu v4” – metryki po
pierwszej rozbieżności są chaotyczne (§ 8).

## 6. Status rozkazu ataku przez MCP

`walka_atak_weryfikowany` (kamera na cel, weryfikacja piksela zaznaczeniem, wybór atakującego, PPM, kontrola
EEUGAttackUnit, 3 próby z powodem) – **nieudany**: LPM na widocznym wrogu nie zmienia zaznaczenia gracza, więc
piksela celu nie da się potwierdzić tą drogą [P: 597, 598]. 594 – cel we mgle (punkt rozkazu ruchu odbiegał
o ok. 2 pola przy przyjętym z = 1,84). Brak klikania na ślepo – każda próba zapisuje powód. Następny krok: wskaźnik
obiektu pod kursorem z pamięci (odczyt różnicowy przy kursorze nad celem i obok).
Nowe narzędzie: `walka_czekaj_na_stan` – wyzwalanie kroków zdarzeniem (stan jednostki) zamiast czasem.

## 7. Pierwsze rozbieżne takty

| Okno | Pierwszy takt | Przyczyna źródłowa | Propagacja |
|---|---|---|---|
| 578 G1 (EE 1:1) | brak | – | – |
| 578 G3 (EE 2:1) | 169 – ω 857 w 2021 | [N] | 858: kurs od 190, pozycja od 240; HP zgodne do 334 (drugi atakujący 858) |
| 580 G1 (AoC 1:1) | 57 – stan (próbka stanu gry spóźniona, pozycja identyczna); rzeczywista: 146 – przeładowanie | ciąg LCG gry zużywany przez inne systemy [N] | trafienia przesunięte w czasie |
| 590 G1 (EE 1:1) | 97 – kurs w trybie 1 | Core obraca o krok ω do ruchomego celu, gra nie; odwrócona kolejność jednostek pogarsza wynik (64) [N] | kurs ≤ 0,005 rad, pozycja ≤ 0,01; stan, HP, przeładowanie, cel zgodne |
| 589 G3 (EE 2:1, nowe) | 1 | start okna w trakcie trasy (odtworzenie trasy z próbki) [N] | – |
| EE 500 | 48 (bez zmian) | [N] | koniec ruchu +1 |

## 8. Regresja i determinizm

| Kontrola | Wynik |
|---|---|
| CMake Release / Debug (GCC 11.4) | OK |
| CTest Release / Debug | 19/19 / 19/19, wyniki identyczne (skrót pojedynku 9ddaf83720646edb, S 68b0c69ecb8b0cbc) |
| GDExtension | 23/23 |
| Godot | 324/324 |
| Riverlands_MCP | 14/14 plików |
| narzędzia Titan | 17/17 |
| `git diff --check` | czysto |

RNG: bez nowych losowań (morale i obrót – bez RNG). Zmiana kryterium w `core_porownanie_gra` (z „błąd nie większy
niż v4” na „pierwszy rozbieżny takt nie wcześniejszy niż v4”) – wymuszona przez AoC 525 1,9 pola, gdzie po wspólnym
punkcie rozjazdu (takt 68) metryki różnią się o 0,00002 pola; decyzja opisana w teście i w dokumentacji.

## 9. Pewność ustaleń

[P]: morale 2 dla 857/858 w EE i AoC, związek modyfikatora ze zmniejszonymi trafieniami, obrót AoC (505, 580),
wycofanie i pościg (601), +0xB0/+0xB4 EEPhysics. [W]: pełna ścieżka DealDamage/TakeDamage, brak kumulacji
modyfikatorów, liczniki +0x2C4/+0x2C8, remisy i osiągalność. [H]: +0xB0 = parzystość taktu, poziom 5 obywatela.
[N]: źródła morale, 856 = 18, obiekt pod kursorem, utrata LOS, przeszkoda, kurs w trybie 1 (590), EE 500 +1.

## 10. Prognoza i etap 34

Prognoza (`PLAN_REKONSTRUKCJI_TITAN.md` § 4.10): pozostało A ≈ 5,73 J (≈ 6,4 tyg.), B ≈ 12,63 J (≈ 16 tyg.),
C ≈ 20,13 J (≈ 29 tyg.); zużyte na walkę od etapu 30 ≈ 7,3 h.

Propozycja etapu 34:
1. Źródła morale: odczyt budynków dających morale (typy, zasięg, maksimum, aktualizacja) – warunek, by Core sam
   wyznaczał poziomy.
2. Wskaźnik obiektu pod kursorem w pamięci → rozkaz ataku przez MCP → utrata celu poza LOS, przeszkoda, remisy.
3. Kurs w trybie 1 przy ruchomym celu (590, takt 97) i ω 857 w 578 G3 (takt 169).
4. Statyka ataków dystansowych (zakres dodatkowy etapu 33 nie został rozpoczęty – priorytety A–D miały pierwszeństwo).
