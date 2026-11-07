# Prędkość jednostek – Empire Earth 1 / The Art of Conquest

Etap 13 OpenEE. Dokument wyjaśnia rozbieżność mnożnika prędkości z etapów 9 i 12: **1,46** na Riverlands (AoC)
i **1,706** na „Wojnie trojańskiej” (EE i AoC). Pomiary wykonano w oryginalnych grach, w kopii testowej plików exe
bez filmów startowych (`Riverlands_MCP`, `ee_start.py`), tylko odczytem pamięci procesu.

**Oznaczenia:**
- **[P]** potwierdzone powtarzalnym pomiarem;
- **[W]** wniosek z ograniczonego pomiaru;
- **[H]** hipoteza;
- **[N]** nieustalone.

**Zakres:** EE, AoC, obie.

## 1. Wynik w skrócie

| Ustalenie | Pewność |
|---|---|
| `Speed` z `dbobjects` podaje pola na sekundę **czasu gry**. | [P] |
| Przy normalnej szybkości czas gry płynie **1,461** raza szybciej niż rzeczywisty (EE i AoC jednakowo). | [P] |
| Prędkość w polach na sekundę rzeczywistą = `Speed` × 1,461. To mnożnik z etapu 9. | [P] |
| Wartość 1,706 z etapu 12 to artefakt metody pomiaru (maksimum próbek), a nie cecha scenariusza. | [P] |
| W scenariuszach testowych zbudowanych z kampanii „Blitzkrieg” jednostki gracza 1 mają dodatek +0,15 pola/s czasu gry (obywatel, prorok; EE i AoC). | [P] pomiar, przyczyna [N] |
| Prorok nie ma własnego mnożnika: prędkość = `Speed`, a w „Blitzkriegu” `Speed` + ten sam dodatek co obywatel. | [P] |
| Rozpędzanie trwa ok. 0,3 s; potem prędkość jest stała. | [W] |

## 2. Zegar gry

Licznik czasu gry znaleziono w obiekcie gry (`A_GRA`, ten sam układ w EE i AoC). Narzędzie: `ee_czas.zegar_gry_znajdz`.
Algorytm zegara (obiekt `EEPhysics`, czas gry = takty × 1000·G/n przy n = 44 i szybkości gry G = 1,5) odtworzono
w etapie 14: `docs/titan/zegar_symulacji.md`.

| Pole | Tempo (na sekundę rzeczywistą, zegar monotoniczny) | Znaczenie | Pewność |
|---|---|---|---|
| `A_GRA+0xD0` (u32) | 1460,7–1461,5 | milisekundy czasu gry; typowy krok 68 ms co 2 takty; stoi w pauzie (F3) i w przerywniku scenariusza | [P] |
| `A_GRA+0xB4`, `+0xC8` | 43,32 | takty symulacji (≈33,75 ms czasu gry na takt); stoją w pauzie | [P] [Etap 14 – doprecyzowane: 42,68–42,86 taktu/s, krok 34,09 ms; `+0xC8` to licznik okna statystyki, zerowany – `docs/titan/zegar_symulacji.md` § 4] |
| `A_GRA+0x5C` | 45,5 | klatki obrazu (biegną w pauzie) | [W] [Etap 14 – zastąpione: wywołania funkcji taktu przez wątek symulacji, timer 22 ms] |
| `A_GRA+0x80` | 49,98 | nieustalone | [N] [Etap 14: suma taktów przydzielonych komunikatami] |

Pomiary tempa ms czasu gry, po 5–10 s każdy:

| Zadanie | Gra | Scenariusz | ms gry / s |
|---|---|---|---|
| 292 | EE | e13_predkosc (z „Blitzkriegu”) | 1461,0 |
| 307 | EE | jw. | 1460,9 |
| 308 | AoC | jw. | 1461,1 |
| 337 | EE | „Wojna trojańska” | 1461,5 |
| 342 | EE | „Wojna trojańska” | 1461,0 |
| 346 | AoC | „Wojna trojańska” | 1460,7 |
| 268–335 (20 przebiegów kolizji) | EE, AoC | scenariusze kolizji | 1440–1484 dla pojedynczych przejść (krótkie odcinki ruchu), średnio ≈1461 |

Klawisz „Pause” nie zatrzymuje gry, pauzuje dopiero F3 [P]. W „Wojnie trojańskiej” zegar stoi przez cały przerywnik
otwierający, który ma dwa ujęcia; każde z nich pomija się klawiszem Esc [P].

## 3. Dlaczego etap 12 dał 1,706

Położenie jednostki w pamięci zmienia się skokowo raz na takt (43,32 taktów/s). Próbki 10 Hz obejmują 4 albo 5
taktów, więc droga między próbkami waha się o ~25%. Etap 12 przyjął **maksimum** prędkości z próbek, czyli przypadki
z 5 taktami w odstępie 0,1 s, co zawyża wynik. Prędkość policzona jako droga / czas na środkowych 60% ruchu daje
na tych samych danych `Speed` × 1,43–1,50 [P]. Nowe narzędzie (`ee_czas.ruch_czas`) zapisuje w każdej próbce zegar
monotoniczny i licznik czasu gry i liczy prędkość właśnie tak.

## 4. Pomiary prędkości (etap 13)

Prędkość w polach na sekundę czasu gry = droga / przyrost licznika `A_GRA+0xD0`, liczona na środkowych 60% ruchu.

| Scenariusz | Jednostka (`Speed`) | Gra | Pola/s gry | Pola/s rzeczywiste | Uwagi |
|---|---|---|---|---|---|
| kolizje (z „Blitzkriegu”), 10 przebiegów EE (57 przejść) + 10 AoC (50 przejść) | obywatel (0,5) | EE, AoC | 0,650 (EE 0,642–0,656; AoC 0,642–0,653) | 0,94–0,957 | trasy 2,5–14 pól |
| e13_predkosc, zad. 307/308 | prorok (0,45), 2 jednostki | EE, AoC | 0,600 / 0,600 | 0,875–0,877 | trasa 27–28,6 pola (wymaganie 15–30) |
| „Wojna trojańska”, zad. 342 / 346 | prorok (0,45) | EE, AoC | 0,461 / 0,461 | 0,673 / 0,672 | trasa 5,7–5,8 pola |
| „Wojna trojańska”, zad. 342 / 346 | gwardia królewska (0,6) | EE, AoC | 0,575 / 0,575 | 0,839 / 0,841 | trasa 16,8 pola obok murów, z zakrętami (−4%; prawdopodobnie obroty w zakrętach [H]) |
| „Wojna trojańska”, etap 12 (przeliczone średnią) | obywatel, gwardia, bohater | EE, AoC | `Speed` × 1,00 ± 3% | `Speed` × 1,43–1,50 | – |
| Riverlands, etap 9 | obywatel, miecznik, jeździec | AoC | `Speed` × 1,00 ± 3% | `Speed` × 1,45–1,55 | – |

Wnioski:
- Bez dodatków prędkość = `Speed` pól na sekundę czasu gry [P]. Obejmuje to trzy scenariusze, obie gry i pięć typów
  jednostek.
- W scenariuszach z „Blitzkriegu” obywatel ma +0,150 pola/s, a prorok +0,150 pola/s ponad `Speed` [P]. Dodatek jest
  stały, nie procentowy: jako mnożnik wyszłoby 1,300 dla obywatela i 1,333 dla proroka (rozrzut pomiaru ±1%).

## 5. Dodatek w scenariuszu „Blitzkrieg” – co sprawdzono

Zmieniano jeden czynnik naraz:
- **Gra.** EE i AoC dają ten sam wynik, więc to nie różnica kodu.
- **Typ jednostki.** Obywatel i prorok mają ten sam dodatek, więc to nie cecha typu.
- **Scenariusz.** „Wojna trojańska” i Riverlands nie mają dodatku. To cecha scenariusza albo jego gracza 1
  („Niemcy”, epoka 10 – atomowa II wojna światowa).
- **`dbobjects`.** Rekordy obywatela (32) i proroka (216) są te same we wszystkich scenariuszach: `Speed` 0,5 / 0,45.
- **Obiekt klasy w pamięci.** Pole `Speed` (klasa +0x430) ma 0,5 / 0,45, bez dodatku, a przyspieszenie (+0x438)
  wynosi 1,2 / 2,0. Zmodyfikowanej prędkości nie znaleziono ani w obiekcie jednostki, ani w obiekcie klasy (zad. 297).
- **Technologie gracza 1.** Scenariusz ma 63 zbadane technologie. Wśród ich efektów nie ma zmiany atrybutu 9
  (`dbeffects`, kod 2 – zmiana atrybutu), z wyjątkiem „Epoch Atomic – WW2”, który dotyczy pocisku obywatela,
  a nie prędkości. Technologie z premią prędkości (Sandals, Oracle, Pharmacy, Orthopedics; +0,05 każda) nie są
  zbadane.
- **Cywilizacja.** Gotowa cywilizacja „Germany” (`civilizations/germany.civ`) nie ma premii prędkości: atrybut 5
  w `dbcivilization` nie występuje w jej 14 wpisach. Gdzie scenariusz zapisuje cywilizację gracza – [N].
- **Teren.** Płaski obszar testowy, wysokość 0,82, ten sam typ terenu. Wpływu terenu nie badano osobno.

Przyczyna dodatku pozostaje **[N]**. Najbliższe tropy:
- zapis cywilizacji gracza w scenariuszu, z kategorią „Civ – Citizens” i premią „Speed bonus”;
- wpływ epoki na prędkość jednostek.

## 6. Przyspieszenie i obrót

- Start do pełnej prędkości trwa ok. 0,3 s czasu rzeczywistego. Wynik zgadza się z `Acceleration` 1,2 (obywatel)
  przeliczoną na czas gry [W].
- Obrót przed startem jest pomijalny, poniżej 0,5 s, jak w etapie 9 [P].
- OpenEE nie modeluje rozpędzania. Przy trasach powyżej 2 pól różnica czasu dojścia wynosi poniżej 0,15 s.

## 7. Skutki dla OpenEE

| Zmiana | Plik |
|---|---|
| `Symulacja.MNOZNIK_PREDKOSCI` = 1,461 (było 1,46). Opis stałej: Speed = pola/s czasu gry × tempo zegara gry. | `godot/silnik/symulacja/symulacja.gd` |
| Wpis „mnożnik zależny od scenariusza 1,706” zastąpiony wpisami `zegar_gry_na_sekunde` (1,461; EE = AoC) i `modyfikator_predkosci_blitzkrieg` (0,15; [N] przyczyny, bez implementacji). Usunięta „różnica” prędkości proroka. | `dane/mechaniki_ee_aoc.json` |
| Testy E13 „prędkość”: stała = zegar gry z danych, brak mnożnika scenariusza, dodatek tylko udokumentowany. | `godot/testy/testy_etapu13.gd` |

Bez osobnego mnożnika dla proroka, bez dodatku „Blitzkriegu” (przyczyna nieznana) i bez rozpędzania.

## 8. Narzędzia i dane

- `Riverlands_MCP/riverlands_mcp/ee_czas.py`:
  - `zegar_gry_znajdz`, `zegar_pomiar`;
  - `ruch_czas` – trajektorie `[t_monotoniczny, ms_gry, x, y]` w `Testy_MCP/ee_ruch/*.json`, lokalnie;
  - `typ_pamiec` – pola obiektu jednostki i klasy.
- Scenariusze testowe: `narzedzia/eksperymenty/scenariusz_testowy_kolizji.py`. Buduje je z kopii „Blitzkriegu”: klonuje rekordy
  jednostek gracza 1 na płaski obszar. Oryginalne pliki scenariuszy pozostają niezmienione.
- Wyniki zadań: `Testy_MCP/ee_zadania/292–345_*.wynik.json`, lokalnie, poza repozytorium.
