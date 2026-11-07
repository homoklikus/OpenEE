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
