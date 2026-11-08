#include "openee/generator.hpp"

namespace openee {

std::int64_t GeneratorTitan::odleglosc(std::uint32_t a, std::uint32_t b, std::int64_t maks) {
    std::uint32_t s = a & 0x7FFFFFFFu;
    for (std::int64_t n = 0; n <= maks; ++n) {
        if (s == (b & 0x7FFFFFFFu)) return n;
        s = (214013u * s + 2531011u) & 0x7FFFFFFFu;
    }
    return -1;
}

}  // namespace openee
