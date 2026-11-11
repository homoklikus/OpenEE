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
static func wejscie(core: Object, scn: ScenariuszEE, zasoby: Object) -> Dictionary:
	return core.wejscie_regionow_z_scn(obiekty(scn, zasoby), zestawy(zasoby))


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
