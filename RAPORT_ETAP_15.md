# OpenEE – raport etapu 15: przydział taktów symulacji Titan

Drugi etap rekonstrukcji kodu silnika Titan. Zakres: kto i według jakich zasad wysyła do `EEPhysics` komunikaty
taktów (typ 0x28) oraz skąd różnica między nominalnym tempem G = 1,5 a zmierzonym 1,461. Szczegóły:
**`docs/titan/przydzial_taktow.md`**. Odbiorca komunikatów: `docs/titan/zegar_symulacji.md` (etap 14).

**Oznaczenia:**
- **[P]** potwierdzone kodem w obu grach i pomiarem;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `607363f`, testy Godota 324/324.

## 1. Wynik

1. **Nadawca.** Komunikaty taktów pochodzą z serwera sieciowego lockstep `NESynchronousServer` z `Low-Level Engine.dll`.
   Gra używa go także w trybie jednoosobowym, jako podklasy `EEServer` z EXE [P].
   - Wątek `NESynchronousServer::Send` co **350 ms** wysyła takt komunikacji (`NEMCommunicationsTick`, typ 0x26).
     Zawiera on liczbę taktów fizyki, n i polecenia graczy.
   - Obsługa tego komunikatu w EXE (`EEServer` vtable +0x6C) tworzy `NEMPhysicsTick` (0x28) i wstawia go do kolejki
     `EEPhysics`, a za nim polecenia graczy [P].
2. **Liczba taktów na komunikat** (bajt +0x10) = obcięcie(n · 350 / 1000) = obcięcie(15,4) = **15** [P: kod; pomiar
   15 w EE i AoC].
3. **Pochodzenie n = 44** (bajt +0x11). `TuneForSlowCPU` liczy n = 1000 / (średni czas taktu · 100/30), gdzie 30 to
   „PT Rate Tuning Threshold (percent)” z rejestru.
   - Na współczesnym komputerze średni czas taktu wynosi 0 → 1 ms, więc wynik to 300.
   - Wynik trafia do pola jednobajtowego: 300 − 256 = **44**. Dopiero potem jest porównywany z granicami 15–125
     z rejestru, więc ograniczenie nie działa.

   [P] – kod jednoznaczny w obu DLL. W pomiarze średni czas taktu = 0, n = 44. Wartość 44 jest możliwa tylko przy
   wyniku 300.
4. **Pauza F3.** `PauseGame` rozsyła `NEMPauseGame` z oczekiwaniem na potwierdzenie.
   - Od jego wysłania komunikaty niosą 0 taktów; po potwierdzeniu stan serwera = 4 (pauza).
   - Komunikaty co 350 ms biegną dalej z 0 taktów; wcześniej przydzielone takty (do 15) `EEPhysics` dokańcza.
   - Wznowienie działa symetrycznie (0x35).

   [P: kod + pomiar obu gier]
5. **Sieć i polecenia.** Przydział taktów jest częścią synchronizacji lockstep. Polecenia graczy jadą w tym samym
   komunikacie co takty i są wykonywane przez tę samą kolejkę [P]. Systemu poleceń i warstwy sieci nie analizowano.
6. **EE ↔ AoC.**
   - Funkcje DLL są identyczne; różnią się tylko numery wierszy w asercjach.
   - Funkcje EXE są identyczne; konstruktor serwera różni się trzema stałymi w argumentach asercji.
   - Wartości w pamięci są takie same: I = 350, 15 taktów na komunikat, n = 44, granice 125/15, 3,333 [P].

**Różnica 1,5 → 1,461 wynika z algorytmu, nie z Wine:**
- wykonuje się 15 taktów / 0,35 s = 42,857 taktu/s, a każdy takt to 1000 · 1,5 / 44 = 34,0909 ms czasu gry;
- daje to **1461,04 ms/s** wobec 1460,7–1461,5 zmierzonych w etapie 13;
- harmonogram komunikatów kompensuje spóźnienia timera, więc średni okres wynosi dokładnie 350 ms [P].

Wine mógłby wpływać pośrednio, tylko przez zmierzony czas taktu, który zmienia n [H].

**Dodatkowo:** klasa bazowa `EEPhysics` z wątkiem i timerem to `RTSPhysics` (RTTI, „RTSPhysics::Main”). Zamyka to
przeszkodę 2 z etapu 14 [P].

## 2. Funkcje (EE / AoC)

| Funkcja | EE | AoC |
|---|---|---|
| DLL `NESynchronousServer::Send` (harmonogram 350 ms) | 0x10055D2E | 0x10049D13 |
| DLL `SendCommunicationsTick` | 0x10054AB8 | 0x10048A9D |
| DLL `TuneForSlowCPU` (n, takty na komunikat) | 0x10055099 | 0x1004907E |
| DLL `TuneForSlowNetwork` (odstęp, min. 350 ms) | 0x100551B1 | 0x10049196 |
| DLL `Main` (stany: gra, pauza) | 0x1005581D | 0x10049802 |
| DLL `PauseGame` / `UnpauseGame` | 0x1005449F / 0x10055789 | 0x10048484 / 0x1004976E |
| EXE utworzenie serwera (16 graczy, 350 ms, 60) | 0x4C2536 | 0x4CA90F |
| EXE `EEServer` +0x6C: komunikat 0x26 → `NEMPhysicsTick` | 0x4C3839 | 0x4CBC77 |
| EXE `EEClient` +0x44: to samo u klienta | 0x4B0580 | 0x4B79B1 |
| wskaźnik serwera / blok ustawień | 0x91984C / 0x919400 | 0x9319C8 / 0x930880 |

## 3. Weryfikacja

Jeden przebieg w każdej grze, tylko odczyt pamięci: zadania MCP 364 (EE) i 366 (AoC), sprzątanie 365 i 367. Odczytano
blok ustawień, obiekt serwera i `EEPhysics` w ruchu, w pauzie F3 i po wznowieniu. Pomiarów prędkości nie powtarzano.

| Wielkość | Algorytm | Pomiar (EE = AoC) | Status |
|---|---|---|---|
| nominalne 44 takty/s | n = 44 to parametr kroku i timera fizyki, nie liczba taktów | n = 44 | wyjaśnione [P] |
| rzeczywiste takty/s | 15 / 0,35 = 42,857 | 42,86 (etap 13), 42,68 z okna 5 s (etap 14) | zgodne [P] |
| `EEPhysics`+0xB8 | porcje po 15, malejące o 1 na takt | 1–13 | zgodne [P] |
| `EEPhysics`+0x80 vs suma serwera | rosną o te same porcje 15 | +225 / +225, stała różnica | zgodne [P] |
| pauza / wznowienie | 0 taktów, komunikaty trwają; stan 4 → 3 | stan 4, typ 0x33; stan 3, typ 0x35 | zgodne [P] |
| `A_GRA+0x80` 49,98/s (etap 13) | średnio 42,86/s w skokach po 15 | – | wynik etapu 13 z krótkiego okna [W] |

## 4. OpenEE (bez zmian w kodzie)

Zalecenie z etapu 14 („odtwarzać G = 1,5”) zostało zastąpione: wierny algorytm daje 1,461. Propozycja dla
`ZegarSymulacji`/`Symulacja` (`przydzial_taktow.md`, „Konsekwencje dla OpenEE”):
- porcje 15 taktów co 0,35 s;
- krok czasu gry 1000 · G / 44 ms;
- licznik czasu gry jak w oryginale;
- pauza = porcje 0, z dokończeniem bieżącej;
- stała `MNOZNIK_PREDKOSCI` staje się zbędna.

Do decyzji: czy odwzorować zależność n od wydajności komputera (przy czasie taktu 2–3 ms tempo wynosiłoby 1,474–1,5).
Zalecam stałe n = 44.

## 5. Przeszkody i zakończone wątki

1. System poleceń graczy (kolejka serwera, wykonanie w `EEPhysics`) – osobny podsystem, nie analizowano.
2. Warstwa sieci (opóźnienia, spóźnieni gracze, migracja) – nie analizowano; dla gry jednoosobowej wystarcza I = 350.
3. Droga lokalnego dostarczenia komunikatu 0x26 do `EEServer` vtable +0x6C – [W].
4. Domyślne wartości ustawień przy braku wpisów w rejestrze – [N].
5. Wpływ n zależnego od wydajności (tabela w `przydzial_taktow.md` § 3) – wyliczony z kodu, niezmierzony [W].

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/przydzial_taktow.md` | nowy wpis atlasu Titan |
| `docs/titan/zegar_symulacji.md` | adnotacje [Etap 15]: znaczenie n, przyczyna niedoboru taktów, nowe zalecenie, nazwa `RTSPhysics` |
| `docs/titan/README.md` | tabela ustalonych miejsc w kodzie uzupełniona o przydział taktów |
| `docs/ARCHITEKTURA_OPENEE.md`, `docs/MECHANIKA_PREDKOSCI_EE.md`, `docs/HISTORIA.md` | stan wiedzy, adnotacja tempa 1,461 i licznika `+0x80`, etap 15 |
| `README.md`, `raporty/README.md`, `RAPORT_ETAP_14.md` → `raporty/archiwum/` | nowy aktualny raport, archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 15”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian. Użyto istniejących kroków Riverlands_MCP: `pamiec_u32`, `start_testowy`,
`sprzataj_scenariusze`.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_15.md`, poprzednie w `raporty/archiwum/` |

## 8. Commit i publikacja

Jeden commit na `main`, lokalnie. Publikacja:
```
cd "/media/precell/Inne/Projekty AI/EE Projekt/OpenEE"
git push origin main
```
