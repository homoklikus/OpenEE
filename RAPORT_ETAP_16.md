# OpenEE – raport etapu 16: droga rozkazu ruchu gracza w silniku Titan

Trzeci etap rekonstrukcji kodu silnika Titan. Zakres: zwykły rozkaz ruchu zaznaczonej jednostki do punktu, od kliknięcia
do wykonania w symulacji, w Empire Earth i The Art of Conquest. Szczegóły: **`docs/titan/rozkazy_gracza.md`**. Nowa
stała zasada projektu i rejestr błędów oryginału: **`docs/titan/BLEDY_ORYGINALU.md`**.

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `056b02e`, testy Godota 324/324.

## 1. Wynik

**Droga rozkazu** (EE; AoC identycznie co do logiki):

```
PPM na terenie → EEAMouseClick +0x0C (0x403CF1): EEMPathTo (typ 0x4D) w akcji → menedżer akcji
→ pętla główna: EEAMouseClick +4 (0x403AA1) → EEServer/NESynchronousServer::ProcessLocalUserInput (DLL)
→ EEServer +0x60: stempel wersji zaznaczenia → NERecordPlayback::Process → ProcessLocalUserInput2
→ kolejka serwera +0x84 → SendCommunicationsTick (co 350 ms): polecenia w NEMCommunicationsTick (0x26)
→ EEServer +0x6C: NEMPhysicsTick + polecenia do kolejki EEPhysics
→ EEPhysics (0x5470B0): po przyjęciu NEMPhysicsTick od razu wykonuje dołączone polecenia, przed nowymi taktami
→ kontrola wersji zaznaczenia (0x4B1A29) → EEMPathTo::Execute (0x4B9D7B) → grupy ruchu z celem (granica: podsystem ruchu)
```

**Struktura komunikatu `EEMPathTo`** – 0x20 B w pamięci, 21 B po serializacji [P]:

| Pole | Zawartość |
|---|---|
| +0x08 | typ 0x4D |
| +0x09 | adresat 0xFF |
| +0x0A | nadawca 0xFE – gniazdo lokalnego gracza |
| +0x0C | wersja zaznaczenia |
| +0x10 | f32, kąt/kierunek [W] |
| +0x14 / +0x18 | f32 x, y celu |
| +0x1C | „zastąp rozkaz”, 1 bez Shift [W] |
| +0x1D…+0x1F | flagi, znaczenie [N] |

**Komunikat nie zawiera identyfikatorów jednostek.** Działa na zaznaczoną grupę gracza w symulacji (EE +0x9BC,
AoC +0x9AC). Tę grupę ustawiają osobne komunikaty zaznaczenia, wysyłane tą samą drogą i numerowane wersją
(`EEServer`+0x349). Rozkaz ze starszą wersją zaznaczenia nie zostanie wykonany [P: kod; pomiar wersji].

**Kiedy rozkaz działa:** na granicy taktu komunikacji, przed pierwszym taktem nowej porcji. Opóźnienie wynosi do 350 ms
plus klatka [P: kod; pomiar 0,10–0,30 s w EE i AoC].

**EE ↔ AoC:** komunikat, serializacja, droga przez serwer i `EEPhysics` są identyczne. Różnice:
- przesunięcia pól obiektu gracza;
- `Execute` w AoC ma jeden przebieg więcej (5 zamiast 4), co odpowiada dodatkowemu rodzajowi jednostek [H];
- rozbudowana funkcja kliknięcia w AoC.

[P: porównanie instrukcji po normalizacji adresów]

## 2. Weryfikacja

Zadania MCP, tylko odczyt pamięci: 368 (EE) i 370 (AoC) – zaznaczenie i rozkaz; 372 (EE) – kontrola tła i rozkaz
z Shift. Sprzątanie: 369, 371, 373.

| Sprawdzenie | Wynik |
|---|---|
| gniazdo lokalnego gracza 0xFE | gracz 1: +0x464 = 254 (EE i AoC) [P] |
| zaznaczenie ramką | wersja +0x349: 0 → 1; wykonana w symulacji (+0x338[1] = 1); 1 polecenie [P] |
| rozkaz ruchu | wersja bez zmian; `EEMPathTo` wykonany (+1 polecenie w 0,3 s); ruch po 0,10–0,30 s [P] |
| tło | brak poleceń przez 6 s bez działań gracza [P] |
| dodatkowe polecenie | po każdym rozkazie jeszcze jedno polecenie 0,3–3,3 s później; typ [N] |
| Shift + PPM | +3 polecenia od razu (prawdopodobnie wejście i wyjście z trybu Shift + `EEMPathTo`) [H] |

## 3. Stała zasada: błędy oryginału

- Do `CLAUDE.md` dodano zasadę: OpenEE wiernie odtwarza oryginał razem z błędami. Błędy dokumentujemy, nie poprawiamy,
  a naprawę rozważymy po rekonstrukcji.
- Utworzono rejestr `docs/titan/BLEDY_ORYGINALU.md`.
- Pierwszy wpis to **BO-1**: przepełnienie 8-bitowego n w `NESynchronousServer::TuneForSlowCPU` (300 → 44), stąd tempo
  1,461 [P]. Status: zachować zgodność.

## 4. Przeszkody i granice

1. Typ dodatkowego polecenia po rozkazie ruchu – [N]. Wymaga śledzenia kolejki serwera albo pułapki w kodzie.
2. Menedżer akcji interfejsu (cofnij/ponów) – nie analizowano poza dodaniem i wykonaniem akcji.
3. Podsystem grup i ruchu od `EEMPathTo::Execute` w dół (0x5DB37C, 0x614D47, 0x5DD436) – granica dokumentu.
4. Znaczenie pól +0x10, +0x1D–+0x1F i bitów flag kliknięcia – [W]/[N].

## 5. OpenEE (bez zmian w kodzie)

OpenEE wysyła listę identyfikatorów jednostek i wykonuje rozkaz w następnym takcie (0,05 s). Wierny model, opisany
w `rozkazy_gracza.md` (konsekwencje):
- rozkaz bez listy jednostek, odnoszący się do zaznaczenia w symulacji;
- zaznaczenie jako osobne komunikaty z wersją;
- wykonanie poleceń porcjami co 350 ms, przed taktami porcji;
- kontrola wersji zaznaczenia.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/rozkazy_gracza.md` | nowy wpis atlasu Titan |
| `docs/titan/BLEDY_ORYGINALU.md` | nowy rejestr błędów oryginału (BO-1) |
| `CLAUDE.md` | stała zasada: wierna rekonstrukcja z błędami, rejestr błędów |
| `docs/titan/README.md`, `docs/titan/przydzial_taktow.md` | atlas uzupełniony; odnośnik do rejestru błędów i drogi poleceń |
| `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | stan wiedzy, etap 16, nowy aktualny raport |
| `RAPORT_ETAP_15.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 16”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian. Użyto istniejących kroków Riverlands_MCP: `pamiec_u32`, `ruch_zaznacz`,
`ruch_rozkaz`, `kam_ustaw`, `start_testowy`, `sprzataj_scenariusze`.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_16.md`, poprzednie w `raporty/archiwum/` |

## 8. Commit

Jeden commit na `main`, lokalnie. Zgodnie z poleceniem etapu – bez wysyłania na GitHub.
