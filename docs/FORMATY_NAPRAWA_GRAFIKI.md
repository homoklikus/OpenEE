# OpenEE – modele, materiały i tekstury: ustalenia naprawy grafiki (0.5.1-dev)

Oznaczenia jak w `FORMATY.md`: [D] – potwierdzone na danych, [K] – z kodu/nazw, [H] – hipoteza OpenEE, [?] – nieznane.
Ustalenia uzyskano z analizy statystycznej plików gry (czytniki OpenEE, Python i GDScript), bez dekompilacji.

## 1. Indeksy trójkątów są względne wobec `v_offset` materiału [D]

Materiał CEM 2.0 opisuje zakres trójkątów w liście LOD oraz zakres wierzchołków `(v_offset, v_liczba)`.
Indeks w liście LOD wskazuje wierzchołek **w obrębie zakresu materiału**:

```
wierzchołek = v_offset + indeks_LOD     (0 ≤ indeks_LOD < v_liczba)
```

Dowód na danych EE (wszystkie modele 2.0 z `data.ssa`):
* 566 części ma więcej niż jeden materiał; 544 materiały mają `v_offset > 0`;
* we **wszystkich** 544 przypadkach indeksy mieszczą się w `[0, v_liczba)`; w **żadnym** nie mieszczą się w
  `[v_offset, v_offset + v_liczba)` (interpretacja bezwzględna);
* materiał pierwszy (`v_offset = 0`) – obie interpretacje dają ten sam wynik, dlatego modele jednomateriałowe były poprawne.

Skutek dawnego odczytu (etapy 1–5): drugi i kolejne materiały (zwykle `player color`, czasem druga tekstura) brały
wierzchołki materiału pierwszego – trójkąty łączyły przypadkowe punkty modelu („rozsypane / eksplodujące” budynki),
dostawały cudze UV (rozciągnięte tekstury) i kolor gracza na dużych, przypadkowych płatach (żółte/pomarańczowe plamy).

## 2. Plik SST z N obrazami = N tekstur modelu, wybór przez `tekstura_id` [D]

Pole `u32 tekstura` materiału (OpenEE: `tekstura_id`) to numer obrazu w pliku SST wskazanym w `dbgraphics`
(„Texture path”) lub w nazwie tekstury materiału.
* W 811 z 824 sprawdzonych grafik liczba obrazów pliku N = max(`tekstura_id`) + 1.
* Przykład: `bld_house_04` – materiały z teksturami `b_house_04_A` (id 0) i `b_house_04_B` (id 1), plik `bld_house_04T.sst`
  ma 2 obrazy 128×128.
* Wyjątek: `nav_fishingboat_02` (N = 1, id = 1) – OpenEE przycina numer do ostatniego obrazu i zgłasza uwagę w dzienniku.
* Hipoteza etapu 1 („drugi obraz = maska koloru gracza”) – **obalona**.

## 3. Kolor gracza: tekstura × kolor [D/H]

* Fragmenty tekstur pod trójkątami `player color` są szare: mediana nasycenia 0/255 (p90 ≈ 10), alfa 255 [D].
  Fragmenty pod zwykłymi materiałami – mediana nasycenia ≈ 36 [D].
* Reguła OpenEE: `ALBEDO = tekstura.rgb × kolor_gracza` (szary odcień niesie cieniowanie i detal) [H co do dokładnej
  jasności/gammy – do porównania z grą].
* Hipoteza etapu 2 („kolor = mix(kolor gracza, tekstura, alfa)”) – **obalona**: przy alfa 255 dawała czystą teksturę albo,
  przy alfa 0 w atlasie, jednolity kolor gracza.
* Alfa w zwykłych materiałach pozostaje wycinaniem (drzewa: mediana 12,5% próbek przezroczystych, budynki ≈ 4%,
  jednostki ≈ 0,6%) [H co do progu 0,5].

## 4. Hierarchia części – bez zmian [D]

Sprawdzono 188 części potomnych z wierzchołkami lokalnymi: 148 to części obrotowe (`orbital_*`) przesunięte o pivot –
spójne z modelem z regułą etapu 4 (wierzchołki lokalne × macierz klatki). 4 przypadki niejednoznaczne statystycznie
(`gun_aagun_11`, `gun_aaskywatcher_11`, `bld_dock_14` orbital, `fx_priesttower_03`) sprawdzone wizualnie – położenie
wiarygodne. Błędu hierarchii nie znaleziono; objawy „rozsypania” wynikały z §1.

## 5. Kontrole w kodzie

* `ModelCEM.kontrola()` i `eeformaty/cem.py: kontrola()` sprawdzają, czy każdy indeks materiału leży w
  `[v_offset, v_offset + v_liczba)`; `cem.py: indeksy_materialu()` zwraca indeksy bezwzględne.
* `ImporterModeli.obraz_materialu()` – jedna ścieżka wyboru obrazu dla siatek statycznych i VAT; brak tekstury i numer
  obrazu poza plikiem są zgłaszane w dzienniku (nie są cicho zastępowane).
* Testy: `godot/testy/testy_grafiki.gd` (jednostkowe na syntetycznym CEM + integracyjne na danych użytkownika).
