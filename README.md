# OpenEE

**OpenEE jest niezależną reimplementacją silnika Empire Earth opartą na Godot. Nie jest kompletną grą i wymaga legalnie
posiadanej instalacji Empire Earth Gold Edition / The Art of Conquest. Projekt nie jest oficjalnie powiązany z właścicielami
marki Empire Earth.**

Wersja: **0.5.2-dev** – wersja rozwojowa, niedokończony silnik. Wzorem jest OpenMW: kod silnika jest nowy, a wszystkie
grafiki, modele, dźwięki i teksty gry są wczytywane wprost z instalacji użytkownika (tylko do odczytu). Repozytorium nie
zawiera żadnych zasobów Empire Earth – patrz [docs/ZASOBY_ORYGINALNE.md](docs/ZASOBY_ORYGINALNE.md).

## Co już działa
* Odczyt archiwów **SSA** i dekompresja **DCL/PK01** (implementacja własna, w GDScript i Pythonie; w Pythonie opcjonalnie w C).
* Import tekstur **SST/TGA** i modeli **CEM** (wersje 2.0 i 1.3), z materiałem koloru gracza.
* **Animacje modeli** z oryginalnych danych: klatki CEM, sekwencje z tabeli `dbgraphics` (atak, ruch, bezczynność,
  śmierć, prace), hierarchia części (koła, wieżyczki) z transformacjami na klatkę, niezależna faza każdej jednostki,
  animowana woda – [docs/FORMATY_ETAP4.md](docs/FORMATY_ETAP4.md). Scena diagnostyczna: `./uruchom_openee.sh animacje`.
* Odczyt **scenariuszy** Empire Earth 1.x (wersja 231) i The Art of Conquest (wersja 250): teren, wysokości, gracze, obiekty.
* **Teren** odtwarzany według reguł oryginalnego silnika: mieszanie tekstur w narożnikach pól, warianty tekstur, woda
  z łagodnym brzegiem, klify jako tekstury i wysokości – [docs/FORMATY_ETAP3.md](docs/FORMATY_ETAP3.md).
* **Budynki i jednostki** w scenie podglądu (pozycja i obrót z danych scenariusza, kolory graczy), jednostki
  w animacji bezczynności, **grupowanie modeli** (MultiMesh) – statycznych i animowanych – dla dużych map.
* **Pierwszy interaktywny ruch jednostek (RTS):** zaznaczanie myszą, rozkaz ruchu, trasy A* na mapie wyprowadzonej
  z danych scenariusza (woda, klify, granice, budynki, drzewa), przechodniość z flag `dbobjects`, prędkość z tabel,
  animacje ruchu i bezczynności, stały krok symulacji – [docs/FORMATY_ETAP5.md](docs/FORMATY_ETAP5.md).
  Scena: `./uruchom_openee.sh rts` (LPM – zaznacz, PPM – idź, P – trasa, spacja – pauza).
* Tabele gry `db*.dat` (obiekty, grafiki, dźwięki, tereny…).
* **Lokalizacja PL/EN** ładowana z instalacji użytkownika – osobny wybór języka tekstów, głosów i kampanii
  ([docs/LOKALIZACJA.md](docs/LOKALIZACJA.md)).
* **Launcher** (PL/EN): wybór instalacji, profil gry, język, nakładki, uruchamianie scen podglądu.
* **Poprawne modele wieloczęściowe i wielomateriałowe** (0.5.1-dev – naprawa grafiki): indeksy materiałów względem
  `v_offset`, obraz tekstury wybierany przez `tekstura_id`, kolor gracza mnożony przez szarą teksturę –
  [docs/FORMATY_NAPRAWA_GRAFIKI.md](docs/FORMATY_NAPRAWA_GRAFIKI.md).
* **Diagnostyka modeli** (0.5.2-dev): scena `./uruchom_openee.sh model --model="Stable - Copper"` – części i materiały
  osobno, kolory materiałów, UV, indeksy, normalne, alfa, klatka CEM, odrzucanie ścian, test głębokości, przezroczystość,
  pary współpłaszczyznowe i duplikaty, opis trójkąta po kliknięciu; porównanie OpenGL/Vulkan `narzedzia/porownaj_renderery.sh`
  – [docs/FORMATY_DIAGNOSTYKA_051.md](docs/FORMATY_DIAGNOSTYKA_051.md).
* **Dwie gry na jednym silniku** – Empire Earth i The Art of Conquest: osobne definicje gier, formaty baz EE 1.0/AoC,
  izolacja danych (`--gra=ee|aoc`, karta „Gra” w launcherze) – [docs/WARIANTY_GRY.md](docs/WARIANTY_GRY.md).
* **Mechaniki zmierzone w oryginale** (etapy 6–13, odczyt pamięci gry – Riverlands_MCP): kamera EE (stały kąt,
  21 poziomów zoomu, przewijanie), zaznaczanie, szyk grupy, trasy oktylowe, prędkość z tempa czasu gry, przenikanie
  jednostek i objazd stojących, grafika zależna od epoki, przezroczystość budynków –
  [docs/ARCHITEKTURA_OPENEE.md](docs/ARCHITEKTURA_OPENEE.md) § 7.
* **321 testów automatycznych** bez okna (część wymaga instalacji gry – bez niej są jawnie pomijane).

## Ograniczenia (stan 0.5.2-dev)
* **Brak rozgrywki** – brak ekonomii, walki, SI, interfejsu gry; sceny są podglądem danych.
* Animacje odtwarzane z danych, ale tempo (czas cyklu z `dbgraphics`) i interpolacja między klatkami to hipotezy
  do potwierdzenia w grze; brak sterowania proceduralnego (celowanie wieżyczek, obrót części `orbital_*`, toczenie kół).
* Ruch jednostek: szyk, zaznaczanie grupowe, kolejka rozkazów i kolizje według pomiarów oryginału; brak formacji
  z przycisków i rozpędzania. Reguły przechodniości częściowo przybliżone (FORMATY_ETAP5 §2–3).
* Niepełny odczyt trzech scenariuszy kampanii EE (polimorficzna lista celów jednostki – jeden gracz częściowo).
* **Brak potwierdzonego porównania wizualnego z oryginalnym Empire Earth** – zgodność wynika z analizy formatów i testów
  na danych, nie z porównania zrzutów z gry.
* System modów nieukończony (na razie wyłącznie nakładki warstw zasobów).
* Testowane na Linuksie (Godot 4.7.2, renderer Compatibility). Inne systemy – nietestowane.

## Wymagania
* **Godot 4.7.x** (standardowy, bez .NET).
* Legalna instalacja **Empire Earth Gold Edition** (gra + The Art of Conquest), np. wersja GOG.
* Opcjonalnie **Python 3.8+** z Pillow i numpy – narzędzia analizy i przygotowania danych testowych.

## Uruchomienie
1. Sklonuj repozytorium.
2. Wskaż instalację gry (jedno z):
   * w launcherze: karta gry → **Zmień…**,
   * w `konfiguracja/openee.cfg` (sekcja `[instalacje]`),
   * zmienną środowiskową `OPENEE_EE_PATH=/ścieżka/do/Empire Earth Gold`.
3. Uruchom:
   ```
   ./uruchom_openee.sh            # launcher (Godot szukany w PATH, zmiennej GODOT lub obok projektu)
   ./uruchom_openee.sh scenariusz # podgląd kampanii testowej wybranej gry (EE: Wojna trojańska, AoC: Żołnierze dla Rzymu)
   ./uruchom_openee.sh testy      # testy bez okna → wyniki/testy_godot.json
   ```
   albo otwórz katalog `godot/` w edytorze Godota.
4. Pełny zestaw testów (porównania z czytnikami Pythona, lokalizacja PL) wymaga danych pomocniczych generowanych
   lokalnie z Twojej instalacji – nie są publikowane:
   ```
   narzedzia/przygotuj_dane_lokalne.sh "/ścieżka/do/Empire Earth Gold" ["/ścieżka/do/instalacji z wersją PL"]
   ```

Podgląd scenariusza z wiersza poleceń: `godot --path godot res://sceny/test_scenariusz.tscn -- --kampania=EETheGreeks.ssa --scenariusz-nr=3` (numer na liście kampanii – niezależny od języka instalacji)
(opcje: `--okno=r0,c0,n | pelne`, `--kamera=blisko`, `--zrzut=plik.png`, `--pomiar=N`, `--bez-animacji`).

Scena animacji: `./uruchom_openee.sh animacje --model=Phalanx --sekwencja=atak` (albo `--galeria=Phalanx;Citizen Paleo;Cannon - 12 Pounder`,
`--pomiar=100,1000,4000`, `--film=katalog`).

## Testy: bez okna i na GPU
| Zestaw | Polecenie | Wymaga |
|---|---|---|
| Testy Godota (formaty, scenariusze, symulacja, kamera, kolizje, model prędkości – 322 testy) | `./uruchom_openee.sh testy` albo `godot --headless --path godot --script res://testy/uruchom_testy.gd` | tylko CPU, **bez okna i GPU** (`--headless`); część testów pomijana bez instalacji gry lub danych lokalnych |
| Test wizualny modeli (OpenGL i Vulkan) | `GODOT=… narzedzia/test_wizualny_051.sh <katalog>` | **GPU** (bez GPU: xvfb + lavapipe – wynik nie jest weryfikacją GPU) |
| Porównanie rendererów | `narzedzia/porownaj_renderery.sh` | **GPU** |
| Zrzuty scen (`test_scenariusz`, `rts_test`, animacje `--film`) | `godot --path godot res://sceny/… -- --zrzut=plik.png` | **GPU** i okno (renderer okienkowy) |
| Pomiary oryginalnych gier (Riverlands_MCP, zadania `Testy_MCP/ee_zadania`) | narzędzia MCP | uruchomiona gra pod Wine, serwer X11; GPU jak do gry; poza repozytorium |

Testy z `--headless` nie sprawdzają obrazu. Renderer weryfikuje się zrzutami na prawdziwym GPU; w projekcie robi się
to na RTX 5090, narzędziem `oe_render` z Riverlands_MCP, zawsze przy zamkniętej grze oryginalnej.

## Dokumentacja
* [docs/ARCHITEKTURA_OPENEE.md](docs/ARCHITEKTURA_OPENEE.md) – **od tego zacznij**: moduły, punkty wejścia, przepływ danych EE/AoC, stan wiedzy o mechanikach
* [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) – zasady i opisy z etapów 1–11; [docs/titan/README.md](docs/titan/README.md) – zasady atlasu funkcji silnika Titan; [narzedzia/README.md](narzedzia/README.md) – narzędzia
* [docs/FORMATY.md](docs/FORMATY.md), [docs/FORMATY_ETAP2.md](docs/FORMATY_ETAP2.md), [docs/FORMATY_ETAP3.md](docs/FORMATY_ETAP3.md) – formaty plików EE
* [docs/WARIANTY_GRY.md](docs/WARIANTY_GRY.md) – Empire Earth i The Art of Conquest jako dwie gry na jednym silniku; [docs/FORMATY_DB_EE_VS_AOC.md](docs/FORMATY_DB_EE_VS_AOC.md) – bazy EE 1.0 i AoC
* [docs/POROWNANIE_MECHANIK_EE_AOC.md](docs/POROWNANIE_MECHANIK_EE_AOC.md) – pomiary mechanik Empire Earth i The Art of Conquest
* [docs/MECHANIKA_RUCHU_EE.md](docs/MECHANIKA_RUCHU_EE.md), [docs/MECHANIKA_PREDKOSCI_EE.md](docs/MECHANIKA_PREDKOSCI_EE.md), [docs/KOLIZJE_JEDNOSTEK_EE.md](docs/KOLIZJE_JEDNOSTEK_EE.md) – ruch, prędkość i kolizje jednostek (pomiary oryginału)
* [docs/LOKALIZACJA.md](docs/LOKALIZACJA.md) – lokalizacja i prawa do nagrań
* [docs/ZASOBY_ORYGINALNE.md](docs/ZASOBY_ORYGINALNE.md) – zasady korzystania z oryginalnych zasobów
* [docs/HISTORIA.md](docs/HISTORIA.md) – historia rozwoju, [docs/MAPA_DROGOWA.md](docs/MAPA_DROGOWA.md) – plan
* [CONTRIBUTING.md](CONTRIBUTING.md) – zasady współpracy
* Raporty: aktualny `RAPORT_ETAP_24.md` (katalog główny); wcześniejsze w `raporty/archiwum/` – indeks z opisami: [raporty/README.md](raporty/README.md)

## Licencja
OpenEE jest udostępniany na licencji **GNU General Public License v3.0** – plik [LICENSE](LICENSE). Projekt zawiera
schemat tabel z projektu społeczności EE DB Editor (GPLv3) – szczegóły i autorzy: [AUTORZY.md](AUTORZY.md).
Licencja obejmuje wyłącznie kod i pliki tego repozytorium, **nie** zasoby Empire Earth.
„Empire Earth” jest znakiem towarowym jego właścicieli; nazwa użyta wyłącznie w celu opisu zgodności.
