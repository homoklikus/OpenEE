class_name TestyEtapu12
extends RefCounted
## Testy etapu 12 (docs/POROWNANIE_MECHANIK_EE_AOC.md, dane/mechaniki_ee_aoc.json): pomiary podstawowych mechanik
## w oryginalnym Empire Earth i w The Art of Conquest a wspólny kod OpenEE.
##  * dane pomiarów: dla każdej mechaniki osobna wartość EE i AoC; wpisy „obie” mają zgodne wartości w obu grach;
##  * wspólny kod (ModelKameryEE) zgadza się z pomiarem KAŻDEJ z gier w granicy tolerancji pomiaru – kamera nie zależy
##    od wybranej gry, więc nie ma rozgałęzienia „jeśli EE”;
##  * różnice nieustalone (narastanie przewijania krawędzią w AoC, prorok) nie są zaimplementowane;
##  * mnożnik prędkości OpenEE pozostaje wartością z etapu 9 (zależy od scenariusza, nie od gry).
## Testy nie wymagają instalacji gry ani działającego oryginału.

var t


func _init(runner) -> void:
	t = runner


func _blisko(a: float, b: float, tol: float, wzgl: bool) -> bool:
	return absf(a - b) <= (tol * absf(b) if wzgl else tol)


func _openee(nazwa: String) -> float:
	match nazwa:
		"azymut_st": return fposmod(rad_to_deg(atan2(ModelKameryEE.KIERUNEK_MAPY.y, ModelKameryEE.KIERUNEK_MAPY.x)), 360.0)
		"pochylenie_st": return ModelKameryEE.POCHYLENIE_ST
		"poziomy_zoomu": return float(ModelKameryEE.POZIOMOW)
		"odleglosc_maks": return ModelKameryEE.odleglosc(ModelKameryEE.POZIOMOW - 1)
		"odleglosc_krok": return ModelKameryEE.odleglosc(20) - ModelKameryEE.odleglosc(19)
		"odleglosc_min": return ModelKameryEE.odleglosc(0)
		"strzalki_poziom_20": return ModelKameryEE.predkosc(20)
		"strzalki_poziom_0": return ModelKameryEE.predkosc(0)
		"dwie_strzalki_poziom_20": return ModelKameryEE.predkosc(20) * sqrt(2.0)
		"krawedz_docelowa_poziom_20": return ModelKameryEE.predkosc_krawedzi(20)
		"krawedz_docelowa_poziom_0": return ModelKameryEE.predkosc_krawedzi(0)
		"wysokosc_ogniska_nad_morzem": return ModelKameryEE.wysokosc_ogniska(-0.8)
	return NAN


func uruchom(K: Node) -> void:
	var d: Variant = t._json(K, "dane/mechaniki_ee_aoc.json")
	t._ok("E12 dane: dane/mechaniki_ee_aoc.json wczytane", d is Dictionary and d.has("mechaniki"))
	if not d is Dictionary or not d.has("mechaniki"):
		return
	var m: Dictionary = d["mechaniki"]

	# osobne wartości dla obu gier; „obie” = zgodne w obu grach
	var bez_obu := []
	var niezgodne := []
	for n in m:
		var w: Dictionary = m[n]
		if not w.has("ee") or not w.has("aoc"):
			bez_obu.append(n)
			continue
		if w.get("zakres") == "obie" and typeof(w["ee"]) in [TYPE_FLOAT, TYPE_INT]:
			var wzgl := w.has("tolerancja_wzgledna")
			var tol: float = float(w.get("tolerancja_wzgledna", w.get("tolerancja", 0.0)))
			if not _blisko(float(w["ee"]), float(w["aoc"]), tol, wzgl):
				niezgodne.append(n)
	t._ok("E12 dane: każda mechanika ma osobny pomiar EE i AoC", bez_obu.is_empty(), bez_obu)
	t._ok("E12 dane: wpisy „obie” – pomiary EE i AoC zgodne w granicy tolerancji", niezgodne.is_empty(), niezgodne)

	# wspólny kod kamery zgadza się z pomiarem każdej z gier
	for gra in ["ee", "aoc"]:
		var zle := []
		var sprawdzone := 0
		for n in m:
			var oczek := _openee(n)
			if is_nan(oczek):
				continue
			var w: Dictionary = m[n]
			var wzgl := w.has("tolerancja_wzgledna")
			var tol: float = float(w.get("tolerancja_wzgledna", w.get("tolerancja", 0.0)))
			sprawdzone += 1
			if not _blisko(float(w[gra]), oczek, tol, wzgl):
				zle.append("%s: %s=%s, OpenEE=%.3f" % [n, gra, str(w[gra]), oczek])
		t._ok("E12 kamera: ModelKameryEE zgodny z pomiarem %s (%d parametrów)" % [gra.to_upper(), sprawdzone],
			zle.is_empty() and sprawdzone >= 12, zle)

	# granica ogniska: romb u ∈ [N, 3N], v ∈ [−N, N] dla mapy 140×140 (narożniki zmierzone w obu grach)
	var g := Rect2(140, -140, 280, 280)
	var r0 := ModelKameryEE.ogranicz(Vector2(0, 0), g)
	var r1 := ModelKameryEE.ogranicz(Vector2(400, 400), g)
	var gr: Dictionary = m.get("granica_ogniska_narozniki", {})
	for gra in ["ee", "aoc"]:
		var p: Array = gr.get(gra, [[0, 0], [0, 0]])
		var tol: float = float(gr.get("tolerancja", 0.2))
		t._ok("E12 kamera: granica ogniska (romb) jak w %s" % gra.to_upper(),
			r0.distance_to(Vector2(p[0][0], p[0][1])) <= tol and r1.distance_to(Vector2(p[1][0], p[1][1])) <= tol, [r0, r1, p])

	# różnice nieustalone – udokumentowane, bez implementacji
	var nieimpl := true
	for r in d.get("roznice", []):
		nieimpl = nieimpl and str(r.get("implementacja", "")).begins_with("brak") and str(r.get("pewnosc", "")) in ["W", "H", "N"]
	t._ok("E12 różnice EE ↔ AoC: tylko [W]/[H]/[N], bez implementacji", nieimpl and not d.get("roznice", []).is_empty())

	# przewijanie krawędzią jest wspólne: jeden współczynnik 5/6, bez narastania
	t._ok("E12 kamera: krawędź = 5/6 strzałek, bez parametru narastania (wspólny kod)",
		is_equal_approx(ModelKameryEE.WSP_PREDKOSCI_KRAWEDZI, 5.0 / 6.0) and not (load("res://silnik/kamera/model_kamery_ee.gd") as Script).get_script_constant_map().has("PRZYSPIESZENIE_KRAWEDZI"))

	# mnożnik prędkości: wartość etapu 9; pomiar etapu 12 na innym scenariuszu nie zmienia stałej
	t._ok("E12 ruch: Symulacja.MNOZNIK_PREDKOSCI = dane openee (1,461 od etapu 13), niezależny od gry",
		is_equal_approx(Symulacja.MNOZNIK_PREDKOSCI, float(d.get("openee", {}).get("mnoznik_predkosci", -1.0))))
	# etap 13: mnożnik 1,706 wycofany (artefakt próbkowania); zgodność tempa czasu gry EE = AoC sprawdza
	# test „E13 prędkość: MNOZNIK_PREDKOSCI = tempo zegara gry” (testy_etapu13.gd) – tu bez powtórzenia (etap 13.5)
