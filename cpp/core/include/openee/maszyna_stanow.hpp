// OpenEE Core – skrypty stanów `.tai` i maszyna stanów jednostki (etap 28).
// docs/titan/skrypty_stanow.md § 2–4. Parser obsługuje podzbiór składni: stany, przejścia z jednym zdarzeniem,
// allof/anyof, true()/false(), remove(), #include, komentarze „/”. To NIE jest pełna implementacja języka
// (brak parametrów zdarzeń i innych konstrukcji – parser zgłasza je jako błąd).
#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace openee {

struct Przejscie {
    enum class Typ { pojedyncze, allof, anyof };
    Typ typ = Typ::pojedyncze;
    std::vector<std::string> zdarzenia;
    std::string cel_prawda;  // pusty = brak
    std::string cel_falsz;
};

struct StanSkryptu {
    std::string nazwa;
    int numer = 0;  // numer stanu Titan (0 = nazwa nierozpoznana [H])
    std::vector<Przejscie> przejscia;
};

/// Numer stanu z nazwy (tablica nazw EXE 0x618E11 – podzbiór ustalony w etapach 25–27).
int numer_stanu(const std::string& nazwa);
const char* nazwa_stanu(int numer);

class SkryptStanow {
public:
    using Dolaczanie = std::function<std::optional<std::string>(const std::string& nazwa_pliku)>;

    /// Parsuje tekst skryptu. Zwraca false i opis błędu przy nieobsługiwanej konstrukcji.
    bool parsuj(const std::string& tekst, const Dolaczanie& dolacz, std::string& blad);

    /// Skrypt ruchu jednostki lądowej odtworzony z tabeli docs/titan/skrypty_stanow.md § 4 (land.tai bez wrogów).
    static SkryptStanow wbudowany_land();

    const StanSkryptu* stan(int numer) const;
    const std::map<std::string, StanSkryptu>& stany() const { return stany_; }

private:
    bool parsuj_rek(const std::string& tekst, const Dolaczanie& dolacz, std::string& blad, int glebokosc);
    void dodaj_przejscie(StanSkryptu& s, Przejscie p, bool usun);
    std::map<std::string, StanSkryptu> stany_;
};

}  // namespace openee
