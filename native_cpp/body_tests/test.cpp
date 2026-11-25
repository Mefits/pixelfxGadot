#include "../body_raster.hpp"
#ifdef NDEBUG
#error Body raster tests require assertions
#endif
#include <cassert>
#include <fstream>
#include <iostream>
#include <limits>
using namespace body;

static Primitive sphere(Vec center, double radius, int part = 1, int material = 0) {
    Primitive p;
    p.a = center;
    p.ra = radius;
    p.part = part;
    p.material = material;
    return p;
}
int main(int argc, char **argv) {
    assert(argc == 2);
    Config c;
    c.width = c.height = 33;
    c.ox = c.oy = 16;
    c.ink = 0xff000001;
    c.seam = 0xff000002;
    c.light = {-.55, -.72, .5};
    double norm = std::sqrt(dot(c.light, c.light));
    for (auto &v : c.light)
        v /= norm;
    Ramp ramp{0xff102030, 0xff203040, 0xff304050, 0xff405060};
    c.materials.push_back(ramp);
    for (auto &v : ramp)
        v += 5;
    c.materials.push_back(ramp);
    Primitive sweep = sphere({-5.2, 2, 1}, 2.25, 3, 1);
    sweep.shape = Shape::Sweep;
    sweep.b = {4.1, -2.6, -1};
    sweep.rb = 1.15;
    sweep.bulge = .7;
    Primitive ell = sphere({1.3, .7, 1}, 1, 4);
    ell.shape = Shape::Ellipsoid;
    ell.radii = {2, 3.5, 4};
    ell.basis = {.8, 0, .6, 0, 1, 0, -.6, 0, .8};
    std::vector<std::vector<Primitive>> scenes{{sphere({}, 4), sphere({}, 4, 2, 1)},
                                               {sweep},
                                               {ell},
                                               {sphere({-1, 0, -1}, 4), sphere({2, -1, 2}, 3, 2, 1)}};
    struct Expected {
        int part = 0, mat = 0, tone = 0;
        float z = 0;
        uint32_t color = 0;
    };
    std::vector<std::vector<Expected>> golden(4, std::vector<Expected>(33 * 33));
    std::ifstream in(argv[1]);
    int scene, x, y, count = 0;
    Expected e;
    while (in >> scene >> x >> y >> e.part >> e.mat >> e.tone >> e.z >> e.color) {
        golden.at(scene).at(y * 33 + x) = e;
        count++;
    }
    assert(in.eof() && count == 302);
    Raster r;
    int mismatches[5]{};
    for (size_t s = 0; s < scenes.size(); s++) {
        assert(!r.render(c, scenes[s]));
        for (size_t i = 0; i < r.pixels.size(); i++) {
            auto &p = r.pixels[i];
            auto &g = golden[s][i];
            mismatches[0] += (p.part != 0) != (g.part != 0);
            mismatches[1] += p.part != g.part || p.material != g.mat;
            mismatches[2] += std::abs(p.depth - g.z) > 1e-6;
            mismatches[3] += p.tone != g.tone;
            mismatches[4] += r.color[i] != g.color;
        }
    }
    for (int n : mismatches)
        std::cout << n << " ";
    std::cout << "mask/ownership/depth/tone/RGBA mismatches across 4356 pixels\n" << std::flush;
    for (int n : mismatches)
        assert(!n);
    const int center = 16 * 33 + 16;
    // A subpixel sphere hits only its center, so cleanup cannot hide threshold errors.
    auto old_light = c.light;
    for (double threshold : {.08, .42, .8}) {
        for (double delta : {-1e-5, 0., 1e-5}) {
            double z = threshold + delta;
            c.light = {std::sqrt(1 - z * z), 0, z};
            assert(!r.render(c, {sphere({}, .1)}));
            double stored = double(float(z));
            int expected = stored > .8 ? 0 : stored > .42 ? 1 : stored > .08 ? 2 : 3;
            assert(r.pixels[center].tone == expected);
        }
    }
    c.light = old_light;
    auto horizontal = sweep, vertical = sweep;
    horizontal.a = {-6, 0, 1};
    horizontal.b = {6, 0, 1};
    horizontal.group = 1;
    vertical.a = {0, -6, -1};
    vertical.b = {0, 6, -1};
    vertical.part = 5;
    vertical.group = 2;
    assert(!r.render(c, {horizontal, vertical}) && r.pixels[center].part == 3);
    vertical.a[2] = vertical.b[2] = 4;
    assert(!r.render(c, {horizontal, vertical}) && r.pixels[center].part == 5);
    auto p = sphere({}, 1);
    p.frame = 23;
    auto q = p;
    q.part = 2;
    assert(!r.render(c, {p, q}) && r.pixels[center].part == 1 && r.pixels[center].frame == 23);
    p.shape = Shape::Sweep;
    p.rb = 3;
    assert(!r.render(c, {p}) && r.pixels[center].depth == 3);
    c.ox = 0;
    c.outline = 2;
    p = sphere({}, 1);
    assert(!r.render(c, {p}) && r.color[16 * 33 + 3] == c.ink && !r.color[16 * 33 + 4]);
    for (int row = 0; row < 33; row++)
        assert(!r.color[row * 33 + 32]);
    c.ox = 16;
    c.oy = 16;
    c.density = 2;
    c.outline = 0;
    assert(!r.render(c, {p}) && r.body_pixels() == 13 && r.pixels[center].depth == 1);
    assert(!r.render(c, {}) && r.body_pixels() == 0);
    for (auto v : r.color)
        assert(v == 0);
    ell.basis[0] = 1.1;
    assert(r.render(c, {ell}));
    p.ra = std::numeric_limits<double>::quiet_NaN();
    assert(r.render(c, {p}));
    p.ra = 0;
    assert(r.render(c, {p}));
    p.ra = 1;
    p.part = 0;
    assert(r.render(c, {p}));
    // Ordered elbow and knee joins. Prove silhouette expansion and preserved
    // ownership of an unrelated body in front of the joint.
    for (double angle : {1.5707963267948966, 2.2}) {
        c.width = c.height = 96;
        c.ox = c.oy = 48;
        c.density = 4;
        auto a = sphere({-8, 0, 0}, 2), b = sphere({}, 2, 2);
        a.shape = b.shape = Shape::Sweep;
        a.b = {0, 0, 0};
        b.b = {8 * std::cos(angle), 8 * std::sin(angle), 0};
        a.rb = b.rb = 2;
        a.group = b.group = 9;
        c.organic = false;
        c.smooth = 0;
        c.joins.clear();
        assert(!r.render(c, {a, b}));
        auto hard = r.pixels;
        auto colors = r.color;
        c.organic = true;
        c.joins = {{0, 1}};
        assert(!r.render(c, {a, b}) && r.color == colors);
        c.smooth = 1.2;
        assert(!r.render(c, {a, b}));
        int expanded = 0, raised = 0;
        for (int i = 0; i < 96 * 96; i++) {
            auto &soft = r.pixels[i];
            expanded += soft.part && !hard[i].part;
            raised += hard[i].part && soft.depth > hard[i].depth + .01f;
            if (std::hypot((i % 96 - 48) / 4., (i / 96 - 48) / 4.) > 5.2)
                assert(soft.depth == hard[i].depth && soft.part == hard[i].part);
        }
        assert(expanded > 0 && raised > 0);
        auto front = sphere({0, 0, 8}, 1, 7);
        assert(!r.render(c, {a, b, front}) && r.pixels[48 * 96 + 48].part == 7);
        b.group = 8;
        assert(r.render(c, {a, b}));
        b.group = 9;
        b.a[0] = .01;
        assert(r.render(c, {a, b}));
        b.a[0] = 0;
        b.b[2] = 1;
        assert(r.render(c, {a, b}));
        b.b[2] = 0;
        c.joins.clear();
        assert(!r.render(c, {a, b}) && r.color == colors);
    }
    std::cout << "Two local smooth unions expand silhouette; unlinked and foreground surfaces preserved\n";
    c.organic = false;
    c.smooth = 0;
    c.width = c.height = 512;
    sweep.ra = 256;
    sweep.b[0] = 1024;
    assert(r.render(c, {sweep}));
    std::cout << "Bounds, crossing, density, tie, outline, degeneracy, clearing and rejection OK\n";
}
