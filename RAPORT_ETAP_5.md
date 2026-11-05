# OpenEE – raport etapu 5: zgodność z oryginałem i pierwszy interaktywny ruch jednostek

Wersja: **0.5.0-dev** (rozwojowa). Punkt wyjścia: `main` = `509f812` (GitHub i lokalnie zgodne, drzewo czyste),
95/95 testów. Kopia przed zmianami: `kopie_OpenEE/OpenEE_przed_etap5_2026-11-05.tar.gz`.
Reguły i formaty: [docs/FORMATY_ETAP5.md](docs/FORMATY_ETAP5.md); architektura: [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) §Etap 5.

**Kryterium zakończenia – spełnione na mapie „The Trojan War” (EE):**
* zaznaczenie jednostki myszą (LPM);
* cel prawym przyciskiem;
* trasa A* omijająca mur i wieżę;
* ruch tylko po polach przechodnich;
* animacja ruchu, a po dotarciu do celu (odległość 0,00) zatrzymanie i powrót do bezczynności;
* jednostka na powierzchni terenu (odchylenie 3·10⁻⁸);
* rozkaz do głębokiej wody odrzucony z przyczyną, jednostka zostaje na miejscu;
* wszystkie wcześniejsze testy przechodzą.

## 1. Architektura symulacji jednostek
Warstwy rozdzielone (szczegóły – ARCHITEKTURA §Etap 5):
1. **Dane i stan jednostki:**
   * `JednostkaSym.DaneJednostki` – dane ze scenariusza, niezmienne;
   * `JednostkaSym` – stan w symulacji: trwałe id, typ (dbobjects), właściciel, pozycja, kurs, stan ruchu (stoi / obrót / idzie), cel, ścieżka, prędkość i prędkości obrotu z dbobjects, stan animacji, ostatnia przyczyna odrzucenia rozkazu.
2. **Logika przemieszczania** – `Symulacja` (RefCounted, bez węzłów):
   * stały krok 0,05 s;
   * kolejka rozkazów wykonywana na początku taktu;
   * aktualizacja w porządku rosnących id, bez losowości;
   * zdarzenia taktu dla widoku.
3. **Trasy** – `MapaNawigacji`, `PolitykaRuchu`, `Sciezki` (A*).
4. **Renderowanie i animacja** – `WidokJednostek`:
   * MultiMesh na model z VAT z etapu 4;
   * pozycja i kurs interpolowane między taktami;
   * wysokość z terenu.
5. **Sterowanie użytkownika** – `SterowanieRTS` i `Zaznaczanie` (logika trafień bez węzłów).

`ZegarSymulacji` napędza symulację z akumulatora czasu, niezależnie od FPS. Scenariusz na dysku nie jest zmieniany –
pozycje istnieją tylko w pamięci.

## 2. Rozkazy i nawigacja
* **Rozkazy** to dane `{id, typ: ruch|stop, cel}` w kolejce – podstawa przyszłych kolejek rozkazów i trybu
  wieloosobowego (wymiana rozkazów). Nowy rozkaz zastępuje poprzedni.
* **Trasa:**
  * A* z 8 sąsiadami, bez ścinania narożników;
  * koszt rośnie z |Δh|;
  * składowe spójności na politykę – cel nieosiągalny rozpoznawany natychmiast;
  * wygładzanie skrótami widocznymi i nie droższymi z uwzględnieniem wysokości.
* **Przebieg ruchu:** obrót w miejscu (gdy różnica > 45°) → ruch z animacją → zatrzymanie i bezczynność.
* **Odrzucenia** z przyczyną w dzienniku symulacji:
  * poza mapą;
  * niedostępna nawierzchnia, przeszkoda, drzewa;
  * cel nieosiągalny.
* **Implementacja na tablicach upakowanych:**
  * pojedyncza trasa na Troi trwa ok. 0,6 ms (mediana z 84 rozkazów), najdłuższa 3,9 ms;
  * wstępne przygotowanie przechodniości i składowych przy wczytywaniu sceny: 0,26–0,40 s.

## 3. Reguły przechodniości terenu
| Reguła | Status |
|---|---|
| Granica mapy = romb pól z kawałka 4 | **potwierdzona [D]** |
| Woda: klasy punktów 0xA8…0xAF = poziomy głębokości (wszystkie poniżej 0); **poziom wody = 0** | **potwierdzona [D]** |
| Dopuszczalność wody głębokiej i płytkiej, klifów i lądu z flag `dbobjects` (piechota/kawaleria: głęboka 0, płytka 1, klify 0; okręty: ląd 0, głęboka 1) | **potwierdzona [D]** (flagi); przypisanie kategorii pól – częściowo [H] |
| Próg płytka/głęboka: poziom A8 = płytka, A9+ = głęboka | przybliżenie [H] |
| Klif = tekstura z dbcliffterrain | tekstura [D], znaczenie dla flagi „Elevation: cliffs” [H] |
| Wszystkie nawierzchnie lądu jak „Grass” | przybliżenie [H] |
| Przeszkody: Unit type 1/2/24/25/29/30, koło o promieniu „Size of collider”; drzewa osobno („Can walk through trees”) | typy i pola [D], promień [H] |
| Nachylenie: brak progu, tylko koszt | świadomie nieprzyjęte (reguła EE nieznana) |
| `Speed` = pola/s, prędkość obrotu = rad/s, takt 20/s | [H] (rząd wielkości zgodny z chodem modeli) |
| Przód modelu = +Y (stopa podparta, punkt attack) – **sprostowanie etapu 4** | **potwierdzona [D]** |

Polityka ruchu jest osobną klasą: zmiana reguł nie wymaga zmian w A* ani w symulacji.

## 4. Integracja z animacjami CEM
`WidokJednostek` reaguje na zdarzenie `animacja` z symulacji:
* `ruch` → sekwencja „ruch” z dbgraphics (gniazdo 1);
* `bezczynnosc` → gniazdo 2, a gdy go brak – gniazdo 3.

Brak sekwencji nie zatrzymuje ruchu i trafia do `brakujace_animacje` oraz dziennika. W Troi 17 z 18 ruchomych typów
ma sekwencję ruchu; `gun_stonethrower_03` nie ma sekwencji bezczynności. Kurs po obrocie przechodzi przez tę samą
transformację osi co obiekty scenariusza (etap 3). Test: punkt `attack` falangi po transformacji wskazuje kierunek
ruchu w 24/24 próbkach.

## 5. Porównanie z oryginalnym EE
Środowisko przygotowano zgodnie z wymaganiami (`narzedzia/izolowane_ee.sh`, `izolowane_ee_sesja.py`):
* przenośne Wine 10.0 WoW64 (11.20 kończyło się błędem segmentacji przy starcie) w katalogu tymczasowym maszyny wirtualnej;
* osobny prefiks;
* osobny Xvfb `:77`, bez dostępu do KDE, myszy i klawiatury; wejście wyłącznie przez XTEST do Xvfb;
* kopia gry (oryginał tylko czytany);
* bez sudo, bez pakietów systemowych, bez ruszania Lutrisa i procesów Wine użytkownika.

Po **zgodzie autora projektu** uruchomiono `EE-AOC.exe`. Proces kończy się sygnałem **„Bad system call”**: piaskownica
maszyny ma filtr seccomp, który blokuje wywołania potrzebne Wine do wykonania 32-bitowego kodu w trybie WoW64. Jest to
granica bezpieczeństwa środowiska i nie była obchodzona. **Porównanie nie zostało wykonane.** Środowisko (Wine,
prefiks, kopia gry) zostało usunięte. Kwestie z listy (orientacja/lustro, kolejność warstw, skala, kolory, białe
sylwetki, tempo animacji, interpolacja) pozostają nierozstrzygnięte zrzutami. Z danych rozstrzygnięto natomiast poziom
wody (= 0) i przód modelu (+Y).

## 6. Wyniki testów – `wyniki/testy_godot.json`: **121/121** (z instalacją, 0 pominiętych)
* **95 testów etapów 1–4 i launchera** – bez regresji (importery, DCL = Python, animacje, scenariusze, launcher).
* **26 nowych** (`testy/testy_etapu5.gd`).
  * Jednostkowe, na syntetycznych mapach:
    * omijanie przeszkody;
    * linia prosta;
    * bród (woda płytka);
    * woda głęboka blokuje: cel nieosiągalny lub niedostępny z przyczyną;
    * polityka okrętu;
    * granica mapy i klify;
    * wysokość jako koszt;
    * obrót przed ruchem;
    * dotarcie do celu i animacje bezczynność → ruch → bezczynność;
    * prędkość (7,50 s na 7 pól + obrót);
    * zastąpienie rozkazu;
    * cel nieosiągalny – jednostka zostaje;
    * wynik po 90 taktach identyczny przy 60, 17 i 144 kl./s;
    * akumulator stałego kroku;
    * jednostka na powierzchni zbocza (odchylenie 2·10⁻⁷);
    * zaznaczanie: jednostka, puste miejsce, przesłonięcie przez jednostkę i przez teren;
    * architektura bez węzłów;
    * wydajność;
    * strażnik „wykonane do końca”.
  * Integracyjne:
    * flagi dbobjects;
    * mapa nawigacji Troi;
    * trasa i odrzucenie celu w wodzie;
    * przód modelu;
    * sekwencje ruchu jednostek Troi;
    * strażnik.
* **Bez instalacji:** testy integracyjne są jawnie pomijane (wynik w §10).
* **Błędy znalezione testami podczas prac:**
  * wygładzanie trasy ignorowało wysokość;
  * odwołania do autoloadu w klasach symulacji nie kompilowały się w trybie testów;
  * oś przodu modelu – sprostowanie etapu 4.

  Strażnik „wykonane do końca” wychwycił przerwany blok testów.

## 7. Pomiary wydajności
Warunki: maszyna wirtualna, Xvfb + **llvmpipe** (renderowanie programowe), Godot 4.7.2. Czasy klatki są czasami
rasteryzacji CPU, więc liczą się koszty symulacji mierzone osobno.

| Scena (Troja) | Jednostek z rozkazem | Takt symulacji | Trasy (łącznie) | Transformacje / klatkę | Animacje (zdarzenia) | Klatka śr. / p95 | Wywołania rysowania |
|---|---|---|---|---|---|---|---|
| okno 48×48, 85 jedn. | 1 | 0,078 ms | 0,74 ms | 0,13 ms | 0,08 ms | 80,5 / 84,3 ms | 56 |
| okno 48×48 | 15 | 0,135 ms | 8,4 ms | 0,23 ms | 0,44 ms | 79,4 / 83,9 ms | 56 |
| okno 48×48 | 49 | 0,27 ms | 25,7 ms | 0,46 ms | 1,35 ms | 79,7 / 83,2 ms | 58 |
| okno 48×48 | 84 | 0,41 ms | 47 ms | 0,73 ms | 1,94 ms | 80,8 / 84,0 ms | 58 |
| cała mapa, 207 jedn. | 162 | 0,47 ms | 77 ms (maks. 3,9 ms/trasa) | 1,16 ms | 4,5 ms | 177,6 / 187,7 ms | 364 |

* **Przygotowanie sceny** (okno Troi): mapa nawigacji 74 ms, przeszkody 27 ms (554 budynki/zasoby, 4555 drzew),
  przechodniość i składowe 0,26–0,40 s, modele jednostek i VAT 0,55 s.
* **Mapa syntetyczna 64×64** (128×128 komórek), 50 tras wokół długiej przeszkody wodnej: 22–27 ms na trasę (przeszukanie
  większości mapy). Takt dla 50 jednostek wynosi 0,047 ms.
* **Trasy nie są przeliczane co klatkę** – tylko przy rozkazie.
* Optymalizacja dla dużych armii (trasy hierarchiczne, współdzielone pola przepływu, GDExtension) – dopiero po pomiarach na
  większych mapach.

## 8. Znane ograniczenia
* Brak unikania kolizji i formacji – jednostki mogą na siebie nachodzić. Zaznaczana jedna jednostka naraz (struktura
  przewiduje listę).
* Reguły przybliżone z §3: próg wody płytkiej, nawierzchnie lądu, promień przeszkód, jednostki prędkości, częstotliwość taktu.
* Budynki blokują jako koła, nie dokładne obrysy; bramy blokują zawsze.
* Ruch okrętów obsłużony przez politykę, ale niesprawdzony wizualnie w scenie (Troja – piechota).
* Jednostki lotnicze nie są włączane do symulacji.
* Brak porównania z oryginalnym EE (§5); deterministyczność między platformami nietestowana.
* Pojedyncza trasa przez dużą część mapy kosztuje dziesiątki ms (A* w GDScript).

## 9. Zrzuty i nagrania (lokalne – zawierają zasoby EE, nie trafiają do repozytorium)
`wyniki/etap5/`:
* `demo_4.png` – zaznaczenie, trasa wokół muru, ruch;
* `rts_blisko_4.png` – z bliska: ruch i zatrzymanie;
* `rts_troja_koniec.png`;
* nagrania `rts_demo.mp4` (ruch + odrzucenie celu w wodzie) i `rts_demo_blisko.mp4` (dotarcie do celu, powrót do bezczynności), 25 kl./s czasu symulacji;
* wyniki pomiarów `pomiar_*.json`.

## 10. Git i GitHub
Uzupełniane przy publikacji – patrz koniec raportu.
