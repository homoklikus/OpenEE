class_name JednostkaSym
extends RefCounted
## Stan jednostki w symulacji (etap 5). Dane ze scenariusza (DaneJednostki) są niezmienne i oddzielone od tego stanu.

enum Ruch { STOI, OBROT, IDZIE }

var id: int = 0                    # trwały identyfikator w sesji
var typ: int = -1                  # ID dbobjects
var wlasciciel: int = 0            # indeks gracza scenariusza
var nazwa: String = ""
var pozycja := Vector2.ZERO        # punkt mapy (x = kolumna, y = wiersz); wysokość z MapaNawigacji
var pozycja_poprz := Vector2.ZERO  # pozycja w poprzednim takcie (interpolacja renderu)
var kurs: float = 0.0              # θ wokół osi Z świata EE (UkladEE)
var kurs_poprz: float = 0.0
var ruch: int = Ruch.STOI
var cel := Vector2.ZERO
var sciezka := PackedVector2Array()
var indeks_punktu: int = 0         # bieżący punkt ścieżki
var predkosc: float = 0.73         # pola/s – dbobjects „Speed” × Symulacja.MNOZNIK_PREDKOSCI (etap 9, pomiar EE)
var obrot_w_miejscu: float = 6.0   # rad/s – dbobjects „Idle turning speed” [H: rad/s]
var obrot_w_ruchu: float = 6.0     # rad/s – dbobjects „Moving turning speed” [H: rad/s]
var promien: float = 0.25          # dbobjects „Circle selection size” (zaznaczanie)
var rozmiar_szyku: float = 0.625   # dbobjects „Size in formation” – odstęp w szyku EE (etap 9)
var miejsce_w_szyku := Vector2.INF # ostatnie miejsce przydzielone rozkazem grupy (diagnostyka)
var kolejka_celow := PackedVector2Array()  # Shift + PPM: kolejne punkty po dojściu do bieżącego celu (etap 9) [P]
var polityka: PolitykaRuchu
var stan_animacji: String = "bezczynnosc"
var ostatni_powod: String = ""     # diagnostyka ostatniego rozkazu
var przebyta_droga: float = 0.0


## Dane jednostki ze scenariusza – niezmienne (zapisu na dysk brak; pozycje zmieniają się tylko w JednostkaSym).
class DaneJednostki:
	var indeks_scn: int = -1
	var typ: int = -1
	var wlasciciel: int = 0
	var pozycja := Vector2.ZERO
	var kurs: float = 0.0
	var skala: float = 1.0


func w_ruchu() -> bool:
	return ruch != Ruch.STOI


func opis() -> Dictionary:
	return {"id": id, "typ": typ, "nazwa": nazwa, "wlasciciel": wlasciciel, "pozycja": pozycja, "kurs_st": rad_to_deg(kurs),
		"stan": ["stoi", "obrót", "idzie"][ruch], "cel": cel, "punkty_trasy": sciezka.size() - indeks_punktu,
		"predkosc": predkosc, "animacja": stan_animacji, "powod": ostatni_powod}
