# OpenEE – raport etapu 21: kolejka rozkazów ruchu i Shift w silniku Titan

Ósmy etap rekonstrukcji kodu silnika Titan. Zakres: jak Titan przechowuje, dopisuje, uruchamia i usuwa cele jednostki
przy rozkazach ruchu do punktu, czyli przy zwykłym PPM, Shift + PPM i zwykłym PPM w trakcie kolejki. Pojedyncza
jednostka lądowa. Szczegóły: **`docs/titan/kolejka_rozkazow.md`**.

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `411d104`, testy Godota 324/324.

## 1. Wynik

1. **Struktura kolejki** (pytanie 1). Jednostka +0x90 to wektor poziomów celów (+0x94 / +0x98, element 0x28 B).
   - Zwykła jednostka lądowa ma jeden poziom.
   - Poziom to kolejka dwustronna wskaźników do celów: mapa bloków, indeks pierwszego, liczba elementów
     (+0x14), właściciel (+0x18).
   - **Pierwszy element = cel bieżący** (jednostka +0x1F0).
   - Jednostka +0x1EC wskazuje pierwszy cel, który nie jest punktem trasy.

   [P: kod i pomiar EE, AoC]
2. **Dopisanie** (pytania 2–4). Przy Shift (grupa +0xB5 = 1) jednostka, która **ma** cel, dostaje swój cel z szyku
   **na koniec** kolejki (0x4412D4). Stan jednostki się nie zmienia, a cel ma +0x34 = 0 i +0x1D = 0. Jednostka bez celu
   traktuje Shift jak zwykły rozkaz [P].
3. **Następny cel** (pytania 5–6). Wejście w stan 5000 („Idle”) po dojściu wywołuje 0x5EAE25(0):
   - zdjęcie celu bieżącego;
   - aktywacja następnego (`EEUGLocation` vtable +0x54 → stan 8000 „PrepareToMove”).

   [P: pomiar A → B → C; W: punkt przekazania w kodzie]. Punkty pośrednie trasy (+0x32 = 1) trafiają na początek
   kolejki przed oczekujące rozkazy [P: pomiar].
4. **Zwykły PPM w trakcie kolejki** (pytanie 7):
   - zdjęcie celu bieżącego z aktywacją następnego;
   - wyczyszczenie całej kolejki;
   - nowy cel na początek;
   - stan 8000.

   W kolejce zostaje tylko nowy cel [P].
5. **Przypadki brzegowe** (pytanie 8):
   - pusta kolejka po ostatnim celu: „Idle”, +0x1F0 = 0, zgłoszenie bezczynności [P/W];
   - Shift na stojącej jednostce = zwykły rozkaz [P];
   - cel w miejscu jednostki: aktywacja od razu przechodzi do „Idle” i następnego celu [W].
6. **Takty** (pytanie 9). Zmiany kolejki od rozkazów zachodzą w poleceniu gracza przed taktami porcji. Przejście do
   następnego celu zachodzi w takcie wejścia w „Idle” [W].
7. **EE ↔ AoC** (pytanie 10). Funkcje kolejki identyczne. W AoC inne gałęzie wokół (lotnisko, typy ruchu) oraz nakładka
   `EEUCLand` vtable +0x74 [P].
8. **Przy okazji:** w EXE są tablice nazw stanów i zdarzeń jednostek, np. 8000 „PrepareToMove”, 10003 „Advance”,
   5000 „Idle”, 9006 „TurnToUnitFacing” (EE 0x617C34, 0x618E11) [P]. Ułatwią dalsze etapy.

## 2. Weryfikacja

Zadania MCP 425–442 (EE 425–436, AoC 437–442), tylko odczyt pamięci. Gwardia 0x100018B, scenariusz „Wojna trojańska”,
pauza F3 przed odczytami. Odczytywano jednostkę, poziom 0, mapę bloków i obiekty celów.

| Przypadek | Wynik |
|---|---|
| EE: PPM A, Shift B, Shift C | [A, B, C] w tej kolejności; A bieżący (+0x34 = 4, +0x1D = 1), B i C (0, 0) [P] |
| EE: dojście do A, B, C | A zdjęty, dwa punkty trasy na początku, potem [B, C] → [C] → pusta; stan 10003 → 5000 [P] |
| EE: Shift na stojącej jednostce | jeden cel, ruch od razu – jak zwykły rozkaz [P] |
| EE: zwykły PPM w trakcie kolejki | tylko nowy cel [P] |
| AoC: PPM A, Shift B, Shift C; potem zwykły PPM | ta sama kolejka; po zwykłym PPM tylko nowy cel [P] |

**Ograniczenia.**
- Kliknięcia trafiały w inne pola niż żądane, dlatego cele odczytywano z pamięci.
- Jednostka omijała przeszkodę długą trasą. Punkty trasy widać w kolejce, ale ich tworzenia nie badano.
- Celu w miejscu jednostki nie mierzono.
- Pusty plik zadania 432 został w kolejce Riverlands_MCP jako „w toku” (bez wpływu na wyniki, poza repozytorium).

## 3. Błędy oryginału

**BO-4 (podejrzenie, nowy wpis):** zwykły rozkaz najpierw aktywuje następny cel z kolejki, a dopiero potem czyści
kolejkę.
- Kolejność wywołań [P: kod EE i AoC].
- Skutki uboczne (dodatkowe przejścia stanu, możliwe zgłoszenie bezczynności) [H]. W pomiarach wynik końcowy był
  poprawny.
- Status: zachować zgodność.

BO-1, BO-2, BO-3 bez zmian.

## 4. Przeszkody

1. Warunek przejścia stanów ruchu do „Idle” (tolerancja dojścia) – podsystem ruchu, poza zakresem [N].
2. Znaczenie +0x34 celu i chwila ustawienia +0x1D przy aktywacji [N].
3. Wyjątek dla obywateli przy wejściu w „Idle” [N].
4. Dalszy los grupy przy Shift, gdy wszystkie jednostki mają cele [N].

## 5. OpenEE (bez zmian w kodzie)

Do wiernego odtworzenia potrzebne są:
- kolejka celów z celem bieżącym na początku i osobnym wskazaniem bieżącego rozkazu (+0x1EC);
- Shift: dopisanie na koniec tylko jednostkom z celem;
- zwykły rozkaz: zdjęcie z aktywacją następnego (BO-4), wyczyszczenie, nowy cel, stan 8000;
- przejście do następnego celu przy wejściu w „Idle”;
- punkty trasy wstawiane na początek kolejki.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/kolejka_rozkazow.md` | nowy wpis atlasu Titan |
| `docs/titan/BLEDY_ORYGINALU.md` | BO-4 (podejrzenie) |
| `docs/titan/cele_jednostek.md`, `docs/titan/grupy_ruchu.md` | adnotacje „[Etap 21 – …]”: czyszczenie i dopisywanie celów, znaczenie +0xB5 w stanie 8000 |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 21, nowy aktualny raport |
| `RAPORT_ETAP_20.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 21”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_21.md` |

## 8. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
