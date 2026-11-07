# OpenEE – wskazówki dla sesji i agentów AI

Ten plik czytają kolejne sesje (Claude Code / Opus i inni agenci) przed pracą w repozytorium.

## Od czego zacząć

- Stan projektu, moduły, przepływ danych EE/AoC i stan wiedzy o mechanikach: `docs/ARCHITEKTURA_OPENEE.md`.
- Aktualny raport: jedyny plik `RAPORT_*.md` w katalogu głównym. Wcześniejsze raporty: `raporty/README.md`.
- Zasady analizy kodu oryginalnego silnika (atlas Titan): `docs/titan/README.md`. Narzędzia: `narzedzia/README.md`.

## Stała zasada: raporty

W katalogu głównym OpenEE leży **tylko jeden raport – najnowszy**. Przy kończeniu każdego etapu:

1. Utwórz nowy raport `RAPORT_*.md` w katalogu głównym.
2. Przenieś dotychczasowy aktualny raport do `raporty/archiwum/` przez `git mv`.
3. Popraw odwołania do przeniesionego raportu (README, `docs/`, `raporty/README.md`, komentarze w kodzie i narzędziach,
   lista dokumentów w `godot/launcher/launcher.gd`).
4. Dopisz go do listy w `raporty/README.md` i ustaw tam nowy raport jako aktualny. Pełna historia zostaje w archiwum.
5. Zaktualizuj aktualności launchera `dane/launcher/aktualnosci.json`:
   - dopisz nowy wpis na początku listy `wpisy` (data, `tytul`/`tekst` PL i EN zrozumiałe dla gracza,
     `raport` = ścieżka nowego raportu w katalogu głównym);
   - zmień `raport` poprzedniego wpisu na `raporty/archiwum/…`;
   - sprawdź, że trzy najnowsze wpisy prowadzą do istniejących plików, czyli do poprawnych linków GitHub
     (`repozytorium_url` + `raport`). Pilnują tego testy Godota „L aktualności”.

Nie twórz raportów bezpośrednio w `raporty/archiwum/`, chyba że chodzi o odzyskanie dokumentacji historycznej.
Treści zarchiwizowanych raportów nie zmieniaj, poza odnośnikami potrzebnymi do nawigacji. Obalony wniosek oznacz
adnotacją „[Etap … – zastąpione]” i nie usuwaj pierwotnej obserwacji.

## Inne zasady projektu

- Instalacje gry są tylko do odczytu. Do repozytorium nie trafiają zasoby gry, pliki exe, zrzuty pamięci, zrzuty
  ekranu ani lokalne wyniki (`docs/ZASOBY_ORYGINALNE.md`, `.gitignore`).
- Nie commituj lokalnej zmiany `godot/project.godot` (wtyczka Godot MCP użytkownika).
- Riverlands_MCP to osobne, lokalne repozytorium bez `origin`; nie publikuj go.
- Bez `reset --hard`, `clean -fd`, `push --force`. Commity małe i logiczne.
- Ustalenia oznaczaj poziomem pewności: [P] potwierdzone, [W] wniosek, [H] hipoteza, [N] nieustalone.
- Dokumentacja i raporty po polsku.
