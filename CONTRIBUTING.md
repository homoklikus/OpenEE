# Współpraca z OpenEE

Dziękujemy za zainteresowanie! OpenEE to wczesna wersja rozwojowa – zmiany są mile widziane, ale obowiązuje kilka zasad.

## Zasady najważniejsze
1. **Żadnych zasobów Empire Earth w repozytorium** – modeli, tekstur, dźwięków, archiwów SSA, plików EXE/DLL, tekstów gry,
   zrzutów ekranu zawierających grafikę gry, zrzutów tabel ani manifestów wygenerowanych z instalacji.
   Patrz [docs/ZASOBY_ORYGINALNE.md](docs/ZASOBY_ORYGINALNE.md).
2. **Żadnego kodu z dekompilacji** oryginalnej gry. Wolno opisywać formaty i reguły własnymi słowami (dokumentacja
   w `docs/`) i implementować je samodzielnie.
3. **Rozróżniaj fakty od hipotez** – w dokumentacji formatów oznaczamy: [K] potwierdzone kodem, [D] danymi,
   [P] kodem i danymi, [H] hipoteza.
4. Licencja wkładu: **GPLv3** (jak cały projekt). Kod z innych projektów tylko na licencji zgodnej z GPLv3 i z podaniem
   autorstwa w [AUTORZY.md](AUTORZY.md).

## Przed wysłaniem zmian
* Uruchom testy: `./uruchom_openee.sh testy` – wynik `ZALICZONE` (testy wymagające instalacji mogą być pominięte;
  jeśli masz instalację – uruchom też `narzedzia/przygotuj_dane_lokalne.sh` i pełny zestaw).
* Sprawdź listę plików w commicie: `git status`, `git diff --cached --stat` – bez plików z `wyniki/`, `audyt/`, `cache/`,
  `kopie/`, `konfiguracja/uzytkownik.cfg`, `dane/lokalizacja/`.
* Nie zapisuj w repozytorium prywatnych ścieżek, tokenów ani haseł.
* Zaktualizuj dokumentację, jeśli zmieniasz format, zachowanie lub sposób uruchamiania.
* Opisuj commity zwięźle (po polsku lub angielsku): co i dlaczego.

## Styl kodu
* GDScript: nazwy po polsku jak w istniejącym kodzie, typy statyczne tam, gdzie to proste, komentarze `##` przy klasach.
* Python: biblioteka standardowa + Pillow/numpy; narzędzia czytają instalację wyłącznie w trybie odczytu.
* Nowa funkcjonalność = nowy test w `godot/testy/uruchom_testy.gd` (z `_pomin(...)`, jeśli wymaga danych gry).

## Zgłoszenia
Opisz wersję Godota, system, instalację EE (np. GOG Gold Edition) i kroki do odtworzenia. Nie dołączaj plików gry.
