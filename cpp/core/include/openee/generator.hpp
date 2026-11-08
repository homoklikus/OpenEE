// OpenEE Core – globalny generator pseudolosowy Titan (URandom, Low-Level Engine.dll EE 0x10002117).
// s = (214013·s + 2531011) mod 2^31, wynik s / 2^31 (docs/titan/kolizje_objazdy.md § 5).
// Jeden obiekt na symulację (RTSPhysics+0x18). Nie tworzyć generatorów per jednostka.
#pragma once

#include <cstdint>

namespace openee {

class GeneratorTitan {
public:
    explicit GeneratorTitan(std::uint32_t ziarno = 1) { ustaw_ziarno(ziarno); }

    void ustaw_ziarno(std::uint32_t s) { stan_ = s & 0x7FFFFFFFu; liczba_losowan_ = 0; }

    /// Jeden krok LCG (32-bitowe przepełnienie, potem mod 2^31). Zwraca nowy stan.
    std::uint32_t krok() {
        stan_ = (214013u * stan_ + 2531011u) & 0x7FFFFFFFu;
        ++liczba_losowan_;
        return stan_;
    }

    /// URandom::Generate: wartość w [0, 1) = stan / 2^31 (dokładnie w double; dzielenie przez potęgę 2).
    double losuj() { return double(krok()) * (1.0 / 2147483648.0); }

    std::uint32_t stan() const { return stan_; }
    std::uint64_t liczba_losowan() const { return liczba_losowan_; }

    /// Diagnostyka: ile kroków dzieli stan a od stanu b (≤ maks), −1 gdy więcej.
    static std::int64_t odleglosc(std::uint32_t a, std::uint32_t b, std::int64_t maks);

private:
    std::uint32_t stan_ = 1;
    std::uint64_t liczba_losowan_ = 0;
};

}  // namespace openee
