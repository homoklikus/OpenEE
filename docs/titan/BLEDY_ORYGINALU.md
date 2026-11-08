# Rejestr błędów oryginału (Titan) – Empire Earth / The Art of Conquest

Centralny rejestr wykrytych i podejrzewanych błędów oryginalnego silnika, prowadzony od etapu 16. Zasada projektu
(`CLAUDE.md`): **OpenEE odtwarza oryginał wiernie, razem z jego błędami.** Błędy dokumentujemy, ale ich nie poprawiamy.
O ewentualnej naprawie, np. jako opcji, zdecydujemy dopiero po zakończeniu rekonstrukcji.

**Oznaczenia pewności:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza, czyli podejrzenie, nie fakt;
- **[N]** nieustalone.

Zachowanie, które tylko wygląda na błąd, wpisujemy jako **podejrzenie** z pewnością [H] albo [W].

**Status** każdego wpisu: „zachować zgodność – decyzja o ewentualnej naprawie odłożona”, chyba że wpis stanowi inaczej.

## Wzór wpisu

```
### BO-<numer>: <krótki tytuł>
- Zachowanie:
- Lokalizacja EE / AoC (pliki, adresy funkcji):
- Przyczyna:
- Skutki:
- Pewność:
- Status:
- Źródło (dokument, etap, zadania MCP):
```

## Wpisy

### BO-1: Przepełnienie 8-bitowej wartości n w `NESynchronousServer::TuneForSlowCPU`

- **Zachowanie.** Serwer lockstep wylicza n, czyli liczbę taktów fizyki na sekundę, ze średniego czasu taktu:
  n = obcięcie(1000 / (t · 100 / próg)), gdzie próg to „PT Rate Tuning Threshold (percent)” = 30.
  - Przy t = 1 ms (na szybkim komputerze 0 jest zamieniane na 1) wynik to 300.
  - Wynik jest zapisywany do bajtu, więc n = 300 − 256 = **44**.
  - Granice z rejestru (min. 15, maks. 125) są sprawdzane dopiero po obcięciu do bajtu, więc nie korygują wyniku.

  Zamiar autorów był najpewniej taki, by przy szybkim komputerze n przyjęło wartość maksymalną 125 [W].
- **Lokalizacja.** `Low-Level Engine.dll`, `NESynchronousServer::TuneForSlowCPU`:
  - EE: 0x10055099, DLL SHA-256 `0350ef77…8e05b`;
  - AoC: 0x1004907E, DLL SHA-256 `4acf0404…cbefb`.

  Zapis bajtu `+0x1FB` obiektu serwera następuje przed porównaniem z `+0x1B4`/`+0x1B8`. Kod w obu DLL jest identyczny.
- **Przyczyna.** Wartość jest przenoszona przez rejestr 8-bitowy i zapisywana do pola `u8` przed porównaniem
  z granicami. Porównanie dotyczy już obciętej wartości rozszerzonej zerami.
- **Skutki.**
  - W grze jednoosobowej (pomiar w EE i AoC): n = 44, porcje po obcięcie(44 · 0,35) = 15 taktów co 350 ms, czyli
    42,857 taktu/s.
  - Krok czasu gry wynosi 1000 · G / 44 ms, timer fizyki 22 ms.
  - Czas gry płynie 1,461 × szybciej niż rzeczywisty zamiast nominalnych 1,5. To jest tempo zmierzone w etapie 13.
  - n zależy od wydajności komputera (tabela w `przydzial_taktow.md` § 3) [W].
- **Pewność:** [P] – kod jednoznaczny w obu grach. Pomiar: n = 44, takty na komunikat = 15 (zadania MCP 364, 366).
  Wartość 44 jest możliwa tylko przy wyniku 300.
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona. Odtworzenie w OpenEE: stałe n = 44 z porcjami
  po 15 taktów, a nie „poprawione” 125 ani tempo 1,5.
- **Źródło:** etap 15, `docs/titan/przydzial_taktow.md`, `raporty/archiwum/RAPORT_ETAP_15.md`.

### BO-2 (podejrzenie): klucz przydziału pozycji szyku liczony od początku układu mapy z wartością bezwzględną

- **Zachowanie.** W ścieżce dalekiej przydziału celów jednostkom (stan grupy 8000) pozycje szyku i jednostki są
  sortowane według klucza k(p) = |a·y + b·x| + |0,1·b·y − 0,1·a·x|. Para (a, b) to kierunek od środka jednostek do
  środka szyku, znormalizowany sumą wartości bezwzględnych. Rzuty są liczone dla **bezwzględnych współrzędnych mapy**,
  nie względem środków, i potem brana jest ich wartość bezwzględna.
  - Dopóki wszystkie rzuty mają ten sam znak, kolejność odpowiada ustawieniu poprzecznemu i przydział zachowuje szyk.
  - Gdy prosta zerowego rzutu przechodzi przez obszar grupy, wartość bezwzględna „składa” kolejność i jednostki z obu
    stron osi mogą dostać pozycje na krzyż. Ta prosta przechodzi przez początek układu mapy, a przy ruchu po przekątnej
    także przez środek mapy.

  Zamiarem autorów było najpewniej porządkowanie względem środka grupy [H].
- **Lokalizacja.** `Empire Earth.exe` 0x5DB641 (klucze pozycji ok. 0x5DBFF2–0x5DC105, jednostek 0x5DC186–0x5DC277),
  `EE-AOC.exe` 0x5EBF85 (ta sama logika).
- **Przyczyna.** Obliczenie rzutu bez odjęcia punktu odniesienia; `fabs` po obu składnikach [W: kod].
- **Skutki.** Możliwe krzyżowanie się tras jednostek przy niektórych kierunkach i położeniach na mapie [H].
  W pomiarach etapu 18 wszystkie rzuty miały ten sam znak i przydział był zgodny z modelem.
- **Pewność:** kod [W] – odczytany jednoznacznie, ale bez pomiaru przypadku złożenia; skutek [H].
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona. OpenEE ma odtwarzać klucz dokładnie,
  z wartością bezwzględną i współrzędnymi mapy.
- **Źródło:** etap 18, `docs/titan/cele_jednostek.md`.

### BO-3 (podejrzenie): flaga kierunku w przydziale bliskim liczona względem stałej osi +y mapy

- **Zachowanie.** W ścieżce bliskiej przydziału pozycji szyku (stan grupy 8000, cel przy grupie) jednostki o tej samej
  prędkości i „Size of collider” wybierają pozycje w kolejności numerów w grupie: rosnąco albo malejąco. O kierunku
  decyduje flaga: ile jednostek ma kąt ≤ π/2 między wektorem (pozycja − cel) a osią odniesienia; gdy co najmniej
  obcięcie(n/2), numery rosną.
  - Osią odniesienia jest wektor (0, 1, 0) przekształcony **domyślną** `GETransformation`, utworzoną w funkcji i
    nieustawioną. W praktyce to stała oś +y mapy, czyli flaga mówi, czy co najmniej połowa jednostek stoi na północ
    od celu (y ≥ G.y), niezależnie od kierunku rozkazu.
  - Po arccos funkcja zmienia znak kąta dla wartości ujemnej, ale arccos zwraca wartości ≥ 0, więc ta gałąź nigdy nie
    działa.

  Obecność przekształcenia i gałęzi znaku sugeruje, że autorzy chcieli liczyć kąt względem kierunku szyku (θ) [H].
- **Lokalizacja.** `Empire Earth.exe` 0x62D460 (wywołanie z 0x5DC490, próg π/2 w 0x831414); `EE-AOC.exe` 0x642345
  (wywołanie z 0x5ECDC7, próg w 0x846CF0). Kod identyczny.
- **Przyczyna.** `GETransformation::GETransformation()` bez ustawienia orientacji przed `Apply`; porównanie wyniku
  `UMArcCos` z 0 zamiast np. znaku iloczynu wektorowego [W: kod].
- **Skutki.** Kolejność wyboru jednostek jednego typu zależy od tego, po której stronie celu na osi północ–południe
  mapy stoją jednostki, a nie od kierunku ruchu. Przydział pozycji może się więc zmieniać przy obróceniu sytuacji na
  mapie [H]. Sam mechanizm flagi i oba kierunki numeracji zmierzono w EE i AoC (zadania 405, 412, 415).
- **Pewność:** zachowanie [P] – oś +y wynika jednoznacznie z kodu. W rozkazach 402 i 412 flaga liczona względem
  kierunku rozkazu θ dałaby inną kolejność i inny przydział niż zmierzony, a flaga z osi +y mapy daje zgodny wynik.
  To, że jest to błąd (zamiar autorów), oraz ocena skutków – [H].
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona. OpenEE ma liczyć flagę względem osi +y mapy,
  z progiem π/2 i progiem obcięcie(n/2).
- **Źródło:** etap 19, `docs/titan/przydzial_bliski.md`.

### BO-4 (podejrzenie): zwykły rozkaz aktywuje następny cel z kolejki przed jej wyczyszczeniem

- **Zachowanie.** Przy zwykłym rozkazie ruchu (bez Shift) obsługa stanu grupy 8000 wywołuje dla jednostki kolejno:
  - 0x5EAE25(0) – zdejmuje cel bieżący i, jeśli w kolejce jest następny „aktualny” cel (vtable +0x70; dla
    `EEUGLocation` zawsze tak), **aktywuje go** (vtable +0x54): ustawia stan 8000, a przy celu dokładnie w miejscu
    jednostki stan 5000 albo 9006, i powiadamia typ jednostki;
  - 0x5E9664(0) – czyści całą kolejkę, także właśnie aktywowany cel;
  - 0x5F05BD – wstawia nowy cel i ustawia stan 8000.

  Aktywacja celu, który za chwilę zostaje usunięty, wygląda na niezamierzoną. Prawdopodobnie miało to być samo
  wyczyszczenie [H].
- **Lokalizacja.** `Empire Earth.exe` 0x5DCCEF–0x5DCD03 (funkcje 0x5EAE25, 0x5E9664, 0x5F05BD); `EE-AOC.exe`
  0x5ED3DA–0x5ED3F1 (0x5F88FE, 0x5F6FBC, 0x5FE863). Kod identyczny.
- **Przyczyna.** Użycie funkcji „zdejmij bieżący i przejdź do następnego” przed czyszczeniem kolejki [W: kod].
- **Skutki.**
  - Dodatkowe przejścia stanu i powiadomienia typu jednostki w tym samym poleceniu [W].
  - Gdy następny cel leży dokładnie w miejscu jednostki, wejście w „Idle” może zdjąć kolejne cele i zgłosić jednostkę
    jako bezczynną (0x4A35AA), zanim dostanie nowy rozkaz [H]. [Etap 22 – poprawka opisu: 0x4A35AA anuluje prośby
    o trasę jednostki w `EEPathManager`, nie zgłasza bezczynności; hipoteza skutku dotyczy więc anulowania tras –
    `nawigacja_wejscie.md`.]
  - W pomiarach (zadania 435, 441) wynik końcowy był poprawny: w kolejce tylko nowy cel, stan ruchu.
- **Pewność:** kolejność wywołań [P: kod EE i AoC]; skutki uboczne [H], niemierzone.
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona. OpenEE ma wykonywać te same trzy kroki
  w tej samej kolejności.
- **Źródło:** etap 21, `docs/titan/kolejka_rozkazow.md`.

### BO-5 (obserwacja): limit „−1” w teście końca A* działa jak „limit osiągnięty”

- **Zachowanie.** Koniec wyszukiwania (cel vtable +8) ustawia flagę „szukaj najbliższego węzła” (+0x28), gdy
  iteracje ≥ limit całkowity. Porównanie jest ze znakiem, więc przy limicie −1 („bez limitu”) flaga jest ustawiana
  zawsze, także po dojściu do celu.
- **Lokalizacja.** `Empire Earth.exe` 0x41CC8E–0x41CCA0; `EE-AOC.exe` 0x40EA7B (funkcja identyczna).
- **Przyczyna.** Brak osobnego warunku dla −1, które pętla (0x4A5428) traktuje jako „bez limitu” [W: kod].
- **Skutki.** Trasa kończy się wtedy na najbliższym dostępnym węźle zamiast na węźle testu celu. Zwykle to ten sam
  węzeł. Prośby jednostek zawsze mają dodatni limit, więc w badanych ścieżkach skutku brak [W].
- **Pewność:** kod [W]; skutek w grze niezmierzony.
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona.
- **Źródło:** etap 24, `docs/titan/astar_wyniki.md` § 2.

### BO-6 (podejrzenie, zachowanie wyjaśnione w etapie 26 – nie jest błędem ruchu): trasa do celu nieosiągalnego przez pola niedostępne dla typu jednostki

- **Zachowanie.** Jednostka lądowa dostała rozkaz na wodę (156,143). Trasa w jej kolejce prowadziła prosto po x = 147
  przez pola z terenem 10, który tablica typu (`EEUCLand` +0x5D6) oznacza jako niedostępny, do punktu pośredniego grafu
  (147,154) za jeziorem. Jednostka zatrzymała się przed tymi polami (149,137) i straciła cel oraz trasę.
- **Lokalizacja.** Nieustalona: prośba jednostki 0x4A1AFF i etap grafu, możliwe też przekazanie trasy 0x4A2B29.
- **Przyczyna.** [N]. Hipotezy:
  - inne znaczenie komórki +4 dla terenu 10;
  - trasa spoza A*;
  - pozostałości pamięci podręcznej dostępności.
- **Skutki.** Jednostka przerywa ruch przy brzegu zamiast dojść do najbliższego dostępnego miejsca [P: pomiar EE
  481–483].
- **Pewność:** pomiar zachowania [P]; mechanizm i to, czy jest to błąd – [H].
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona; wymaga dalszych pomiarów.
- **Źródło:** etap 24, `docs/titan/astar_wyniki.md` § 7.
- **[Etap 25 – uzupełnienie]** Powtórka z innego punktu startu (EE 509–510, gwardia z (178,6; 125,2) na (156,5; 143,5))
  nie odtworzyła zachowania.
  - Jednostka przejechała m.in. przez (147,5; 145–148), obeszła jezioro i stanęła w najbliższym dostępnym polu
    (155,5; 151,5) bez utraty celu.
  - Możliwy mechanizm z kodu ruchu, nadal [H]:
    1. Pole niedostępne przy przejeździe blokuje krok (0x54E275) albo daje ciągłe odpychanie, więc +0x248 rośnie.
    2. Po 3–5 s następuje „ObstacleDetected” → 9002 RepathAroundObstacle.
    3. Po wyczerpaniu limitu prób celu (wejście w 8000) następuje Idle z porzuceniem celu.
  - Szczegóły: `docs/titan/ruch_trasa_przeszkody.md` § 4–5.

- **[Etap 26 – rozstrzygnięcie zachowania]** Odczyt końcowy zadania 483 (etap 24) pokazuje stan **6002 „UnitRotting”**
  (tryb 6), +0x1F0 = 0 i v = 0, czyli jednostka **zginęła** [P]. Powtórki EE 513–514 i 524 na ten sam cel kończą się
  tak samo: popychanie w rejonie (150–154, 126–131), potem 6000 Dying → 6002 → 6003 Dead, w obecności wrogów
  scenariusza [P].
  - „Zatrzymanie i utrata celu” to więc skutek śmierci, a nie błąd ruchu ani trasy.
  - Otwarte pozostaje tylko to, czy zapisana w etapie 24 trasa prowadziła przez pola z terenem 10. Powtórka szła inną
    trasą [N].
  - Wpis zostaje w rejestrze jako nierozstrzygnięte podejrzenie dotyczące wyłącznie trasy (`docs/titan/kolizje_objazdy.md`
    § 10).

### BO-7 (obserwacja): docisk ostatniego kroku porównuje prędkość z odległością i nie działa przy vmax

- **Zachowanie.** W fazie przyspieszania przy jednym punkcie trasy (+0x8C == 1) nowa prędkość v′ = v + a·dt jest
  obcinana do d (odległość do punktu), gdy v′ > d.
  - Jednostki się nie zgadzają: v′ jest w polach/s, d w polach. Wymiarowo poprawne byłoby v′·dt > d.
  - Gałąź jest pomijana, gdy v′ zostało wcześniej obcięte do vmax.
- **Lokalizacja.** `Empire Earth.exe` 0x54858E (gałąź 0x54860F–0x548639, argument d z 0x54D886); `EE-AOC.exe` 0x554BDE
  (logika identyczna według porównania stałych i struktury).
- **Przyczyna.** Porównanie z argumentem d bez mnożenia przez dt, sprawdzane dopiero w gałęzi „bez obcięcia do vmax”
  [W: kod].
- **Skutki.**
  - Przy jeździe z vmax docisk nic nie robi. Dojazd do celu zapewnia wtedy dokładna dyskretna droga hamowania S, a
    zatrzymanie w celu jest i tak dokładne [P: EE 500, AoC 505].
  - Przy krótkich rozkazach (d < ok. 0,6 pola) i przy ponownym przyspieszaniu tuż przed celem v′ = d. Krok na takt
    wynosi wtedy d·dt, a dojazd staje się wykładniczy (stała czasowa ok. 1 s gry), dopóki d ≥ 0,05 [W; skutek
    niezmierzony].
- **Pewność:** kod [W]; zgodność z pomiarem przy vmax [P]; skutek dla krótkich rozkazów niezmierzony.
- **[Etap 26 – potwierdzone pomiarem]** Skutek zmierzony w EE i AoC [P]:
  - krótki rozkaz EE 517 (cel ok. 0,4 pola): po rozpędzie v = d co takt, czyli 0,2556 → 0,2469 … (×0,966 = 1 − dt);
    dojazd ok. 80 taktów (2,7 s gry) zamiast ok. 15;
  - AoC 525 (Aleksander, ok. 0,5 pola): to samo, 0,6818 → 0,6667 → 0,644 …;
  - cel w miejscu jednostki (d < 0,05): v′ = d = 0, brak ruchu, od razu 9006 → 5001 → 5000.

  Przy v = vmax docisk nie działa. Także po hamowaniu na stoku v + a·dt w precyzji x87 jest o 7,5e-9 większe od vmax
  [P: model w precyzji 53/64 bitów bezbłędny w EE 517]. Model z dosłownym kodem odtwarza krótkie rozkazy co do taktu.
  Status bez zmian: zachować zgodność.
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona.
- **Źródło:** etap 25, `docs/titan/ruch_jednostki.md` § 5–6.

### BO-8 (podejrzenie): ocena stanu Idle „co 350 ms” działa w praktyce co takt

- **Zachowanie.** Krok maszyny stanów pomija ocenę w stanie Idle, gdy termin +0x254 jest **mniejszy** od zegara gry
  (EEPhysics+0xD0).
  - Każda ocena w Idle ustawia termin na zegar + 350 ms, a wejście w Idle na 0xFFFFFFFF.
  - Warunek pomija więc ocenę tylko wtedy, gdy od ostatniej oceny minęło ponad 350 ms, czyli praktycznie nigdy.
  - Idle jest oceniany co takt, a nie co 350 ms, jak sugeruje pole terminu.
- **Lokalizacja.** `Empire Earth.exe` 0x5F0F7E (porównanie z +0x254), wejście w Idle 0x61B05B; `EE-AOC.exe` 0x5FF2E8
  (+0x258) – identycznie.
- **Przyczyna.** Prawdopodobnie odwrócony warunek porównania [W co do kodu, H co do intencji].
- **Skutki.**
  - Każda jednostka w spoczynku ocenia co takt przejście CanISeeEnemy (szukanie wrogów).
  - Koszt obliczeń. Zmienia też chwile wykrycia wroga i wywołań generatora losowego, co wpływa na determinizm.

  Pomiar: przejście Idle → 2015 następuje w takcie zaraz po rozkazie [P]. Zgodne z oceną co takt, ale nie rozstrzyga.
- **Pewność:** kod [W]; intencja [H].
  **[Etap 27]** kod potwierdzony: skok `jb` (porównanie bez znaku), termin = zegar + 350 przy każdej ocenie. Wejście w
  Idle zużywa warunkowo 2 losowania globalnego generatora, więc błąd wpływa na sekwencję RNG całej gry. Pewność kodu
  [P], intencji [H] (`skrypty_stanow.md` § 6).
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona.
- **Źródło:** etap 26, `docs/titan/skrypty_stanow.md` § 3; etap 27, § 6.

### BO-9 (podejrzenie obalone w etapie 27 – zob. BO-9′): test bramy nadpisuje wynik testu zgodności rozkazów w pętli kolizji

**[Etap 27 – zastąpione]** Nadpisanie wyniku na 1 dotyczy tylko obiektów kategorii 0x19 (25), które nie są bramą,
czyli murów. Dla zwykłych jednostek wynik testu zgodności nie jest nadpisywany. Opis poniżej to pierwotna obserwacja.


- **Zachowanie.** W pętli kontaktów 0x5498C4 najpierw liczony jest wynik „zgodność rozkazów”: kontakt pomijany, gdy
  obie jednostki mają flagę +0x347 i ten sam rozkaz zbioru / budowy.
  - Następnie dla obiektu typu 25 sprawdzane jest rzutowanie na `EEUCGate`. Gdy się nie udaje, czyli dla każdego
    obiektu, który nie jest bramą, wynik ustawiany jest na 1 („kolizja”).
  - To nadpisuje poprzedni wynik, więc pominięcie kolizji dla zgodnych rozkazów nigdy nie działa.
- **Lokalizacja.** `Empire Earth.exe` 0x5498C4; `EE-AOC.exe` 0x5560CF (te same operacje, inne przesunięcia).
- **Przyczyna.** Przypisanie zamiast koniunkcji [W co do kodu, H co do intencji].
- **Skutki.** Jednostki wykonujące razem ten sam rozkaz zbioru lub budowy odpychają się mimo flagi +0x347 [H; dla
  ruchu zwykłego bez skutku].
- **Pewność:** kod [W]; skutek niezmierzony.
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona.
- **Źródło:** etap 26, `docs/titan/kolizje_objazdy.md` § 7.

### BO-9′ (podejrzenie): flaga pominięcia kontaktu nie jest zerowana między kontaktami

- **Zachowanie.** W pętli kontaktów 0x5498C4 flaga „pomiń kontakt” (zgodność rozkazów zbioru / budowy, +0x347)
  ustawiana jest przed pętlą i nie jest zerowana na początku każdej iteracji. Jeśli jeden kontakt ją ustawi, kolejne
  kontakty tej jednostki w tym samym takcie też mogą zostać pominięte.
- **Lokalizacja.** `Empire Earth.exe` 0x5498C4; `EE-AOC.exe` 0x5560CF.
- **Przyczyna.** Inicjalizacja zmiennej poza pętlą [W co do kodu, H co do intencji].
- **Skutki.** Jednostki zbierające razem surowce lub budujące mogą przenikać inne jednostki z listy kontaktów [H].
  Dla zwykłego ruchu bez rozkazów zbioru / budowy bez skutku [W].
- **Pewność:** kod [W]; skutek niezmierzony [H].
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona.
- **Źródło:** etap 27, `docs/titan/walidacja_kolizji.md` § 8.

### BO-10 (podejrzenie): punkt przechwycenia celu liczony z błędnie dodanymi składowymi z

- **Zachowanie.** Funkcja przechwycenia ruchomego celu 0x62C963 liczy długość wektora atakującego jako
  sqrt(dx² + dy² + 2·dz) zamiast sqrt(dx² + dy² + dz²), a iloczyn skalarny jako Dty·Day + Dtz + Daz + Dtx·Dax
  (składowe z dodane zamiast pomnożone). Punkt bieżący trasy celu ma z = 0, a odległość d jest liczona w 3D.
- **Lokalizacja.** `Empire Earth.exe` 0x62C963 (wołana z celu EEUGAttackUnit vt+0x08 0x60AF05 przez PrepareToMove
  0x6222A8); AoC – odpowiednik nieodczytany [N].
- **Przyczyna.** Sekwencja `fadd` w miejscu `fmul` dla składowych z [W co do kodu, H co do intencji].
- **Skutki.** Na terenie pochyłym punkt przechwycenia przesuwa się względem geometrycznie poprawnego; na płaskim
  (dz = 0) błąd znika. Pomiar 578 (takt 2076): punkt z gry (177,1906; 106,795) odtworzony bitowo **tylko** wzorem
  z błędami [P].
- **Pewność:** kod [W]; zgodność wyniku [P].
- **Status:** zachować zgodność – decyzja o ewentualnej naprawie odłożona. Core odtwarza wzór z błędami
  (`Swiat::punkt_podejscia`).
- **Źródło:** etap 31, `docs/titan/walka.md` § 10.
