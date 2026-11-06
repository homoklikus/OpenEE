# Raport – etap 10: wierne odtworzenie kamery oryginalnego Empire Earth

Data: 2026-11-06. Specyfikację pomiarów zawiera `docs/MECHANIKA_KAMERY_EE.md`. Poprzednie badanie opisuje
`RAPORT_KAMERA_EE_OPENEE.md`, a zmiany w MCP – `Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 14.

**Oznaczenia pewności:**
- **[P]** potwierdzone powtarzalnymi pomiarami;
- **[W]** wniosek z ograniczonych pomiarów;
- **[H]** przybliżenie OpenEE;
- **[N]** nieustalone.

## 1. Wyniki badań oryginalnej gry

Pomiary w EE: The Art of Conquest (GOG, Wine/DXVK, RTX 5090, okno 3440×1440), na trzech mapach: Riverlands
100×100 i 150×150 oraz „Wojna trojańska”. Metoda: odczyt pamięci plus zwykłe wejście. Wykonałem 14 zadań MCP
(146–159) oraz kadry porównawcze (160).

Najważniejsze ustalenia:

- **Orientacja stała w rozgrywce [P].** Azymut 135° i pochylenie 35° nie zmieniły się w żadnej próbie: strzałki,
  kółko (także z Shift, Ctrl, Alt), środkowy przycisk (także z modyfikatorami), krawędzie, 3 mapy. Własną, dowolnie
  obracaną kamerę mają tylko **przerywniki scenariusza**. We wstępie „Wojny trojańskiej” azymut zmieniał się od −55°
  do 166°. Esc przywraca kamerę rozgrywki.
- **Zoom [P].**
  - 21 poziomów, odległość 0,1–29,7, krok 1,49.
  - Zmiana natychmiastowa także w kopiach macierzy renderera (pierwsza próbka po 19 ms ma już nową wartość), więc
    obraz nie jest wygładzany.
  - Punkt pod kursorem i modyfikatory nie mają wpływu.
- **Strzałki [P].** 15 / 30 / 45 pól/s przy poziomach 0 / 10 / 20. Dwie strzałki sumują się (×√2), przeciwne się
  znoszą.
- **Krawędź ekranu [P] – zachowanie inne, niż zakładało pierwsze badanie:**
  - Nie ma strefy o stałej szerokości: kursor stojący 0–30 px od krawędzi nie przewija.
  - Przewijanie włącza dopiero pchanie myszy poza krawędź. Trwa, dopóki kursor zostaje na krawędzi, i ustaje po
    ruchu do wnętrza.
  - Prędkość wynosi 5/6 prędkości strzałek: zmierzone 12,6 / 24,9 / 37,2 pola/s.
  - Podczas przeciągania ramki zaznaczenia przewijanie jest wyłączone.
- **Środkowy przycisk myszy przesuwa kamerę [P] (nowe ustalenie):**
  - przesunięcie = Δ myszy × prędkość strzałek / 640;
  - w kierunku ruchu myszy;
  - kursor zatrzymany, bez bezwładności.
- **Granice [P].** Romb pól: x + y ∈ [N, 3N], x − y ∈ [−N, N]. Sprawdzone dla N = 100 i 150; kamera dochodzi do
  narożników.
- **Wysokość ogniska [P].** max(0, wysokość terenu) + 0,4. Ognisko nadąża za górami (do 4,3), a nad wodą zostaje na
  0,4. Wysokość terenu w EE bywa o ≤ 0,23 wyższa od interpolacji OpenEE [W].
- **Geometria.** Rzut perspektywiczny [P]. Poziomy kąt widzenia ≈ 48,4° [W]; pierwsze badanie podało 50,4°.
  Pionowo obraz EE jest ~21 px niżej niż w OpenEE [W].

## 2. Zmierzone parametry

| Parametr | Wartość | Pewność |
|---|---|---|
| Azymut, pochylenie | 135°, 35° | [P] |
| Poziomy zoomu | 21; odległość 29,7 − 1,49·(20 − p), poziom 0 = 0,1 | [P] |
| Prędkość strzałek | 15 + 30·p/20 pól/s | [P] |
| Prędkość krawędzi | 5/6 prędkości strzałek | [P] |
| Środkowy przycisk | 0,0235 / 0,0469 / 0,0703 pola na jednostkę myszy (p = 0 / 10 / 20) | [P] |
| Granice | x + y ∈ [N, 3N], x − y ∈ [−N, N] | [P] |
| Ognisko | max(0, h) + 0,4 | [P] |
| Kąt widzenia | 48,4° w poziomie (3440×1440) | [W] |
| Przesunięcie środka rzutu | ~21 px w dół | [W] |
| Kąt widzenia przy innych proporcjach | – | [N] |

## 3. Rozbieżności względem dotychczasowej kamery OpenEE

| Element | Przed etapem 10 | EE (pomiar) | Teraz |
|---|---|---|---|
| Krawędź | Strefa 3 px, prędkość strzałek | Pchanie poza krawędź, 5/6 prędkości, wyłączone przy ramce | Jak EE |
| Środkowy przycisk | Brak (tylko kamera diagnostyczna obracała) | Przesuwanie kamery | Jak EE (kursor ukryty na czas przeciągania [H]) |
| Ognisko nad wodą | Teren + 0,4 (pod wodą) | max(0, h) + 0,4 | Jak EE |
| Kąt widzenia | 50,4° | ≈ 48,4° | 48,4° |
| Ukos strzałek | Suma wektorów [N] | Suma wektorów [P] | Bez zmian, teraz potwierdzone |
| Obrót w rozgrywce | Brak (od etapu kamery) | Brak | Bez zmian |
| Wygładzanie zoomu | Brak [N] | Brak [P] | Bez zmian, teraz potwierdzone |

## 4. Zmiany w kodzie

**Faza A – MCP (poza repozytorium OpenEE; kopia i opis w § 14 raportu MCP):**
- `wejscie.py`: rejestr trzymanych klawiszy, zwolnienie w `finally`, kontrola X11, szybka aktywacja okna, `atexit`.
- `ee_kamera.py`: kontrola dryfu po zwolnieniu, `kam_zwolnij_klawisze`, nowe funkcje pomiarowe.
- `gra.py`: bezpieczne usuwanie (nazwa, wzorce, ścieżki, dowiązania, rejestr z SHA-256, podgląd).
- `server.py`: zmieniony opis narzędzia `gra_usun_scenariusz`.
- `ee_api.py`, `ee_async.py`, `ee_worker.py`: zwalnianie klawiszy po zadaniu i obsługa odmowy usunięcia.
- Testy: `test_zz_bezpieczenstwo.py` – 14 testów.

**Fazy C–E – OpenEE:**
- `godot/silnik/kamera/model_kamery_ee.gd`: prędkość krawędzi, przesunięcie środkowym przyciskiem, wysokość ogniska,
  kąt 48,4°, oznaczenia [P]/[W]/[H]/[N].
- `godot/sceny/kamera_rts.gd`:
  - stan przewijania krawędzią z ruchu myszy;
  - blokada przy ramce;
  - przeciąganie środkowym przyciskiem;
  - zamykanie kursora w oknie na pełnym ekranie [H];
  - ognisko nad wodą.
- `godot/silnik/symulacja/sterowanie_rts.gd`: informuje kamerę o przeciąganiu ramki.
- `godot/silnik/rdzen/konfiguracja.gd`: `--konfiguracja-domyslna` dla powtarzalnych renderów diagnostycznych. Wybory
  użytkownika w launcherze pozostają nietknięte.
- `godot/sceny/diag_modelu.gd`: opis (kąt z modelu).
- Kamera diagnostyczna (swobodny obrót) bez zmian. Działa tylko w trybie diagnostycznym (`--kamera-wolna`, podgląd
  scenariusza).

## 5. Wyniki porównania

Kadry EE i OpenEE przy identycznym ognisku i poziomie zoomu, na tej samej mapie (Riverlands, `etap9_pasy.scn`),
GPU RTX 5090 (Vulkan). Porównywałem położenia obiektów na obrazie (centroidy flag gracza i jednostek), nie piksele.
Zrzuty są lokalne, poza repozytorium.

| Kadr | Kąt 50,4° (przed): Δx [px] | Kąt 48,4° (teraz): Δx [px] | Δy [px] |
|---|---|---|---|
| Poziom 20: 5 jednostek + 3 flagi centrum miasta | +14 … +69 (obraz o 4–5% mniejszy) | +1 … +8 | −17 … −39 (stałe ~−21 [W]) |
| Poziom 10: 3 flagi centrum miasta | +27 … +41 | +3 … +6 | −18 … −24 |

Pozostałe punkty porównania:
- **Maksymalne przybliżenie (poziom 2):** kadry bez obiektów (sama trawa). Zgodność geometrii wynika z modelu
  odległości [P].
- **Przesunięcie o zadaną odległość, krawędzie mapy, ramka przy przewijaniu:** porównane liczbowo z pomiarami EE
  w testach automatycznych OpenEE (§ 6).
- **Modele na RTX 5090 (Vulkan):** stajnia, koszary, meczet i świerk (billboard), widok `--kamera-ee=8` przy kącie
  48,4°. Wyrenderowane bez błędów: arkada meczetu kompletna, impostor świerka zwrócony do kamery. Bezpośrednie
  porównanie skali z EE: pierwsze badanie (centrum miasta) i tabela powyżej.
- **Troja w scenie RTS (demo ruchu):** bez błędów, sterowanie i HUD działają.
- **Rendery programowe** w tym etapie nie były wykonywane. Zgodności z rendererem programowym nie deklaruję.

## 6. Wyniki testów

- **Godot: 247/247** (baza 230 + 17 nowych testów kamery K10), 0 pominiętych. Nowe testy sprawdzają:
  - prędkość krawędzi;
  - przesunięcie środkowym przyciskiem (wartości z EE);
  - wodę pod ogniskiem;
  - granice mapy 150×150;
  - brak strefy krawędzi;
  - włączenie pchaniem i trwanie bez ruchu myszy;
  - wyłączenie ruchem do wnętrza;
  - górną krawędź;
  - blokadę przy ramce;
  - przeciąganie środkowym przyciskiem i stan po zwolnieniu;
  - zoom niezależny od kursora;
  - ukos i znoszenie się strzałek;
  - stabilność przy 2000 losowych operacjach;
  - niezależność kamery od symulacji (ten sam skrót stanu);
  - sygnał ramki z SterowanieRTS do kamery.
- Testy ruchu grupowego, zaznaczania, kolejki, animacji, epok i przezroczystości (etapy 5–9) przechodzą bez zmian.
- **MCP: 35/35** (baza 21 + 14 testów bezpieczeństwa).

## 7. Problemy nierozwiązane

1. **Przesunięcie środka rzutu ~21 px w pionie [W].** Wymaga rzutu z przesuniętym środkiem (np. projekcja frustum
   w Godocie). Nie wprowadzone, bo przyczyna nie jest potwierdzona.
2. **Kąt widzenia przy innych proporcjach okna [N].** Pomiar wymaga zmiany rozdzielczości w opcjach gry
   użytkownika.
3. **Jednostka ruchu myszy [H].** Przyjąłem piksel Godota = jednostka DirectInput EE. Związku z fizyczną myszą nie
   zmierzyłem.
4. **Kursor w oknie zwykłym [H].** Kursor zamykam w oknie tylko na pełnym ekranie. W oknie wyjście kursora za okno
   przerywa przewijanie krawędzią, co różni się od EE.
5. **Kursor przy środkowym przycisku [H].** W OpenEE jest ukryty na czas przeciągania; w EE pozostaje widoczny
   i zatrzymany.
6. **Wysokość terenu w EE [W].** Bywa o ≤ 0,23 wyższa od interpolacji OpenEE; reguła wygładzania nieustalona.
7. **Przerywniki filmowe** (kamera skryptowa) – poza zakresem.
8. **Profil `vanilla_ee` z launchera** (obecny wybór w `uzytkownik.cfg`): `dbobjects` z EE 1.0 nie dekoduje się
   gramatyką AoC (błąd indeksu w `baza_db.gd`), a scena scenariusza nie ma wtedy obiektów. Ten błąd istniał przed
   etapem 10 i nie dotyczy kamery. Obejście diagnostyczne: `--konfiguracja-domyslna`. Wymaga osobnej naprawy
   dekodera dla EE 1.0.
9. `kam_ustaw` (MCP) po poprawce szybkiej aktywacji okna nie został jeszcze sprawdzony w grze.

## 8. Stan Git i publikacja

Lokalny `main` po etapie 10 (na `7498db0`, czyli stanie GitHuba):

1. `154ee8d` – Etap 10: badanie kamery oryginalnego EE (docs/MECHANIKA_KAMERY_EE.md)
2. `7195fe2` – Etap 10: kamera OpenEE według pomiarów EE
3. commit testów i raportów („Etap 10: testy kamery i raport”) – lokalny HEAD

Naprawy MCP leżą poza repozytorium OpenEE (Riverlands_MCP nie jest repozytorium Git). Opis i kopie: § 14 raportu
MCP, `kopie_OpenEE/Riverlands_MCP_przed_etapem10.tgz`.

Bez force push i bez przepisywania historii. Lokalnej zmiany `godot/project.godot` (dodatek Godot MCP) celowo nie
commitowałem.

**Publikacja (do wykonania przez użytkownika):**

```bash
cd "/media/precell/Inne/Projekty AI/EE Projekt/OpenEE"
git log --oneline origin/main..main      # 3 commity etapu 10
git push origin main
```
