# Historia rozwoju OpenEE

| Wersja / etap | Zakres | Raport |
|---|---|---|
| 0.1 – etap 1 | Audyt instalacji i warstw (vanilla, AoC, lokalizacja, NeoEE, dreXmod), czytniki SSA, DCL/PK01, SST/TGA, CEM 2.0, teren SCN; szkielet projektu Godot (konfiguracja, warstwy, importery, dziennik, zdarzenia); pierwszy test graficzny | `raporty/archiwum/RAPORT_ETAP_1.md` |
| 0.2 – etap 2 | Instalacja referencyjna GOG (weryfikacja sum kontrolnych dystrybucji), porównanie z instalacją społecznościową, CEM 1.3, tabele db, obiekty i kolory graczy ze scenariuszy AoC, warianty tekstur, warstwa lokalizacji PL (teksty, głosy, narracja) z niezależnym wyborem języków | `raporty/archiwum/RAPORT_ETAP_2.md`, `docs/FORMATY_ETAP2.md`, `docs/LOKALIZACJA.md` |
| 0.2 – launcher | Launcher PL/EN: instalacje, profile, język gry, nakładki, sceny podglądu, skalowanie HiDPI | `raporty/archiwum/RAPORT_LAUNCHER_UI.md` |
| 0.3 – etap 3 | Teren wg reguł silnika EE (mieszanie tekstur w narożnikach, warianty, woda, klify), scenariusze EE 1.x (wersja 231), obrót obiektów z macierzy rekordu, grupowanie MultiMesh, pomiary wydajności | `raporty/archiwum/RAPORT_ETAP_3.md`, `docs/FORMATY_ETAP3.md` |
| 0.3.0-dev | Pierwsza publikacja na GitHubie (licencja GPLv3), testy działające bez danych komercyjnych, skrypt danych lokalnych | `raporty/archiwum/RAPORT_PUBLIKACJI_GITHUB.md` |
| **0.4.0-dev – etap 4** | Animacje CEM (klatki kluczowe, sekwencje z dbgraphics), hierarchia części z transformacjami na klatkę, odtwarzacz z niezależną fazą (VAT + MultiMesh), scena diagnostyczna, animowana woda, 3× szybsza dekompresja DCL | `raporty/archiwum/RAPORT_ETAP_4.md`, `docs/FORMATY_ETAP4.md` |
| **etap 13.5 – porządki** | Audyt projektu i MCP, narzędzia jednorazowe w `narzedzia/eksperymenty/`, usunięty martwy kod, dokument orientacyjny `docs/ARCHITEKTURA_OPENEE.md`, zasady atlasu Titan, adnotacje przy obalonych wnioskach; MCP: zadania w kolejności numerów, sprzątanie kopii scenariuszy | `RAPORT_PORZADKI_ETAP_13_5.md` |
| **etap 13 – prędkość i kolizje** | Start oryginałów bez filmów (łatka kopii testowej exe), zegar czasu gry w pamięci, prędkość = `Speed` × tempo czasu gry (1,461), kolizje grup w EE i AoC (przenikanie, objazd stojących), scenariusz testowy wybierany numerem z listy kampanii | `raporty/archiwum/RAPORT_ETAP_13.md`, `docs/MECHANIKA_PREDKOSCI_EE.md`, `docs/KOLIZJE_JEDNOSTEK_EE.md` |
| **etap 12 – mechaniki EE i AoC** | Narzędzia MCP dla podstawowego `Empire Earth.exe` (osobne definicje pamięci obu gier), pomiary kamery, zaznaczania, ruchu i grafiki w EE i AoC na tym samym scenariuszu; wspólny kod OpenEE zgodny z obiema grami, testy na danych pomiarów | `raporty/archiwum/RAPORT_ETAP_12_EE_AOC.md`, `docs/POROWNANIE_MECHANIK_EE_AOC.md` |
| **etap 11 – Empire Earth i The Art of Conquest** | Dwie gry na jednym silniku: warianty formatu baz EE 1.0/AoC rozpoznawane ze struktury (naprawa `vanilla_ee`), definicje gier (`dane/gry.json`), wybór gry w launcherze niezależny od profilu, izolacja danych i pamięci podręcznej, migracja konfiguracji; audyt obu instalacji i pomiar plików otwieranych przez oryginał | `raporty/archiwum/RAPORT_EE_AOC_FORMATY.md`, `docs/FORMATY_DB_EE_VS_AOC.md`, `docs/WARIANTY_GRY.md` |
| **etap 10 – kamera wierna EE** | Pomiary kamery AoC (poziomy zoomu, przewijanie krawędzią, granice mapy, teren) i kamera produkcyjna OpenEE | `raporty/archiwum/RAPORT_KAMERA_OPENEE.md`, `docs/MECHANIKA_KAMERY_EE.md` |
| **etap 9 – ruch grupowy** | Zaznaczanie, szyk grupy, trasy oktylowe, prędkość, kolejka rozkazów według pomiarów AoC; porównanie trajektorii | `raporty/archiwum/RAPORT_RUCH_GRUPOWY_EE.md`, `docs/MECHANIKA_RUCHU_EE.md` |
| **etap 8 – epoki i przezroczystość** | Grafika zależna od epoki (warianty modeli z łańcucha technologii), przezroczystość budynków (F5) | `raporty/archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md`, `docs/WARIANTY_EPOK.md` |
| **etap 7 – układ współrzędnych** | Przyczyna odbicia lustrzanego świata i jej usunięcie (`UkladEE`) | `raporty/archiwum/RAPORT_UKLAD_WSPOLRZEDNYCH_OPENEE.md` |
| **etap 6 – kamera EE** | Pierwsze pomiary kamery oryginału (Riverlands_MCP) i zbliżenie kamery OpenEE | `raporty/archiwum/RAPORT_KAMERA_EE_OPENEE.md` |
| **0.5.2-dev – diagnostyka modeli** | Tryb diagnostyczny pojedynczego modelu, porównanie rendererów; wycinanie alfa także w „player color”, odrzucanie tylnych ścian (z lustrzaną bazą obiektów), obrót impostorów do kierunku kamery EE, przesunięcie głębi modeli, kolor pod alfa = 0 przed mipmapami | `raporty/archiwum/RAPORT_DIAGNOSTYKA_MODELI_051.md`, `docs/FORMATY_DIAGNOSTYKA_051.md` |
| **0.5.1-dev – naprawa grafiki** | Audyt importu modeli: indeksy materiałów względem `v_offset`, wybór obrazu SST przez `tekstura_id`, kolor gracza jako mnożenie przez szarą teksturę; testy regresji grafiki | `raporty/archiwum/RAPORT_NAPRAWA_GRAFIKI.md`, `docs/FORMATY_NAPRAWA_GRAFIKI.md` |
| **0.5.0-dev – etap 5** | Symulacja jednostek ze stałym krokiem, nawigacja z danych mapy (klasy głębokości wody, klify, przeszkody), A*, zaznaczanie i rozkazy ruchu myszą, animacje ruchu/bezczynności, izolowane środowisko Wine (porównanie zablokowane przez seccomp) | `raporty/archiwum/RAPORT_ETAP_5.md`, `docs/FORMATY_ETAP5.md` |

Hipotezy obalone w toku prac (dla przejrzystości): obrót obiektów z pola `angle` (etap 2 → etap 3: obrót z macierzy),
układ wariantów tekstur bez odbicia kolumn (etap 2 → etap 3), znaczenie „klasy punktu” dla przejść (etap 3: brak wpływu),
części potomne w układzie rodzica (etap 1–3 → etap 4: wierzchołki lokalne + macierz klatki), przód modelu −Y
(etap 4 → etap 5: +Y – stopa podparta w chodzie, punkt attack poza klatkami śmierci), indeksy trójkątów bezwzględne
(etapy 1–5 → naprawa grafiki: względne wobec `v_offset` materiału), drugi obraz SST = maska koloru gracza (etap 1 →
naprawa: kolejna tekstura wybierana przez materiał), kolor gracza = mix(kolor, tekstura, alfa) (etap 2 → naprawa: mnożenie), „player color” bez wycinania alfa (naprawa →
0.5.2: alfa wycina we wszystkich materiałach), rysowanie modeli obustronnie (etapy 1–5 → 0.5.2: odrzucanie tylnych ścian),
billboard zwracający oś +Z modelu do kamery (etap 3 → 0.5.2: kierunek projektowy -45°).

Obalone lub zastąpione w etapach 6–13: mnożnik prędkości zależny od scenariusza (etap 12: 1,706 → etap 13: artefakt
metody, jeden mnożnik 1,461 = tempo czasu gry), prędkość proroka 0,853/0,96 pola/s (etap 12, trasa 1,2 pola → etap 13:
`Speed`, bez osobnego mnożnika), niejasne unikanie przy grupach idących naprzeciw w EE (etap 12 → etap 13: przenikanie
jak w AoC; nowa reguła – objazd jednostek stojących), brak unikania kolizji jako uproszczenie OpenEE (etap 5 →
etapy 9 i 13: zgodne z oryginałem), świat OpenEE odbity lustrzanie (etapy 1–6 → etap 7), narzędzia MCP tylko dla
`EE-AOC.exe` (etap 11 → etap 12: osobne definicje pamięci obu gier).
