extends RefCounted
## Używać przez preload: const ParametryTypowDB := preload("res://silnik/symulacja/parametry_typow_db.gd")
## (bez class_name – skrypty uruchamiane z --script nie wymagają wtedy odświeżenia pamięci klas globalnych).
## Etap 53: parametry ruchu i walki typu jednostki dla Core wyprowadzone z rekordu `dbobjects`.
##
## Źródłem prawdy są wartości zmierzone w pamięci gry (`dane/testy_walki/parametry_jednostek_ee.json` → „ruch”, „walka”).
## Dla typów bez pomiaru (np. jednostki z produkcji koszar) ta klasa stosuje te same reguły, które dla typów zmierzonych
## dają dokładnie wartości z pomiaru (422, 32, 216, 173 – docs/titan/produkcja.md § 5.4):
##   a = „Acceleration/Deceleration”, vmax = „Speed”, α = „Idle turning speed”, ωmax = „Moving turning speed”,
##   rozmiar = „Size of collider”, c4 = 1/a, c8 = 1/α, t488 = 0,5;
##   HP = „Health”, atak = „Attack”, pancerz = [Shock, Arrow, Pierce, Gun, Laser, Missile armor], zasięg = „Max range”,
##   pole widzenia = „Line of sight”, przeładowanie = „Attack reload time” · 1000, klasa trafienia = „Family ID”,
##   rodzina ataku = „Family attack type”, łuk = „Attack angle”, punktowy = „<PROBABLY> Melee attack”, pole_ac = „Speed”.
## Wartości spoza bazy (okres szukania celu, opóźnienie trafienia z animacji) pochodzą ze zmierzonego typu-wzorca o tym
## samym skrypcie .tai i tej samej rodzinie; bez wzorca: szukanie 2000 ms, opóźnienie nieustawione. To wypełnienie danych,
## nie pomiar – wynik niesie pole „pochodne” = true.

const PANCERZE := ["Shock armor", "Arrow armor", "Pierce armor", "Gun armor", "Laser armor", "Missile armor"]


static func ruch(o: Dictionary) -> Dictionary:
	var a := float(o.get("Acceleration/Deceleration", 0.0))
	var alfa := float(o.get("Idle turning speed", 0.0))
	return {"a": a, "vmax": float(o.get("Speed", 0.0)), "alfa": alfa, "wmax": float(o.get("Moving turning speed", 0.0)),
		"rozmiar": float(o.get("Size of collider", 0.5)), "c4": (1.0 / a) if a > 0.0 else 0.0,
		"c8": (1.0 / alfa) if alfa > 0.0 else 0.0, "t488": 0.5}


static func walka(o: Dictionary, wzorzec: Dictionary = {}) -> Dictionary:
	var panc := []
	for k in PANCERZE: panc.append(int(o.get(k, 0)))
	var p := {"atak": float(o.get("Attack", 0)), "pancerz": panc, "zasieg_max": float(o.get("Max range", 0.0)),
		"pole_widzenia": float(o.get("Line of sight", 0.0)), "przeladowanie_ms": int(round(float(o.get("Attack reload time", 0.0)) * 1000.0)),
		"klasa_trafienia": int(o.get("Family ID", 0)), "rodzina_ataku": int(o.get("Family attack type", 0)),
		"luk_ataku": float(o.get("Attack angle", 0.0)), "rozmiar": float(o.get("Size of collider", 0.5)),
		"punktowy": int(o.get("<PROBABLY> Melee attack", 0)), "szukanie_ms": int(wzorzec.get("szukanie_ms", 2000)),
		"pole_ac": float(o.get("Speed", 0.0)), "typ_bazy": int(o.get("ID", -1)), "typ_jednostki": int(o.get("Unit type", 0))}
	if wzorzec.has("opoznienie_trafienia_ms"): p["opoznienie_trafienia_ms"] = int(wzorzec["opoznienie_trafienia_ms"])
	return {"hp": int(o.get("Health", 1)), "p": p, "pochodne": true}


## Wzorzec = zmierzony typ o tym samym skrypcie .tai i tej samej rodzinie („Family ID”); {} gdy brak.
static func wzorzec_walki(par: Dictionary, obiekty: Dictionary, o: Dictionary) -> Dictionary:
	for t in par.get("walka", {}):
		var ow: Dictionary = obiekty.get(int(t), {})
		if ow.is_empty() or bool(par["walka"][t].get("pochodne", false)): continue
		if String(ow.get("TAI Script", "")) == String(o.get("TAI Script", "?")) and int(ow.get("Family ID", -1)) == int(o.get("Family ID", -2)):
			return par["walka"][t].get("p", {})
	return {}


## Uzupełnia par["ruch"][typ] i par["walka"][typ] z dbobjects, gdy brak pomiaru. Zwraca true, gdy typ jest dostępny.
static func uzupelnij(par: Dictionary, obiekty: Dictionary, typ: int) -> bool:
	var ty := str(typ)
	var o: Dictionary = obiekty.get(typ, {})
	if par.get("ruch", {}).has(ty) and par.get("walka", {}).has(ty): return true
	if o.is_empty() or float(o.get("Speed", 0.0)) <= 0.0: return false
	if not par.has("ruch"): par["ruch"] = {}
	if not par.has("walka"): par["walka"] = {}
	if not par["ruch"].has(ty): par["ruch"][ty] = ruch(o)
	if not par["walka"].has(ty): par["walka"][ty] = walka(o, wzorzec_walki(par, obiekty, o))
	return true
