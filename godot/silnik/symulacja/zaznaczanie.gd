class_name Zaznaczanie
extends RefCounted
## Zaznaczanie myszą – logika bez węzłów (testowalna bez renderera), etap 5.
## Promień kamery → (a) najbliższa jednostka przecięta przez promień (walec pionowy o promieniu „Circle selection size”
## i wysokości `wys_jednostki`), (b) punkt terenu (przecięcie z polem wysokości). Jednostka ma pierwszeństwo, jeśli leży
## przed punktem terenu – kliknięcie jednostki nie zaznacza terenu za nią.

const WYS_JEDNOSTKI := 1.2


## Przecięcie promienia (Godot: origin, dir) z terenem mapy; zwraca punkt mapy (Vector2) i odległość albo {}.
static func teren(mapa: MapaNawigacji, origin: Vector3, dir: Vector3, maks: float = 2000.0) -> Dictionary:
	var d := dir.normalized()
	var krok := 0.25
	var t := 0.0
	var poprz_t := 0.0
	var poprz_nad := true
	while t < maks:
		var p := origin + d * t
		var h := mapa.wysokosc(Vector2(p.x, p.z))
		var nad := p.y >= h
		if not nad and poprz_nad and t > 0.0:
			var a := poprz_t; var b := t
			for i in 24:
				var m := (a + b) * 0.5
				var q := origin + d * m
				if q.y >= mapa.wysokosc(Vector2(q.x, q.z)): a = m
				else: b = m
			var r := origin + d * b
			return {"punkt": Vector2(r.x, r.z), "odleglosc": b, "pozycja": r}
		poprz_nad = nad; poprz_t = t
		t += krok
		if t > 50.0: krok = 0.5
	return {}


## Jednostka trafiona promieniem: [id, odległość] albo [-1, INF]. jednostki: Array[JednostkaSym].
static func jednostka(sym: Symulacja, origin: Vector3, dir: Vector3) -> Array:
	var d := dir.normalized()
	var najl := -1; var odl := INF
	for j in sym.lista():
		var h := sym.wysokosc(j)
		var t := _walec(origin, d, Vector3(j.pozycja.x, h, j.pozycja.y), j.promien, WYS_JEDNOSTKI)
		if t >= 0.0 and t < odl:
			odl = t; najl = j.id
	return [najl, odl]


## Wynik kliknięcia: {"jednostka": id|-1, "teren": punkt mapy|null}.
static func klik(sym: Symulacja, origin: Vector3, dir: Vector3) -> Dictionary:
	var u := jednostka(sym, origin, dir)
	var te := teren(sym.mapa, origin, dir)
	var odl_t: float = te.get("odleglosc", INF)
	if int(u[0]) >= 0 and float(u[1]) <= odl_t + 0.05:
		return {"jednostka": int(u[0]), "teren": te.get("punkt")}
	return {"jednostka": -1, "teren": te.get("punkt")}


## Przecięcie promienia z walcem pionowym (podstawa w `p`, promień r, wysokość h); odległość albo −1.
static func _walec(o: Vector3, d: Vector3, p: Vector3, r: float, h: float) -> float:
	var ox := o.x - p.x; var oz := o.z - p.z
	var a := d.x * d.x + d.z * d.z
	var najl := -1.0
	if a > 1e-9:
		var b := 2.0 * (ox * d.x + oz * d.z)
		var c := ox * ox + oz * oz - r * r
		var delta := b * b - 4.0 * a * c
		if delta >= 0.0:
			var sq := sqrt(delta)
			for t in [(-b - sq) / (2.0 * a), (-b + sq) / (2.0 * a)]:
				if t >= 0.0:
					var y: float = o.y + d.y * t
					if y >= p.y and y <= p.y + h:
						najl = t if najl < 0.0 else minf(najl, t)
	# podstawy walca (widok z góry)
	if absf(d.y) > 1e-9:
		for yy in [p.y, p.y + h]:
			var t: float = (yy - o.y) / d.y
			if t >= 0.0:
				var x := ox + d.x * t; var z := oz + d.z * t
				if x * x + z * z <= r * r:
					najl = t if najl < 0.0 else minf(najl, t)
	return najl
