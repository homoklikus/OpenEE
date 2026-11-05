# OpenEE – lokalizacja (teksty i głosy), warstwa `localization/pl`

## 1. Co zawiera polska wersja instalacji społecznościowej (porównanie z GOG EN)

| Element | Gdzie | Liczba | Powiązanie z grą (dowód) |
|---|---|---|---|
| Głosy jednostek / bohaterów | `Empire Earth/Data/data.ssa`, `sounds/*.wav` | **462** | ten sam klucz wpisu; `dbsounds` (ścieżka → ID, opis np. „Kv1 - Where should I go”), `dbobjects` (Selection/Action/Death sound → ID) |
| Głosy jednostek AoC | `…AoC/Data/data.ssa`, `sounds/*.wav` | **80** | jw. (3 pliki bez wpisu w dbsounds AoC) |
| Narracja kampanii | archiwa `Data/Campaigns/*.ssa`, `sounds/een1ve1s_*.mp3` | **1517** | ten sam klucz wpisu w archiwum kampanii; wywołania w scenariuszach |
| Brak polskiego nagrania | AOCAsian (1), AOCPacific (7) | **8** | → angielski odpowiednik (`narracja_brak_pl`) |
| Scenariusze kampanii (teksty) | archiwa kampanii, `scenarios/*.scn` | **55** par | pozycja na liście kampanii + identyczny teren (55/55) |
| Obrazy kampanii z tekstem | archiwa kampanii, `*.jpg` | 55 | ten sam klucz |
| Ekrany tytułowe AoC | AoC `data.ssa`, `textures/bkg_*.tga` | 6 | ten sam klucz |
| Nazwy cywilizacji | AoC `data.ssa`, `civilizations/*.civ` | 21 | identyczna treść poza nazwą (`england.civ` ↔ `anglia.civ`) |
| Teksty interfejsu i jednostek | `Language.dll` (EE, AoC) | 3397 / 3707 | identyfikatory RT_STRING = „Language ID” w tabelach db |

* Format nagrań: WAV PCM 8-bit mono 22 050 Hz (wszystkie 542), MP3 (narracja). Łączny czas głosów: PL 791 s, EN 565 s.
* 263 obiekty `dbobjects` używają co najmniej jednego polskiego głosu (wybór i polecenia: 253 + 251 + 262 + 263, śmierć: 1).
* Nieprzetłumaczone (bez zmian w wersji PL) wpisy kategorii dialogów `dbsounds`: 48 – okrzyki, odgłosy, nagrania w językach
  obcych (np. „Dv0 - German Inf”) – odtwarzane z wersji oryginalnej. Np. obywatel (Citizen) używa wyłącznie pomruków
  („Dv1 - Grunt Q2”), więc nie ma polskiego głosu – to cecha oryginału, nie brak lokalizacji.
* Teksty: EE – 1 identyfikator tylko w EN (30334, „'s”); AoC – komplet.
* 7 zmienionych nagrań poza kategorią głosów jednostek: komunikat „Under Attack”, „Glory!!”, 2 pliki testowe `perftest`,
  3 głosy AoC bez wpisu w dbsounds – oznaczone `rodzaj = dzwiek_zmieniony_nieglosowy?` w manifeście.
* NeoEE/dreXmod nie zmieniają zasobów audio (żaden zmieniony wpis audio nie leży poza lokalizacją; luźne MP3 muzyki → `hd_nieustalone`).

## 2. Warstwa `localization/pl`
`dane/lokalizacja/pl/manifest.json` (generowany lokalnie: `narzedzia/przygotuj_dane_lokalne.sh` → `narzedzia/lokalizacja_pl.py`; nie jest publikowany) – **wyłącznie odniesienia**: instalacja,
archiwum, klucz wpisu, SHA-256 wersji PL i EN, parametry WAV, identyfikatory `dbsounds`, użycie w `dbobjects`, pary
scenariuszy, pary cywilizacji, statystyka tekstów. Żadne nagranie ani tekst nie jest kopiowane do OpenEE.

## 3. Niezależny wybór języka (konfiguracja `[lokalizacja]`)
* `jezyk_tekstow` – Language.dll i grafika z tekstem,
* `jezyk_glosow` – głosy jednostek i komunikaty (`sounds/*.wav`),
* `jezyk_kampanii` – archiwa kampanii (scenariusze, narracja, obrazy),
* `zrodlo_pl` – instalacja, z której czytana jest wersja polska (domyślnie `spolecznosciowa`).

Przykłady: polski tekst + angielskie głosy (`pl/en/…`), całkowicie polska wersja (`pl/pl/pl`), oryginał (`en/en/en`).
Test automatyczny „głosy EN + teksty PL” potwierdza oddzielny wybór. Nakładka działa niezależnie od instalacji bazowej
i nie włącza NeoEE ani dreXmoda (czytane są tylko wpisy wymienione w manifeście).

## 4. Zachowanie przy brakach
* brak polskiego nagrania narracji → odpowiednik angielski z archiwum GOG, wpis w dzienniku (`plik_kampanii()`),
* brak polskiej wersji głosu (48 wpisów kategorii dialogów) → oryginał,
* baza = instalacja społecznościowa i `jezyk_glosow = en` → wersja EN z instalacji GOG (jeśli skonfigurowana), w przeciwnym
  razie ostrzeżenie i polska wersja (oryginalnych nagrań EN w tej instalacji nie ma).

## 5. Audio w Godocie
WAV → `AudioStreamWAV.load_from_buffer()` z oryginalnych bajtów, MP3 → `AudioStreamMP3.data` – **bez przekodowania** i bez
kopiowania na dysk. Test: głos „Kv1 - Where should I go” (falanga, `Selection sound 1` = 827) → PL z nakładki,
SHA-256 = manifest, długość 1,319 s = długość z nagłówka WAV, odtwarzanie rozpoczęte.

## 6. Prawa i redystrybucja
Nagrania i teksty polskiej wersji pochodzą z instalacji użytkownika (wydanie społeczności oparte na polskiej wersji gry);
są chronione prawem autorskim ich właścicieli. OpenEE odczytuje je w miejscu, a manifest zawiera tylko odniesienia i sumy
kontrolne. **Katalog `cache/`, wyodrębnione pliki ani manifesty z próbkami danych nie mogą trafić do publicznego pakietu
OpenEE.** Publiczna dystrybucja powinna zawierać wyłącznie kod, schematy i narzędzia; dane użytkownik wskazuje sam.
