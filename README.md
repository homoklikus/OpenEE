# OpenEE

**OpenEE jest niezależną reimplementacją silnika Empire Earth opartą na Godot. Nie jest kompletną grą i wymaga legalnie
posiadanej instalacji Empire Earth Gold Edition / The Art of Conquest. Projekt nie jest oficjalnie powiązany z właścicielami
marki Empire Earth.**

Wersja: **0.4.0-dev** – wersja rozwojowa, niedokończony silnik. Wzorem jest OpenMW: kod silnika jest nowy, a wszystkie
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
* Tabele gry `db*.dat` (obiekty, grafiki, dźwięki, tereny…).
* **Lokalizacja PL/EN** ładowana z instalacji użytkownika – osobny wybór języka tekstów, głosów i kampanii
  ([docs/LOKALIZACJA.md](docs/LOKALIZACJA.md)).
* **Launcher** (PL/EN): wybór instalacji, profil gry, język, nakładki, uruchamianie scen podglądu.
* **95 testów automatycznych** (część wymaga instalacji gry – bez niej są jawnie pomijane).

## Ograniczenia (stan 0.4.0-dev)
* **Brak rozgrywki** – brak ekonomii, walki, SI, interfejsu gry; sceny są podglądem danych.
* Animacje odtwarzane z danych, ale tempo (czas cyklu z `dbgraphics`) i interpolacja między klatkami to hipotezy
  do potwierdzenia w grze; brak sterowania proceduralnego (celowanie wieżyczek, obrót części `orbital_*`, toczenie kół).
* Brak symulacji: jednostki nie poruszają się po mapie.
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
   ./uruchom_openee.sh scenariusz # podgląd scenariusza AoC „Soldiers for Rome”
   ./uruchom_openee.sh testy      # testy bez okna → wyniki/testy_godot.json
   ```
   albo otwórz katalog `godot/` w edytorze Godota.
4. Pełny zestaw testów (porównania z czytnikami Pythona, lokalizacja PL) wymaga danych pomocniczych generowanych
   lokalnie z Twojej instalacji – nie są publikowane:
   ```
   narzedzia/przygotuj_dane_lokalne.sh "/ścieżka/do/Empire Earth Gold" ["/ścieżka/do/instalacji z wersją PL"]
   ```

Podgląd scenariusza z wiersza poleceń: `godot --path godot res://sceny/test_scenariusz.tscn -- --kampania=EETheGreeks.ssa --scenariusz="trojan war"`
(opcje: `--okno=r0,c0,n | pelne`, `--kamera=blisko`, `--zrzut=plik.png`, `--pomiar=N`, `--bez-animacji`).

Scena animacji: `./uruchom_openee.sh animacje --model=Phalanx --sekwencja=atak` (albo `--galeria=Phalanx;Citizen Paleo;Cannon - 12 Pounder`,
`--pomiar=100,1000,4000`, `--film=katalog`).

## Dokumentacja
* [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) – struktura silnika i projektu
* [docs/FORMATY.md](docs/FORMATY.md), [docs/FORMATY_ETAP2.md](docs/FORMATY_ETAP2.md), [docs/FORMATY_ETAP3.md](docs/FORMATY_ETAP3.md) – formaty plików EE
* [docs/LOKALIZACJA.md](docs/LOKALIZACJA.md) – lokalizacja i prawa do nagrań
* [docs/ZASOBY_ORYGINALNE.md](docs/ZASOBY_ORYGINALNE.md) – zasady korzystania z oryginalnych zasobów
* [docs/HISTORIA.md](docs/HISTORIA.md) – historia rozwoju, [docs/MAPA_DROGOWA.md](docs/MAPA_DROGOWA.md) – plan
* [CONTRIBUTING.md](CONTRIBUTING.md) – zasady współpracy
* Raporty etapów: `RAPORT_ETAP_1.md`, `RAPORT_ETAP_2.md`, `RAPORT_ETAP_3.md`, `RAPORT_LAUNCHER_UI.md`

## Licencja
OpenEE jest udostępniany na licencji **GNU General Public License v3.0** – plik [LICENSE](LICENSE). Projekt zawiera
schemat tabel z projektu społeczności EE DB Editor (GPLv3) – szczegóły i autorzy: [AUTORZY.md](AUTORZY.md).
Licencja obejmuje wyłącznie kod i pliki tego repozytorium, **nie** zasoby Empire Earth.
„Empire Earth” jest znakiem towarowym jego właścicieli; nazwa użyta wyłącznie w celu opisu zgodności.
