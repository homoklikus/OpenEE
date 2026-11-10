// OpenEE – klasa OpenEESymulacja: most GDScript ↔ OpenEE Core (etap 28).
// Bez logiki ruchu: tylko konwersja danych i wywołania Core. Stan świata należy do Core (std::unique_ptr),
// GDScript nie dostaje wskaźników – tylko identyfikatory jednostek i migawki.
#pragma once

#include <memory>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

#include "openee/mapa.hpp"
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
    bool rozkaz_ruchu(int64_t id, double x, double y, const godot::Variant& kurs_koncowy, bool shift);
    void ustaw_przejezdnosc(int64_t ix, int64_t iy, bool przejezdne);
    int64_t takt(int64_t ile);
    godot::PackedFloat64Array migawka() const;
    godot::PackedStringArray pola_migawki() const;
    godot::Dictionary jednostka(int64_t id) const;
    godot::Dictionary diagnostyka() const;
    // etap 30: mapa scenariusza w reprezentacji Titan (interpretacja wyłącznie w Core – MapaTitan::z_scn)
    godot::Dictionary wczytaj_mape_scn(int64_t A, int64_t B, const godot::PackedByteArray& tekstura,
                                       const godot::PackedByteArray& flagi, const godot::PackedFloat32Array& f10,
                                       const godot::PackedFloat32Array& wysokosc, const godot::Dictionary& rodziny);
    bool dodaj_obiekt_mapy(const godot::Dictionary& obiekt);
    int64_t mapa_teren(int64_t x, int64_t y) const;
    int64_t mapa_pewnosc(int64_t x, int64_t y) const;
    bool utworz_swiat_na_mapie(const godot::String& wariant, const godot::PackedByteArray& teren_dozwolony);
    bool pole_przejezdne(int64_t x, int64_t y) const;
    // etap 31: walka w Core – GDScript podaje dane i czyta migawki; decyzje i obrażenia liczy wyłącznie Core
    bool ustaw_walke(int64_t id, int64_t gracz, bool czlowiek, const godot::Dictionary& parametry, int64_t hp);
    bool ustaw_tablice_walki(const godot::Dictionary& tablice, const godot::Array& wagi);
    bool rozkaz_ataku(int64_t id, int64_t cel);
    double kat_rozkazu(const godot::Array& ids, double x, double y) const;
    void ustaw_modyfikator_wysokosci(bool wlaczony);
    int64_t ustaw_graf_podsektorow(const godot::Dictionary& d);
    godot::Array sciezka_grafu(int64_t x0, int64_t y0, int64_t x1, int64_t y1) const;
    int64_t ustaw_efekty_obszaru(const godot::Dictionary& d);
    void odtworz_efekty_obszaru();
    godot::Array morale(int64_t id) const;
    godot::Dictionary walka(int64_t id) const;
    godot::Array zdarzenia_walki() const;
    // etap 36: potyczka w Godocie – stan wszystkich jednostek jednym wywołaniem, przyrostowe zdarzenia walki,
    // dyplomacja i liczba taktów (bez logiki: tylko odczyt Core)
    godot::Array stan_jednostek() const;
    godot::Array zdarzenia_walki_od(int64_t od) const;
    void ustaw_wrogow(int64_t g1, int64_t g2, bool wrog);
    int64_t takty() const;

protected:
    static void _bind_methods();

private:
    std::shared_ptr<const openee::TabliceTrig> tablice_;
    std::unique_ptr<openee::Swiat> swiat_;
    std::unique_ptr<openee::MapaTitan> mapa_;
    godot::String ostatni_blad_;
};
