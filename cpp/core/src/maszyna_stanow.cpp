#include "openee/maszyna_stanow.hpp"

#include <cctype>

namespace openee {

namespace {
struct NazwaNumer { const char* n; int k; };
// Numery z etapów 25–27 (pomiar stanu +0x1E8 i tablica nazw). Pozostałe nazwy → 0 [H].
const NazwaNumer NAZWY[] = {
    {"Idle", 5000},
    {"ReacquireGoal", 5001},
    {"PrepareToMove", 8000},
    {"GetNextAutoWaypoint", 8021},
    {"LookForEnemies", 2015},
    {"ShouldIReturnToInitialContactLocation", 2025},
    {"GetNextMoveWaypoint", 9000},
    {"RepathAroundObstacle", 9002},
    {"TurnToUnitFacing", 9006},
    {"Advance", 10003},
    {"Dying", 6000},
    {"UnitRotting", 6002},
    {"Dead", 6003},
    // etap 31: stany walki (tablica rejestracji EE 0x618E11, numery identyczne w AoC [P: kod obu binarek])
    {"AttackEnemyUnit", 2001},
    {"FaceEnemyUnit", 2012},
    {"CheckRange", 2013},
    {"InitialAttackState", 2016},
    {"UnderAttack", 2018},
    {"RunFromAttacker", 2019},
    {"RetaliateAgainstAttacker", 2020},
    {"WaitForReload", 2021},
    {"ShouldIFollowEnemyUnit", 2024},
    {"ReturnToInitialContactLocation", 2026},
    {"ChangeTargetForSpecialEnemy", 2031},
    {"ReacquireEnemyUnit", 5002},
    {"ResourcesRotting", 6001},
    // etap 44/45: rejestracja nazw 0x618E11 (push numer, push nazwa) [W]
    {"FleeDanger", 8019},
    {"MoveToRepairSite", 8018},
    // etap 46: Healer.tai (rejestracja 0x6194D3/0x619914/0x6195A8) [W]
    {"LookForHealee", 16000},
    {"HealUnit", 16001},
    {"TurnToFaceHealee", 16002},
};
}  // namespace

int numer_stanu(const std::string& nazwa) {
    for (const auto& x : NAZWY)
        if (nazwa == x.n) return x.k;
    return 0;
}

const char* nazwa_stanu(int numer) {
    for (const auto& x : NAZWY)
        if (numer == x.k) return x.n;
    return "?";
}

namespace {
struct Lekser {
    const std::string& t;
    std::size_t i = 0;
    explicit Lekser(const std::string& s) : t(s) {}
    void pomin() {
        for (;;) {
            while (i < t.size() && std::isspace(static_cast<unsigned char>(t[i]))) ++i;
            if (i < t.size() && t[i] == '/') {  // komentarz: jeden ukośnik wystarcza
                while (i < t.size() && t[i] != '\n') ++i;
                continue;
            }
            break;
        }
    }
    // token: identyfikator, "#include", "\"...\"" albo pojedynczy znak
    std::string nastepny() {
        pomin();
        if (i >= t.size()) return {};
        const char c = t[i];
        if (std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '#') {
            const std::size_t p = i++;
            while (i < t.size() && (std::isalnum(static_cast<unsigned char>(t[i])) || t[i] == '_')) ++i;
            return t.substr(p, i - p);
        }
        if (c == '"') {
            const std::size_t p = ++i;
            while (i < t.size() && t[i] != '"') ++i;
            std::string s = t.substr(p, i - p);
            if (i < t.size()) ++i;
            return "\"" + s;
        }
        ++i;
        return std::string(1, c);
    }
    std::string podglad() {
        const std::size_t z = i;
        std::string s = nastepny();
        i = z;
        return s;
    }
};
}  // namespace

void SkryptStanow::dodaj_przejscie(StanSkryptu& s, Przejscie p, bool usun) {
    // 0x618ED9: przejście z jednym zdarzeniem zastępuje w miejscu wcześniejsze z tym samym zdarzeniem (albo je usuwa)
    if (p.typ == Przejscie::Typ::pojedyncze) {
        for (auto it = s.przejscia.begin(); it != s.przejscia.end(); ++it) {
            if (it->typ == Przejscie::Typ::pojedyncze && it->zdarzenia == p.zdarzenia) {
                if (usun) s.przejscia.erase(it);
                else *it = std::move(p);
                return;
            }
        }
    }
    if (!usun) s.przejscia.push_back(std::move(p));
}

bool SkryptStanow::parsuj(const std::string& tekst, const Dolaczanie& dolacz, std::string& blad) {
    const bool ok = parsuj_rek(tekst, dolacz, blad, 0);
    if (ok && !stany_.count("Idle")) stany_["Idle"] = StanSkryptu{"Idle", 5000, {}};  // Idle zawsze istnieje [W]
    return ok;
}

bool SkryptStanow::parsuj_rek(const std::string& tekst, const Dolaczanie& dolacz, std::string& blad, int gl) {
    if (gl > 16) {
        blad = "#include: zbyt głęboka rekurencja";
        return false;
    }
    Lekser L(tekst);
    for (;;) {
        std::string tok = L.nastepny();
        if (tok.empty()) return true;
        if (tok == "#include") {
            if (L.nastepny() != "(") { blad = "#include: oczekiwano '('"; return false; }
            std::string plik = L.nastepny();
            if (plik.empty() || plik[0] != '"') { blad = "#include: oczekiwano nazwy w cudzysłowie"; return false; }
            plik = plik.substr(1);
            if (L.nastepny() != ")") { blad = "#include: oczekiwano ')'"; return false; }
            auto t = dolacz ? dolacz(plik) : std::nullopt;
            if (!t) { blad = "#include: nie znaleziono pliku " + plik; return false; }
            if (!parsuj_rek(*t, dolacz, blad, gl + 1)) return false;
            continue;
        }
        if (!(std::isalpha(static_cast<unsigned char>(tok[0])) || tok[0] == '_')) {
            blad = "oczekiwano nazwy stanu, jest '" + tok + "'";
            return false;
        }
        StanSkryptu& s = stany_[tok];
        s.nazwa = tok;
        s.numer = numer_stanu(tok);
        if (L.nastepny() != "{") { blad = "stan " + tok + ": oczekiwano '{'"; return false; }
        for (;;) {
            std::string z = L.nastepny();
            if (z == "}") break;
            if (z.empty()) { blad = "stan " + tok + ": brak '}'"; return false; }
            Przejscie p;
            if (z == "allof" || z == "anyof") {
                p.typ = z == "allof" ? Przejscie::Typ::allof : Przejscie::Typ::anyof;
                if (L.nastepny() != "(") { blad = z + ": oczekiwano '('"; return false; }
                for (;;) {
                    std::string e = L.nastepny();
                    if (e.empty() || !(std::isalnum(static_cast<unsigned char>(e[0])))) {
                        blad = z + ": oczekiwano nazwy zdarzenia";
                        return false;
                    }
                    p.zdarzenia.push_back(e);
                    std::string sep = L.nastepny();
                    if (sep == ")") break;
                    if (sep != ",") { blad = z + ": oczekiwano ',' albo ')'"; return false; }
                }
            } else if (std::isalpha(static_cast<unsigned char>(z[0]))) {
                p.zdarzenia.push_back(z);
                if (L.podglad() == "(") {
                    blad = "zdarzenie z parametrami (" + z + "(...)) – nieobsługiwane w etapie 28";
                    return false;
                }
            } else {
                blad = "nieoczekiwany znak '" + z + "' w stanie " + tok;
                return false;
            }
            bool usun = false;
            for (;;) {
                const std::string k = L.podglad();
                if (k != "true" && k != "false" && k != "remove") break;
                L.nastepny();
                if (L.nastepny() != "(") { blad = k + ": oczekiwano '('"; return false; }
                if (k == "remove") {
                    usun = true;
                } else {
                    std::string cel = L.nastepny();
                    if (cel.empty() || !std::isalpha(static_cast<unsigned char>(cel[0]))) {
                        blad = k + ": oczekiwano nazwy stanu";
                        return false;
                    }
                    (k == "true" ? p.cel_prawda : p.cel_falsz) = cel;
                    if (!stany_.count(cel)) stany_[cel] = StanSkryptu{cel, numer_stanu(cel), {}};
                }
                if (L.nastepny() != ")") { blad = k + ": oczekiwano ')'"; return false; }
            }
            if (usun && p.typ != Przejscie::Typ::pojedyncze) { blad = "remove() tylko dla jednego zdarzenia"; return false; }
            dodaj_przejscie(stany_[tok], std::move(p), usun);
        }
    }
}

const StanSkryptu* SkryptStanow::stan(int numer) const {
    for (const auto& [n, s] : stany_)
        if (s.numer == numer && numer != 0) return &s;
    return nullptr;
}

namespace {
const char* tekst_land() {
    // Odtworzone z tabeli docs/titan/skrypty_stanow.md § 4 (połączony land.tai: najpierw przejścia z części ataku,
    // potem ruchu). Własny zapis, nie kopia pliku gry. Etap 31: stany walki wręcz z Generic Attack (kolejność przejść
    // jak w połączonym skrypcie [P: przebiegi 564]) i stany śmierci; transport, eksploracja, FaceLocation – tylko nazwy.
    return R"TAI(
Idle { CanISeeEnemy true(CheckRange) }
PrepareToMove {
  allof(GoalIsLoadContainer,ContainerInRange) true(WaitForTransport)
  NoMoreWaypoints true(TurnToUnitFacing)
  MovePreparationComplete true(LookForEnemies)
}
LookForEnemies {
  allof(CanITargetEnemies,GoalIsPatrol,EnemyUnitSpotted) true(CheckRange)
  allof(GoalIsLocation,AttackMoveEnabled,EnemyUnitSpotted) true(CheckRange)
  allof(CanITargetEnemies,GoalIsNotPlayerInitiated,GoalIsNotAttack,EnemyUnitSpotted) true(CheckRange) false(Advance)
}
Advance {
  ArrivedAtMoveWaypoint true(GetNextMoveWaypoint)
  ObstacleDetected true(RepathAroundObstacle)
  allof(OneWaypointRemaining,GoalIsUnit) true(ReacquireEnemyUnit)
}
GetNextMoveWaypoint {
  anyof(EnemyUnitDestroyed,CeaseFire) true(ShouldIReturnToInitialContactLocation)
  allof(GoalIsAttackLocation,LocationInWeaponRange) true(FaceLocation)
  allof(AttackerIsRangedUnit,UnitInWeaponRange) true(FaceEnemyUnit)
  EnemyUnitMoved true(CheckRange)
  allof(GoalIsLoadContainer,NextWaypointRetrieved) true(GetContainerProgress)
  ShouldMoveToNextAutoWaypoint true(GetNextAutoWaypoint)
  NextWaypointRetrieved true(LookForEnemies) false(TurnToUnitFacing)
}
RepathAroundObstacle { MovePreparationComplete true(Advance) false(ShouldIReturnToInitialContactLocation) }
GetNextAutoWaypoint { UnitHasGoal true(PrepareToMove) false(ShouldIReturnToInitialContactLocation) }
TurnToUnitFacing {
  GoalIsLoadContainer true(GetContainerProgress)
  anyof(UnitFacingNotRequired,CompletedUnitFacing) true(ReacquireGoal)
  UnitHasGoal false(ReacquireGoal)
}
ReacquireGoal {
  BlockedByWall true(ShouldIReturnToInitialContactLocation)
  GoalIsUnit true(ReacquireEnemyUnit)
  GoalIsAttackLocation true(FaceLocation)
  GoalIsLocation true(Idle)
  GoalIsExplore true(FindUnexploredArea)
  GoalIsLoadContainer true(ReacquireLoadContainer)
  UnitHasGoal false(ShouldIReturnToInitialContactLocation)
}
ShouldIReturnToInitialContactLocation {
  allof(HasValidInitialContactLocation,ReturnsToInitialContactLocation,GoalIsNotPlayerInitiated) true(ReturnToInitialContactLocation) false(Idle)
}
CheckRange {
  anyof(EnemyUnitDestroyed,CeaseFire,UnitNotOnMap,EnemyWithinMinimumRange) true(ShouldIReturnToInitialContactLocation)
  allof(EnemyUnitNoLongerVisible,GoalIsNotPlayerInitiated) true(ShouldIReturnToInitialContactLocation)
  UnitInWeaponRange true(FaceEnemyUnit)
  anyof(CanIMoveFreely,GoalIsPlayerInitiated) true(ShouldIFollowEnemyUnit) false(ShouldIReturnToInitialContactLocation)
}
ShouldIFollowEnemyUnit {
  allof(OneWaypointRemaining,GoalIsUnit,EnemyUnitHasNotMovedOneTile) true(Advance)
  anyof(CanIPursuePastInitialContactLOS,EnemyInsideInitialContactLOS,GoalIsPlayerInitiated) true(PrepareToMove) false(ShouldIReturnToInitialContactLocation)
}
FaceEnemyUnit {
  ShouldIRun true(RunFromAttacker)
  anyof(EnemyUnitDestroyed,CeaseFire,UnitNotOnMap,EnemyWithinMinimumRange) true(ShouldIReturnToInitialContactLocation)
  allof(EnemyUnitNoLongerVisible,GoalIsNotPlayerInitiated) true(ShouldIReturnToInitialContactLocation)
  UnitInWeaponRange false(CheckRange)
  allof(TargetIsSpecialEnemy,Reloaded,EnemyUnitInsideFiringArch) true(ChangeTargetForSpecialEnemy)
  allof(Reloaded,EnemyUnitInsideFiringArch) true(AttackEnemyUnit)
  FacingEnemyUnit true(WaitForReload)
}
ChangeTargetForSpecialEnemy { AlwaysTrue true(ReacquireGoal) }
AttackEnemyUnit {
  ShouldIRun true(RunFromAttacker)
  ShouldIRetaliate true(RetaliateAgainstAttacker)
  EnemyUnitInsideFiringArch false(FaceEnemyUnit)
  AlwaysTrue true(WaitForReload)
}
WaitForReload {
  ShouldIRun true(RunFromAttacker)
  ShouldIRetaliate true(RetaliateAgainstAttacker)
  allof(GoalIsAttackLocation,Reloaded) true(FaceLocation)
  Reloaded true(FaceEnemyUnit)
  anyof(EnemyUnitDestroyed,CeaseFire,UnitNotOnMap,EnemyWithinMinimumRange) true(ShouldIReturnToInitialContactLocation)
  allof(EnemyUnitNoLongerVisible,GoalIsNotPlayerInitiated) true(ShouldIReturnToInitialContactLocation)
}
InitialAttackState {
  GoalIsUnit true(FaceEnemyUnit)
  GoalIsAttackLocation true(FaceLocation)
}
ReacquireEnemyUnit { EnemyUnitReachable true(CheckRange) false(ShouldIReturnToInitialContactLocation) }
RetaliateAgainstAttacker { GoalIsUnit true(CheckRange) false(PrepareToMove) }
RunFromAttacker { AlwaysTrue true(PrepareToMove) }
UnderAttack {
  CanFlee true(RunFromAttacker)
  allof(CanITargetEnemies,UnitIdleOrAttackingDefenselessBuilding,IsAttackerInRetaliationRange,CanDamageAttacker,AttackerIsReachable) true(RetaliateAgainstAttacker) false(ReacquireGoal)
}
ReturnToInitialContactLocation { AlwaysTrue true(PrepareToMove) }
Dying { DyingAnimationFinished true(ResourcesRotting) }
ResourcesRotting { ResourcesRottedAway true(UnitRotting) }
UnitRotting { UnitRottedAway true(Dead) }
)TAI";
}

// Etap 46 – Healer.tai [W: plik skryptu; zdarzenia 18000–18006, stany 16000–16002]. Własny zapis. W skrypcie
// „Military Healer Prophet” Healer.tai jest dołączany PRZED Military Prophet.tai (Generic Attack/Movement/Death),
// więc jego przejścia stoją w każdym stanie przed przejściami ruchu i walki.
const char* tekst_healer() {
    return R"TAI(
Idle { HealSearchTimeElapsed true(LookForHealee) }
LookForEnemies { AttackMoveEnabled true(LookForHealee) }
LookForHealee {
  GoalIsHeal true(TurnToFaceHealee)
  GoalIsLocation true(Advance) false(ShouldIReturnToInitialContactLocation)
}
TurnToFaceHealee {
  anyof(HealeeDestroyed,UnitNotOnMap,HealeeNoLongerVisible) true(ShouldIReturnToInitialContactLocation)
  HealeeInHealingRange false(PrepareToMove)
  FacingHealee true(HealUnit)
}
HealUnit {
  TargetNeedsHealing false(ShouldIReturnToInitialContactLocation)
  anyof(HealeeDestroyed,UnitNotOnMap,HealeeNoLongerVisible) true(ShouldIReturnToInitialContactLocation)
  HealeeInHealingRange false(PrepareToMove)
}
GetNextMoveWaypoint { HealeeInHealingRange true(TurnToFaceHealee) }
ReacquireGoal { GoalIsHeal true(TurnToFaceHealee) }
)TAI";
}

// Etap 48 – Prophet.tai [W: plik skryptu; P: 648 – prorok 0x1000858 przechodzi GetNextMoveWaypoint (9000) → Advance
// (10003) bez LookForEnemies (2015), gwardia (Land Patrolling) z 2015]. Własny zapis w kolejności dołączeń:
// część proroka (bez Generic Attack – Idle reaguje tylko na AmIUnderAttack), Generic Movement, nadpisanie
// GetNextMoveWaypoint/Advance (0x618ED9: przejście z tym samym pojedynczym zdarzeniem zastępowane w miejscu), Generic
// Death, na końcu ReacquireGoal { AlwaysTrue true(Idle) }. Klątwy (calamity) – w Core brak celu klątwy (fałsz).
const char* tekst_prorok() {
    return R"TAI(
Idle { AmIUnderAttack true(UnderAttack) }
UnderAttack {
  CanFlee true(RunFromAttacker)
  AlwaysTrue true(ReacquireGoal)
}
RunFromAttacker { AlwaysTrue true(PrepareToMove) }
FaceEnemyUnit {
  EnemyUnitDestroyed true(Idle)
  allof(GoalIsCalamity,FacingEnemyUnit) true(CalamityPreCast)
}
CalamityPreCast { CalamityTargetStillValid true(CastCalamity) false(Idle) }
PrepareToCastCalamity { AlwaysTrue true(CastCalamity) }
ReacquireGoal {
  EnemyUnitDestroyed true(Idle)
  allof(GoalIsCalamity,UnitInWeaponRange) true(CalamityPreCast)
  GoalIsCalamity true(PrepareToMove)
}
CastCalamity {
  allof(OwnerIsHuman,OneAndAHalfSecondsElapsed) true(Idle)
  allof(OwnerIsComputer,OneAndAHalfSecondsElapsed) true(PostCalamityFlee)
}
PrepareToMove { allof(GoalIsCalamity,UnitInWeaponRange) true(FaceEnemyUnit) }
GetNextMoveWaypoint {
  EnemyUnitDestroyed true(Idle)
  allof(GoalIsCalamity,NextWaypointRetrieved,UnitInWeaponRange) true(FaceEnemyUnit)
}
PostCalamityFlee { AlwaysTrue true(Idle) }
PrepareToMove {
  allof(GoalIsLoadContainer,ContainerInRange) true(WaitForTransport)
  NoMoreWaypoints true(TurnToUnitFacing)
  MovePreparationComplete true(LookForEnemies)
}
Advance {
  ArrivedAtMoveWaypoint true(GetNextMoveWaypoint)
  ObstacleDetected true(RepathAroundObstacle)
  allof(OneWaypointRemaining,GoalIsUnit) true(ReacquireEnemyUnit)
}
RepathAroundObstacle { MovePreparationComplete true(Advance) false(ShouldIReturnToInitialContactLocation) }
GetNextAutoWaypoint { UnitHasGoal true(PrepareToMove) false(ShouldIReturnToInitialContactLocation) }
GetNextMoveWaypoint {
  allof(GoalIsLoadContainer,NextWaypointRetrieved) true(GetContainerProgress)
  ShouldMoveToNextAutoWaypoint true(GetNextAutoWaypoint)
  NextWaypointRetrieved true(LookForEnemies) false(TurnToUnitFacing)
}
TurnToUnitFacing {
  GoalIsLoadContainer true(GetContainerProgress)
  anyof(UnitFacingNotRequired,CompletedUnitFacing) true(ReacquireGoal)
  UnitHasGoal false(ReacquireGoal)
}
ShouldIReturnToInitialContactLocation {
  allof(HasValidInitialContactLocation,ReturnsToInitialContactLocation,GoalIsNotPlayerInitiated) true(ReturnToInitialContactLocation) false(Idle)
}
ReturnToInitialContactLocation { AlwaysTrue true(PrepareToMove) }
LookForEnemies {
  allof(CanITargetEnemies,GoalIsPatrol,EnemyUnitSpotted) true(CheckRange)
  allof(GoalIsLocation,AttackMoveEnabled,EnemyUnitSpotted) true(CheckRange)
  allof(CanITargetEnemies,GoalIsNotPlayerInitiated,GoalIsNotAttack,EnemyUnitSpotted) true(CheckRange) false(Advance)
}
ReacquireGoal {
  GoalIsLocation true(Idle)
  GoalIsExplore true(FindUnexploredArea)
  GoalIsLoadContainer true(ReacquireLoadContainer)
  UnitHasGoal false(ShouldIReturnToInitialContactLocation)
}
GetNextMoveWaypoint { NextWaypointRetrieved true(Advance) false(TurnToUnitFacing) }
Advance { allof(OneWaypointRemaining,GoalIsUnit) true(TurnToUnitFacing) }
Dying { DyingAnimationFinished true(ResourcesRotting) }
ResourcesRotting { ResourcesRottedAway true(UnitRotting) }
UnitRotting { UnitRottedAway true(Dead) }
ReacquireGoal { AlwaysTrue true(Idle) }
)TAI";
}
}  // namespace

SkryptStanow SkryptStanow::wbudowany_land() {
    SkryptStanow s;
    std::string blad;
    s.parsuj(tekst_land(), nullptr, blad);
    return s;
}

SkryptStanow SkryptStanow::wbudowany_uzdrowiciel() {
    SkryptStanow s;
    std::string blad;
    s.parsuj(std::string(tekst_healer()) + tekst_land(), nullptr, blad);
    return s;
}

SkryptStanow SkryptStanow::wbudowany_prorok() {
    SkryptStanow s;
    std::string blad;
    s.parsuj(tekst_prorok(), nullptr, blad);
    return s;
}

SkryptStanow SkryptStanow::wbudowany_budynek() {
    // Etap 47 [W: simple building.tai = #include("Generic Death.tai")]: Idle bez przejść, Dying → ResourcesRotting →
    // UnitRotting → Dead. Zdarzenie DyingAnimationFinished budynku – EEUCBuilding vt[39] 0x601A4B (z < −2,0).
    const SkryptStanow l = wbudowany_land();
    SkryptStanow s;
    s.stany_["Idle"] = StanSkryptu{"Idle", 5000, {}};
    for (const char* n : {"Dying", "ResourcesRotting", "UnitRotting", "Dead"}) {
        auto it = l.stany_.find(n);
        if (it != l.stany_.end()) s.stany_[n] = it->second;
    }
    return s;
}

SkryptStanow SkryptStanow::wbudowany_obywatel() {
    // Etap 45 [W: citizen.tai – #include Gather.tai (Idle { TakingLightDamage true(FleeDanger) }), własne Idle
    // { BuildingInBuildQueue true(MoveToRepairSite); TakingLightDamage true(FleeDanger) }, potem Generic Attack /
    // Movement / Death jak land]. Własny zapis: skrypt ruchu i walki jak wbudowany_land, Idle w kolejności dołączeń.
    // Budowa i zbieranie surowców – poza Core (zdarzenia nieobsługiwane = fałsz).
    SkryptStanow s = wbudowany_land();
    auto& idle = s.stany_["Idle"];
    std::vector<Przejscie> nowe;
    nowe.push_back({Przejscie::Typ::pojedyncze, {"TakingLightDamage"}, "FleeDanger", ""});
    nowe.push_back({Przejscie::Typ::pojedyncze, {"BuildingInBuildQueue"}, "MoveToRepairSite", ""});
    for (const auto& p : idle.przejscia) nowe.push_back(p);
    idle.przejscia = nowe;
    s.stany_["FleeDanger"] = StanSkryptu{"FleeDanger", 8019, {}};   // stan natywny – akcja wejścia EEUC vt+0x40
    s.stany_["MoveToRepairSite"] = StanSkryptu{"MoveToRepairSite", 8018, {}};
    return s;
}

}  // namespace openee
