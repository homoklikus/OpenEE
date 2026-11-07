# OpenEE – raport pierwszej publikacji na GitHubie (0.3.0-dev)

Data: 2026-11-05 · Repozytorium: **https://github.com/homoklikus/OpenEE** (gałąź `main`)

## 1. Stan publikacji
| Element | Wartość |
|---|---|
| Wersja | 0.3.0-dev (wersja rozwojowa, **bez wydania stabilnego**) |
| Commit z kodem | `d0acd9c` – „OpenEE 0.3.0-dev – pierwsza publiczna wersja rozwojowa” |
| Commit z raportem | następny po `d0acd9c` (ten plik) |
| Licencja | GNU GPL v3 (`LICENSE`), decyzja autora projektu |
| Stan na GitHubie | **oczekuje na wypchnięcie** – repozytorium istnieje i jest puste; sesja nie ma jeszcze dostępu do konta GitHub. Status zostanie zaktualizowany po weryfikacji na GitHubie. |

Kopia zapasowa sprzed utworzenia repozytorium: `kopie_OpenEE/OpenEE_przed_git_2026-11-05.tar.gz` (99,9 MB, 599 plików, suma w `.sha256`), poza katalogiem projektu.

## 2. Opublikowane pliki (161 + ten raport)
| Katalog | Pliki | Zawartość |
|---|---|---|
| (główny) | 10 | `README.md`, `LICENSE`, `CONTRIBUTING.md`, `AUTORZY.md`, `.gitignore`, `uruchom_openee.sh`, raporty etapów 1–3 i launchera |
| `docs/` | 8 | architektura, formaty (etapy 1–3), lokalizacja, zasady zasobów oryginalnych, historia, mapa drogowa |
| `godot/` | 59 | projekt Godot: rdzeń (konfiguracja, dziennik, zdarzenia), importery (SSA, DCL, SST/TGA, CEM, db, Language.dll, dźwięki, scenariusze), render terenu, zasoby/warstwy, launcher, sceny testowe, testy (`.gd`, `.uid`, `.tscn`, `project.godot`) |
| `narzedzia/` | 28 | narzędzia Python/C: czytniki formatów (`eeformaty/`), audyt i porównanie instalacji, klasyfikacja warstw, manifest lokalizacji, testy, `przygotuj_dane_lokalne.sh` |
| `dane/` | 55 | schemat pól tabel z EE DB Editor (37 `.dats` + `LICENSE`, `README.txt`, `ZRODLO.md`), `uklad_db.json`, `gramatyka_jednostki.json`, `warstwy.json`, launcher: teksty PL/EN, profile domyślne, aktualności, 3 grafiki nagłówka + `ZRODLO.md` |
| `konfiguracja/` | 1 | `openee.cfg` – szablon bez prywatnych ścieżek |

Jedyne pliki binarne: 3 grafiki nagłówka launchera (PNG, ok. 1,1 MB każda) – prawa potwierdzone przez autora projektu (`dane/launcher/grafika/ZRODLO.md`).

Kontrole faktycznej listy plików (`git ls-files`): brak ścieżek prywatnych (`/media/…`, `/sessions/…`, katalog domowy), brak adresu e-mail, tokenów, kluczy i haseł; brak plików w formatach gry (`ssa cem sst tga wav mp3 bik exe dll scn dat civ rms`).

## 3. Świadomie pominięte (lokalnie zostają, wykluczone w `.gitignore`)
| Ścieżka | Powód |
|---|---|
| `audyt/` | inwentarze instalacji, kopia GOG hashdb, prywatne ścieżki – dane konkretnej instalacji |
| `wyniki/` | zrzuty ekranu z zasobami gry, wyniki testów i pomiarów |
| `cache/` | zasoby pochodne (rozpakowane/złożone grafiki gry, dane testu graficznego) |
| `kopie/`, `SUMY_SHA256.txt` | kopie zapasowe, sumy lokalnych plików |
| `dane/lokalizacja/pl/manifest.json` | odniesienia do polskiego dubbingu i próbki tekstów – generowany lokalnie (`przygotuj_dane_lokalne.sh`) |
| `dane/schemat_db_eedbeditor/AOC/language.txt` | teksty gry w pakiecie schematu |
| `konfiguracja/uzytkownik.cfg`, `profile_uzytkownika.json` | ustawienia i ścieżki użytkownika |
| `godot/.godot/`, `*.import` | pamięć podręczna edytora (zawiera prywatną ścieżkę) |
| `__pycache__/`, `*.so`, `*.o` | artefakty kompilacji |
| plik wykonywalny Godota | silnik nie jest dołączany (MIT, pobierany przez użytkownika) |
| `wyniki/RAPORT_ZGODNOSCI_RENDEROWANIA.md` | leży w `wyniki/`; treść zastąpiona przez raport etapu 3 |

## 4. Audyt licencji
* **Kod OpenEE** (GDScript, Python, C, dokumentacja) – własny, GPLv3. Dekodery formatów napisane od nowa; do repozytorium nie trafił kod ani fragmenty dekompilacji gry (reguły silnika opisano własnymi słowami).
* **Schemat EE DB Editor** (Forlini91) – GPLv3, pliki bez zmian z oryginalnym `LICENSE` i opisem pochodzenia; `uklad_db.json` to utwór zależny (GPLv3). Pominięto `language.txt`. Zgodność GPLv3 ↔ GPLv3 – bez konfliktu.
* **Grafiki nagłówka launchera** – autor potwierdził prawa do publikacji (2026-11-05).
* **Godot** – MIT, niedołączony. **Ghidra** – narzędzie lokalne, wyniki niepublikowane.
* **Zasoby Empire Earth** – nieobecne; wczytywane w czasie działania z legalnej instalacji użytkownika.
* Pliki o niejasnych prawach: brak w publikacji (jedyny taki przypadek – `language.txt` – pominięty).

## 5. Test czystej kopii
Klon repozytorium w osobnym katalogu (`OpenEE_czysta_kopia_test`, poza projektem), Godot 4.7.2.

| # | Wymaganie | Wynik |
|---|---|---|
| 1 | Godot otwiera projekt | ✅ import (`--headless --import`) bez błędów skryptów |
| 2 | Wskazanie zewnętrznej instalacji | ✅ `StanLaunchera.ustaw_sciezke_instalacji` → zapis do lokalnego `uzytkownik.cfg`; Zasoby gotowe, `dbterrain` 93 rekordy, tekstura z archiwum instalacji |
| 3 | Brak ukrytej zależności od cache | ✅ bez instalacji: brak błędów, testy zależne od danych pomijane z opisem powodu; dane lokalne odtworzone skryptem |
| 4 | Launcher działa | ✅ zrzut 1600×900 (PL): instalacja wykryta, „Gotowy do uruchomienia”, wersja 0.3.0-dev; scena scenariusza „The Trojan War” renderuje się z danych instalacji (48×48 pól, 335 obiektów) |
| 5 | Testy niekomercyjne | ✅ bez instalacji: **66 testów: 20 zaliczonych, 46 pominiętych, 0 błędów** |
| 6 | Pozostałe testy z instalacją | ✅ po `przygotuj_dane_lokalne.sh`: **65 zaliczonych, 1 pominięty, 0 błędów** (pominięty: nakładka HD – wymaga `audyt/manifest_zasobow.json` z klasyfikacji warstw etapu 1) |
| 7 | Dokumentacja wystarcza | ✅ czysta kopia uruchomiona wyłącznie według `README.md` (wymagania, wskazanie instalacji, `uruchom_openee.sh`, skrypt danych lokalnych) |

W trakcie testów `git status` czystej kopii pozostał pusty (wszystkie dane lokalne trafiają do katalogów ignorowanych). W projekcie źródłowym: 66/66.

## 6. Ograniczenia wersji 0.3.0-dev
* To nie jest gra: brak rozgrywki, ruchu jednostek, interfejsu gry, SI i dźwięku zdarzeń.
* Brak bezpośredniego porównania wizualnego z oryginalnym EE – zgodność renderowania oceniana na podstawie reguł i danych, nie zrzutów z gry.
* Brak animacji modeli i wody, ścian brzegowych, map kosmicznych; 3 scenariusze EE wczytywane częściowo (lista celów jednostki).
* Mody: tylko szkielet (warstwy, nakładki); menedżer modów niekompletny.
* Test nakładki HD wymaga pełnego audytu warstw (pominięty w czystej kopii).
* Nie deklarujemy zgodności funkcjonalnej z Empire Earth.

## 7. Dalszy tryb pracy
Każdy etap: testy → dokumentacja → kontrola `git ls-files` pod kątem zasobów gry i prywatnych ścieżek → jeden opisowy commit. Wydania stabilne dopiero po decyzji autora projektu.
