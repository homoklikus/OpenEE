# Przydział taktów symulacji (NESynchronousServer → EEPhysics) – Empire Earth / The Art of Conquest

Etap 15 OpenEE, drugi wpis atlasu funkcji silnika Titan (`docs/titan/README.md`). Uzupełnia
`docs/titan/zegar_symulacji.md`, który opisuje odbiorcę komunikatów taktów (`EEPhysics`). Ten dokument opisuje:
- kto wysyła komunikat taktów (typ 0x28);
- jak liczona jest liczba taktów i wartość n = 44;
- jak działa pauza;
- skąd bierze się różnica między nominalnym tempem 1,5 a zmierzonym 1,461.

**Oznaczenia:**
- **[P]** potwierdzone, czyli kod jednoznaczny i zgodny w obu grach oraz zgodny z pomiarem w działającej grze;
- **[W]** wniosek z kodu, sprawdzony częściowo;
- **[H]** hipoteza;
- **[N]** nieustalone.

## Wynik w skrócie

- Także w grze jednoosobowej czas symulacji wyznacza **serwer sieciowy lockstep** `NESynchronousServer` z biblioteki
  `Low-Level Engine.dll`. Gra używa jego podklasy `EEServer`, zdefiniowanej w EXE [P: RTTI obiektu w pamięci obu gier].
- Co **I = 350 ms** serwer wysyła „takt komunikacji” (`NEMCommunicationsTick`, typ 0x26). Zawiera on:
  - liczbę taktów fizyki do wykonania (**15**);
  - wartość **n = 44**;
  - polecenia graczy.

  Obsługa tego komunikatu w EXE tworzy z niego komunikat taktów `NEMPhysicsTick` (typ 0x28) i wstawia go do kolejki
  `EEPhysics` [P].
- **Liczba taktów na komunikat** = obcięcie(n · I / 1000) = obcięcie(44 · 0,35) = obcięcie(15,4) = **15** [P].
- **n = 44 to skutek przepełnienia bajtu.** Serwer liczy n = 1000 / (średni czas taktu · 100/30). Średni czas taktu
  to 1 ms (0 zamieniane na 1), więc wynik wynosi 300. Zapisany do pola jednobajtowego daje 300 − 256 = **44**.
  Dopiero ta wartość jest porównywana z granicami 15–125 z rejestru, więc ograniczenie nie zadziała [P: kod +
  pomiar, wartość 44 możliwa tylko przy wyniku 300].
- **Rzeczywiste tempo taktów** = 15 taktów / 0,35 s = **42,857 taktu/s**, a nie 44. Każdy takt dodaje
  1000 · G / n = 34,0909 ms czasu gry. Czas gry płynie więc z szybkością 42,857 · 34,0909 = **1461,0 ms/s**,
  co dokładnie odpowiada pomiarom etapu 13 (1460,7–1461,5) [P].
- Różnica 1,5 → 1,461 **wynika z algorytmu**: obcięcia 15,4 do 15 taktów na komunikat. Nie odpowiada za nią Wine ani
  harmonogram timera. Timer komunikatów kompensuje opóźnienia, więc średni okres wynosi dokładnie 350 ms [P: kod; wynik
  zgodny z pomiarem co do 0,1 ms/s].
- **Pauza F3:** serwer rozsyła `NEMPauseGame` i czeka na potwierdzenie, a potem przechodzi w stan „pauza”. Komunikaty
  co 350 ms przychodzą nadal, ale z liczbą taktów 0. Takty przydzielone wcześniej (do 15) `EEPhysics` dokańcza [P].
- Algorytm jest identyczny w EE i AoC: w obu DLL, w obu EXE i co do wartości w pamięci [P].

## Warianty plików i metoda

| Gra | Plik | SHA-256 |
|---|---|---|
| EE | `Empire Earth.exe` | `e352d7ae5ebc91f8d2f9c4363e41e990d7be8b063b1ee9e686a0d2a5f9bea2b5` |
| EE | `Low-Level Engine.dll` (data pliku 2014) | `0350ef776b68d3a6ac84d8addf05e710907bea911aa15b23b8dffdbf68e8b05b` |
| AoC | `EE-AOC.exe` | `db8fc5ceb85dbb9bb7e47804e15f1a025373efe995948cddc5b3d05605797f52` |
| AoC | `Low-Level Engine.dll` (data pliku 2002) | `4acf04043867c02edd2ac95201f03342400840cf8469414c44ed3363fd8cbefb` |

Biblioteki DLL obu gier są różnymi plikami, ale wszystkie opisane funkcje są w nich identyczne. Baza obrazu DLL to
0x10000000. DLL eksportuje funkcje z pełnymi nazwami C++, co daje nazwy klas i metod bez zgadywania.

**Metoda:**
- analiza statyczna (pefile + capstone);
- start od obsługi komunikatu 0x28 w `EEPhysics` (etap 14), dalej:
  - konstruktor `NEMessage(0x28, …)` w EXE;
  - obsługa komunikatu 0x26;
  - `NESynchronousServer::SendCommunicationsTick` i funkcje strojenia w DLL;
- porównanie EE ↔ AoC instrukcja po instrukcji po zastąpieniu adresów bezwzględnych symbolem, z wyrównaniem
  sekwencji (difflib).

**Weryfikacja:** jeden przebieg w każdej grze, tylko odczyt pamięci (zadania MCP 364 EE i 366 AoC; sprzątanie 365, 367).
Odczytano obiekt serwera, obiekt `EEPhysics` i blok ustawień w trzech chwilach: w ruchu, w pauzie F3 i po wznowieniu.

## Struktury

### Obiekt serwera (`EEServer` : `NESynchronousServer` : `NESynchronousCommunications`)

Wskaźnik: EE 0x91984C, AoC 0x9319C8. RTTI w pamięci: `EEServer` w obu grach [P]. Tę samą zmienną globalną używa obsługa
komunikatu taktów w `EEPhysics`.

| Pole | Typ | Znaczenie | Pomiar (EE = AoC) | Pewność |
|---|---|---|---|---|
| +0x2D | u8 | gra wstrzymana (`GetIsGamePaused`) | 0 → 1 w pauzie | [P] |
| +0x2E | u8 | sesja wieloosobowa (`GetIsMultiplayerSession`) | 0 | [P] |
| +0x14 / +0x18 | u32 | średni czas wykonania taktu / średni odstęp między taktami, przepisywane z `EEPhysics` +0xD8 / +0xDC przy każdym komunikacie taktów | – | [P] (kod) |
| +0x170 | f32 | współczynnik = 100 / „PT Rate Tuning Threshold (percent)” | 3,3333 (100/30) | [P] |
| +0x174 | u8 | stan gry: 0 zatrzymana, 3 trwa, 4 pauza (`GetGameState`) | 3 → 4 → 3 | [P] |
| +0x178 | u32 | suma wysłanych taktów fizyki (`GetCurrentPhysicsTick`) | +15 na komunikat | [P] |
| +0x180 / +0x184 | u32 | odstęp / numer najbliższego komunikatu z żądaniem sumy kontrolnej świata | 1 / bieżący numer | [P] |
| +0x190 | u32 | numer bieżącego taktu komunikacji (`GetCurrentCommunicationsTick`) | ~2,86/s | [P] |
| +0x198 | u32 | **I** – bieżący odstęp komunikatów, ms (`GetSendInterval`) | **350** | [P] |
| +0x19C | u32 | odstęp domyślny (argument konstruktora) | 350 | [P] |
| +0x1B4 / +0x1B8 | u32 | maks. / min. taktów fizyki na sekundę (rejestr) | 125 / 15 | [P] |
| +0x1C4 / +0x1C8 / +0x1CC | u32 | maks. odstęp / krok w górę / krok w dół odstępu (rejestr) | 2250 / 125 / 10 | [P] |
| +0x1F8 | u8 | typ komunikatu „wyślij do wszystkich i czekaj” w toku | 0x33 (pauza), 0x35 (wznowienie) | [P] |
| +0x1F9 | u8 | **takty fizyki na komunikat** (`GetPTsPerCT`) | **15** | [P] |
| +0x1FA | u8 | takty na komunikat – wartość początkowa (konstruktor) | 60 | [P] |
| +0x1FB | u8 | **n** – takty fizyki na sekundę wysyłane do `EEPhysics` | **44** | [P] |
| +0x206 | u8 | trwa „wyślij do wszystkich i czekaj” (`GetProcessingSendToAllAndWait`) | 0 | [P] |

### Komunikat taktu komunikacji `NEMCommunicationsTick` (typ 0x26, pochodna `NEMPlayerInput`)

| Pole | Znaczenie |
|---|---|
| +0x08 | typ 0x26 |
| +0x1C | numer taktu komunikacji (serwer +0x190) |
| +0x20 | n (serwer +0x1FB) |
| +0x21 | liczba taktów fizyki: serwer +0x1F9, 0 (pauza, oczekiwanie) albo 0xFF („bez taktów”, stany inne niż 3/4) |
| +0x22 | żądanie sumy kontrolnej świata |
| +0x23 | „zrzut świata” (OOS) |
| lista | polecenia graczy (`AddPlayerInput`, łącznie do 0x240 B) |

### Komunikat taktów `NEMPhysicsTick` (typ 0x28)

| Pole | Znaczenie |
|---|---|
| +0x0C | liczba poleceń graczy dołączonych do taktu komunikacji |
| +0x10 | liczba taktów do wykonania (= komunikat 0x26 +0x21) |
| +0x11 | n (= komunikat 0x26 +0x20) |
| +0x12 | żądanie sumy kontrolnej (= +0x22) |
| +0x13 | zrzut świata (= +0x23) |

[P] – konstruktor w DLL (`NEMPhysicsTick(uchar&, ulong&, uchar&, bool, bool)`) i ta sama kolejność zapisów w EXE.

### Blok ustawień w EXE

EE 0x919400–0x919427, AoC 0x930880–0x9308A7: w pomiarze `[125, 10, 125, 15, 2250, 0, 2, 2, 0, 30, 1]`. Wartości są
zgodne z ustawieniami rejestru `Software\Neo\Empire Earth`:

| Ustawienie | Wartość |
|---|---|
| „CT Send Interval Step Up” | 125 |
| „CT Send Interval Step Down” | 10 |
| „Max PTs per Second” | 125 |
| „Min PTs per Second” | 15 |
| „Max CT Send Interval” | 2250 |
| „PT Rate Tuning Threshold (percent)” | 30 |

Odpowiedniość pól bloku i ustawień: [P] co do wartości. Droga od odczytu rejestru (EE ok. 0x528E77) do bloku: [W].
Wartości domyślne przy braku wpisu w rejestrze: [N].

## Funkcje

| Funkcja | EE | AoC | Zgodność |
|---|---|---|---|
| **DLL** `NESynchronousServer::Send` – wątek wysyłania, harmonogram I | 0x10055D2E | 0x10049D13 | identyczne (148 instr.; różni się tylko numer wiersza w asercji) |
| `NESynchronousServer::SendCommunicationsTick` – budowa i wysłanie komunikatu 0x26 | 0x10054AB8 | 0x10048A9D | identyczne (271) |
| `NESynchronousServer::TuneServer` | 0x100556B5 | 0x1004969A | identyczne (63) |
| `NESynchronousServer::TuneForSlowCPU` – n i takty na komunikat | 0x10055099 | 0x1004907E | identyczne (82) |
| `NESynchronousServer::TuneForSlowNetwork` – odstęp I | 0x100551B1 | 0x10049196 | identyczne (302) |
| `NESynchronousServer::Main` – zdarzenia: start, pauza, wznowienie, stop | 0x1005581D | 0x10049802 | identyczne (310; numery wierszy w asercjach) |
| `NESynchronousServer::PauseGame` / `UnpauseGame` | 0x1005449F / 0x10055789 | 0x10048484 / 0x1004976E | identyczne (31 / 31) |
| `NESynchronousServer::SendToAllAndWait` | 0x10054E7C | 0x10048E61 | – |
| `NESynchronousServer::ProcessCommunicationsTickResponse` | 0x100544F9 | 0x100484DE | identyczne (49) |
| konstruktor `NESynchronousServer` | 0x10053460 | 0x10047400 | – |
| konstruktor `NEMCommunicationsTick` | 0x10008F87 | 0x1003C6FB | identyczne (23) |
| **EXE** utworzenie serwera (wywołanie konstruktora ze stałymi 16, 350, 60) | 0x4C2536 (wywołanie 0x4C2593) | 0x4CA90F (wywołanie 0x4CA96C) | identyczne poza 3 stałymi w argumentach asercji |
| `EEServer` vtable +0x6C: obsługa komunikatów serwera; dla typu 0x26 tworzy `NEMPhysicsTick` | 0x4C3839 (konstrukcja 0x4C3994) | 0x4CBC77 (0x4CBDD2) | identyczne (279) |
| `EEClient` vtable +0x44: to samo po stronie klienta (gra wieloosobowa) | 0x4B0580 (konstrukcja 0x4B0690) | 0x4B79B1 (0x4B7AC1) | identyczne (402) |
| `EEServer` vtable +0x28: „lista graczy pusta” (0x918CB4 / AoC odpowiednik) | 0x4C3703 | 0x4CBB41 | identyczne (16) |
| vtable `EEServer` / `EEClient` | 0x829718 / 0x8283C4 | 0x83E384 / 0x83D054 | – |

Odbiorca, czyli obsługa komunikatu 0x28 w `EEPhysics` (EE 0x5470B0, AoC 0x55355C), jest opisany
w `zegar_symulacji.md`. Klasa bazowa `EEPhysics` z wątkiem i timerem to **`RTSPhysics`** (`RTSPhysics::Main` =
EE 0x5532FB, AoC 0x56140C). Potwierdzają to hierarchia RTTI `EEPhysics → RTSPhysics` i komunikat diagnostyczny
„RTSPhysics::Main: …” w tej funkcji [P].

## Algorytm

### 1. Harmonogram komunikatów (wątek `Send`)

Wątek czeka na zdarzenia z limitem czasu wyliczonym tak, że kolejne wysyłki przypadają w chwilach
B<sub>k</sub> + I − 50 ms, gdzie B<sub>k+1</sub> = B<sub>k</sub> + I. Przy każdym przebudzeniu limit jest korygowany
o różnicę między czasem planowym a rzeczywistym (`TMGetTime`). Spóźnienie jednej wysyłki skraca więc następne
oczekiwanie, a **średni okres jest równy I** [P: kod]. Każde przebudzenie po limicie czasu woła
`SendCommunicationsTick`. Od numeru +0x184 (pierwszy raz 40) z żądaniem sumy kontrolnej; potem +0x184 += +0x180.

### 2. Komunikat taktu komunikacji (`SendCommunicationsTick`)

1. Strojenie (`TuneServer`) – jeśli nie stwierdzono rozsynchronizowania:
   - `TuneForSlowNetwork` – opóźnienia klientów, odstęp I;
   - `TuneForSlowCPU` – n i takty na komunikat, tylko w stanie 3.

   Gdy strojenie zgłasza oczekiwanie na spóźnionego klienta, zamiast taktu wysyłany jest „serwer żyje”.
2. Jeżeli czeka komunikat „wyślij do wszystkich i czekaj” (np. `NEMPauseGame`), serwer wysyła go i ustawia +0x206 = 1.
3. Liczba taktów fizyki P:
   - stan 3 (gra trwa), nic nie oczekuje (+0x206 = 0, brak rozsynchronizowania) i nie zachodzi „sesja
     wieloosobowa z pustą listą graczy”: **P = +0x1F9**, a +0x178 += P;
   - stan 4 (pauza) albo +0x206 = 1: **P = 0**;
   - inne stany: P = 0xFF – komunikat bez taktów, EXE nie tworzy wtedy komunikatu 0x28.
4. Budowa komunikatu 0x26 (pola jak wyżej). Dołączenie oczekujących poleceń graczy z kolejki +0x84, do 0x240 B.
   Wysłanie do wszystkich; +0x190 += 1.

### 3. n i takty na komunikat (`TuneForSlowCPU`)

```
t = największy z ostatnich zgłoszonych średnich czasów taktu (u16, ms) ; 0 → 1
x = obcięcie(1000 / (t · (+0x170)))         ; +0x170 = 100 / 30
n = x mod 256                                ; zapis do bajtu +0x1FB
jeśli n > maks (125): n = maks ;  jeśli n ≤ min (15): n = min      ; porównanie już po obcięciu do bajtu
takty_na_komunikat = obcięcie(n / (1000 / I)) ; ≥ 255 → 254
```

[P] dla kodu. Obcięcie do bajtu następuje przed porównaniem z granicami: wartość jest przenoszona przez rejestr 8-bitowy
i dopiero potem rozszerzana do porównania. „Średni czas taktu” pochodzi z `EEPhysics` +0xD8, średniego czasu wykonania
taktu w ms (`zegar_symulacji.md`, tabela struktur). W pomiarze wynosi 0 → t = 1 → x = 300 → **n = 44**,
a takty na komunikat = obcięcie(44 · 0,35) = **15**.

Skutek [W, z kodu, niezmierzone]: n zależy od wydajności komputera.

| t (ms) | x | n | takty / komunikat | taktów/s | czas gry / s (G = 1,5) |
|---|---|---|---|---|---|
| 0–1 | 300 | 44 (przepełnienie) | 15 | 42,86 | 1461 ms |
| 2 | 150 | 125 (maks.) | 43 | 122,9 | 1474 ms |
| 3 | 100 | 100 | 35 | 100 | 1500 ms |
| 4 | 75 | 75 | 26 | 74,3 | 1486 ms |

Czas gry na sekundę = (takty/komunikat ÷ I) · 1000 · G / n. Różnica względem G · 1000 bierze się wyłącznie z obcięcia
n · I / 1000. Na szybkim komputerze, jak w pomiarach etapów 13–15, obowiązuje pierwszy wiersz.

### 4. Odstęp I (`TuneForSlowNetwork`)

Odstęp startowy to 350 ms (stała w EXE, przekazywana do konstruktora). Funkcja zwiększa I, gdy opóźnienie odpowiedzi
klientów przekracza I, najwyżej do +0x1C4 = 2250. Zmniejsza I o +0x1CC = 10 ms po 10 komunikatach bez opóźnień, ale
tylko wtedy, gdy wynik pozostaje **większy niż 350**. W praktyce I ≥ 350 [P: kod; pomiar I = 350 w obu grach]. W grze
jednoosobowej nie ma opóźnień sieci, więc I = 350.

### 5. Od komunikatu 0x26 do `EEPhysics` (EXE)

Obsługa komunikatów `EEServer` (vtable +0x6C), dla typu 0x26:
1. Jeśli P ≠ 0xFF: tworzy `NEMPhysicsTick` (pola jak wyżej) i wstawia go do kolejki `EEPhysics` (vtable +4, w sekcji
   krytycznej `EEPhysics`+0x4C).
2. Następnie wstawia do tej samej kolejki **polecenia graczy** z komunikatu.

Polecenia graczy są wykonywane przez tę samą kolejkę i w tym samym rytmie co takty, czyli lockstep [P: kod]. Szczegóły
poleceń należą do systemu komend, poza zakresem tego dokumentu.

Komunikat 0x26 trafia do własnej obsługi serwera prawdopodobnie przez lokalne dostarczenie wiadomości w DLL (wywołania
vtable +0x6C w okolicy `ProcessPendingPlayerInputs2`) [W]. W grze wieloosobowej klient robi to samo przez `EEClient`
vtable +0x44.

Po stronie `EEPhysics` (etap 14):
- kolejny komunikat taktów zostanie przyjęty dopiero po wykonaniu poprzednich, bo `EEPhysics`+0x2C = 1 (pomiar);
- takty nie giną: +0x80 i suma serwera +0x178 rosną o te same porcje 15 [P: pomiar, stała różnica 138];
- timer fizyki ma okres floor(1000/n) = 22 ms (45,45 wywołań/s), więc 15 taktów wykonuje się w ok. 330 ms, przed
  następnym komunikatem.

### 6. Pauza i wznowienie

1. Pauzę włącza w EXE wywołanie `NESynchronousServer::PauseGame` (import, kilka miejsc wywołań; że wywołuje je
   obsługa F3, wynika z pomiaru, a nie z odczytanej obsługi klawisza – [W]). `PauseGame` tworzy `NEMPauseGame` (typ 0x33)
   i wstawia go do „wyślij do wszystkich i czekaj”.
2. Najbliższy `SendCommunicationsTick` wysyła ten komunikat i ustawia +0x206 = 1 oraz +0x1F8 = 0x33. Od tej chwili
   komunikaty mają **P = 0**.
3. Po potwierdzeniu przez wszystkich graczy `Main` zeruje +0x206 i ustawia zdarzenie pauzy: stan +0x174 = 4,
   +0x2D = 1. Komunikaty biegną dalej co 350 ms z P = 0.
4. `UnpauseGame`: to samo z komunikatem typu 0x35. Na końcu stan 3, +0x2D = 0.

Pomiar w obu grach:
- w pauzie: stan 4, +0x1F8 = 51 (0x33), numer komunikatu rośnie, suma taktów +0x178 stoi;
- `EEPhysics`: +0xB8 = 0, +0xB4 stoi;
- po wznowieniu: stan 3, +0x1F8 = 53 (0x35), suma rośnie o 15 na komunikat [P].

To wyjaśnia obserwację etapu 14, że po F3 dokańcza się jeszcze kilka–kilkanaście taktów: przydzielone wcześniej,
najwyżej 15.

## Weryfikacja wobec etapów 13–14

| Wielkość | Algorytm | Pomiar | Status |
|---|---|---|---|
| nominalne „44 takty/s” | n = 44 wysyłane do `EEPhysics` (krok 1000·G/n, timer 22 ms), ale **nie** liczba taktów na sekundę | n = 44 (EE, AoC) | [P] |
| rzeczywiste takty/s | 15 / 0,35 s = 42,857 | etap 13: 1461,0 ms/s ÷ 34,0909 = 42,86; etap 14: 42,68 z okna 5 s | [P] |
| tempo czasu gry 1,461 | 42,857 · 34,0909 / 1000 = 1,46104 | 1,4607–1,4615 (etap 13) | [P] |
| `EEPhysics`+0xB8 | porcje 15 co 350 ms, malejące o 1 na takt | 1–13 w odczytach | [P] |
| `EEPhysics`+0x80 | suma przydzielonych taktów, rośnie skokami po 15 | +225 przy +15 komunikatach | [P] |
| `A_GRA+0x80` „49,98/s” (etap 13) | średnio 42,86/s, skoki po 15 – w krótkim oknie pomiaru wynik silnie zależy od tego, ile porcji się zmieściło | – | [W] – wynik etapu 13 nie jest średnią |
| pauza | P = 0, komunikaty trwają | stan 4, suma stoi | [P] |

**Wine:** opisany mechanizm nie zależy od dokładności timera, bo okres komunikatów jest kompensowany. Wynik 1,461 jest
własnością algorytmu przy t ≤ 1 ms [P]. Pośrednio Wine mógłby wpłynąć tylko na pomiar t, a przez niego na n
(tabela w § 3) [H].

## Zależności i zakończone wątki

1. **System poleceń graczy** (kolejka +0x84 serwera, `ProcessLocalUserInput`, wykonanie poleceń w `EEPhysics`) – osobny
   podsystem; nie analizowano.
2. **Sieć:** połączenia, pomiar opóźnień, „serwer żyje”, wyrzucanie spóźnionych graczy, migracja serwera – nie
   analizowano. Dla gry jednoosobowej istotne jest tylko I = 350.
3. **Suma kontrolna świata:** od 40. komunikatu każdy komunikat z taktami ma żądanie sumy, a `EEPhysics` odpowiada
   komunikatem (`NEMWorldDatabaseChecksumResponse`). Koszt i treść sumy – [N].
4. Dokładna droga lokalnego dostarczenia komunikatu 0x26 do `EEServer` vtable +0x6C – [W].
5. Wartości domyślne ustawień przy braku wpisów w rejestrze – [N].

## Konsekwencje dla OpenEE (bez zmian w kodzie)

Zalecenie z etapu 14, by odtwarzać algorytm z G = 1,5, wymaga korekty: wierne odtworzenie oryginału daje **1,461**, nie
1,5. Propozycja dla `ZegarSymulacji` / `Symulacja`:
- Parametry przydziału jak w oryginale: n = 44, I = 0,35 s, takty na komunikat = obcięcie(n · I) = 15.
- Krok czasu gry na takt 1000 · G / n ms; wykonanie najwyżej floor(1000/n) = 22 ms na takt (timer fizyki).
- Czas gry liczony sumą kroków jak w oryginale. Tempo 1,461 wynika wtedy z algorytmu, a stała `MNOZNIK_PREDKOSCI`
  przestaje być potrzebna.
- Pauza: od chwili pauzy porcje taktów = 0; porcja już przydzielona jest dokańczana.
- Do decyzji: czy odtwarzać zależność n od wydajności (tabela w § 3). Zalecenie: stałe n = 44, odpowiadające
  współczesnym komputerom i wszystkim pomiarom, z adnotacją o mechanizmie.

## Dane

- Zadania MCP:
  - `Testy_MCP/ee_zadania/364_e15_ee_takty` (EE) i `366_e15_aoc_takty` (AoC);
  - sprzątanie: `365`, `367`.
- Odczyty: blok ustawień, obiekt serwera (0x220 B), `EEPhysics` (0x100 B); kroki `pamiec_u32`, bez zapisu do pamięci.
- Wyniki lokalne nie są dodawane do repozytorium.
