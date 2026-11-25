// Geometry and finish adapted from patch-gg/pixelfx rig.js (5294518), MIT.
// Copyright (c) 2026 Patch and Hugo Duprez. See LICENSE-PixelFX.txt.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <vector>

namespace body {
using Vec = std::array<double, 3>;
using Ramp = std::array<uint32_t, 4>;
enum class Shape { Sphere, Sweep, Ellipsoid, CutTube, Triangle };
struct Primitive {
    Shape shape = Shape::Sphere;
    Vec a{}, b{}, radii{1, 1, 1};
    Vec v2{}, na{0,0,1}, nb{0,0,1}, nc{0,0,1};
    std::array<double, 9> basis{1, 0, 0, 0, 1, 0, 0, 0, 1};
    double ra = 1, rb = 1, bulge = 0;
    double depth_ratio = 1, profile = 2;
    int part = 1, material = 0, frame = -1, group = 0, dim = 0;
};
struct Config {
    int width = 64, height = 64, outline = 1;
    double ox = 0, oy = 0, density = 1;
    Vec light{0, 0, 1};
    uint32_t ink = 0xff000000, seam = 0xff303030;
    bool seams = true;
    std::vector<Ramp> materials;
    bool organic = false;
    double smooth = 0;
    std::vector<std::array<int, 2>> joins;
};
struct Pixel {
    float depth = 0, light = 0;
    int part = 0, material = 0, frame = -1;
    int join = -1;
    uint8_t tone = 0, dim = 0, mark = 0;
};
inline double dot(const Vec &a, const Vec &b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
inline bool bounded(double x, double limit) { return std::isfinite(x) && std::abs(x) <= limit; }
inline bool point(const Vec &p) {
    return bounded(p[0], 16384) && bounded(p[1], 16384) && bounded(p[2], 16384);
}
inline bool radius(double r) { return r >= 1e-4 && r <= 512; }
inline int steps(const Primitive &p) {
    return std::max(2, int(std::ceil(std::hypot(p.b[0] - p.a[0], p.b[1] - p.a[1], p.b[2] - p.a[2]) / .4)));
}
class Raster {
    std::vector<int> touched;
    struct Ball {
        double x, y, r;
    };
    std::vector<Ball> left_balls, right_balls;
    static double joint_radius(const Primitive &a, const Primitive &b, double smooth) {
        return 2 * std::min(a.rb, b.ra) + smooth;
    }
    static const char *validate(const Config &c, const std::vector<Primitive> &ps) {
        if (c.width < 1 || c.height < 1 || c.width > 1024 || c.height > 1024 || !bounded(c.ox, 65536) ||
            !bounded(c.oy, 65536) || !(c.density >= .125 && c.density <= 8) || !point(c.light) ||
            std::abs(dot(c.light, c.light) - 1) > 1e-5 || c.outline < 0 || c.outline > 4 ||
            c.materials.empty() || c.materials.size() > 256 || ps.size() > 512)
            return "invalid canvas, light, material table or primitive count";
        double cost = 0;
        for (const auto &p : ps) {
            if (!point(p.a) || p.part <= 0 || p.material < 0 || size_t(p.material) >= c.materials.size() ||
                p.frame < -1 || p.group < 0 || p.dim < 0 || p.dim > 3)
                return "invalid center or ownership";
            double r = p.ra;
            int stamps = 1;
            if (p.shape == Shape::Triangle) {
                if (!point(p.b) || !point(p.v2)) return "invalid triangle positions";
                for (const auto &n : {p.na,p.nb,p.nc})
                    if (!point(n) || std::abs(dot(n,n)-1)>1e-5) return "invalid triangle normal";
                const double w = std::max({p.a[0],p.b[0],p.v2[0]})-std::min({p.a[0],p.b[0],p.v2[0]});
                const double h = std::max({p.a[1],p.b[1],p.v2[1]})-std::min({p.a[1],p.b[1],p.v2[1]});
                cost += (std::min(double(c.width),std::ceil(w*c.density)+3)) *
                        (std::min(double(c.height),std::ceil(h*c.density)+3));
                if (cost>16000000) return "triangle work budget exceeded";
                continue;
            }
            if (p.shape == Shape::Ellipsoid) {
                for (auto axis : p.radii)
                    if (!radius(axis))
                        return "invalid axes";
                for (int i = 0; i < 3; i++)
                    for (int j = i; j < 3; j++) {
                        double v = 0;
                        for (int k = 0; k < 3; k++)
                            v += p.basis[i * 3 + k] * p.basis[j * 3 + k];
                        if (!bounded(v - (i == j), 1e-5))
                            return "basis must be orthonormal";
                    }
                r = *std::max_element(p.radii.begin(), p.radii.end());
            } else {
                if (!radius(r))
                    return "invalid radius";
                if (p.shape == Shape::Sweep) {
                    if (!point(p.b) || !radius(p.rb) || !bounded(p.bulge, 512) ||
                        std::min(r, p.rb) + std::min(0., p.bulge) < 1e-4)
                        return "invalid sweep";
                    r = std::max(r, p.rb) + std::max(0., p.bulge);
                    stamps = steps(p) + 1;
                } else if (p.shape == Shape::CutTube) {
                    const double len = std::hypot(p.b[0]-p.a[0],p.b[1]-p.a[1]);
                    if (!point(p.b) || !radius(p.rb) || p.a[2] != p.b[2] ||
                        !(len >= .0001) || !(p.depth_ratio >= .1 && p.depth_ratio <= 2) ||
                        !(p.profile >= 2 && p.profile <= 6))
                        return "invalid coplanar cut tube";
                    r = len * .5 + std::max(p.ra,p.rb);
                } else if (p.shape != Shape::Sphere)
                    return "unknown shape";
            }
            const double side = std::ceil(2 * r * c.density) + 3;
            cost += stamps * (1 + std::min(side, double(c.width)) * std::min(side, double(c.height)));
            if (cost > 16000000)
                return "geometry work budget exceeded";
        }
        if (!(c.smooth >= 0 && c.smooth <= 8) || c.joins.size() > 64 ||
            (!c.organic && (c.smooth != 0 || !c.joins.empty())))
            return "invalid smoothing configuration";
        for (auto pair : c.joins) {
            if (pair[0] < 0 || pair[1] < 0 || size_t(pair[0]) >= ps.size() || size_t(pair[1]) >= ps.size() ||
                pair[0] == pair[1])
                return "invalid join indices";
            const auto &a = ps[pair[0]], &b = ps[pair[1]];
            if (a.shape != Shape::Sweep || b.shape != Shape::Sweep || a.b != b.a || a.a[2] != a.b[2] ||
                b.a[2] != b.b[2] || a.group == 0 || a.group != b.group || a.material != b.material)
                return "join requires adjacent coplanar sweeps with common group and material";
            double side = std::ceil(2 * joint_radius(a, b, c.smooth) * c.density) + 3;
            cost += (1 + std::min(side, double(c.width)) * std::min(side, double(c.height))) *
                    (steps(a) + steps(b) + 2);
            if (cost > 16000000)
                return "joint work budget exceeded";
        }
        return nullptr;
    }
    template <class F> void stamp(const Config &c, const Vec &a, double r, F sample) {
        const int left = std::max(0, int(std::floor(c.ox + (a[0] - r) * c.density)));
        const int right = std::min(c.width - 1, int(std::ceil(c.ox + (a[0] + r) * c.density)));
        const int top = std::max(0, int(std::floor(c.oy + (a[1] - r) * c.density)));
        const int bottom = std::min(c.height - 1, int(std::ceil(c.oy + (a[1] + r) * c.density)));
        // rig.js visits increasing world Y (decreasing screen Y). Cleanup is ordered.
        for (int y = bottom; y >= top; y--)
            for (int x = left; x <= right; x++) {
                ++samples;
                sample(y * c.width + x, (x - c.ox) / c.density - a[0], (y - c.oy) / c.density - a[1]);
            }
    }
    void plot(int i, double z, double light, const Primitive &p) {
        Pixel &v = pixels[i];
        if (v.part && z <= v.depth)
            return;
        if (!v.part)
            touched.push_back(i);
        v.depth = float(z);
        v.light = float(light);
        v.part = p.part;
        v.material = p.material;
        v.join = -1;
        v.frame = p.frame;
        v.dim = uint8_t(p.dim);
    }
    void sphere(const Config &c, const Primitive &p, const Vec &a, double r) {
        stamp(c, a, r, [&](int i, double x, double y) {
            double xy = x * x + y * y;
            if (xy > r * r)
                return;
            double z = std::sqrt(r * r - xy);
            plot(i, a[2] + z, dot({x / r, y / r, z / r}, c.light), p);
        });
    }
    void ellipsoid(const Config &c, const Primitive &p) {
        double m[9]{};
        for (int i = 0; i < 3; i++)
            for (int j = 0; j < 3; j++)
                for (int k = 0; k < 3; k++)
                    m[i * 3 + j] += p.basis[i * 3 + k] * (1 / (p.radii[k] * p.radii[k])) * p.basis[j * 3 + k];
        stamp(c, p.a, *std::max_element(p.radii.begin(), p.radii.end()), [&](int i, double x, double y) {
            double b = 2 * (m[2] * x + m[5] * y), d = m[0] * x * x + 2 * m[1] * x * y + m[4] * y * y - 1;
            double disc = b * b - 4 * m[8] * d;
            if (disc < 0)
                return;
            double z = (-b + std::sqrt(disc)) / (2 * m[8]);
            Vec n{m[0] * x + m[1] * y + m[2] * z, m[3] * x + m[4] * y + m[5] * z,
                  m[6] * x + m[7] * y + m[8] * z};
            plot(i, p.a[2] + z, dot(n, c.light) / std::sqrt(dot(n, n)), p);
        });
    }
    // New Sol shape (not an upstream PixelFX primitive). A tapered, flat-ended
    // XY tube with superelliptic cross-section and analytic visible surface.
    void cut_tube(const Config &c, const Primitive &p) {
        const double dx = p.b[0]-p.a[0], dy = p.b[1]-p.a[1];
        const double len = std::hypot(dx,dy), ux = dx/len, uy = dy/len;
        const double vx = -uy, vy = ux, dr = (p.rb-p.ra)/len;
        const Vec center{(p.a[0]+p.b[0])*.5,(p.a[1]+p.b[1])*.5,p.a[2]};
        stamp(c,center,len*.5+std::max(p.ra,p.rb),[&](int i,double x,double y) {
            const double s = x*ux+y*uy+len*.5;
            if (s < 0 || s > len) return;
            const double r = p.ra+dr*s, w = (x*vx+y*vy)/r;
            if (std::abs(w)>1) return;
            const double t = std::pow(std::max(0.,1-std::pow(std::abs(w),p.profile)),1/p.profile);
            const double side = std::copysign(std::pow(std::abs(w),p.profile-1),w);
            const Vec n{vx*side-ux*dr,vy*side-uy*dr,std::pow(t,p.profile-1)/p.depth_ratio};
            const double norm = std::sqrt(dot(n,n));
            plot(i,p.a[2]+r*p.depth_ratio*t,norm?dot(n,c.light)/norm:0,p);
        });
    }
    // Optional 2.5D triangle surface. Integer sample centers, inclusive shared
    // edges, deterministic existing depth rule; degenerate projections emit nothing.
    void triangle(const Config &c, const Primitive &p) {
        const double ux=p.b[0]-p.a[0], uy=p.b[1]-p.a[1];
        const double vx=p.v2[0]-p.a[0], vy=p.v2[1]-p.a[1], det=ux*vy-uy*vx;
        if (std::abs(det)<1e-10) return;
        const int left=std::max(0,int(std::floor(c.ox+c.density*std::min({p.a[0],p.b[0],p.v2[0]}))));
        const int right=std::min(c.width-1,int(std::ceil(c.ox+c.density*std::max({p.a[0],p.b[0],p.v2[0]}))));
        const int top=std::max(0,int(std::floor(c.oy+c.density*std::min({p.a[1],p.b[1],p.v2[1]}))));
        const int bottom=std::min(c.height-1,int(std::ceil(c.oy+c.density*std::max({p.a[1],p.b[1],p.v2[1]}))));
        for (int y=bottom;y>=top;--y) for(int x=left;x<=right;++x) {
            ++samples;
            const double px=(x-c.ox)/c.density-p.a[0], py=(y-c.oy)/c.density-p.a[1];
            const double b=(px*vy-py*vx)/det, d=(ux*py-uy*px)/det, a=1-b-d;
            if (a < -1e-9 || b < -1e-9 || d < -1e-9) continue;
            const Vec n{a*p.na[0]+b*p.nb[0]+d*p.nc[0],a*p.na[1]+b*p.nb[1]+d*p.nc[1],a*p.na[2]+b*p.nb[2]+d*p.nc[2]};
            const double norm=std::sqrt(dot(n,n));
            plot(y*c.width+x,a*p.a[2]+b*p.b[2]+d*p.v2[2],norm>1e-10?dot(n,c.light)/norm:0,p);
        }
    }
    // At constant center Z, a sampled sweep has exact squared front height
    // max(r*r - dx*dx - dy*dy). Negative values extend the field outside it.
    template <class F> static void each_ball(const Primitive &p, int n, F visit) {
        for (int k = 0; k <= n; k++) {
            double u = double(k) / n;
            Vec center{};
            for (int j = 0; j < 3; j++)
                center[j] = p.a[j] + (p.b[j] - p.a[j]) * u;
            visit(center, p.ra + (p.rb - p.ra) * u + p.bulge * std::sin(u * 3.14159265358979323846));
        }
    }
    void balls(const Primitive &p, std::vector<Ball> &out) {
        int n = steps(p);
        out.clear();
        buffer_growths += out.capacity() < size_t(n + 1);
        out.reserve(n + 1);
        each_ball(p, n, [&](const Vec &c, double r) { out.push_back({c[0], c[1], r}); });
    }
    struct Field {
        double h, dx, dy;
    };
    static Field surface(const std::vector<Ball> &balls, double x, double y) {
        Field best{-1e30, 0, 0};
        for (const auto &b : balls) {
            double dx = x - b.x, dy = y - b.y, h = b.r * b.r - dx * dx - dy * dy;
            if (h > best.h)
                best = {h, -2 * dx, -2 * dy};
        }
        return best;
    }
    void smooth_joint(const Config &c, const Primitive &a, const Primitive &b, int join) {
        balls(a, left_balls);
        balls(b, right_balls);
        const double radius = joint_radius(a, b, c.smooth), rr = radius * radius;
        const double band = 2 * std::min(a.rb, b.ra) * c.smooth;
        stamp(c, a.b, radius, [&](int i, double dx, double dy) {
            const double falloff = 1 - (dx * dx + dy * dy) / rr;
            if (falloff <= 0)
                return;
            const double w = band * falloff * falloff;
            field_tests += left_balls.size() + right_balls.size();
            auto u = surface(left_balls, dx + a.b[0], dy + a.b[1]);
            auto v = surface(right_balls, dx + a.b[0], dy + a.b[1]);
            if (std::abs(u.h - v.h) >= w)
                return;
            // Polynomial smooth maximum; differentiate the varying band for lighting.
            double t = .5 + .5 * (u.h - v.h) / w, mix = t * (1 - t);
            double h = t * u.h + (1 - t) * v.h + w * mix;
            if (h < 0)
                return;
            double dz = std::sqrt(h), z = a.b[2] + dz;
            if (pixels[i].part && z <= pixels[i].depth)
                return;
            double dw = -4 * band * falloff / rr;
            Vec normal{-(t * u.dx + (1 - t) * v.dx + mix * dw * dx),
                       -(t * u.dy + (1 - t) * v.dy + mix * dw * dy), 2 * dz};
            double length = std::sqrt(dot(normal, normal));
            plot(i, z, length ? dot(normal, c.light) / length : 0, u.h >= v.h ? a : b);
            pixels[i].join = join;
        });
    }
    void finish(const Config &c) {
        for (int i : touched) {
            auto &p = pixels[i];
            int t = p.light > .8 ? 0 : p.light > .42 ? 1 : p.light > .08 ? 2 : 3;
            p.tone = uint8_t(std::min(3, t + p.dim));
        }
        for (int i : touched) {
            auto &p = pixels[i];
            int x = i % c.width, y = i / c.width, votes[4]{};
            auto visit = [&](int j) {
                if (pixels[j].part == p.part)
                    ++votes[pixels[j].tone];
            };
            if (x > 0)
                visit(i - 1);
            if (x + 1 < c.width)
                visit(i + 1);
            if (y > 0)
                visit(i - c.width);
            if (y + 1 < c.height)
                visit(i + c.width);
            auto best = std::max_element(votes, votes + 4);
            if (!votes[p.tone] && *best)
                p.tone = uint8_t(best - votes);
            auto seam = [&](int j) {
                auto &q = pixels[j];
                if (!q.part || q.part == p.part)
                    return;
                if (p.join >= 0 && p.join == q.join && std::abs(p.depth - q.depth) <= 2.2)
                    return;
                auto &far = p.depth < q.depth ? p : q;
                far.mark = std::max<uint8_t>(far.mark, std::abs(p.depth - q.depth) > 2.2 ? 2 : 1);
            };
            if (c.seams && x + 1 < c.width)
                seam(i + 1);
            if (c.seams && y + 1 < c.height)
                seam(i + c.width);
            for (int dy = -c.outline; dy <= c.outline; dy++) {
                int row = y + dy, span = c.outline - std::abs(dy);
                if (row < 0 || row >= c.height)
                    continue;
                for (int col = std::max(0, x - span); col <= std::min(c.width - 1, x + span); col++) {
                    int j = row * c.width + col;
                    if (!pixels[j].part)
                        color[j] = c.ink;
                }
            }
        }
        for (int i : touched) {
            auto &p = pixels[i];
            color[i] = p.mark == 2 ? c.ink : p.mark == 1 ? c.seam : c.materials[p.material][p.tone];
        }
    }

  public:
    std::vector<Pixel> pixels;
    std::vector<uint32_t> color; // 0xAABBGGRR
    uint64_t samples = 0, field_tests = 0;
    int buffer_growths = 0;
    size_t body_pixels() const { return touched.size(); }
    const char *render(const Config &c, const std::vector<Primitive> &ps) {
        if (const char *error = validate(c, ps))
            return error;
        size_t area = size_t(c.width) * c.height;
        buffer_growths =
            int(pixels.capacity() < area) + int(color.capacity() < area) + int(touched.capacity() < area);
        field_tests = 0;
        pixels.assign(area, Pixel{});
        color.assign(area, 0);
        touched.clear();
        touched.reserve(area);
        samples = 0;
        for (const auto &p : ps) {
            if (p.shape == Shape::Ellipsoid)
                ellipsoid(c, p);
            else if (p.shape == Shape::Sphere)
                sphere(c, p, p.a, p.ra);
            else if (p.shape == Shape::CutTube)
                cut_tube(c,p);
            else if (p.shape == Shape::Triangle)
                triangle(c,p);
            else
                each_ball(p, steps(p), [&](const Vec &center, double r) { sphere(c, p, center, r); });
        }
        if (c.organic && c.smooth > 0) {
            for (size_t i = 0; i < c.joins.size(); i++) {
                auto pair = c.joins[i];
                smooth_joint(c, ps[pair[0]], ps[pair[1]], int(i));
            }
        }
        finish(c);
        return nullptr;
    }
};
} // namespace body
