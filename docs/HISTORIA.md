# Historia rozwoju OpenEE

| Wersja / etap | Zakres | Raport |
|---|---|---|
| 0.1 – etap 1 | Audyt instalacji i warstw (vanilla, AoC, lokalizacja, NeoEE, dreXmod), czytniki SSA, DCL/PK01, SST/TGA, CEM 2.0, teren SCN; szkielet projektu Godot (konfiguracja, warstwy, importery, dziennik, zdarzenia); pierwszy test graficzny | `RAPORT_ETAP_1.md` |
| 0.2 – etap 2 | Instalacja referencyjna GOG (weryfikacja sum kontrolnych dystrybucji), porównanie z instalacją społecznościową, CEM 1.3, tabele db, obiekty i kolory graczy ze scenariuszy AoC, warianty tekstur, warstwa lokalizacji PL (teksty, głosy, narracja) z niezależnym wyborem języków | `RAPORT_ETAP_2.md`, `docs/FORMATY_ETAP2.md`, `docs/LOKALIZACJA.md` |
| 0.2 – launcher | Launcher PL/EN: instalacje, profile, język gry, nakładki, sceny podglądu, skalowanie HiDPI | `RAPORT_LAUNCHER_UI.md` |
| 0.3 – etap 3 | Teren wg reguł silnika EE (mieszanie tekstur w narożnikach, warianty, woda, klify), scenariusze EE 1.x (wersja 231), obrót obiektów z macierzy rekordu, grupowanie MultiMesh, pomiary wydajności | `RAPORT_ETAP_3.md`, `docs/FORMATY_ETAP3.md` |
| 0.3.0-dev | Pierwsza publikacja na GitHubie (licencja GPLv3), testy działające bez danych komercyjnych, skrypt danych lokalnych | `RAPORT_PUBLIKACJI_GITHUB.md` |
| **0.4.0-dev – etap 4** | Animacje CEM (klatki kluczowe, sekwencje z dbgraphics), hierarchia części z transformacjami na klatkę, odtwarzacz z niezależną fazą (VAT + MultiMesh), scena diagnostyczna, animowana woda, 3× szybsza dekompresja DCL | `RAPORT_ETAP_4.md`, `docs/FORMATY_ETAP4.md` |
| **0.5.0-dev – etap 5** | Symulacja jednostek ze stałym krokiem, nawigacja z danych mapy (klasy głębokości wody, klify, przeszkody), A*, zaznaczanie i rozkazy ruchu myszą, animacje ruchu/bezczynności, izolowane środowisko Wine (porównanie zablokowane przez seccomp) | `RAPORT_ETAP_5.md`, `docs/FORMATY_ETAP5.md` |

Hipotezy obalone w toku prac (dla przejrzystości): obrót obiektów z pola `angle` (etap 2 → etap 3: obrót z macierzy),
układ wariantów tekstur bez odbicia kolumn (etap 2 → etap 3), znaczenie „klasy punktu” dla przejść (etap 3: brak wpływu),
części potomne w układzie rodzica (etap 1–3 → etap 4: wierzchołki lokalne + macierz klatki), przód modelu −Y
(etap 4 → etap 5: +Y – stopa podparta w chodzie, punkt attack poza klatkami śmierci).
