# OpenEE – raport etapu 20: gałąź specjalna przydziału pozycji w silniku Titan

Siódmy etap rekonstrukcji kodu silnika Titan. Zakres: warunek w obsłudze stanu grupy 8000 (EE 0x5DB641, AoC 0x5EBF85)
zależny od grupy +0xB6, grupy +0x70 i pola typu +0x474 / +0x178 – kiedy działa, co robi i jak łączy się
z przydziałem bliskim i dalekim. Szczegóły: **`docs/titan/przydzial_specjalny.md`**.

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `e625a3b`, testy Godota 324/324.

## 1. Wynik

1. **Warunek wejścia** (pytanie 1), kolejno [P: kod]:
   - grupa +0xB6 ≠ 0 (u8);
   - największe „Size of collider” jednostek (EE +0x474, AoC +0x178, f32) < 1,0;
   - grupa +0x70 (f32) > 0,5.

   Niespełnienie któregokolwiek prowadzi do zwykłego wyboru ścieżki bliskiej albo dalekiej.
2. **Znaczenie pól** (pytania 2–3) [W: kod, wartości P]:
   - +0xB6 to flaga „ruch w szyku”: przy niej grupa podaje jednostkom wspólne parametry ruchu;
   - +0x70 to pierwszy z tych parametrów – średnia prędkość jednostek, ograniczona do 2,0 · najmniejszej (mnożnik
     z tablicy reguł);
   - +0x474 to „Size of collider”: gałąź działa tylko dla jednostek o kolizji < 1,0.
3. **Kiedy +0xB6 = 1.** Rozkaz PPM wydany **przeciągnięciem**:
   - `EEUICCommandUnits` zapamiętuje przekroczenie progu przeciągnięcia (+0xB9);
   - przy zwolnieniu przekazuje je do `EEMPathTo`+0x1F;
   - stamtąd trafia do celu grupy (+0x33) i do flagi grupy +0xB6.

   Zwykłe kliknięcie daje 0 [P: kod i pomiar]. Rozładunek transportu (stan grupy 12001) ustawia +0xB6 = 1 inną
   drogą [W].
4. **Operacje** (pytania 4–6). Gałąź nie liczy niczego nowego, tylko skacze do wspólnego nadawania celów
   (EE 0x5DC6B5, AoC 0x5ECFF2) z pominięciem przydziału bliskiego i dalekiego. Zostaje przypisanie zapisane wcześniej
   przez układ szyku: **jednostka k grupy → pozycja k**. Geometria szyku i nadawanie celów się nie zmieniają [P].
5. **EE ↔ AoC** (pytanie 7). Warunek, stałe, pola grupy i droga flagi są identyczne. Różnice:
   - pole typu;
   - w AoC dwa dodatkowe `Unit type` (0x1F, 0x21), dla których interfejs śledzi przeciągnięcie.

   [P]
6. **Przy okazji:** kąt szyku θ to atan2(−Δx, Δy) od środka zaznaczenia do punktu kliknięcia, a przy przeciągnięciu –
   z wektora przeciągnięcia (0x64138B) [W]. To zamyka otwarty punkt etapu 18.

## 2. Weryfikacja

Najpierw sprawdzono statycznie, kto może uruchomić gałąź:
- jednostki lądowe z kolizją < 1,0 (gwardia, Aleksander, prorok, obywatele);
- dowolny rozkaz PPM z przeciągnięciem.

Zadania MCP 418–424 (EE 418–421, AoC 422–424), tylko odczyt pamięci. Przeciągnięcie wykonano istniejącym krokiem
`kam_przeciagnij` z prawym przyciskiem.

| Zadanie | Warunek | Wynik |
|---|---|---|
| EE 419, 6 jednostek, przeciągnięcie | +0xB6 = 1, kolizja 0,55, +0x70 = 0,6167 z wzoru (odczyt po rozejściu: 0,6) | pozycje 0–5 = kolejność grupy; model bliski daje inny przydział, a żadna z 720 kolejności wyboru nie daje wyniku [P] |
| AoC 423, te same jednostki | jw. | to samo [P] |
| EE 420, 5 obywateli, przeciągnięcie (kontrola) | +0xB6 = 1, ale +0x70 = 0,5 | zwykły przydział bliski, dokładnie jak model (1 ze 120 kolejności) [P] |
| Etap 19 (402–415), kliknięcia bez przeciągnięcia (kontrola) | +0xB6 = 0 | przydział bliski [P] |
| EE 421, cel grupy po przeciągnięciu | – | `EEUGLocation`, +0x33 = 1, θ z kierunku przeciągnięcia [P] |

**Ograniczenia.**
- Krok przeciągnięcia czeka ok. 0,6 s przed pauzą, więc część jednostek doszła do celu i opuściła grupę. Dowodem
  przydziału są numery pozycji (+0x298 / +0x29C) i końcowe położenia.
- Kolejność grupy przyjęto jak zmierzona w etapie 19 (według ID).
- Przypadku z kolizją ≥ 1,0 i rozładunku transportu nie mierzono – tylko kod.

## 3. Błędy oryginału

Bez nowego wpisu. Pominięcie przydziału przy ruchu w szyku i próg „> 0,5” wyglądają na zamierzone (zachowanie kolejności
szyku). Skutek uboczny w postaci krzyżowania tras jest możliwy, ale to tylko hipoteza [H]. BO-1, BO-2 i BO-3 bez zmian.

## 4. Przeszkody i niewiadome

1. Wartość globalna progu przeciągnięcia (EE 0x9197A4 → +0x0C · 0,02) [N].
2. Obiekt jednostka+0x34 (parametry ruchu jednostki; prorok 0,5 mimo prędkości typu 0,45) [N].
3. Mnożnik +0xB0 z tablicy reguł i pełna lista `Unit type` w `EEUICCommandUnits` [N].
4. Wpływ +0xB6 na ruch w kolejnych taktach i stan 12001 – poza zakresem.

## 5. OpenEE (bez zmian w kodzie)

Do wiernego odtworzenia potrzebne są:
- rozkaz PPM z przeciągnięciem: flaga „ruch w szyku” i kąt z kierunku przeciągnięcia;
- w stanie 8000, przed wyborem ścieżki: przy +0xB6, maks. kolizji < 1,0 i +0x70 > 0,5 przypisanie w kolejności grupy;
- +0x70 = min(średnia, 2,0 · minimum) prędkości jednostek.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/przydzial_specjalny.md` | nowy wpis atlasu Titan |
| `docs/titan/cele_jednostek.md`, `docs/titan/przydzial_bliski.md` | odwołania, § „Gałąź specjalna — etap 20”, adnotacje „[Etap 20 – …]” |
| `docs/titan/grupy_ruchu.md`, `docs/titan/rozkazy_gracza.md` | adnotacje: +0xB6, +0x70…+0xAC (z jednostki, nie z gracza), `EEMPathTo`+0x1F |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 20, nowy aktualny raport |
| `RAPORT_ETAP_19.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 20”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_20.md` |

## 8. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
