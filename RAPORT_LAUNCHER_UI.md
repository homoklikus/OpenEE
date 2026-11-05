# OpenEE – raport: launcher UI

Launcher jest częścią projektu Godot OpenEE (scena `res://launcher/launcher.tscn`, teraz scena główna projektu).
Układ i klimat odtworzone według dostarczonej grafiki referencyjnej: ciemne tło, granatowe karty z niebieską poświatą,
lewy pasek nawigacji, baner ze złotym logo, karty informacyjne, sekcje profilu / języka / modów / podglądu
i duży zielony przycisk uruchamiania. UI jest budowane w kodzie z kontenerów Godota (bez współrzędnych „na sztywno”).

Zrzuty: `wyniki/launcher/` – `start_1920x1080_pl.png`, `start_1920x1080_en.png`, `start_2560x1440_pl/en.png`,
`hidpi_3840x2160_pl.png`, `start_1440x900_pl.png`, `start_1536x1024_pl.png`, `start_1920x1080_skala125_pl.png`,
`strona_*_pl.png` (6 stron), `strona_profile_en.png`, `przejscie_do_sceny.png` (scena OpenEE uruchomiona z launchera).

## 1. Co jest gotowe
| Element | Stan |
|---|---|
| Pasek boczny: Start, Gra, Mody, Profile, Ustawienia, Narzędzia, Informacje | działa – każda pozycja ma własną stronę |
| Nagłówek: grafika z referencji (hełm, logo „OpenEE”, panorama epok), podtytuł PL/EN | gotowy (patrz §3) |
| Karta instalacji gry | wykrywanie instalacji, ścieżka, status, źródło (Referencyjna GOG / Społecznościowa), „Zmień…” |
| Karta silnika | wersja (0.2.0-dev), renderer (wykryty z Godota), platforma, status gotowości |
| Aktualności / plan rozwoju | lokalne, statyczne (`dane/launcher/aktualnosci.json`), „Więcej…” → Informacje |
| Profil gry | lista profili, opis, Nowy / Klonuj / Usuń (profile wbudowane nieusuwalne) |
| Język gry | Polski / English / Polski tekst + angielskie głosy (+ „Własne” gdy konfiguracja nie pasuje do presetu) |
| Aktywne mody (N) | stan pusty jak na referencji; lista, Dodaj mod…, W górę, W dół, Wyłącz/włącz, Usuń |
| Podgląd gry | ostatni zrzut z testu graficznego OpenEE (`wyniki/test_graficzny_etap2`) |
| „Używaj silnika OpenEE (zamiast oryginalnego EE)” | działa, zapamiętywany |
| Przycisk „Uruchom Empire Earth” + menu trybów | uruchamia OpenEE (patrz §2) |
| Język UI PL/EN | przełącznik w pasku bocznym i w Ustawieniach, natychmiastowa przebudowa UI; obejmuje też wbudowane okna Godota (wybór katalogu, OK/Anuluj, menu pól tekstowych) – `dane/launcher/i18n/godot/pl.json` |
| Skalowanie | 1440×900 … 3840×2160 i HiDPI, dodatkowo skala użytkownika 70–140 % |

## 2. Co jest realnie podpięte
* **Ścieżka gry i źródło danych** – odczyt z istniejącej `Konfiguracja` (`[instalacje]`, `[zrodlo]`); weryfikacja katalogu
  (`Empire Earth/Data/data.ssa`, AoC, pliki GOG). „Zmień…” otwiera wybór katalogu; poprawna ścieżka trafia do
  `konfiguracja/uzytkownik.cfg` (doklejana przed ścieżkami z `openee.cfg`), a źródła zasobów są przebudowywane.
* **Profil gry** → `zrodlo/gra`, `zrodlo/profil` (EE / EE+AoC), `warstwy/aktywne` w `uzytkownik.cfg` +
  `Zasoby.przebuduj_zrodla()`. Sprawdzone: profil „Vanilla + tekstury HD” powoduje, że tekstura terenu pochodzi z warstwy
  `hd_nieustalone`; po ponownym uruchomieniu wybór profilu jest odtwarzany.
* **Język gry** → `[lokalizacja] jezyk_tekstow / jezyk_glosow / jezyk_kampanii` (istniejący system etapu 2).
  Sprawdzone: preset „Polski tekst, angielskie głosy” – głos falangi wczytywany z archiwum referencyjnego (EN).
  W Ustawieniach można wybrać każdy z trzech języków osobno.
* **Mody** = nakładki warstw z `dane/warstwy.json` (obecnie realnie działa `hd_nieustalone`); NeoEE i dreXmod pokazane
  na stronie Mody jako komponenty informacyjne (OpenEE ich nie wczytuje). Zmiana modów profilu wbudowanego tworzy
  automatycznie kopię profilu („Kopia – …”). Profile użytkownika: `konfiguracja/profile_uzytkownika.json`.
* **Uruchamianie**: przy zaznaczonym „Używaj silnika OpenEE” przycisk uruchamia tryb demonstracyjny – scenariusz testowy
  etapu 2 (Soldiers for Rome, z instalacji); menu strzałki: scenariusz / test terenu / diagnostyka. W scenie Esc lub
  przycisk „← Launcher” wraca do launchera. Zweryfikowane zrzutem `przejscie_do_sceny.png`.
* **Narzędzia**: sceny testowe, uruchomienie testów automatycznych w tle, wynik ostatnich testów, otwieranie folderów.
* **Gra**: lista instalacji z rolą (baza / źródło PL), wynik weryfikacji GOG (602/602) z `wyniki/hashdb_po_etapie2.json`.

## 3. Co jest placeholderem / tymczasowe
* **Nagłówek** – wycięty z grafiki referencyjnej (`dane/launcher/grafika/`, narzędzie `narzedzia/baner_launchera.py`):
  oryginalny podpis usunięty (inpainting), podtytuł wpisany ponownie w wersji `baner_pl.png` / `baner_en.png`
  (nowy język → `baner_<kod>.png`, brak → EN). Wysokość nagłówka dopasowuje się do szerokości okna (proporcje grafiki,
  128–176 jednostek). **Tymczasowe:** źródło ma tylko 154 px wysokości (powiększone ×2) – przy 2560×1440 i HiDPI jest lekko
  miękkie; potrzebna wersja w pełnej rozdzielczości i potwierdzenie praw przed publicznym wydaniem. Bez tych plików
  launcher wraca do nagłówka zastępczego z grafiką z instalacji gry.
* **Okładka na karcie gry** – składana w locie z Twojej instalacji (EE `splash_*`, 3×4 kafle) i zapisywana tylko lokalnie
  w `cache/launcher/` – nie wolno jej rozpowszechniać. Bez instalacji – ikona zastępcza.
* **Ikony** – własne, proste rysunki SVG (`launcher/ikony.gd`), tymczasowe do czasu zestawu graficznego projektu.
* **Aktualności** – statyczny plik lokalny, bez sieci.
* **Uruchomienie oryginalnej gry** (pole odznaczone) – hak `_uruchom_oryginalna_gre()` pokazuje komunikat; niepodpięte.
* **„Dodaj mod…”** – wybór tylko spośród znanych nakładek; brak instalacji archiwów modów, zależności i manifestów modów
  (wykrywanie katalogu `OpenEE/mody/<nazwa>/mod.json` przygotowane, bez ładowania).
* Tryb „Uruchom” = scena demonstracyjna (bez rozgrywki) – pełna gra to przyszłe etapy.

## 4. Pliki
Nowe:
* `godot/launcher/launcher.tscn`, `launcher.gd` – ekran i strony,
* `godot/launcher/stan_launchera.gd` – model (profile, mody, język, ustawienia, info instalacji/silnika), bez UI – testowalny,
* `godot/launcher/motyw.gd` – paleta, czcionki systemowe, style, Theme,
* `godot/launcher/ikony.gd` – ikony SVG i flagi (renderowane ×3, rozmiar logiczny przez `size_override` – ostre w HiDPI),
* `godot/launcher/teksty_ui.gd` – teksty UI z `dane/launcher/i18n/<kod>.json`,
* `godot/launcher/grafiki_gry.gd` – grafiki z instalacji (z pamięcią podręczną),
* `godot/launcher/powrot.gd` – przycisk/klawisz powrotu ze sceny OpenEE,
* `dane/launcher/grafika/` – nagłówek z grafiki referencyjnej (`baner_pl.png`, `baner_en.png`, `baner_bez_podtytulu.png`, `ZRODLO.md`),
  `narzedzia/baner_launchera.py` – odtworzenie nagłówka z grafiki referencyjnej,
* `dane/launcher/i18n/pl.json`, `en.json` (137 kluczy), `dane/launcher/profile_domyslne.json`, `dane/launcher/aktualnosci.json`.

Zmienione (kopie: `kopie/etap2_przed_launcherem/`):
* `godot/project.godot` – scena główna = launcher, `config/version="0.2.0-dev"`, `allow_hidpi`,
* `godot/silnik/rdzen/konfiguracja.gd` – nakładka `konfiguracja/uzytkownik.cfg` (zapis/odczyt), `czy_instalacja_ee()`,
  `tryb_testow()` (testy ignorują ustawienia użytkownika); `openee.cfg` z komentarzami nigdy nie jest nadpisywany,
* `godot/testy/uruchom_testy.gd` – 18 nowych testów launchera (razem **53/53**),
* `uruchom_openee.sh` – domyślnie launcher; `diag`, `scenariusz`, `test`, `testy`,
* `README.md`, `docs/ARCHITEKTURA.md`.

Tworzone w trakcie używania: `konfiguracja/uzytkownik.cfg`, `konfiguracja/profile_uzytkownika.json`, `cache/launcher/*.png`.

## 5. Jak uruchomić
```
./uruchom_openee.sh              # launcher
./uruchom_openee.sh testy        # testy automatyczne (51)
# zrzut bez okna użytkownika (np. do dokumentacji):
xvfb-run -a -s "-screen 0 2600x1500x24" <godot> --path godot res://launcher/launcher.tscn -- \
    --zrzut=/tmp/l.png --rozmiar=1920x1080 --jezyk-ui=en --strona=start
```
Argumenty launchera: `--strona=`, `--jezyk-ui=`, `--rozmiar=`, `--skala=`, `--zrzut=`, `--uruchom=0|1|2`
(zrzut/rozmiar/język z wiersza poleceń nie zmieniają zapisanych ustawień).

## 6. Skalowanie
Układ projektowany w rozmiarze logicznym 1520×900; okno używa `content_scale_mode = canvas_items` + `aspect = expand`,
więc całość skaluje się proporcjonalnie do okna (1920×1080 → ×1,2; 2560×1440 → ×1,6; 3840×2160 → ×2,4),
a nadmiar szerokości/wysokości poszerza karty. Ekrany HiDPI dostają większe okno w pikselach fizycznych i większy
współczynnik. Pierwsze otwarcie: okno ~88 % ekranu, wyśrodkowane; minimum 1100×700. Skala użytkownika (Ustawienia)
zmienia rozmiar logiczny; gdy przy dużej skali układ się nie mieści, ekran Start przewija się zamiast nachodzić.

## 7. Testy (`wyniki/testy_godot.json` – 53/53)
Teksty UI (te same klucze PL/EN, brak brakujących kluczy, przełączanie), profile (wczytanie, domyślny = konfiguracja
silnika, kopia przy zmianie modów, usuwanie), mody (warstwy z nakładką / bez wyłączonej), język gry, brak zapisu w trybie
testów, 30 ikon, scena (7 pozycji menu, przycisk startu, karty, przebudowa po zmianie języka, wszystkie strony).
Osobno sprawdzony realny zapis (poza trybem testów) – po próbie przywrócono stan domyślny (plik próby w `cache/_proba/`).
Wszystkie 33 testy etapu 2 nadal przechodzą.

## 8. Ograniczenia
* Wybór katalogu: gdy system udostępnia natywne okno (portal XDG – KDE/GNOME), używane jest ono, w języku systemu;
  w przeciwnym razie okno Godota przetłumaczone na język UI launchera.
* Okno ma natywną ramkę systemu (nie własny pasek tytułu jak na referencji).
* Czcionki systemowe (Noto Sans / DejaVu; logo: DejaVu Serif Bold Italic) – brak dołączonej czcionki projektu;
  wygląd zależy od czcionek zainstalowanych w systemie.
* Złote logo to tekst z obrysem i cieniem (bez gradientu metalicznego z referencji).
* Zrzuty wykonane w xvfb (llvmpipe) – na prawdziwej karcie wygląd ten sam, ale nie sprawdzałem interakcji myszą
  na Twoim pulpicie (zasada: bez przejmowania myszy). Okna dialogowe (wybór katalogu) – osadzone okna Godota.
* Ścieżki w VM pokazują się jako `~/mnt/...`; na Twoim komputerze będą to ścieżki z `openee.cfg` (`/media/...`).
* Przy skali użytkownika > ~115 % w oknie 1920×1080 pojawia się przewijanie ekranu Start.
