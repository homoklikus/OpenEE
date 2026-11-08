// OpenEE – klasa OpenEESymulacja: most GDScript ↔ OpenEE Core (etap 28).
// Bez logiki ruchu: tylko konwersja danych i wywołania Core. Stan świata należy do Core (std::unique_ptr),
// GDScript nie dostaje wskaźników – tylko identyfikatory jednostek i migawki.
#pragma once

#include <memory>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include "openee/symulacja.hpp"

class OpenEESymulacja : public godot::RefCounted {
    GDCLASS(OpenEESymulacja, godot::RefCounted)

public:
    OpenEESymulacja() = default;
    ~OpenEESymulacja() override = default;

    godot::String wersja() const;
    godot::Dictionary zaladuj_tablice(const godot::String& sciezka_dll);
    void uzyj_tablic_przyblizonych();
    bool utworz_swiat(const godot::String& wariant);
    int64_t dodaj_jednostke(const godot::Dictionary& parametry, double x, double y, double kurs);
    bool nadaj_trase(int64_t id, const godot::PackedFloat64Array& punkty_xy, const godot::Variant& kurs_koncowy,
                     const godot::String& start);
    int64_t takt(int64_t ile);
    godot::PackedFloat64Array migawka() const;
    godot::PackedStringArray pola_migawki() const;
    godot::Dictionary jednostka(int64_t id) const;
    godot::Dictionary diagnostyka() const;

protected:
    static void _bind_methods();

private:
    std::shared_ptr<const openee::TabliceTrig> tablice_;
    std::unique_ptr<openee::Swiat> swiat_;
    godot::String ostatni_blad_;
};
