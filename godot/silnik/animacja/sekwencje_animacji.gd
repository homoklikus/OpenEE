class_name SekwencjeAnimacji
extends RefCounted
## Sekwencje animacji obiektu z rekordu dbgraphics – etap 4 (docs/FORMATY_ETAP4.md §2).
##
## Ustalenia [D] (858 rekordów EE, 991 AoC; narzedzia/analiza_animacji.py):
## * jeden model CEM na grafikę; sekwencje to ZAKRESY KLATEK tego modelu (np. falanga: 0–15, 16–31, 32–47, 48–74
##   = 75 klatek modelu); 99,7 % zakresów mieści się w modelu (wyjątki: 3 rekordy kobiety-obywatela – błąd danych gry);
## * po polach Name/Sequence number/ID: 3 liczby nagłówka, potem 12 gniazd; gniazdo = sekwencje po 6 liczb
##   [flagi, klatka_od, klatka_do, wartość, pętla, parametr] + 2 klatki zdarzeń + 2 identyfikatory dbsounds
##   (zdarzenie i dźwięk – np. kroki obywatela na klatkach 8 i 15 → „Walk1”, „walk2”);
##   gniazdo 4 zawiera 3 sekwencje (śmierć i dwie kolejne), pozostałe po jednej;
## * „flagi” i „pętla” to bajty (wyższe bajty bywają przypadkowe, np. 0x6C0101) – liczy się bajt 0 (i 1 flag).
## Znaczenie gniazd – wyłącznie z danych (dźwięki dbsounds przypisane do gniazd, 858 rekordów EE):
##   0 atak [D: Arrow, Gun, Catapult Shot, Cannon…], 1 ruch [D: Horse Trot, Boat Move, Tank moving…],
##   2 bezczynność [D/H: wirnik helikoptera, „Mech shutdown”; pętla bez ruchu], 3 nieustalone [H: wariant gniazda 2 –
##   ten sam zakres klatek, inne tempo; u części jednostek dźwięki ataku/nawracania], 4 śmierć (jednorazowa) +
##   2 sekwencje po śmierci [D: pętla 0, ostatnie klatki modelu], 5–11 czynności zależne od rodzaju jednostki
##   [D: obywatel – Mining, forage, Farm, Chopping wood, Build; kapłan – Convert].
## „Wartość” – HIPOTEZA OpenEE [H]: czas cyklu sekwencji w setnych sekundy (uzasadnienie w FORMATY_ETAP4.md §2.3);
## przelicznik w `CZAS_JEDNOSTKA` – do potwierdzenia porównaniem z uruchomioną grą.

const LICZBA_GNIAZD := 12
const CZAS_JEDNOSTKA := 0.01        # [H] wartość × 0,01 s = czas cyklu
const STANY := {0: "atak", 1: "ruch", 2: "bezczynnosc", 3: "gniazdo_3", 4: "smierc"}

## Sekwencja: {gniazdo, podsekwencja, stan, od, do, klatki, wartosc, czas_cyklu, klatki_na_s, petla, flagi, param,
##             zdarzenia:[klatki], dzwieki:[ID]}
var sekwencje: Array = []
var naglowek: Array = []
var blad: String = ""


## Z rekordu dbgraphics (słownik BazaDB – kolejność pól = układ tabeli).
static func z_rekordu(rek: Dictionary) -> SekwencjeAnimacji:
	var s := SekwencjeAnimacji.new()
	var klucze := rek.keys(); var w := rek.values()
	var i0 := klucze.find("Name")
	var dz: Array = []
	for i in klucze.size():
		if String(klucze[i]).begins_with("Sound ID"): dz.append(i)
	if i0 < 0 or dz.size() < 2 * LICZBA_GNIAZD:
		s.blad = "rekord dbgraphics bez pól sekwencji"; return s
	s.naglowek = [w[i0 + 3], w[i0 + 4], w[i0 + 5]]
	var p := i0 + 6
	for g in LICZBA_GNIAZD:
		var k: int = dz[2 * g]
		var blok := w.slice(p, k)
		var zd := [int(blok[blok.size() - 2]), int(blok[blok.size() - 1])] if blok.size() >= 8 else []
		var snd := [int(w[k]), int(w[k + 1])]
		var nsek := (blok.size() - 2) / 6
		for j in nsek:
			var q := blok.slice(6 * j, 6 * j + 6)
			s._dodaj(g, j, q, zd if j == 0 else [], snd if j == 0 else [-1, -1])
		p = k + 2
	return s


func _dodaj(g: int, j: int, q: Array, zd: Array, snd: Array) -> void:
	var od := int(q[1]); var do_ := int(q[2]); var wart := int(q[3])
	var petla := int(q[4]) & 0xFF
	# pusta = wszystkie (od, do, wartość) zerowe i brak dźwięków; zakres jednej klatki ≠ 0 (np. 74–74 – zwłoki) istnieje
	var istnieje := od != 0 or do_ != 0 or wart > 0 or snd.any(func(x): return int(x) != -1)
	if not istnieje or od < 0 or do_ < od:
		return
	var n := do_ - od + 1
	var czas := wart * CZAS_JEDNOSTKA
	var stan: String
	if g == 4:
		stan = ["smierc", "po_smierci_1", "po_smierci_2"][mini(j, 2)]
	else:
		stan = STANY.get(g, "czynnosc_%d" % g)
	sekwencje.append({"gniazdo": g, "podsekwencja": j, "stan": stan, "od": od, "do": do_, "klatki": n,
		"wartosc": wart, "czas_cyklu": czas, "klatki_na_s": (n / czas) if czas > 0.0 else 0.0,
		"petla": petla != 0, "flagi": int(q[0]) & 0xFFFF, "param": int(q[5]),
		"zdarzenia": zd.filter(func(x): return int(x) > 0), "dzwieki": snd.filter(func(x): return int(x) != -1)})


## Sekwencja dla stanu (np. "bezczynnosc") albo {}.
func dla_stanu(stan: String) -> Dictionary:
	for q in sekwencje:
		if q.stan == stan: return q
	return {}


## Sekwencja bezczynności: gniazdo 2, a gdy brak – gniazdo 3 (ten sam zakres klatek w danych) [D/H].
func bezczynnosc() -> Dictionary:
	var q := dla_stanu("bezczynnosc")
	return q if not q.is_empty() else dla_stanu("gniazdo_3")


## Sprawdzenie zakresów wobec liczby klatek modelu – lista problemów.
func kontrola(klatki_modelu: int) -> Array:
	var bl: Array = []
	for q in sekwencje:
		if int(q.do) >= klatki_modelu:
			bl.append("gniazdo %d: klatki %d–%d poza modelem (%d klatek)" % [q.gniazdo, q.od, q.do, klatki_modelu])
	return bl
