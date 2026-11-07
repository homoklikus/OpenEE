# OpenEE – raport etapu 14: rekonstrukcja zegara symulacji Titan

Pierwszy etap systematycznej rekonstrukcji kodu silnika Titan. Zakres: wyłącznie mechanizm aktualizacji licznika
czasu gry `A_GRA+0xD0` i liczników taktów `+0xB4`, `+0xC8` w Empire Earth i The Art of Conquest. Szczegóły:
**`docs/titan/zegar_symulacji.md`**.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem albo kodem jednoznacznym w obu plikach;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `a15b8dd`, testy Godota 324/324.

## 1. Wynik

Czas gry w oryginale to **liczba wykonanych taktów × stały krok**, liczony w akumulatorze zmiennoprzecinkowym [P]:

- `A_GRA` wskazuje obiekt klasy **`EEPhysics`** (RTTI w obu plikach).
- Krok czasu gry na takt: `+0x98 = 1000 · G / n` ms, gdzie:
  - `n` – nominalna liczba taktów na sekundę rzeczywistą, przekazywana w komunikacie taktów;
  - `G` – szybkość gry (`GRA_STAT+0xC0`, `G = 0,1 · k + 0,1`).

  W działającej grze: **n = 44, G = 1,5**, czyli **34,0909 ms** na takt [P: pamięć obu gier].
- Każdy takt dodaje krok do `+0x94` (f32, ms gry) i zapisuje `+0xD0 = obcięcie(+0x94)`, stąd skoki 34/35 ms
  (68 ms na 2 takty z etapu 13). Potem zmniejsza liczbę oczekujących taktów `+0xB8` i, po aktualizacji świata,
  zwiększa licznik taktów `+0xB4` [P].
- `+0xC8` nie jest licznikiem całkowitym: to licznik taktów w oknie statystyki czasu wykonania, zerowany po
  1000 ms sumarycznego czasu taktów [P].
- Takty wyzwala wątek klasy bazowej z timerem `TMTimer` (interwał floor(1000/n) = 22 ms). Na każde zdarzenie wątek
  woła funkcję taktu najwyżej dwa razy (`+0x5C` ≈ 45,5/s). Takt wykonuje się tylko wtedy, gdy wcześniej
  przyszedł komunikat przydzielający takty [P].
- **Pauza F3:** nie przychodzą nowe przydziały taktów; już przydzielone (do ~11) dokańczają się, potem zegar
  stoi [P: pomiar obu gier].
- **Tempo 1,461 z etapu 13:**
  - nominalnie czas gry płynie G = **1,5** raza szybciej niż rzeczywisty;
  - w pomiarze wykonuje się 42,68–42,86 zamiast 44 taktów/s (97,0–97,4%), stąd 1,461 [P];
  - przyczyna niedoboru taktów leży u nadawcy komunikatów taktów [N].

## 2. Funkcje (EE / AoC)

| Funkcja | EE | AoC |
|---|---|---|
| wątek symulacji (klasa bazowa) | 0x5532FB | 0x56140C |
| takt `EEPhysics` (vtable +0x20) | 0x546C63 | 0x553082 |
| obsługa komunikatu taktów | 0x5470B0 | 0x55355C |
| ustawienie n i timera | 0x553663 | 0x561774 |
| przeliczenie kroku (vtable +0x0C) | 0x5476C1 | 0x553BD8 |
| reset zegara | 0x54650E | 0x552909 |
| `__ftol2` | 0x53BA92 | 0x548291 |
| G = 0,1 · k + 0,1 | 0x5AD53F | 0x5BD897 |

**Porównanie EE ↔ AoC** – instrukcja po instrukcji, adresy bezwzględne zastąpione symbolem, z wyrównaniem
sekwencji:
- wątek, obsługa komunikatu, ustawienie n, przeliczenie kroku, takt alternatywny i `__ftol2` są **identyczne**;
- w funkcji taktu instrukcje zegara są identyczne. Różni je tylko alokacja rejestrów i dodatkowy blok AoC
  (jednorazowy komunikat zależny od czasu gry, flaga `+0xE8`), który zegara nie zmienia;
- reset zeruje te same pola w innej kolejności.

Algorytm zegara jest w obu grach ten sam [P].

## 3. Weryfikacja wobec etapu 13

| Pomiar etapu 13 | Wyjaśnienie | Status |
|---|---|---|
| `+0xD0` 1460,7–1461,5 ms/s, krok 68 na 2 takty | 34,0909 ms/takt × 42,86 taktu/s; obcięcie f32 | zgodne [P] |
| `+0xB4` 43,32/s | 42,68/s ze znaczników `TMGetTime` w obiekcie (215 taktów / 5037 ms); 43,32 pochodziło z okna < 1 s | doprecyzowane |
| `+0xC8` „takty 43,32/s” | licznik okna statystyki, zerowany | wyjaśnione [P] |
| `+0x5C` 45,5/s | wywołania funkcji taktu, 1000/22 = 45,45/s | wyjaśnione [P] |
| pauza F3 zatrzymuje zegar | brak nowych przydziałów taktów | wyjaśnione [P] |
| czas gry = 1,461 × rzeczywisty | G = 1,5 nominalnie; 97% taktów wykonanych | wyjaśnione częściowo (przyczyna niedoboru [N]) |

**Dodatkowe eksperymenty:** jedno zadanie na grę, tylko odczyt (zadania 360/362). Odczytano obiekt `EEPhysics` i G
w pięciu chwilach: ruch, ruch, pauza, pauza, po wznowieniu. Pomiarów prędkości i kolizji nie powtarzano.

## 4. OpenEE – rozbieżności i proponowana poprawka (nie wprowadzona)

`ZegarSymulacji`/`Symulacja` używają kroku 0,05 s czasu rzeczywistego (20 taktów/s, [H]) i stałej
`MNOZNIK_PREDKOSCI = 1,461`. Oryginał ma inną konstrukcję:
- 44 takty/s;
- krok w czasie gry G/n;
- szybkość gry G;
- licznik czasu gry w ms;
- pauza przez wstrzymanie przydziału taktów.

Proponowana poprawka (`docs/titan/zegar_symulacji.md` § 7):
- `KROK_GRY = G/n` (n = 44, G domyślnie 1,5);
- 44 takty/s;
- prędkość na takt = `Speed` × `KROK_GRY`, bez osobnego mnożnika;
- licznik czasu gry jak w oryginale.

Do decyzji: odtwarzać algorytm (1,5) czy zmierzone tempo pod Wine (1,461). Zalecam algorytm.

## 5. Przeszkody i zakończone wątki

1. **Nadawca komunikatów taktów** (typ 0x28, kolejka `EEPhysics+4`). Nie ustalono, kto go wysyła, skąd bierze n = 44
   i liczbę taktów ani gdzie sprawdza pauzę. To prawdopodobnie warstwa komend/sieci (lockstep także w grze
   jednoosobowej) [H]. Wątek zakończony zgodnie z ograniczeniem zakresu; kandydat na kolejny fragment atlasu.
2. Nazwa klasy bazowej z wątkiem i timerem [N]. Warunek budżetu wywołań `+0x60` ustalono częściowo [W].
3. Powiązanie k = 14 z ustawieniem szybkości w interfejsie gry [N].
4. Akumulator f32 (+0x94): przy długich grach (po ~4,7 h czasu gry, 2^24 ms) rośnie błąd zaokrąglenia kroku. To wniosek
   z typu danych [W], niezmierzony.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/zegar_symulacji.md` | nowy – wpis atlasu Titan (adresy EE/AoC, struktury, algorytm, pewność, weryfikacja, porównanie z OpenEE) |
| `docs/titan/README.md` | tabela ustalonych miejsc w kodzie uzupełniona o zegar |
| `docs/ARCHITEKTURA_OPENEE.md` | zegar w mechanikach rozpoznanych; nadawca komunikatów taktów w nierozpoznanych |
| `docs/MECHANIKA_PREDKOSCI_EE.md` | adnotacja: algorytm zegara i doprecyzowanie częstotliwości taktów |
| `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | etap 14, nowy aktualny raport, `RAPORT_PORZADKI_ETAP_13_5.md` w archiwum |
| `dane/launcher/aktualnosci.json` | nowa aktualność „Etap 14”, ścieżka poprzedniego raportu w archiwum |
| `CLAUDE.md` | stała zasada: aktualizacja aktualności launchera przy kończeniu etapu |

Kod gry, silnika i MCP – bez zmian. Kod Riverlands_MCP – bez zmian; użyto istniejących kroków `pamiec_u32`,
`start_testowy`, `sprzataj_scenariusze`.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Linki aktualności (testy L aktualności) | najnowszy wpis = `RAPORT_ETAP_14.md`, poprzednie w `raporty/archiwum/` |

## 8. Commit i publikacja

Jeden commit na `main`, lokalnie. Publikacja z komputera użytkownika:
```
cd "/media/precell/Inne/Projekty AI/EE Projekt/OpenEE"
git push origin main
```
Po publikacji link aktualności do `RAPORT_ETAP_14.md` zacznie działać na GitHubie.
