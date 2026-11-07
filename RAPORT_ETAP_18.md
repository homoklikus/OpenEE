# OpenEE – raport etapu 18: przydział celów jednostkom w silniku Titan

Piąty etap rekonstrukcji kodu silnika Titan. Zakres: jak obsługa stanu grupy 8000 (EE 0x5DB641, AoC 0x5EBF85) robi ze
wspólnego celu grupy cele poszczególnych jednostek. Najprostsza ścieżka: jednostki lądowe, PPM na terenie, bez Shift.
Szczegóły: **`docs/titan/cele_jednostek.md`**.

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `c6d532c`, testy Godota 324/324.

## 1. Wynik

1. **Pozycje docelowe** (pytania 1, 2, 4) wyznacza obiekt szyku grupy, domyślnie **`EEFShortLine`** (RTTI w pamięci EE
   i AoC). Dla k-tej pozycji:
   - kolumna k mod 5 z przesunięciem [0, −1, +1, −2, +2] (środek, lewo, prawo, …);
   - rząd k div 5 leży **za** punktem celu (pusty rząd co 5 rzędów);
   - odstęp S = największe „Size in formation” w grupie;
   - pozycja = G + M(θ)·(S·przesunięcie, −rząd·S), gdzie θ to kąt rozkazu, a lokalna oś +y to kierunek ruchu.

   [P: kod; pomiar – zgodność do 10⁻⁴ pola w 4 rozkazach EE i AoC]
2. **Dobór jednostek do pozycji** (pytanie 3). Ścieżka daleka obowiązuje, gdy cel jest poza prostokątem otaczającym
   jednostki i dalej niż jego dłuższy bok.
   - Pozycje i jednostki są sortowane rosnąco według klucza k(p) = |a·y + b·x| + |0,1·b·y − 0,1·a·x|, gdzie (a, b) to
     kierunek środek jednostek → środek szyku, znormalizowany sumą modułów.
   - Następnie łączy się je w pary według kolejności.

   [P: kod; pomiar 3 jednostek – identyczny przydział w EE i AoC]. Ścieżka bliska (cel przy grupie) przydziela inaczej
   i nie była analizowana [N].
3. **Cele jednostek** (pytanie 5) to nowe obiekty `EEUGLocation` z pozycją szyku i kątem θ:
   - stają się bieżącym celem jednostki (+0x1F0), a jednostka dostaje stan 8000;
   - jednostka zapisuje numer pozycji (EE +0x298, AoC +0x29C) i obcięcie(4·numer/n) (EE +0x2DC, AoC +0x2E0).

   [P: kod i pomiar]
4. **EE ↔ AoC** (pytanie 6). Układ szyku i rdzeń przydziału są zgodne. Różnice:
   - przesunięcia pól;
   - w AoC `Unit type` 34 (myśliwiec kosmiczny) obsługiwany jak samolot;
   - dodatkowe warunki AoC przy nadawaniu celu.

   [P]

## 2. Weryfikacja

Zadania MCP, tylko odczyt pamięci: 384–391 (EE), 392–397 (AoC), scenariusz „Wojna trojańska”; pauza F3 po rozkazie.

| Rozkaz | Wynik |
|---|---|
| EE, 1 jednostka | cel jednostki = cel grupy, pozycja 0 [P] |
| EE, 3 jednostki (ścieżka daleka) | 3 pozycje i przydział dokładnie jak w modelu [P] |
| AoC, te same 3 jednostki | dokładnie jak w EE i w modelu [P] |
| EE, 6 jednostek (ścieżka bliska) | wszystkie 6 pozycji zgodne, w tym drugi rząd; przydział – inny algorytm [N] |
| AoC, 3 jednostki (ścieżka bliska) | pozycje zgodne [P] |
| pola +0x298/+0x2DC | zgodne z kodem dla 3 i 6 jednostek [P] |

**Ograniczenie.** Zaznaczanie ramką w Riverlands_MCP często obejmowało tylko część jednostek, więc nie powstały czyste
przypadki 2 i 5 jednostek. Wykorzystano zaznaczenia faktycznie odczytane z pamięci: 1, 3 i 6 jednostek. Nowego
narzędzia nie budowano.

## 3. Błędy oryginału

**BO-2 (podejrzenie):** klucz przydziału liczony od początku układu mapy z wartością bezwzględną. Dla grup przecinanych
prostą zerowego rzutu kolejność może się „złożyć”, a jednostki dostać pozycje na krzyż. Pewność: kod [W], skutek [H];
niemierzone. Status: zachować zgodność.

## 4. Przeszkody

1. Ścieżka bliska przydziału i gałąź specjalna (parametry +0xB6, +0x474) – [N].
2. Pochodzenie kąta θ w obsłudze kliknięcia – [W].
3. Szyki inne niż `EEFShortLine` (koło, klin, odmiany linii) – znane adresy, nieanalizowane.
4. Znaczenie +0x2DC, wartości +0x34 celu, typu ruchu 15 i lotniska – [N].

## 5. OpenEE (bez zmian w kodzie)

`FormacjaEE` (etap 9) odpowiada idei szyku. Do wiernego odtworzenia potrzebne są:
- kolejność kolumn (środek, lewo, prawo, …);
- rzędy za celem;
- odstęp = maksimum „Size in formation”;
- obrót o θ;
- pusty rząd co 5 rzędów;
- przydział sortowaniem według k(p) w ścieżce dalekiej, z BO-2.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/cele_jednostek.md` | nowy wpis atlasu Titan |
| `docs/titan/BLEDY_ORYGINALU.md` | BO-2 (podejrzenie) |
| `docs/titan/grupy_ruchu.md` | odnośnik do przydziału celów (granica etapu 17) |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 18, nowy aktualny raport |
| `RAPORT_ETAP_17.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 18”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_18.md` |

## 8. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
