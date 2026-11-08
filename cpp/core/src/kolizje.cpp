#include "openee/kolizje.hpp"

#include "openee/f32.hpp"

namespace openee {

WynikOdpychania odpychanie_male(double ux, double uy, double ru, double ox, double oy, double ro, double o_v,
                                double o_vmax) {
    WynikOdpychania w;
    const double dx = ux - ox;
    const double dy = f32(uy - oy);
    const double S = (ru + ro) * 0.5;  // połowa sumy promieni
    double dx2 = dx * dx, dy2 = dy * dy;
    if (dx2 + dy2 > S * S) return w;
    w.kolizja = true;
    if (dx2 == 0 && dy2 == 0) dx2 = dy2 = 0.1;
    const double d2 = f32(dx2 + dy2);
    const double cx = f32(dx2 / d2);
    const double m = f32((S * S - d2) * (ru / ro));
    const double px = (dx < 0 ? 1.0 : -1.0) * m * cx;
    const double py = (dy < 0 ? 1.0 : -1.0) * m * (1 - cx);
    if (ro <= ru && o_vmax > 0) {
        w.push_o_x = px;
        w.push_o_y = py;
    } else {
        w.budzik_dla_o = true;
        w.push_o_x = 0.001;
        w.push_o_y = 0.001;
    }
    if (o_v == 0 && (ro > ru || o_vmax == 0)) {
        w.push_u_x = -2 * px;
        w.push_u_y = -2 * py;
    }
    return w;
}

}  // namespace openee
