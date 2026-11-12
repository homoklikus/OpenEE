class_name ObiektyScnCore
extends RefCounted
## Etap 44: dane wejściowe rejestracji obiektów SCN na polach mapy w Core (OpenEESymulacja.wejscie_regionow_z_scn).
## Tylko zbiera pola z kawałka 5 SCN i z baz gry (dbobjects, dbunitset) – reguły rejestracji, +0x612 i klasyfikacja
## pól są w Core (openee::dodaj_obiekty_scn, openee::zestaw_zawiera). Rekordy z valid = 0 są pomijane.


## Obiekty w kolejności rekordów SCN (gracze 0…, rekordy w kolejności pliku).
static func obiekty(scn: ScenariuszEE, zasoby: Object) -> Array:
	var db := {}
	for r in zasoby.tabela("dbobjects"): db[int(r["ID"])] = r
	var out := []
	for g in range(scn.gracze.size()):
		for u in scn.gracze[g].jednostki:
			if int(u.get("valid", 0)) == 0: continue
			var o: Dictionary = db.get(int(u.type), {})
			out.append({"id": int(u.get("id", 0)), "gracz": g, "X": int(u.get("X", 0)), "Y": int(u.get("Y", 0)),
				"typ": int(u.type), "kwadrat": maxi(1, int(o.get("Square occupied", 1))), "hp": int(o.get("Health", 0)),
				"zasob": int(o.get("Resource type", 0)), "budynek": int(o.get("Is building?", 0)),
				"unit_type": int(o.get("Unit type", 0))})
	return out


## Zestawy jednostek dbunitset (obiekty, rodziny, zestaw dołączony i wykluczony).
static func zestawy(zasoby: Object) -> Array:
	var out := []
	for r in zasoby.tabela("dbunitset"):
		if int(r.get("ID", -1)) < 0: continue
		var ob := []; var rd := []
		for k in r.keys():
			if String(k).begins_with("Object ID"): ob.append(int(r[k]))
			elif String(k).begins_with("Family ID"): rd.append(int(r[k]))
		out.append({"ID": int(r["ID"]), "obiekty": ob, "rodziny": rd,
			"dolacz": int(r.get("Include unit set...", -1)), "wyklucz": int(r.get("Exclude unit set", -1))})
	return out


## Pełne wejście floodu regionów z danych lokalnych (mapa SCN musi być już wczytana do `core`).
static func wejscie(core: Object, scn: ScenariuszEE, zasoby: Object, dodatkowe: Array = []) -> Dictionary:
	# etap 47: obiekty spoza SCN (budynki potyczki) dopisane po rekordach scenariusza – format jak obiekty()
	return core.wejscie_regionow_z_scn(obiekty(scn, zasoby) + dodatkowe, zestawy(zasoby))


## Etap 44: parametry śmierci typu (Generic Death.tai) z baz gry – sekwencja umierania dbgraphics (gniazdo 4,
## podsekwencja 0: liczba klatek, „wartość” = ms na klatkę, typ +0x318), czas rozkładu dbobjects „Rotting time”
## (s → ms, typ +0x548). Zasoby niesione (+0x40) – 0. Interpretacja (przejścia 6000–6003) – w Core.
## Etap 46: parametry leczenia (Healer.tai) z rekordu dbobjects typu: „Healer heal amount” (ulepszenie +0x150),
## „Unknown#50” (typ +0x49C – próg HP), „Healing range / Ability range” (+0x4A0), „Unknown#51” (+0x4A4 – okres szukania)
## [P: pamięć typu bohatera 173 = 1,0 / 4,0 / 1,0]. Zestaw leczonych typów (ulepszenie +0x10C) – nieodczytany [N]:
## przekazywane `leczone_typy` (domyślnie pusty – brak leczenia). Reakcja UnderAttack (EEUC +0x370 ze stanem 2018)
## [P: bohater-kapłan EEUCLandPriest] – przyjęta dla skryptu „Military Healer Prophet” [H dla innych typów].
static func parametry_leczenia(ob: Dictionary, leczone_typy: Array = []) -> Dictionary:
	if int(ob.get("Healer heal amount", 0)) <= 0: return {}
	var w := {"leczenie_hp": int(ob.get("Healer heal amount", 0)), "leczenie_prog": float(ob.get("Unknown#50", 0.0)),
		"leczenie_zasieg": float(ob.get("Healing range / Ability range", 0.0)), "leczenie_okres": float(ob.get("Unknown#51", 0.0)),
		"leczone_typy": leczone_typy}
	if String(ob.get("TAI Script", "")) == "Military Healer Prophet": w["reakcja_underattack"] = 1
	return w


## Etap 47: parametry budynku jako obiektu Core z rekordu dbobjects (wartości typu i ulepszenia gracza – odczyt pamięci
## domu 37 gracza 5 w zad. 647 [P]: HP maks. 500 = „Health”, pancerz 0, pole widzenia 2,0, +0x4C0 = 3 („Weapon to hit
## ID”), +0x4C4 = 3 („Family ID”), +0x4C8 = 9 („Family attack type”), +0x474 = 1,0 („Size of collider”), +0x612 = 0,
## +0x61A = 0, +0x4B4 = 2 („Unit type”)). Ulepszenia z technologii epok – poza Core [N]: wartości z rekordu typu.
static func parametry_budynku(ob: Dictionary, db: Dictionary = {}) -> Dictionary:
	# etap 48: pozostałość przy śmierci – „Debris on death#2” (np. 361 „Amb - Debris 1x”, 362 „2x”) i jej „Square occupied”
	var gt := int(ob.get("Debris on death#2", 0))
	var gk := int((db.get(gt, {}) as Dictionary).get("Square occupied", 1)) if gt > 0 else 1
	return {"gruz_typ": gt, "gruz_kwadrat": maxi(1, gk), "hp_max": int(ob.get("Health", 0)), "atak": float(ob.get("Attack", 0)),
		"pancerz": [float(ob.get("Shock armor", 0)), float(ob.get("Arrow armor", 0)), float(ob.get("Pierce armor", 0)),
			float(ob.get("Gun armor", 0)), float(ob.get("Laser armor", 0)), float(ob.get("Missile armor", 0))],
		"pole_widzenia": float(ob.get("Line of sight", 0.0)), "zasieg_max": float(ob.get("Max range", 0.0)),
		"przeladowanie_ms": int(round(float(ob.get("Attack reload time", 0.0)) * 1000.0)),
		"rodzaj_ataku": int(ob.get("Weapon to hit ID", 0)), "wiersz_celu": int(ob.get("Weapon to hit ID", 0)),
		"klasa_trafienia": int(ob.get("Family ID", 0)), "rodzina_ataku": int(ob.get("Family attack type", 0)),
		"rozmiar": float(ob.get("Size of collider", 1.0)), "typ_jednostki": int(ob.get("Unit type", 0)),
		"typ_bazy": int(ob.get("ID", 0)), "rozklad_ms": int(round(float(ob.get("Rotting time", 0.0)) * 1000.0)), "zasoby": 0}


static func parametry_smierci(typ: int, zasoby: Object) -> Dictionary:
	var o := {}
	for r in zasoby.tabela("dbobjects"):
		if int(r["ID"]) == typ: o = r; break
	if o.is_empty(): return {}
	var gr := {}
	for r in zasoby.tabela("dbgraphics"):
		if int(r["ID"]) == int(o.get("Graphic ID", -1)): gr = r; break
	if gr.is_empty(): return {}
	var q := SekwencjeAnimacji.z_rekordu(gr).dla_stanu("smierc")
	if q.is_empty(): return {}
	return {"smierc_klatki": int(q.klatki), "smierc_ms_klatki": int(q.wartosc),
		"rozklad_ms": int(round(float(o.get("Rotting time", 0.0)) * 1000.0)), "zasoby": 0}
