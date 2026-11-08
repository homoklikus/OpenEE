// Minimalny parser JSON tylko dla testów OpenEE Core (liczby przez strtod – dokładne odtworzenie double).
#pragma once

#include <cstdlib>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace json_mini {

struct Wartosc {
    enum class Typ { null, logiczna, liczba, tekst, tablica, obiekt } typ = Typ::null;
    bool b = false;
    double n = 0;
    std::string s;
    std::vector<Wartosc> t;
    std::vector<std::pair<std::string, Wartosc>> o;

    const Wartosc& operator[](const std::string& k) const {
        for (const auto& [kk, v] : o)
            if (kk == k) return v;
        throw std::runtime_error("JSON: brak klucza " + k);
    }
    const Wartosc* znajdz(const std::string& k) const {
        for (const auto& [kk, v] : o)
            if (kk == k) return &v;
        return nullptr;
    }
    const Wartosc& operator[](std::size_t i) const { return t.at(i); }
    bool null() const { return typ == Typ::null; }
};

class Parser {
public:
    explicit Parser(const std::string& s) : s_(s) {}
    Wartosc parsuj() {
        Wartosc w = wartosc();
        bialy();
        if (i_ != s_.size()) throw std::runtime_error("JSON: nadmiarowe dane");
        return w;
    }

private:
    void bialy() {
        while (i_ < s_.size() && (s_[i_] == ' ' || s_[i_] == '\n' || s_[i_] == '\r' || s_[i_] == '\t')) ++i_;
    }
    Wartosc wartosc() {
        bialy();
        if (i_ >= s_.size()) throw std::runtime_error("JSON: koniec danych");
        const char c = s_[i_];
        Wartosc w;
        if (c == '{') {
            w.typ = Wartosc::Typ::obiekt;
            ++i_;
            bialy();
            if (s_[i_] == '}') { ++i_; return w; }
            for (;;) {
                bialy();
                std::string k = tekst();
                bialy();
                if (s_[i_++] != ':') throw std::runtime_error("JSON: oczekiwano ':'");
                w.o.emplace_back(std::move(k), wartosc());
                bialy();
                const char z = s_[i_++];
                if (z == '}') break;
                if (z != ',') throw std::runtime_error("JSON: oczekiwano ','");
            }
        } else if (c == '[') {
            w.typ = Wartosc::Typ::tablica;
            ++i_;
            bialy();
            if (s_[i_] == ']') { ++i_; return w; }
            for (;;) {
                w.t.push_back(wartosc());
                bialy();
                const char z = s_[i_++];
                if (z == ']') break;
                if (z != ',') throw std::runtime_error("JSON: oczekiwano ','");
            }
        } else if (c == '"') {
            w.typ = Wartosc::Typ::tekst;
            w.s = tekst();
        } else if (s_.compare(i_, 4, "true") == 0) {
            w.typ = Wartosc::Typ::logiczna; w.b = true; i_ += 4;
        } else if (s_.compare(i_, 5, "false") == 0) {
            w.typ = Wartosc::Typ::logiczna; i_ += 5;
        } else if (s_.compare(i_, 4, "null") == 0) {
            i_ += 4;
        } else {
            w.typ = Wartosc::Typ::liczba;
            const char* p = s_.c_str() + i_;
            char* e = nullptr;
            w.n = std::strtod(p, &e);
            if (e == p) throw std::runtime_error("JSON: zła liczba");
            i_ += std::size_t(e - p);
        }
        return w;
    }
    std::string tekst() {
        if (s_[i_] != '"') throw std::runtime_error("JSON: oczekiwano tekstu");
        ++i_;
        std::string r;
        while (i_ < s_.size() && s_[i_] != '"') {
            if (s_[i_] == '\\') {
                ++i_;
                const char e = s_[i_];
                if (e == 'u') {  // tylko BMP, kodowanie UTF-8
                    const unsigned cp = unsigned(std::strtoul(s_.substr(i_ + 1, 4).c_str(), nullptr, 16));
                    i_ += 4;
                    if (cp < 0x80) r += char(cp);
                    else if (cp < 0x800) { r += char(0xC0 | (cp >> 6)); r += char(0x80 | (cp & 0x3F)); }
                    else { r += char(0xE0 | (cp >> 12)); r += char(0x80 | ((cp >> 6) & 0x3F)); r += char(0x80 | (cp & 0x3F)); }
                } else {
                    r += (e == 'n') ? '\n' : (e == 't') ? '\t' : e;
                }
                ++i_;
            } else {
                r += s_[i_++];
            }
        }
        ++i_;
        return r;
    }
    const std::string& s_;
    std::size_t i_ = 0;
};

}  // namespace json_mini
