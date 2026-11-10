# OpenEE – raport etapu 35: nowa metodologia eksperymentów, przyczyna niepowodzeń PPM i działający rozkaz ataku

Etap 35 zmienił metodę badawczą. Zamiast kolejnych prób klikania w tych samych warunkach powstał minimalny,
kontrolowany scenariusz `e35_a` i seria eksperymentów rozstrzygających. Każdy z nich eliminował jedną hipotezę.
Ustalono, że niepowodzenia etapów 32–34 miały **trzy niezależne przyczyny**:
- cel we mgle wojny;
- cel już martwy (zwłoki);
- błędny model rzutu kamery w Riverlands_MCP.

Po przejściu na rzut z pól kamery gry **rozkaz ataku gracza (EEUGAttackUnit) działa**. Potwierdziły to 3 kolejne
uruchomienia, w tym dawna procedura z etapu 32, która po samej poprawce rzutu zadziałała w pierwszej próbie.

Szczegóły:
- `docs/titan/dziennik_eksperymentow.md` – dziennik eksperymentów 602–618;
- `docs/titan/rozkazy_gracza.md` § 7–8;
- `docs/PLAN_REKONSTRUKCJI_TITAN.md` § 4.12.

**Oznaczenia:** [P] pomiar i kod; [W] wniosek ze statyki; [H] hipoteza; [N] nieustalone.
**Środowisko:** komputer główny użytkownika (Debian 13, KDE Wayland). Gra działa przez Wine w oknie XWayland
(3440 × 1440, okno X11 „Empire Earth”). Polecenia w maszynie roboczej Ubuntu 22.04. Proxmox – poza zakresem.

## 1. Stan początkowy i końcowy

| | Etap 34 (`43e577a`) | Etap 35 |
|---|---|---|
| Rozkaz ataku gracza przez MCP | nigdy nie uzyskany (etapy 32–34) | **działa**: 616, 617, 618 (3/3 uruchomienia z celem żywym i widocznym) |
| Przyczyna niepowodzeń PPM | [N] | **ustalona** [P]: mgła, zwłoki, rzut MCP |
| Rzut ekranowy MCP | model z etapu 7 (ogniskowa 3650, środek 720) | pola kamery gry (macierz +0x104, ogniskowa = +0x280 / +0x274, środek +0x288 / +0x28C) |
| Core | bez zmian | bez zmian (etap badawczy) |
| CTest Release / Debug | 20/20 / 20/20 | 20/20 / 20/20 |
| GDExtension / Godot | 23/23 / 324/324 | 23/23 / 324/324 |
| Riverlands_MCP | 15 plików | 16 plików (`test_ee_etap35.py`) |
| narzędzia Titan | 20/20 | 20/20 |
| S1–S7, 578 G1 | 68b0c69ecb8b0cbc, 986/986 | bez zmian |

## 2. Nowa metodologia

1. **Pytanie → przewidywanie → eksperyment rozstrzygający.** Każdy eksperyment ma w dzienniku pytanie, oczekiwany
   wynik i wyeliminowane hipotezy. Najpierw kontrola (np. LPM na własnej jednostce), potem cel właściwy.
2. **Najpierw dane, potem klikanie.** Przed nowymi próbami sprawdzono w istniejących nagraniach warunki poprzednich
   prób. Porównanie czasu PPM z czasem śmierci celu wykazało, że w 605–610 każde kliknięcie trafiło w zwłoki.
3. **Statyka ścieżki wejścia.** Odczytano warunki tworzenia komunikatu ataku w `EEAMouseClick` +0x0C:
   - wiersz dyplomacji lokalnego gracza;
   - kategoria obiektu;
   - HP > 0 → EEMAttackUnit (0x4C);
   - inaczej EEMPathTo.

   Każdy warunek sprawdzono pomiarem.
4. **Kontrolowana scena** zamiast scen walki: jednostki nieruchome, oddalone, widoczne przez obserwatora bez ataku
   (prorok – pole widzenia 8, atak 0).
5. **Weryfikacja wizualna:** zrzut okna z naniesionymi rzutami. Ujawnił, że model kamery MCP rozjeżdża się z obrazem.
   Pola kamery gry dały poprawny rzut.
6. **Limit 3 identycznych prób** – po trzech niepowodzeniach zmieniano warunek albo metodę.

## 3. Scenariusz, mapa i jednostki

`e35_a` to kopia scenariusza kampanii „Wojna trojańska” (SCN 231) z 8 jednostkami dopisanymi narzędziem
`narzedzia/eksperymenty/scenariusz_testowy_kolizji.py zbuduj` według `dane/testy_walki/e35_a.uklad_wej.json`.
Odtwarzalny bez ręcznej konfiguracji: plik SCN powstaje lokalnie z pliku kampanii i opisu układu.
- Gracz 1:
  - prorok-obserwator (pole widzenia 8, atak 0);
  - gwardia atakująca;
  - obywatel;
  - gwardia kontrolna.
- Gracz 5:
  - obywatel – cel widoczny;
  - gwardia – celowo poza polem widzenia, kontrola mgły;
  - bohater Aleksander;
  - dom.
- Odległości > 4 pola, więc nikt nie zaczyna walki sam.

Ograniczenia [N]:
- mapa nie jest całkowicie płaska (teren kampanii);
- bez wariantu dużej jednostki (np. słonia) i jednostki neutralnej;
- tylko EE – AoC nie badano.

## 4. Porównanie metod sterowania

| Metoda | Wynik |
|---|---|
| Riverlands_MCP (xdotool → XWayland, pętla zamknięta kursora z odczytem pozycji z pamięci gry) | kursor i przyciski docierają poprawnie [P]: PPM w teren daje ruch, LPM zaznacza; kursor gry w 0,5–5 px od celu |
| Rzut MCP z etapu 7 | chybia modele (612; zrzut 613: błąd do ~120 px w pionie przy zoomie 1) |
| Rzut z pól kamery gry (`walka_kamera_gry`, `walka_atak_rzut_gry`) | LPM zaznacza własną jednostkę (617), PPM tworzy EEUGAttackUnit (616, 617) |
| Dawna procedura `walka_atak` z poprawionym `ee_kamera.rzut` | EEUGAttackUnit w 1. próbie (618) |
| Ręczne kliknięcie użytkownika | nieużyte – niepotrzebne po ustaleniu przyczyny |

## 5. Przyczyna problemów MCP

1. **Mgła wojny** (602–604, 612–617: gwardia 0x5000ad1): obiekt spoza listy renderu kamery nie może być wybrany [P].
2. **Zwłoki** (605–610): PPM wykonano po śmierci celu. Zwłoki są na liście renderu, a dla HP ≤ 0
   `EEAMouseClick` tworzy EEMPathTo (0x4044CD) [P: kod i nagrania].
3. **Rzut MCP** (612, wcześniejsze): ogniskowa 3650 zamiast 3844 i środek pionowy 720 zamiast 672 (pasek
   interfejsu 42 px, widok 1302 px). Do tego oko i osie liczone z modelu.

Hipoteza dyplomacji – obalona (611: gracz 1 → 5 = wróg). Hipoteza zasłonięcia przez sąsiada (etap 34) przestała
być potrzebna. Nie badano jej osobno [N].

## 6. Status rozkazu EEUGAttackUnit

**Działa** [P]: 616 (próba 3), 617 (próba 1), 618 (próba 1, dawna procedura). Cel: wrogi obywatel, żywy, widoczny,
samotny.

Otwarte [N]:
- wrogi bohater – kolejka pusta w chwili odczytu, cel przypisany później (616);
- obywatel na wrogim domu → EEUGGather;
- AoC (adresy kamery i myszy znane: 0x928D78, [0x931924]) – nie sprawdzano.

## 7. Metoda bez klikania (priorytet C)

Powtarzalna metoda istnieje i jest udokumentowana [P]:
1. scenariusz generowany z opisu układu (`scenariusz_testowy_kolizji.py zbuduj`, gracz, typ wzorca, pozycje);
2. walka rozpoczynana przez AI:
   - jednostki ustawione w polu widzenia albo wprowadzone w nie rozkazem ruchu (PPM w teren, `obs_rozkaz`);
   - dalej wyzwalacz stanem (`walka_czekaj_na_stan`, etap 33).

Metodą tą powstały pomiary 578–610. To badanie zachowania AI, nie wejścia gracza. Wyzwalaczy edytora scenariuszy EE
w tym etapie nie badano [N].

## 8. Eksperymenty fizyki i walki

- Śmierć celu → 2025 → Idle (etap 34, potwierdzone ponownie w 616/617 przy pościgu za uciekającym obywatelem): po
  ataku gracza obywatel ucieka, a gwardia cyklicznie traci i odzyskuje cel co około 8 s (616: 6 par nowy cel /
  utrata) [P]. Analiza tego pościgu w Core – etap 36.
- Priorytet D (578 G3, 590, 580, 505, 500) – **bez nowych ustaleń** w tym etapie. Czas przeznaczono na
  przełamanie impasu PPM, który blokował scenariusze C [N].

## 9. Pierwsze rozbieżne takty

Bez zmian względem etapu 34:

| Przypadek | Pierwszy rozbieżny takt |
|---|---|
| 578 G1 | brak w oknie |
| 578 G3 | 169 |
| 590 G1 | 97 |
| 580 G1 | 57 / 146 |
| AoC 505 | 803 |
| EE 500 | koniec +1 |

## 10. Regresja

- CTest Release i Debug 20/20, GDExtension 23/23, Godot 324/324.
- Riverlands_MCP 16/16 plików, narzędzia Titan 20/20.
- S 68b0c69ecb8b0cbc, 578 G1 986/986.
- Core bez zmian, więc pomiary porównawcze bez zmian.

## 11. Prognoza do pierwszej grywalnej potyczki

Zależności (co blokuje co):
- **Sterowanie oryginałem przez MCP** odblokowane. Scenariusze C (rozkaz ataku, przerwanie ruchem, zmiana celu,
  pościg, utrata LOS) są teraz wykonalne w 1–2 etapach.
- **Walka wręcz w Core** zgodna co takt w pojedynku (578 G1). Do domknięcia: walka wielu jednostek (578 G3 / 590 –
  kolejność fizyki przy ruchomym celu) i RNG AoC.
- **Strzelcy i pociski** – tylko mapa statyczna; implementacja po pomiarach (1–2 etapy).
- **Potyczka** wymaga dodatkowo integracji Core z Godotem i sterowania (lista niżej). To osobna ścieżka,
  równoległa do zgodności walki.

## 12. Brakujące elementy pierwszej grywalnej potyczki

**Mechanika symulacji (Core):**
- walka wręcz wielu jednostek z pełnym .tai walki – częściowo, rozbieżności 578 G3 / 590;
- jednostki dystansowe i pociski – brak;
- graf podsektorów A* dla dalekich tras – brak (tylko A* po polach);
- grupy i szyk – brak;
- mgła wojny i widoczność jako system świata – częściowo (warunki wykrycia [W]);
- śmierć, zwłoki, usuwanie z mapy – częściowo (stan 6000);
- warunek zwycięstwa (zniszczenie wszystkich jednostek) – brak;
- budynki z efektami (morale) – jest; produkcja, ekonomia i epoki – poza zakresem pierwszej potyczki.

**Integracja z Godotem:**
- GDExtension wystawia `Swiat` (ruch, walka – test 23/23). Brak sceny potyczki, która co klatkę czyta migawkę
  Core i synchronizuje węzły jednostek (pozycja, orientacja, animacja ataku i śmierci);
- brak ładowania parametrów typów (`ParametryRuchu`, `ParametryWalki`) z bazy gry. Dziś pochodzą z pomiarów.

**Sterowanie jednostkami:**
- zaznaczanie (klik i ramka) w Godocie, PPM → `rozkaz_ruchu` / `rozkaz_ataku`, Shift (kolejka);
- przeniesienie reguł `EEAMouseClick` (rozdział 8): kategorie, dyplomacja, HP > 0, mgła.

**Renderowanie i interfejs:**
- modele i animacje jednostek z CEM w scenie (importery istnieją);
- koła zaznaczenia, paski HP, kursor ataku, minimapa i mgła – brak w scenie potyczki.

**Dane i zasoby testowe:**
- scenariusz potyczki (np. `e35_a`-podobny, dwie armie po kilka jednostek) jako dane wejściowe Core i Godota;
- tabele obrażeń i wag celu z bazy gry zamiast z odczytu pamięci;
- pomiary referencyjne potyczki z oryginału przez MCP – teraz możliwe dzięki etapowi 35.

## 13. Rekomendacja etapu 36

1. Scenariusze C 1, 3–9 na `e35_a` z rozkazem ataku gracza (`walka_atak_rzut_gry`) i porównanie co takt z Core.
   Zacząć od pościgu za uciekającym obywatelem (616).
2. Priorytet D: 578 G3 takt 169 i 590 takt 97 – kontrolowana para „jednostka w ruchu + cel nieruchomy” na `e35_a`.
3. Sprawdzenie AoC (te same narzędzia, adresy kamery AoC).
4. Równolegle: scena potyczki w Godocie z migawką Core i sterowaniem (rozdział 12).
