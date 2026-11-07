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
