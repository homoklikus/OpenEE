#!/usr/bin/env python3
"""OpenEE – klasyfikacja plików instalacji do warstw na podstawie DOWODÓW (tylko odczyt).

Wejście:
  inwentarz_instalacji.json        (audyt_instalacji.py – SHA-256, rozmiary, PE, dziennik instalatora)
  gogdb_build_..._drzewo.txt       (referencja: lista plików GOG 2.0.0.2974 v3, rozmiary zaokrąglone, BEZ sum)
  katalog instalacji               (do sprawdzeń zawartości: sygnatury, napisy, wpisy archiwów)
Wyjście: manifest_zasobow.json, manifest_zasobow.csv, podsumowanie na stdout.

Klasy: vanilla, aoc, localization, neoee, drexmod, nieustalone, dane_uzytkownika
Pewność: wysoka | srednia | niska
Każdy wpis zawiera listę dowodów (identyfikatory D-xx opisane w RAPORT_SEPARACJI_WARSTW.md).
"""
import csv, json, os, re, sys, collections

EE, AOC = "empire earth/", "empire earth - the art of conquest/"   # porównania na małych literach

# Pliki WONLobby Resources obecne w referencji GOG (nazwy z gogdb; EE 68 wpisów, AoC 67).
GOG_WONLOBBY = set("""AddFriendDialog.cfg AdminActionDialog.cfg BadUserDialog.cfg ChatCtrl.cfg ChooseNetworkAdapterDialog.cfg
ColorScheme.cfg CommonOptions.cfg CreateAccountCtrl.cfg CreateGameDialog.cfg CreateRoomDialog.cfg CreditsDialog.cfg
DirectConnectCtrl.cfg DirectConnectDialog.cfg EELobbyConnectDialog.cfg EELobbyFileDialog.cfg FriendsListCtrl.cfg
GameBrowserCtrl.cfg GameOptionsCtrl.cfg GameStagingCtrl.cfg GameStagingTabs.cfg GameUserListCtrl.cfg GenericDialog.cfg
GettingStartedCtrl.cfg Help/Chat.html Help/CommunityTab.html Help/DirectTab.html Help/EntryRestrictions.html Help/Friends.html
Help/GameBrowser.html Help/GamePlayHelp.html Help/GamePorts.html Help/GameTab.html Help/HelpRoot.html Help/HelpTab.html
Help/HostGame.html Help/Icons.html Help/Ignore.html Help/LanTab.html Help/LobbyTab.html Help/OptionsTab.html Help/Overview.html
Help/QuickPlayTab.html Help/Security.html Help/Troubleshooting.html Help/loginhelp.html Help/vssver.scc Icons/AFK.png Icons/Admin.png
Icons/Ask2Join.png Icons/Blocked.png Icons/BlueCheck.png Icons/Captain.png Icons/Firewall.png Icons/Flashlight.png
Icons/GameClosed.png Icons/GameOpen.png Icons/Ignored.png Icons/InviteNot.png Icons/Invited.png Icons/Joystick.png
Icons/Moderator.png Icons/Muted.png Icons/Password.png Icons/SkillAdvanced.png Icons/SkillExpert.png Icons/SkillIntermediate.png
Icons/SkillNovice.png Icons/Tombstone.png Icons/blank.png Icons/vssver.scc Images/DefaultBanner.jpg Images/Logo.jpg
Images/MainBackgroundTile.jpg Images/QuickPlayBottom.jpg Images/SierraLogo.png Images/bkg_german.jpg Images/bkg_fleet.jpg Images/logo.png
Images/main_menu_compilation.jpg Images/vssver.scc InitFailedCtrl.cfg InternetGameStagingCtrl.cfg InternetOptions.cfg
InternetQuickPlay.cfg InternetScreen.cfg LANNameDialog.cfg LANPortDialog.cfg LanOptions.cfg LanScreen.cfg LoginCtrl.cfg
LoginHelpCtrl.cfg LoginScreen.cfg LoginStatusCtrl.cfg LostPasswordCtrl.cfg LostUserNameCtrl.cfg MOTDCtrl.cfg MainInternetTab.cfg
MainLanTab.cfg OkCancelDialog.cfg PasswordDialog.cfg PlayerOptionsCtrl.cfg RoomCtrl.cfg RoomDialog.cfg RoomLabelCtrl.cfg
RootScreen.cfg ServerListCtrl.cfg ServerListCustomHeader.cfg Skin/ArrowCursor.png Skin/Buttons.png Skin/Checkbox.png
Skin/CloseButton.png Skin/ComboButton.png Skin/Dialog2.png Skin/GoldDialog.png Skin/Header.png Skin/MenuButtons.png
Skin/OptionButtons.png Skin/Radio.png Skin/Scrollbar.png Skin/SilverDialog.png Skin/TabBorder.png Skin/Tabs.png Skin/vssver.scc
Sounds/AllNotReady.wav Sounds/AllReady.wav Sounds/AskToJoinRecv.wav Sounds/ButtonClick.wav Sounds/Error.wav Sounds/FriendJoined.wav
Sounds/FriendLeft.wav Sounds/InviteRecv.wav Sounds/LobbyMusic.wav Sounds/PlayerJoined.wav Sounds/SierraLogon.wav
Sounds/WhisperRecv.wav Sounds/vssver.scc StatusDialog.cfg TOUDialog.cfg UpdateAccountCtrl.cfg UserListCtrl.cfg UserListTabCtrl.cfg
_GameMaster.cfg _GameResource.cfg _LobbyMaster.cfg _LobbyResource.cfg _LobbyResourceOrig.cfg _LobbySkin.cfg _WONStatus.cfg
vssver.scc""".split())


def fmt_gog(n):
    """Formatowanie rozmiaru jak w gogdb (jednostki dziesiętne, 2–3 cyfry znaczące)."""
    if n < 1000:
        return f"{n}B"
    for jedn, dz in (("KB", 1e3), ("MB", 1e6), ("GB", 1e9)):
        v = n / dz
        if v < 1000 or jedn == "GB":
            return f"{v:.1f}{jedn}" if v < 10 else f"{v:.0f}{jedn}"
    return str(n)


def wczytaj_gog(p):
    pliki, katalogi = {}, {}
    for line in open(p, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        cz = line.split("|")
        if cz[0] == "@DIR":
            katalogi[cz[1].lower()] = int(cz[2])
        elif cz[0] == "@WONLOBBY":
            katalogi[cz[1].lower()] = int(cz[2])
        else:
            pliki[cz[0].lower()] = cz[1]
    return pliki, katalogi


PL_ZNAKI = set("ąćęłńóśźżĄĆĘŁŃÓŚŹŻ")


def polskie_wpisy(root, rel):
    """Zwraca listę przykładowych nazw wpisów archiwum SSA zawierających polskie znaki."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from eeformaty import ssa
    A = ssa.ArchiwumSSA(os.path.join(root, rel))
    pl = [w.nazwa for w in A.wpisy.values() if PL_ZNAKI & set(w.nazwa)]
    A.zamknij()
    return pl


def main():
    inw, gogp, root, outdir = sys.argv[1:5]
    I = json.load(open(inw))["pliki"]
    gog, gogdir = wczytaj_gog(gogp)
    wyn = []
    for f in I:
        p = f["sciezka"]; pl = p.lower(); n = f["rozmiar"]; name = os.path.basename(pl)
        sekcje = ((f.get("pe") or {}).get("sekcje")) or []
        e = {"sciezka": p, "rozmiar": n, "sha256": f["sha256"], "mtime": f["mtime"],
             "z_instalatora": f["w_dzienniku_instalatora"], "warstwa": None, "pewnosc": None, "dowody": [], "uwagi": ""}
        D = e["dowody"]
        gref = gog.get(pl)
        if gref is not None:
            D.append(f"D-GOG: nazwa w referencji GOG ({gref}); lokalnie {fmt_gog(n)}"
                     + (" – rozmiar ZGODNY" if fmt_gog(n) == gref else " – rozmiar RÓŻNY"))
        zgodny_gog = gref is not None and fmt_gog(n) == gref

        def ustaw(w, pew, *d, uw=""):
            e["warstwa"], e["pewnosc"] = w, pew
            D.extend(d)
            if uw:
                e["uwagi"] = uw

        # --- dane użytkownika / środowiska uruchomieniowego (spoza instalatora) ---
        if not f["w_dzienniku_instalatora"]:
            if name.startswith("unins000"):
                ustaw("neoee", "wysoka", "D-REG: rejestr Wine – deinstalator 'NeoEE v2.0.0.5 - Setup v1.7.2' (Empire Earth Community & NeoEE)",
                      uw="deinstalator instalatora społeczności")
            else:
                ustaw("dane_uzytkownika", "wysoka", "D-LOG: plik nieobecny w dzienniku instalatora unins000.dat (utworzony później: zapis gry, scenariusz, pamięć podręczna)")
        # --- NeoEE ---
        elif ".neoee" in sekcje:
            ustaw("neoee", "wysoka", "D-PE: sekcja PE '.neoee' – plik zmodyfikowany przez NeoEE",
                  uw="zmodyfikowany plik oryginalny (vanilla/AoC + NeoEE); wersja niezmodyfikowana nieobecna w instalacji")
        elif name in ("neoee.dll",):
            ustaw("neoee", "wysoka", "D-STR: napisy wewnątrz (ścieżka PDB '...\\NeoEE\\Module\\Release\\neoee.pdb', 'connected to NeoEE')")
        elif name == "neoee.cfg":
            ustaw("neoee", "wysoka", "D-STR: nazwa odczytywana przez neoee.dll ('NeoEE.cfg')",
                  uw="zawartość pliku to ścieżka do katalogu instalatora Lutris (…/lutris/installer/…/neoeefix/NeoEE.cfg) – plik nadpisany przez skrypt Lutris")
        elif "/neoee updater/" in pl:
            ustaw("neoee", "wysoka", "D-DIR+D-STR: aktualizator NeoEE (NeoEEUp.cfg wskazuje http://www.neoee.net/patch/…)")
        elif name in ("neoee_rules.rtf", "neoee.ico"):
            ustaw("neoee", "srednia" if name.endswith(".ico") else "wysoka",
                  "D-STR: treść 'Terms of Use … NeoEE'" if name.endswith(".rtf") else "D-NAZWA+D-LOG: ikona instalatora NeoEE (tylko nazwa i dziennik instalatora)")
        elif "_neoeeresource.cfg" in pl:
            ustaw("neoee", "wysoka", "D-STR: zasób lobby NeoEE (nazwa używana przez instalator: '/shared/Data/WONLobby Resources/_NeoEEResource.cfg')")
        # --- dreXmod ---
        elif name == "drexmod.dll":
            ustaw("drexmod", "wysoka", "D-STR: OriginalName/PDB '…EEPatchProject2017…dreXmod.pdb', napis 'drexmod.config'")
        elif name == "drexmod.config":
            ustaw("drexmod", "wysoka", "D-STR: nazwa odczytywana przez dreXmod.dll ('drexmod.config')")
        elif "/data/dxm/" in pl:
            pew = "wysoka" if ("/dxm/mods/dxm/" in pl or "/drexmod.com/" in pl) else "srednia"
            ustaw("drexmod", pew, "D-DIR: katalog Data/dxm (drexmod.com, mods/dxm – CREDITS wymienia dreXmod); komponent instalatora 'additional\\drexmod\\v3'",
                  uw="motywy yukon/energycube to dodatki do dreXmoda (CREDITS: autorzy społeczności)" if pew == "srednia" else "")
        elif "_drexmod" in pl:
            ustaw("drexmod", "srednia", "D-NAZWA: plik konfiguracyjny lobby dreXmoda")
        # --- lokalizacja ---
        elif "/data/languages/" in pl:
            ustaw("localization", "wysoka", "D-REG: komponenty instalatora 'language\\pl', 'language\\update'; katalog Languages/<kod> nieobecny w GOG",
                  uw="pakiety językowe lobby (WONLobby.cfg, _NeoEEResource.cfg) – dotyczą także NeoEE")
        elif name == "language.dll":
            ustaw("localization", "wysoka", "D-STR: zasoby zawierają polskie napisy (np. 'Czarna Peleryna', 'Dom (e. nano)')",
                  uw="angielska wersja vanilla/AoC NIEOBECNA w instalacji")
        elif pl.startswith((EE + "data/campaigns/", AOC + "data/campaigns/")) and pl.endswith(".ssa"):
            plw = polskie_wpisy(root, p)
            if plw and not zgodny_gog:
                ustaw("localization", "wysoka", f"D-SSA: {len(plw)} wpisów archiwum z polskimi znakami (np. '{plw[0]}'); rozmiar ≠ GOG",
                      uw="kampania zlokalizowana (polskie scenariusze/dźwięki) – oryginał EN niedostępny")
            elif zgodny_gog and not plw:
                ustaw("vanilla" if pl.startswith(EE) else "aoc", "srednia",
                      "D-MTIME: oryginalna data 2002 zachowana (dowód pomocniczy)" if f["mtime"].startswith("2002") else "D-GOG")
            else:
                ustaw("nieustalone", "srednia", f"D-SSA: polskie wpisy: {len(plw)}; zgodność rozmiaru z GOG: {zgodny_gog}")
        elif pl == (AOC + "data/data.ssa"):
            ustaw("localization", "srednia", "D-SSA: polskie nazwy plików cywilizacji w archiwum (civilizations\\anglia.civ, babilon.civ)",
                  "D-GOG: rozmiar zaokrąglony zgodny (46MB) – zgodność rozmiaru NIE wyklucza lokalizacji",
                  uw="archiwum AoC w wersji polskiej; zawiera zasoby AoC – w OpenEE warstwa 'aoc' musi korzystać z niego do czasu pozyskania wersji EN")
        elif pl == (EE + "data/data.ssa"):
            ustaw("nieustalone", "wysoka", "D-GOG: rozmiar 171,3 MB ≠ 163 MB w GOG – archiwum zmienione",
                  "D-SSA: archiwum spójne, posortowane, bez śladów dopisywania; zawiera pliki deweloperskie (vssver.scc, converteroutput.log)",
                  uw="bazowe dane EE; nie da się wskazać, które wpisy zmieniono i przez kogo (brak sum referencyjnych)")
        # --- luźne nadpisania zasobów archiwum ---
        elif pl.startswith(EE + "data/textures/") or pl.startswith(AOC + "data/textures/"):
            ustaw("nieustalone", "wysoka", "D-OVR: luźny plik nadpisuje wpis data.ssa o tej samej nazwie (treść różna); katalog Textures nieobecny w GOG",
                  uw="hipoteza: komponent instalatora 'additional\\hd\\terrain/buildings/tech/effects' (tekstury 32 bpp) – brak manifestu komponentów")
        elif pl.startswith(EE + "data/sounds/"):
            ustaw("nieustalone", "wysoka", "D-OVR: nadpisuje wpis sounds/*.mp3 z data.ssa (inna treść); katalog Sounds nieobecny w GOG",
                  uw="hipoteza: komponent 'additional\\hd\\music'")
        elif "/data/db/" in pl:
            ustaw("nieustalone", "wysoka", "D-OVR: nadpisuje db/*.dat z data.ssa (inna treść); katalog db nieobecny w GOG",
                  uw="daty 2011–2016 (pomocniczo) – prawdopodobnie poprawki społeczności/NeoEE; brak dowodu przypisania")
        elif name == "dx7hrgame.dll":
            ustaw("nieustalone", "wysoka", "D-PE: zasób wersji 'UCyborg – Direct3D 7 resolution limit remover' (d3dim700.dll); nieobecny w GOG",
                  uw="poprawka zewnętrzna dołączona przez instalator społeczności – nie NeoEE i nie dreXmod")
        elif "/wonlobby resources/" in pl:
            rel = p.split("WONLobby Resources/", 1)[1]
            if rel in GOG_WONLOBBY:
                ustaw("vanilla" if pl.startswith(EE) else "aoc", "niska",
                      "D-GOG: nazwa obecna w referencyjnej liście WONLobby (bez porównania rozmiaru/sumy)")
            else:
                ustaw("nieustalone", "srednia", "D-GOG: plik spoza referencyjnej listy WONLobby GOG")
        elif "/random map scripts/" in pl:
            ustaw("vanilla" if pl.startswith(EE) else "aoc", "niska" if gref is None else ("srednia" if zgodny_gog else "niska"),
                  "D-GOG: struktura katalogów RMS zgodna z GOG (pliki per rozmiar bez rozmiarów w referencji)" if gref is None else "")
        elif "/users/default/civilizations/" in pl:
            ustaw("nieustalone", "niska", "D-LOG: zainstalowane przez instalator społeczności; brak w GOG",
                  uw="hipoteza: komponent instalatora 'additional\\civs\\ec' / 'ec_full' (cywilizacje społeczności)")
        elif "/manual/" in pl and pl.endswith(".pdf"):
            odp = {"ee manual.pdf": "manual.pdf", "ee scenario editor manual.pdf": "scenario_editor_manual.pdf",
                   "ee technology tree.pdf": "technology_tree.pdf", "aoc manual.pdf": "manual_aoc.pdf",
                   "aoc technology tree.pdf": "technology_tree_aoc.pdf"}.get(name)
            if odp and fmt_gog(n) == gog.get(odp):
                ustaw("vanilla" if pl.startswith(EE) else "aoc", "niska",
                      f"D-GOG: rozmiar zgodny z GOG '{odp}' ({gog[odp]}) przy innej nazwie/lokalizacji")
            else:
                ustaw("nieustalone", "niska", "brak odpowiednika w referencji GOG")
        elif gref is not None:
            if zgodny_gog:
                ustaw("vanilla" if pl.startswith(EE) else ("aoc" if pl.startswith(AOC) else "vanilla"), "srednia",
                      "D-GOG: nazwa i zaokrąglony rozmiar zgodne z GOG (brak sumy – zgodność nie jest dowodem identyczności)")
            else:
                ustaw("nieustalone", "srednia", "D-GOG: plik GOG o innym rozmiarze – zmodyfikowany przez nieustaloną warstwę")
        else:
            ustaw("nieustalone", "niska", "brak dowodu przynależności (plik spoza referencji GOG, bez sygnatur moda)")
        wyn.append(e)

    # brakujące względem GOG
    lok = {f["sciezka"].lower() for f in I}
    brak = sorted(k for k in gog if k not in lok)

    os.makedirs(outdir, exist_ok=True)
    pods = collections.Counter((e["warstwa"], e["pewnosc"]) for e in wyn)
    rozm = collections.Counter()
    for e in wyn:
        rozm[e["warstwa"]] += e["rozmiar"]
    json.dump({"opis": "Manifest zasobów instalacji EE – klasyfikacja warstw OpenEE (etap 1)",
               "referencja_gog": os.path.basename(gogp), "liczba_plikow": len(wyn),
               "podsumowanie": {f"{k[0]}|{k[1]}": v for k, v in sorted(pods.items())},
               "bajty_na_warstwe": dict(rozm),
               "brak_wzgledem_gog": brak, "pliki": wyn},
              open(os.path.join(outdir, "manifest_zasobow.json"), "w"), ensure_ascii=False, indent=1)
    with open(os.path.join(outdir, "manifest_zasobow.csv"), "w", newline="") as fcsv:
        w = csv.writer(fcsv, delimiter=";")
        w.writerow(["sciezka", "warstwa", "pewnosc", "rozmiar", "sha256", "z_instalatora", "dowody", "uwagi"])
        for e in wyn:
            w.writerow([e["sciezka"], e["warstwa"], e["pewnosc"], e["rozmiar"], e["sha256"], e["z_instalatora"],
                        " | ".join(e["dowody"]), e["uwagi"]])
    for k, v in sorted(pods.items(), key=lambda x: (str(x[0][0]), str(x[0][1]))):
        print(f"{k[0]:18s} {k[1]:8s} {v:5d}")
    print("bajty:", {k: round(v / 1e6, 1) for k, v in rozm.items()})
    print("brak względem GOG:", len(brak), brak[:40])


if __name__ == "__main__":
    main()
