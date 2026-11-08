# OpenEE – raport etapu 32: zgodność walki z Titanem, diagnostyka rozbieżności i komplet pomiarów EE/AoC

Etap 32 zaczął od niezawodności pomiarów (wygaszacz ekranu), a potem od pierwszej rozbieżności walki EE z etapu 31
(578 G1, takt 48). Okazało się, że nie była to różnica walki, tylko trzech reguł ruchu przejętych z modelu v4.
Po odczytaniu ich z kodu Titan pojedynek 578 G1 przebiega w OpenEE Core **identycznie jak w grze w każdym z 986
porównań**. Odczytano też konfigurację modyfikatora wysokości (EE i AoC) i tablice obrażeń AoC, co pozwoliło
po raz pierwszy symulować okno walki AoC.

Szczegóły: `docs/titan/walka.md` § 15–19, `docs/titan/ruch_jednostki.md` (aktualizacja etapu 32),
`docs/titan/skrypty_stanow.md` § 8, `docs/titan/testy_referencyjne_ruchu.md`, `docs/cpp/ARCHITEKTURA_CORE.md` § 14,
`docs/PLAN_REKONSTRUKCJI_TITAN.md` § 4.9.

**Oznaczenia:** [P] potwierdzone pomiarem i kodem; [W] wniosek ze statycznej analizy kodu; [H] hipoteza;
[N] nieustalone. „Gra” – pomiar w `Empire Earth.exe` (e352d7ae…) albo `EE-AOC.exe` (db8fc5ce…) przez
Riverlands_MCP; „model” – dane syntetyczne albo obliczenia Core bez serii z gry.

**Środowisko.** Komputer główny użytkownika (sesja KDE Wayland – według zlecenia Debian 13); polecenia
wykonywane w maszynie roboczej Ubuntu 22.04 (GCC 11.4) połączonej z tym komputerem, część kontroli w kontenerze
Ubuntu 24.04 (GCC 13.3). Wyniki obu kompilatorów identyczne. Migracji na Proxmox nie wykonywano.

## 1. Stan wyjściowy i końcowy

| | Etap 31 (`b6d8021`) | Etap 32 |
|---|---|---|
| CTest | 19/19 | 19/19 (nowe sprawdzenia w `walka_swiat`) |
| GDExtension | 22/22 | 23/23 (ten sam plik testów; mapa prawdziwego scenariusza z rodzinami tekstur) |
| Godot | 324/324 | 324/324 |
| Riverlands_MCP | 12 plików | 13 plików |
| narzędzia Titan | 17/17 | 17/17 |
| S1–S7 | c36721320b3595e4 | **13b25b683deb815f** – S2, S4, S4b, S5 przeliczone (§ 5) |
| 578 G1 (EE 1:1) | pierwsza różnica takt 48 | **brak różnic w oknie** |
| 578 G3 (EE 2:1) | takt 53 | takt 102 (obrażenia 13 vs 16, [N]) |
| 580 G1 (AoC 1:1) | SKIP (brak tablic) | symulowany; pierwsza różnica takt 36 (obrót AoC [N]) |
| 590 G1 (EE 1:1, nowy pomiar) | – | stan, HP, przeładowanie, cel – bez różnic; kurs/pozycja od taktu 97 (≤ 0,005 rad, ≤ 0,02 pola) |

## 2. Wykorzystane narzędzia

- **Riverlands_MCP** (lokalnie, bez publikacji): nowy moduł `ee_pulpit` – stan sesji (logind LockedHint/IdleHint,
  wygaszacz przez D-Bus, ustawienia autoblokady, DPMS, xdotool), **odwracalny inhibitor** wygaszacza i usypiania
  (`kde-inhibit`, zapas `systemd-inhibit`; proces kończy się sam po zadanym czasie albo po `pulpit_zwolnij`),
  `gotowosc()` z powodami `srodowisko_*`. `start_testowy` sprawdza gotowość przed startem i zapisuje stan pulpitu
  przy niepowodzeniu; krok zadania zakłada inhibitor (45 min) i raz bezpiecznie ponawia start, gdy utknął na
  odprawie albo środowisko było niegotowe. `walka_atak` – pauza kursora przed PPM (nadal bez skutku, § 3).
- **pomiar_core walka**: w próbkach kurs, ω i tryb ruchu; rodzaj jednostki (typ +0x4B4) w parametrach.
- **Testy porównawcze** (`core_walka_swiat`): porównanie kursu i ω, automatyczny **PIERWSZY ROZBIEŻNY TAKT** z rodzajem
  różnicy, wykrywanie próbek gry spóźnionych o takt (wyścig odczytu pamięci) i ich pomijanie z licznikiem,
  test reguły CompletedUnitFacing na 189 taktach 9006 z gry.
- **Statyka**: Capstone/pefile (skrypty lokalne), dezasemblacja 0x614F52, 0x548266, 0x54DE35, 0x548920, 0x5488D1,
  0x61E500 / AoC 0x631880, 0x631B64, 0x44E46E, 0x63969A, 0x40CFC7.

## 3. Nowe pomiary i odkrycia

| Zadanie | Wynik |
|---|---|
| 585–586 | sesja KDE Wayland, ekran odblokowany, wygaszacz nieaktywny; ustawienia autoblokady nieczytelne (wartości domyślne Plasmy – blokada po kilku minutach bezczynności [H]); `kde-inhibit` działa |
| 587 (EE), 588 (AoC) | **oba starty przeszły odprawę za pierwszym razem**; wagi celu, tablice obrażeń, cfg wysokości, parametry typów [P] |
| 589, 590 (EE) | dwa nowe pojedynki EE (590 G1 – nowe okno testowe); rozkaz ataku gracza – nieudany 3 razy; odwrót – wydany po zakończeniu walki |

Odkrycia (szczegóły w `walka.md`):
1. **CompletedUnitFacing = |Δkurs| ≤ 1° (f32), bez warunku v = ω = 0**, z ustawieniem macierzy na kurs celu
   (0x614F52) [P: 188 z 189 taktów 9006 w 11 pomiarach EE/AoC; reguła modelu v4: 171].
2. **Przycięcie kroku obrotu** (0x548477): przy Δ = 0 bez przycięcia – jednostka przestrzeliwuje kurs [P].
3. **Tryb 4 obraca** o ω′·dt i idzie wzdłuż nowej macierzy (0x54DE35 → 0x548920) [P]; 5001 nie zmienia trybu ruchu [P].
4. **Modyfikator wysokości**: cfg EE [0x917BB8] = AoC [0x92FCA8] = 2,0 / 1,0 / 1,5 / 0,8, premia gracza 0 [P].
5. **Tablice AoC**: 0x0C = EE; 0x08 = 0x0C·2/3, 0x10 = 0x0C·1,5 (EE: ·0,714 i ·1,4) [P].
6. **Mgła** (0x631B64): warunek wykrycia = pole kandydata widoczne dla gracza (licznik widoczności kafla > 1) [W].
7. **Remisy**: lista kandydatów permutowana 0x40CFC7 z kluczem [0x919774]+0xB0 [W].
8. **Śmierć czyści kolejkę celów** ofiary w tym samym takcie [P: 578, 590].
9. **Korekta etapu 31** [P]: „857: 13 zamiast 16” nie wynika z wysokości (z jednostek różni się o 0,01).

Nie udało się [N]: rozkaz ataku wydany przez gracza (PPM na wrogu daje cel EEUGLocation albo nic – trafienie
w obiekt nieuzyskane), utrata LOS i pościg (odwrót wydany po śmierci przeciwnika), wróg za przeszkodą,
potwierdzenie remisów pomiarem. Brak tych pomiarów **nie** jest wynikiem mechaniki.

## 4. Poprawki w Core

- `Swiat::ukonczony_obrot` (CompletedUnitFacing 0x614F52) z ustawieniem macierzy; 5001 bez zmiany trybu; Dying
  czyści kolejkę celów.
- `FizykaLadowa::obrot` – przycięcie kroku jak 0x548477; `tryb_hamowanie` obraca o ω′·dt (0x548920); tryb 5 bez
  zerowania ω.
- `ModyfikatorWysokosci::z_gry(aoc)`; AoC – rodzaj celu 30.
- Bez nowych losowań RNG; bez wyjątków dla scenariusza 578; bez przesuwania taktu ataku.

## 5. Zgodność ruchu i przypadki S1–S7

Warunek zlecenia „S1–S7 bitowo” dotyczył ochrony nawigacji przed zepsuciem. S1–S7 to wyniki **modelu v4**, a nie
pomiary; trzy reguły modelu okazały się sprzeczne z kodem i z pomiarami. Po korekcie:
- S1, S3, S5a, S6, S7 – bez zmian bitowo;
- S2, S4, S4b, S5 – inne wartości (S2/S4b kończą się takt wcześniej; S4/S5 – inny przebieg kursu przy celowaniu);
  przeliczone z Core i opisane w pliku przypadków (`zmiana_etap32`);
- **porównanie z prawdziwymi seriami ruchu**: EE 500 – maks. błąd pozycji 0,0497 → **0,0205**, maks. błąd v 0,332 →
  **0,068**, takty z innym stanem 21 → **17**; koniec ruchu +0 → +1 takt [N]; AoC 505, EE 517, AoC 525 – bez zmian.
  `core_porownanie_gra` wymaga teraz, by Core nie był gorszy od modelu v4 względem gry (był „równy”).
Decyzja o zmianie oczekiwanych wartości S2/S4/S4b/S5 jest świadoma i udokumentowana; stare wartości są w historii
git (etap 27–31).

## 6. Porównanie EE/AoC

Identyczne: wagi wyboru celu, cfg wysokości, wzór przeładowania, numery stanów, reguła CompletedUnitFacing
(przejścia AoC w tym samym zbiorze 189 taktów). Różne: tablice trafień 0x08/0x10, offset premii gracza
(+0xA3C / +0xA34), rodzaj typu (+0x4B4 / +0x1B8), rodzaj celu 30 w AoC, reguła obrotu AoC (0x554738) – przy Δ ≈ 0
oscylacja jak w EE, ale Core AoC jeszcze się różni (580, takt 36) [N].

## 7. Pierwsze rozbieżności i ich przyczyny

| Okno | Pierwszy takt | Przyczyna źródłowa | Propagacja |
|---|---|---|---|
| 578 G1 | brak | – | – |
| 578 G3 | 102 | 857 otrzymuje 13 zamiast 16 (współczynnik dokładnie 0,8 – wartość kary wysokości, ale warunek z nie zachodzi) [N] | HP 857 niższe → przy 390 Core nie zabija ad3 w tym samym takcie co gra; 858: kurs od 190, pozycja od 240 (przechwycenie/kolizja z różnym HP i kolejnością) |
| 580 G1 | 36 (35 – próbka spóźniona, pominięta) | reguła obrotu AoC przy Δ ≈ 0 [N] | kurs od 62, stan od 57; przeładowania – ciąg LCG zużywany także przez inne systemy (wzór 14/14) |
| 590 G1 | 97 | kurs/pozycja w 2021 przy kontakcie dwóch jednostek (odpychanie) [H] | bez wpływu na stan, HP, przeładowanie i cel w oknie |

## 8. Pełne wyniki testów

| Kontrola | Wynik |
|---|---|
| CMake Release (GCC 11.4, z GDExtension) | OK |
| CMake Debug (GCC 11.4) | OK |
| CTest Release / Debug (dane lokalne) | **19/19** / **19/19**, wyniki identyczne |
| GDExtension | **23/23** |
| Godot | **324/324** |
| Riverlands_MCP | **13/13** plików (nowy `test_ee_etap32.py`; `test_ee_start.py` z atrapą pulpitu) |
| narzędzia Titan | **17/17** |
| S1–S7 | 9/9, skrót 13b25b683deb815f (§ 5) |
| porównanie 578 G1 / 578 G3 / 580 G1 / 590 G1 | § 7 |
| `git diff --check` | czysto |

## 9. Niewyjaśnione zagadnienia

- Współczynnik 0,8 przy trafieniach 857 (578 G3), AoC 580 (12 zamiast 15) i obywatela 579 (21 zamiast 42) [N].
- Reguła obrotu AoC przy Δ ≈ 0; koniec ruchu EE 500 o takt później [N].
- Permutacja kandydatów 0x40CFC7 i znaczenie [0x919774]+0xB0; osiągalność 0x62D696 [N/W].
- Rozkaz ataku gracza przez MCP; utrata LOS, pościg, przeszkoda – brak pomiaru.
- Ustawienia autoblokady KDE nie dały się odczytać (kreadconfig zwraca puste – wartości domyślne) [H].

## 10. Prognoza

`PLAN_REKONSTRUKCJI_TITAN.md` § 4.9 – pozostało A ≈ 5,75 J (≈ 6,4 tyg.), B ≈ 12,65 J (≈ 16 tyg.), C ≈ 20,15 J
(≈ 29 tyg.); zużyte na walkę od etapu 30 ≈ 5,5 h. Spadek tylko o część zużytego nakładu – nowe niewiadome.

## 11. Propozycja etapu 33

1. Odczyt argumentów i wyniku 0x61E500 / 0x61DE61 w takcie trafienia (współczynnik 0,8) – rejestracja w `ee_walka`.
2. Reguła obrotu AoC 0x554738 (przycięcie przy Δ = 0) i koniec ruchu EE 500.
3. Rozkaz ataku przez MCP: kursor nad obiektem z kontrolą „obiekt pod kursorem” z pamięci, potem PPM; następnie
   utrata LOS (odwrót w trakcie walki z wyzwalaczem po pierwszym trafieniu, a nie po czasie) i przeszkoda.
4. Permutacja 0x40CFC7 z odczytem +0xB0 – kolejność kandydatów i remisy.
5. Dopiero potem statyka ataków dystansowych.

Commit i push na `main` zgodnie ze zleceniem; Riverlands_MCP i dane gry pozostają lokalne.
