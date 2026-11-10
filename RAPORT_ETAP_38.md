# Raport – etap 38: pełne odtworzenie 619 z bohaterem, osiągalność celów, kurs i fizyka obrotu

Etap 38 odtworzył scenariusz `e35_a` w pełnym składzie (bohater 0x5000ad2, druga gwardia, obywatel gracza 1,
gwardia komputera, budynki z efektami). Główna gwardia (0x1000856) zgadza się teraz z grą w każdym takcie całych
nagrań 616, 619, 620 i nowego 622, a HP bohatera – w całym 619. Etap dodał do Core dwie reguły z kodu i pomiaru:
regenerację HP (0x625B47) i obrót trybu 1 do celu EEUGLocation. Pokazał też, że rozbieżności kursu 619/620 nie były
błędem fizyki.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieznane.
Wszystkie wnioski o zgodności z Titan pochodzą z nagrań gry (MCP), nie z testów syntetycznych.

## 1. Commit początkowy i końcowy

- Początek: `0992d63` (lokalny etap 37; GitHub bez zmian na `c776a61`).
- Koniec: jeden lokalny commit etapu 38 (hash w podsumowaniu sesji / `git log -1`). Bez push, pull, fetch, reset i rebase.
- Niezatwierdzone pliki użytkownika `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11` zostały poza commitem.

## 2. Scenariusz 619 z bohaterem

**Parametry bohatera** (zad. 621, odczyt typu, ulepszenia i tablic EE [P]): typ 173, gracz 5, klasa trafienia 8,
rodzina ataku 55, rodzaj/wiersz 5, łuk 0,349066, rozmiar 0,55, punktowy, szukanie 1000 ms, zasięg 0,6, LOS 6, atak 14,
pancerz [3,0,3,0,0,0], przeładowanie 2000, HP 1235, a 2,0, vmax 0,8, α = ωmax = 6,98132, +0xAC 0,8.
Z dbobjects [P]: „Health regeneration” 2, „Healer heal amount” 50, zasięg leczenia 4,0.
Brakujące pola: c4/c8 ruchu bohatera. Bohater w 619 nie rusza się, więc wpływ jest zerowy [N].

**Mechanizmy bohatera:**
- Morale: zestaw TC (szablon 4, typ 5) nie obejmuje typu 173, więc brak morale [P: efekty e35_a].
- Leczenie: to regeneracja własna, nie leczenie z zewnątrz. Rozpoznana w kodzie 0x625B47: +2 HP przy każdym
  wyzerowaniu odliczania +0x290. Odliczanie spada o 34 ms na takt i wraca do 1000, czyli okres to 30 taktów.
  Licznik startowy odczytany z nagrania (619: 898, 622: 1000) [P].
- Leczenie innych (Healer.tai, stan 16000 LookForHealee) – w 619 nikogo nie leczy; skrypt poza Core [N].

**Wyniki odtworzenia** (narzędzie `odtworz_e35.gd --pelny=1`, porównanie `porownaj_pelny.py` i `porownaj_macierz.py`):

| Jednostka | Zgodne takty stanu | Pierwsza różnica | Uwagi |
|---|---|---|---|
| Gwardia A 0x1000856 | 7270 / 7273 (3 próbki spóźnione) | brak | macierz, pozycja, v i ω bitowo w 6375 taktach ruchu |
| Bohater 0x5000ad2 | HP: wszystkie 7273 | stan 5001 w 79045 | 79 trafień po 14 HP, regeneracja w tych samych taktach |
| Gwardia K 0x1000858 | 3350 | 124254 (gra 2016, Core 9006) | EEUGLocation przed celem ataku (§ 3) |
| Prorok, obywatele, gwardia T | wszystkie | brak | – |

Stany bohatera 16000 i 2025 (leczenie) narzędzie pomija jawnym parametrem. Stan 5001 po trafieniu też nie
jest modelowany.

**Pierwsza rozbieżność z etapu 37 (t = 71988) usunięta.** Kolejka celów pokazuje, że cel utworzony w 71988 ma
`pochodzenie` 0. To wybór AI: Idle `CanISeeEnemy` → CheckRange w takcie po porzuceniu obywatela. Nie był to
rozkaz gracza. Rozkaz MCP na bohatera wszedł w 88694. Etap 37 przypisywał 71988 rozkazowi. Core z bohaterem
wybiera go sam w tym samym takcie.

**Próbki spóźnione** (nie usunięte, liczone osobno):

| Nagranie | Spóźnione | Spoczynek przed 1. rozkazem z różnicą macierzy |
|---|---|---|
| 619 | 14 | 884 próbki, maks. 1,36·10⁻⁵ |
| 616 | 5 | 1102 próbki |
| 620 | 4, w tym odczyt pośredni 2016 | 870 próbek |
| 622 | 8 | 889 próbek |

Różnica w spoczynku to macierz startowa z SCN wobec macierzy z kursu Core. Znika przy pierwszym obrocie.

## 3. Eksperymenty ze zmianą pól (priorytet B)

- **B1** (zad. 622, [P]): gwardia porzuciła obywatela i zaatakowała bohatera jak w 619. Potem PPM na
  (162,5; 108,5). Z nowego pola AI wybrała obywatela ponownie w 94524. Stało się to 22,8 s po ostatnim wpisie do
  mapy nieosiągalnych, czyli przed upływem 30 s. Wpis z innym polem atakującego nie blokuje wyboru.
  Dalej: nowy wpis, cykl 8000/9006, porzucenie w 108741 i znów wybór bohatera.
  Reguła z etapu 37 (pola w kluczu ważności wpisu) daje cały zapis 622 co takt (6725 taktów). Nowego licznika
  nie dodano.
- **B2** (zmiana pola celu): niezmierzone. Celu wroga nie da się przesunąć przez MCP. Wymaga celu gracza-człowieka
  ze słabszym atakującym AI albo celu poruszanego skryptem [N].
- **B3** (dwie gwardie na jeden cel): rozkaz dla drugiej gwardii `walka_atak_rzut_gry` zgłasza jako nieudany
  (621, 619, 620), choć cel wchodzi później. Kolejka celów pokazuje czasy: 123981, 152108, 180236. Druga gwardia
  ma inny przebieg niż pierwsza:
  - PrepareToMove omija miejsce zajęte przez gwardię A;
  - wstawia EEUGLocation (163,5; 103,5) przed celem ataku, a trasa ma tylko 1 punkt;
  - po zdjęciu EEUGLocation wraca do 2016, wykonuje drugi PrepareToMove i 9006;
  - na końcu usuwa cel gracza.

  Core nie ma testu zajętości ani wstawiania EEUGLocation, dlatego rozbieżność w 124254 (619) i 109423 (620).
  Pytania o niezależne mapy i liczniki dwóch atakujących pozostają [N]. Wstawiania nie wdrożono bez kodu
  0x632CF4/0x62D696.

## 4. 0x62D696, 0x5ECAD0, 0x632CF4, 0x622776, 0x623717 (priorytet C)

- **0x5ECAD0** [W]: spójność regionów mapy, nie A*.
  - Najpierw test bezpośredni 0x4256BE(jednostka, pole celu).
  - Potem identyfikatory regionów pól (+0xDA z 0x42C49A) i macierz połączeń [0x917CC4].
  - Nie zależy od rozmiaru jednostek ani od zajętości przez jednostki; zajętość przez obiekty mapy – [N].
- **0x62D696** [W, z etapu 37]: odrzuca pole celu −10000. Szybka prawda, gdy typ+0x430 = 0, gdy (+0x5D4 & 6) = 0
  albo przy warunku odległości. W pozostałych przypadkach ograniczony A* 0x4A189C w oknie ≤ 0x23 pól. Limit
  iteracji i moment przeliczenia – [N].
- **0x622776, 0x623717** [W]: miejsca wywołania wpisu 0x5E8651.
  - 0x622776: w PrepareToMove, przed funktorem 0x6233D2/0x630013.
  - 0x623717: w akcji wracającej do 0x6236DD.
- **0x632CF4** [W, etap 37]: wybór miejsca podejścia. Pomiar 619/620 pokazuje, że pomija miejsce zajęte przez
  inną jednostkę [P: wybrane (164,5; 105,025) zamiast bliższego (163,975; 105,025)]. Kod testu zajętości
  niezlokalizowany.
- Core nie zastępuje tych funkcji testem odległości. 0x62D696 i 0x5ECAD0 nadal przyjmowane jako prawda – oznaczone
  w diagnostyce jako założenie [N].

## 5. Kurs i fizyka obrotu (priorytet D)

- **619/620** (≈3,1·10⁻⁴ rad): to nie błąd fizyki [P]. Przyczyny były dwie: porównanie kursu Core z tablicy
  UMArcTan2 z `math.atan2` serii gry oraz zaokrąglone współrzędne kliknięcia. Po porównaniu macierzy i użyciu
  dokładnego punktu macierze są identyczne bitowo: 619 – 6375 taktów, 620 – 5546, 622 – 5831, 616 – 5317.
- **Miara kursu w CTest** liczy teraz kurs Core tą samą funkcją co seria gry: `atan2(−m01, m11)` w f64. Tolerancje
  bez zmian.

| Seria | Pierwszy rozbieżny takt | Stan po poprawce miary |
|---|---|---|
| 590 G1 | 97 | teraz z powodu ω, kurs dopiero od 98 |
| 578 G3 | 169 (ω) | bez zmian, kurs dopiero od 190 |
| 589 G3 | 1 (kurs) | bez zmian |
| 580 G1 | 57 (stan) | bez zmian |
| EE 500 | – | koniec ruchu +1 bez zmian |

- **590 G1, takt 97**: rzeczywista różnica długości kroku 0x1000855 przy kontaktach: Core 0,00356, gra 0,00414
  = v·dt, przy tym samym v i kursie. Odwrócenie kolejności listy psuje 578 G1, więc kolejność nie jest przyczyną.
  Przyczyna [N].
- **578 G3 (ω, 169) i EE 500 (+1)**: brak nowych dowodów, bez zmian.
- **Wspólna przyczyna** wszystkich czterech: nie znaleziono [N]. Funkcji fizyki nie zmieniano bez dowodu, kursu nie
  korygowano ręcznie.

## 6. Zmiany w C++

- `ParametryWalki::regeneracja` (typ+0x578), `BojJednostki::regeneracja_ms` (+0x290) i reguła 0x625B47 w
  `Swiat::liczniki_walki` [P].
- Tryb 1 bez celu-jednostki: pozycja celu = punkt EEUGLocation z czoła kolejki [P: 622, takt 86682 – rozkaz ruchu
  w trakcie WaitForReload].
- GDExtension 0.12.0:
  - `ustaw_modyfikator_wysokosci(bool)`;
  - `ustaw_efekty_obszaru(dict)` i `odtworz_efekty_obszaru()` (format narzędzia `efekty_obszaru.py`);
  - `morale(id)`;
  - w `ustaw_walke` klucze `regeneracja`, `regeneracja_ms`, `ai_szuka_wrogow`, `ai_poscig_poza_icl`,
    `ai_wraca_do_icl`, `ai_moze_swobodnie`.
- `testy_core.cpp`: miara kursu (§ 5).
- `odtworz_e35.gd`:
  - `--pelny=1` (pełny skład z bohaterem), `--efekty`, `--wysokosc`, `--regen-ms`;
  - rozkazy `T:atak:hero|cit:A_GRD|K_GRD`;
  - przejścia i HP wszystkich jednostek, zdarzenia walki.
- `struktury_titan.json`: +0x290 i +0x578 z pewnością [P].

## 7. Wyniki porównań

| Seria | Wynik etapu 38 |
|---|---|
| 616 (pełny skład) | gwardia A: 6420/6423 taktów stanu, macierz bitowo. Inne jednostki: obywatel gracza 1 do 136289, potem cel MCP spoza odtworzenia; 0x1000858 do 220671 (rozkaz nieodtwarzany) |
| 619 | jak w § 2 |
| 620 | gwardia A: 6418/6419 (1 odczyt pośredni 2016), macierz bitowo; 0x1000858 do 109423 |
| 622 (nowe) | gwardia A: 6725/6728, macierz bitowo |
| 578 G1 | 986/986 bez różnicy |
| 578 G3 | 1286 porównań; pierwsza różnica 169 (ω), bez zmian |
| 590 G1 | 1107 porównań, stan i HP bez różnicy; pierwsza różnica 97 (ω) |
| AoC 505 | pierwsza różnica 803, bez zmian |
| EE 500 | koniec +1, bez zmian |
| S1–S7 | `68b0c69ecb8b0cbc` |
| Mapa | `c8297c16f0d48b1a` |

## 8. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | 33/33 (+3: regeneracja, limit HP max, efekty ze słownika) |
| Godot | 325/325 |
| MCP | 16/16 |
| Narzędzia Titan | 20/20 |
| `git diff --check` | czysty |

## 9. Potyczka w Godocie

Test sceny z renderem (xvfb, OpenGL 3, 1280×800, `--potyczka-demo=70 --potyczka-restart`) pokazuje dwie bitwy
wygrane, a restart działa. Scena przegranej (jeden na pięciu): przegrana w takcie 757.

Przebieg demo różni się od etapu 37 (wygrana w takcie 1301/1334 zamiast 1412/1509). Przyczyna to nowa reguła
obrotu do punktu EEUGLocation: demo wydaje rozkazy ruchu w trakcie walki. Godot dalej tylko przedstawia stan Core.

## 10. Mechanizmy niewyjaśnione

- EEUGLocation przed celem ataku i usunięcie celu gracza po drugim 9006 (druga gwardia) – test zajętości miejsca
  podejścia [P pomiar, N kod].
- Skrypt bohatera (Healer.tai: 16000, 2025) i stan 5001 po trafieniu [N].
- Długość kroku 590 G1 w takcie 97 i ω 578 G3 w takcie 169 [N].
- Limit iteracji A* 0x62D696 i moment przeliczenia osiągalności [N].
- B2 (zmiana pola celu) i niezależność map przy dwóch atakujących [N].

## 11. Prognoza

Walka wręcz jednego atakującego, z porzuceniem nieosiągalnego celu, regeneracją i wyborem AI, zgadza się co takt
w czterech pełnych nagraniach. Następny krok to wielu atakujących na jeden cel, czyli zajętość miejsc podejścia i
EEUGLocation. Szacunek bez zmian: 2–3 etapy do zgodności walki wręcz w małych grupach, potem jednostki dystansowe.

## 12. Propozycja etapu 39

1. Kod testu zajętości miejsca podejścia (0x632CF4 → 0x63234D) i wstawiania EEUGLocation przed celem ataku. Pomiar:
   dwie gwardie na stojący cel z różnych stron, z czasem utworzenia celów z kolejki.
2. Metoda MCP wyboru drugiej jednostki (rozkaz wchodzi z opóźnieniem; sprawdzenie kontroli LPM).
3. B2: cel gracza-człowieka przesuwany rozkazem, atakujący AI z wpisem w mapie nieosiągalnych.
4. Skrypt Healer.tai bohatera (16000) i stan 5001.
5. 590 G1 takt 97: zrzut push i kontaktów obu jednostek z pamięci w taktach 95–98.
