# Raport etapu 36 – pierwsza grywalna potyczka w Godocie i dalsza rekonstrukcja walki Titan

Etap 36 uruchamia OpenEE po raz pierwszy jako grę: krótka potyczka na mapie z kampanii EE. Ruch, trasy, kolizje
i walkę wręcz liczy wyłącznie OpenEE Core (C++). Godot rysuje stan Core i przekazuje rozkazy gracza. Drugim
wynikiem są pomiary 619–620 w oryginale: rozkaz ataku gracza i jego przerwanie odtworzone w Core takt po takcie.
Oznaczenia: [P] potwierdzone, [W] wniosek, [H] hipoteza, [N] nieustalone.

## 1. Stan początkowy i końcowy

- Start: `main` = `c776a61` (etap 35), drzewo czyste poza lokalnym `godot/project.godot` (niecommitowany) i
  `konfiguracja/uzytkownik.cfg.przed_etapem11` (nietykany).
- Przed pisaniem sceny sprawdzono, co już istnieje i co można wykorzystać:
  - `test_scenariusz.gd` (teren i obiekty z SCN, kamera EE, haki `_przejmij_obiekt` i `_po_zbudowaniu`);
  - `rts_test.gd` ze starą symulacją GDScript (etap 5), `WidokJednostek` (CEM, MultiMesh, VAT), `SterowanieRTS`,
    `Zaznaczanie`, `ZaznaczenieEE`, `ZegarSymulacji`, `MapaNawigacji` (wysokości);
  - importer SCN z surowym kawałkiem 4 dla Core (etap 30), GDExtension `OpenEESymulacja` (mapa, jednostki, walka).
- Wykorzystano wszystkie powyższe warstwy prezentacji. Nowa jest tylko cienka warstwa `SymulacjaCore` (odczyt stanu
  Core). Drugiego silnika w GDScript nie ma.
- Koniec: dwa commity etapu 36 na `main` (potyczka; rozkaz ataku, pomiary i dokumentacja), osobny commit lokalny
  Riverlands_MCP niepotrzebny (bez zmian w MCP).

## 2. Scena

`godot/sceny/potyczka.tscn` + `potyczka.gd` (rozszerza `test_scenariusz.gd`):
- mapa: scenariusz kampanii EE „Wojna trojańska” (`EETheGreeks.ssa`, nr 3) z lokalnej instalacji gry, okno 30 × 30 pól;
  teren, drzewa, mury i budynki z SCN; ruchome jednostki scenariusza zdjęte;
- Core dostaje tę samą mapę: surowy kawałek 4 (`wczytaj_mape_scn`, skrót `c8297c16f0d48b1a` – ten sam co w CTest)
  i 5120 obiektów z blokadą pól wg reguły z `import_mapy.md` § 4;
- jednostki: 5 gwardii królewskich (typ 422) gracza 1 przeciw 5 gwardiom gracza 5, plik
  `dane/potyczka/potyczka_troja.json` (format `openee_potyczka_v1`); pozycje startowe sprawdzone na przejezdność
  w Core (`--potyczka-siatka`), odstęp linii 8 pól > pole widzenia 4 – walka zaczyna się od rozkazu gracza;
- kamera produkcyjna EE (przesuwanie strzałkami/krawędzią, zoom kółkiem, poziom 14);
- modele i animacje z gry (CEM, sekwencje dbgraphics, kolor gracza), stan animacji z numeru stanu `.tai` Core;
- HUD: liczba jednostek, zaznaczona jednostka (HP, stan, cel), ostatnie zdarzenia walki (`atak`, `trafienie`,
  `smierc`), paski HP nad jednostkami (zielony – gracz, czerwony – wróg, błysk przy trafieniu);
- wynik: ZWYCIĘSTWO, gdy wszyscy wrogowie polegli, PORAŻKA, gdy wszystkie własne jednostki; klawisz R – nowa bitwa.

## 3. Uruchamianie

- Launcher: „Uruchom” → „Potyczka (etap 36: walka w OpenEE Core)” albo Narzędzia → ten sam przycisk (tryb 4).
- Bezpośrednio: `godot --path godot res://sceny/potyczka.tscn`.
- Wymagania: zbudowana biblioteka GDExtension (`docs/cpp/BUDOWANIE.md`), instalacja EE (mapa, modele) i
  `Low-Level Engine.dll` (tablice; bez niej Core przechodzi w tryb przybliżony, oznaczony w HUD).
- Automat testowy: `-- --potyczka-demo=<s> [--potyczka-restart] --potyczka-zrzuty=<katalog> --potyczka-raport=<plik>`;
  inny układ: `--potyczka=<plik.json>`.

## 4. Działające sterowanie

| Funkcja | Stan | Realizacja |
|---|---|---|
| LPM – zaznaczenie | działa | `Zaznaczanie.klik` na jednostkach `SymulacjaCore.lista()` (tylko żywe) |
| Ramka | działa | `ZaznaczenieEE.w_prostokacie`, tylko jednostki gracza lokalnego |
| PPM w teren – ruch | działa | `rozkaz_ruchu` Core (A*, kolejka celów, fizyka) |
| PPM na wrogu – atak | działa | `rozkaz_ataku` Core (EEUGAttackUnit); martwy cel – brak ataku (jak `EEAMouseClick`) |
| Shift + PPM – kolejka | działa | Shift Core: dopisanie celu na koniec kolejki (kolejka_rozkazow.md) |
| Znaczniki zaznaczenia | działa | pierścienie `WidokJednostek` |
| Paski HP | działa | HP z `stan_jednostek` |
| Pauza, restart, powrót | działa | spacja, R, Esc |

Szyk grupy EE nie jest w Core – wszystkie zaznaczone jednostki dostają ten sam punkt [N], rozpycha je fizyka Core.

## 5. Synchronizacja Godot ↔ Core

- Jeden autorytatywny `Swiat` (Core). `SymulacjaCore.krok()` = `takt(1)` + `stan_jednostek()` +
  `zdarzenia_walki_od(n)`; dane trafiają do istniejących obiektów `JednostkaSym` (pozycja, kurs, ruch, animacja).
- Stały krok z modelu Titan: `ZegarSymulacji` z akumulatorem, `KROK` = 0,35 s / 15 (takty EE 42,857/s, każdy
  34,09 ms czasu gry). Render interpoluje pozycję i kurs (`alfa`) – liczba klatek nie zmienia przebiegu.
- Jednostki identyfikowane stałymi id Core. Zwłoki zostają w Core (stan 6000), widok ukrywa je po 3 s (prezentacja).
- Zdarzenia walki w kolejności Core (licznik przyrostowy). Determinizm: te same rozkazy w tych samych taktach dają
  ten sam skrót stanu i tę samą listę zdarzeń (test GDExtension).
- Restart: nowy obiekt `OpenEESymulacja`, nowa mapa i świat, nowe węzły widoku (`remove_child` + `queue_free`).
- Core nie zależy od Godota. Nowe metody GDExtension: `stan_jednostek`, `zdarzenia_walki_od`, `ustaw_wrogow`, `takty`
  (OpenEE Core 0.10.0).

## 6. Modele i dane

- Modele, tekstury i animacje: z instalacji gry przez warstwy OpenEE (nic nie trafia do repozytorium).
- Parametry ruchu gwardii (a, vmax, α, ωmax, rozmiar, c4, c8, t488) – odczyty EE 508 [P]; walka (atak 15, pancerz,
  zasięg 0,5, LOS 4, przeładowanie 2000 ms, klasa 13, rodzina 48, opóźnienie trafienia 1122 ms, łuk 20°, szukanie
  2000 ms, AC 0,6), HP 215 – pomiary 566/578 [P]; tablice trafień klasy 13 i mnożniki – odczyt pamięci EE (etap 30)
  [P]; wagi wyboru celu – odczyt [0x8CFA28] (etap 31) [P]; teren dozwolony gwardii – pamięć [P].
- Ręcznie dobranych statystyk brak. Tymczasowe są tylko elementy prezentacji: czas znikania zwłok (3 s), błysk paska
  HP (0,25 s), kolory pasków.

## 7. Rzeczywiste testy sceny Godot

Uruchomienia z renderem (xvfb, OpenGL 3, 1280 × 800), wejście przez `Input.parse_input_event` (zdarzenia myszy
i klawiatury trafiają do `SterowanieRTS._unhandled_input` jak od gracza):

| Przebieg | Wynik |
|---|---|
| launcher `--uruchom=4` → potyczka, ramka (5 zaznaczonych), PPM w teren + Shift + PPM, PPM na wrogu (5/5 przyjęło, cel 6 w Core) | bitwa 1: zwycięstwo w takcie 1337 (53 ataki, 50 trafień, 5 śmierci, 21 wyborów celu przez AI); własne straty HP, bez poległych |
| klawisz R w tym samym procesie | bitwa 2: nowy świat Core, zwycięstwo w takcie 1439 |
| układ 1 gwardia na 5 (`--potyczka=`) | porażka w takcie 761, napis PORAŻKA |
| kolejne zrzuty ekranu | modele w pozycjach Core, paski HP, pierścienie zaznaczenia, dziennik zdarzeń w HUD |

Przebiegi interaktywne różnią się od siebie (rozkazy trafiają w różne takty zależnie od klatek) – to oczekiwane.
Determinizm sprawdza test GDExtension z rozkazami w stałych taktach.

Testy automatyczne: GDExtension 28/28 (+5: potyczka do rozstrzygnięcia, determinizm, zwłoki, przerwanie ataku ruchem,
sekwencja stanów rozkazu ataku), Godot 325/325 (+1: tryb 4 w launcherze i plik układu).

## 8. Eksperymenty w oryginale (scenariusz e35_a)

| Nr | Zakres | Wynik |
|---|---|---|
| 619 | atak gracza na obywatela; dwóch na bohatera; zmiana celu | sekwencja co takt 2012 → 2013 → 2024 → 8000 → 2015 → 10003 [P]; obywatel stoi na polu z drzewami – cel nieosiągalny, cykl 5002/2013/2024 na ostatnim punkcie trasy; ruch bez ponownego wyboru – odmowa narzędzia (jednostka poza kadrem) |
| 620 | przerwanie ataku zwykłym PPM; dwie gwardie na bohatera | cel ataku zastąpiony jedynym celem EEUGLocation w tym samym takcie [P]; próbka po rozkazie ataku bywa w 2016 InitialAttackState [P]; 858 → bohater: wstawiony EEUGLocation, brak ruchu, porzucenie celu co ok. 27 s – przyczyna [N] |
| 616 (analiza) | „pościg” z etapu 35 | obywatel nie ruszał się; ruch gwardii wynikał z chybionego PPM (EEUGLocation); dalej AI wybiera nieosiągalnego obywatela co 8–30 s [P]. *[Etap 36 – zastąpione: wniosek etapu 35 o pościgu za uciekającym obywatelem.]* |

Pomiar 616 odtworzono w Core (`godot/testy/eksperymenty/odtworz_e35.gd`): ruch do punktu PPM zgodny takt po takcie
do drugiego kliknięcia narzędzia. Pomiar z oryginału nie był zastępowany obserwacjami ze sceny Godota.

Scenariusze priorytetu B:

| Scenariusz | Stan |
|---|---|
| 1. atak gracza | [P] 619/620, Core zgodny co takt |
| 2. atak przerwany ruchem | [P] 620, Core zgodny co takt |
| 3. pościg za uciekającym | niewykonany – w e35_a obywatel nie ucieka (stoi na polu z drzewami) [N] |
| 4. utrata i ponowne wykrycie celu | [P] cykl AI co 8–30 s przy celu nieosiągalnym; Core go nie odtwarza |
| 5. zmiana celu | wydana w 619 (bohater → obywatel), nieanalizowana co takt [N] |
| 6. kilka jednostek na jeden cel | nieudane: 858 nie osiąga bohatera [N] |
| 7. wróg za przeszkodą | [P] obywatel na polu z drzewami (619, 620) |
| 8. rozkaz gracza a wybór AI | [P] cel od gracza: `pochodzenie_1C` = 1, AI po porzuceniu wybiera cel sama (`GoalIsNotPlayerInitiated`) |

## 9. Zmiany fizyki i walki w Core

Jedna zmiana, wynikająca z pomiaru: `Swiat::rozkaz_ataku` wchodzi w **InitialAttackState (2016)**, a krok maszyny
w tym samym takcie daje FaceEnemyUnit (2012). Obrót w trybie 1 zaczyna się więc w takcie rozkazu.
*[Etap 36 – zastąpione: wejście w CheckRange [H] z etapu 31 – przejścia o 1 takt za wcześnie, kurs o 1 takt za grą.]*
Wejście w 2016 ma w Core pustą akcję (ICL zapisywane przy 2013, jak dotąd) [W]. Regresja 578 G1, S1–S7 i porównania
bez zmian (AI nie używa tej ścieżki).

## 10. Pierwsze rozbieżne takty

| Przypadek | Pierwszy rozbieżny takt | Uwagi |
|---|---|---|
| 619 (atak gracza, Core na mapie SCN) | t = 64147 (po 116 zgodnych przejściach) | 9006 na końcu trasy: gra 1 takt z zamrożoną pozycją przy v = 0,259, Core 4 takty z hamowaniem [N] |
| 620 (atak → PPM) | t = 59783 (po 37 zgodnych przejściach) | 9006 na końcu trasy: gra 3 takty, Core 1 [N] |
| AI po utracie celu (616/619) | po wejściu w 5000 | Core nie wybiera ponownie celu nieosiągalnego (osiągalność 0x62D696 [N]) |
| 578 G1 | brak w oknie (986/986) | bez zmian |
| 578 G3 | 169 (ω) | bez zmian – kolejność fizyki przy ruchomym celu nie była badana w tym etapie |
| 590 G1 | 97 | bez zmian |
| 580 G1 (AoC) | 57 (stan) / 146 | bez zmian; RNG AoC nie był badany |
| AoC 505 | 803 | bez zmian |
| EE 500 | koniec +1 | bez zmian |

Priorytet C (578 G3, 590 G1, AoC) nie dostał w tym etapie nowych pomiarów. Czas przeznaczono na potyczkę i rozkaz
ataku gracza, który odblokował porównania co takt na prawdziwej mapie. Wyjątków, przesunięć RNG ani tolerancji nie
dodawano.

## 11. Regresja

- CTest Release 20/20, Debug 20/20.
- GDExtension 28/28 (było 23/23; +5 nowych).
- Godot 325/325 (było 324/324; +1 nowy).
- Riverlands_MCP 16/16 plików (bez zmian w kodzie), narzędzia Titan 20/20.
- S1–S7 `68b0c69ecb8b0cbc`, 578 G1 986/986, skrót mapy SCN `c8297c16f0d48b1a`.
- Oczekiwanych wyników nie zmieniano.

## 12. Ograniczenia prototypu

1. Jeden typ jednostki (gwardia 422) i jeden układ; obywatel, bohater i strzelcy nie są w potyczce.
2. Szyk grupy EE nie jest w Core: grupa dostaje jeden punkt, jednostki rozdziela fizyka.
3. Brak mgły wojny w renderze i w wyborze myszą (Core ma widoczność pól tylko w wyborze celu przez AI) [W].
4. Brak ekonomii, budowania, minimapy, dźwięków walki i interfejsu EE (panel, portrety, kursory).
5. Zwłoki ukrywane po 3 s (prezentacja); rozkład zwłok EE nieodwzorowany [N].
6. Animacja z numeru stanu: atak w 2001/2021, śmierć w 6000–6003, ruch przy v > 0 – czas klatek ataku nie jest
   powiązany z momentem trafienia z Core [N].
7. Na ekranie zostaje opis sceny bazowej („etap 4”) nad HUD potyczki.
8. Rozkaz ataku dla zaznaczonych wrogich jednostek jest odrzucany (sterowanie tylko gracza lokalnego); AI gracza 5
   nie prowadzi działań – broni się i wybiera cele w polu widzenia.
9. Odchylenia Core od gry z § 10 (9006 na końcu trasy, ponowny wybór celu nieosiągalnego) dotyczą też potyczki.
10. Przy braku `Low-Level Engine.dll` Core używa tablic przybliżonych (oznaczone w HUD).

## 13. Prognoza i rekomendacja na etap 37

- Pierwsza potyczka działa na rekonstrukcji Titan. Kolejne zmiany zgodności trafiają do gry bez zmian po stronie
  Godota.
- Rekomendacja na etap 37:
  1. 9006 TurnToUnitFacing przy celu ataku i przy PPM (kurs końcowy rozkazu, zamrożenie pozycji) – na danych 619/620,
     które już są odtwarzane co takt;
  2. ponowny wybór celu nieosiągalnego (osiągalność 0x62D696, liczniki prób) – 616/619;
  3. pościg za ruchomym celem: nowy układ e36 z celem, który się porusza (obywatel z rozkazem ucieczki), potem 578 G3
     / 590 G1;
  4. potyczka: szyk grupy w Core, drugi typ jednostki (strzelec po pomiarach pocisku), mgła wojny w widoku.
- Pomiary strzelców (priorytet opcjonalny § 7) nie były wykonywane.
