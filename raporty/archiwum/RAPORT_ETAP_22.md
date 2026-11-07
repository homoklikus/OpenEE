# OpenEE – raport etapu 22: wejście do systemu nawigacji Titan

Dziewiąty etap rekonstrukcji kodu silnika Titan. Zakres: przejście od celu `EEUGLocation` i stanu „PrepareToMove” do
prośby o trasę oraz droga wyniku do kolejki celów jednostki (punkty pośrednie +0x32). Algorytm wyszukiwania pozostaje
poza zakresem. Szczegóły: **`docs/titan/nawigacja_wejscie.md`**.

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `a343eed`, testy Godota 324/324.

## 1. Wynik

1. **Dwa poziomy tras** (pytania 1–3, 6) [W: kod; P: skutki w pomiarze].
   - **Grupowa.** Po nadaniu celów obsługa stanu grupy 8000 woła vtable +0x44 / +0x40 (EE 0x5DB4B8). Jednostki dzielą
     się na podgrupy i dla każdej powstaje prośba do `EEPathManager` (EE 0x4A15E7, AoC 0x4A6948): z pola startowego
     do pola celu grupy, z listą jednostek.
   - **Jednostki.** Wejście w „PrepareToMove” (EE 0x6222A8, AoC 0x63674B) wysyła prośbę z pola jednostki (+0x1C,
     +0x20) do pola celu (0x4A1AFF). Wynik zostaje w danych ruchu jednostki, nie w kolejce celów.
2. **Start i cel** (pytanie 4). Pola mapy (int x, y): start z pierwszej jednostki podgrupy albo z jednostki, cel to
   punkt celu obcięty do pola [P: kod; W: pole startowe podgrupy].
3. **Natychmiast czy w taktach** (pytanie 5). Menedżer uruchamia wyszukiwanie od razu.
   - Gdy wyszukiwanie się skończy, wynik jest dostępny i grupa stosuje go w tym samym wywołaniu.
   - Gdy nie, prośba trafia do kolejki menedżera, a grupa sprawdza ją w swojej aktualizacji (vtable +0x34 → +0x3C).

   [W]. W pomiarach wynik był zawsze natychmiastowy: znacznik +0x34 = 4 już przy pierwszym odczycie, pusta mapa
   oczekujących [P].
4. **Bez przeszkód / krótka trasa** (pytanie 7). Brak celów +0x32. Cel gracza dostaje +0x34 = 4, a ruch prowadzi
   trasa jednostki. Tak było też przy długim obejściu [P].
5. **Punkty pośrednie** (pytania 8–10). `EEGroup` vtable +0x38 (EE 0x5F6809):
   - zamienia węzły trasy (bez pierwszego i ostatniego) na środki pól, przesunięte szykiem;
   - 0x5EDF6B (AoC 0x5FC0A8) tworzy z nich `EEUGLocation` z +0x32 = 1;
   - wstawia je na początek kolejki, od ostatniego, więc w kolejce stoją we właściwej kolejności;
   - pomija do 3 punktów przy jednostce;
   - nie dodaje nowych, gdy na początku stoi już punkt.

   [W: kod; P: pomiar]. Wynik prośby to `EEAutoPathRequest`+0x08 – wektor pól po 8 B, gotowość +0x4C [W].
6. **Kolejka** (sekcja 3 zlecenia).
   - Punkty pojawiają się naraz.
   - Cel gracza zostaje osobnym elementem i wskazuje go +0x1EC.
   - Zwykły rozkaz usuwa wszystkie punkty.
   - Pierwszy punkt bywa zdejmowany daleko przed osiągnięciem (mechanizm ruchu – [N]).

   [P]
7. **EE ↔ AoC.** Funkcje grupowe i menedżera są identyczne. „PrepareToMove” w AoC leży w innym slocie vtable, testuje
   inne flagi typu i przekazuje dodatkowy argument [P].
8. **Przy okazji:**
   - znaczenie znacznika celu +0x34 (1 świeży rozkaz → 2 prośba jednostki → 3 / 4 trasa grupowa) [W/P];
   - poprawka etapu 21: 0x4A35AA to anulowanie próśb o trasę, nie zgłoszenie bezczynności [W];
   - nazwy klas wyszukiwania z RTTI (`EEAIAStarMachine<…>` dla sektorów, obszarów, grafu) wyznaczają granicę
     podsystemu [P: nazwy].

## 2. Weryfikacja

Zadania MCP 443–454 (EE 443–451, AoC 452–454), tylko odczyt pamięci, gwardia 0x100018B.

| Przypadek | Wynik |
|---|---|
| A: cel daleko / za przeszkodą (EE 444, 445) | brak celów +0x32, +0x34 = 4, obejście bez zmian w kolejce [P] |
| B: przejście do następnego celu Shift (EE 448, 451; AoC 453, 454) | w chwili zdjęcia A dwa cele +0x32 (179,5; 118,5), (178,5; 123,5) przed B; mapa oczekujących grupy pusta [P] |
| C: zwykły PPM przy punktach (AoC 454; EE 435 z etapu 21) | punkty i cele usunięte, nowy cel +0x34 = 4, nowa grupa [P] |

**Ograniczenia.**
- Stan wewnątrz jednego taktu (między prośbą a wstawieniem) jest niewidoczny przy odczycie w pauzie.
- Punkty +0x32 po zwykłym rozkazie nie pojawiły się w żadnym pomiarze.
- Zadanie 446 czytało zły adres jednostki (zmienia się między uruchomieniami) i nie zostało wykorzystane.

## 3. Błędy oryginału

Bez nowego wpisu. Opis skutku BO-4 poprawiono adnotacją (0x4A35AA anuluje trasy). BO-1–BO-4 bez zmian co do istoty.

## 4. Przeszkody

1. Kto zleca trasę grupową przy przejściu do następnego celu Shift [N]. Pomiar wyklucza prośbę odroczoną: mapa
   oczekujących była pusta.
2. Podział na podgrupy (0x5F70A3) i pole startowe podgrupy [N].
3. Wnętrze wyszukiwania, budżety (−1, 0xF), limit prób (cel +0x18 / vtable +0x2C), „CannotPathToTarget” [N].
4. Gdzie trasa jednostki przechowuje punkty i kiedy zdejmuje punkty +0x32 [N].

## 5. OpenEE (bez zmian w kodzie)

Do wiernego odtworzenia potrzebne są:
- trasa grupowa z menedżerem tras: prośba w obsłudze stanu 8000, natychmiastowe albo odroczone zastosowanie, punkty
  +0x32 na początku kolejki z pominięciem do 3 punktów przy jednostce;
- trasa jednostki przy „PrepareToMove”;
- znaczniki +0x34 celu.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/nawigacja_wejscie.md` | nowy wpis atlasu Titan |
| `docs/titan/kolejka_rozkazow.md` | odnośnik, adnotacje „[Etap 22 – …]” (+0x34, 0x4A35AA, źródło punktów +0x32) |
| `docs/titan/cele_jednostek.md`, `docs/titan/BLEDY_ORYGINALU.md` | adnotacje: znaczenie +0x34, poprawka opisu skutku BO-4 |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 22, nowy aktualny raport |
| `RAPORT_ETAP_21.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 22”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_22.md` |

## 8. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
