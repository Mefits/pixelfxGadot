#pragma once
#include "body_raster.hpp"
#include <chrono>
#include <cstring>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace body_bridge {
using namespace godot;
// Avoid Variant coercion (e.g. strings silently becoming numbers).
struct Reader {
    String error;
    Variant get(const Dictionary &d, const char *key, Variant::Type type) {
        Variant v = d.get(key, Variant());
        if (v.get_type() != type && error.is_empty())
            error = String("missing or invalid ") + key;
        return v;
    }
    int64_t integer(const Dictionary &d, const char *key, int64_t lo, int64_t hi, int64_t fallback = 0) {
        if (!d.has(key))
            return fallback;
        Variant v = get(d, key, Variant::INT);
        if (!error.is_empty())
            return fallback;
        int64_t n = v;
        if (n < lo || n > hi) {
            error = String("out of range: ") + key;
            return fallback;
        }
        return n;
    }
    double number(const Variant &v, const char *key) {
        if (v.get_type() != Variant::FLOAT && v.get_type() != Variant::INT) {
            if (error.is_empty())
                error = String("expected number: ") + key;
            return 0;
        }
        return double(v);
    }
    template <size_t N> void tuple(const Dictionary &d, const char *key, std::array<double, N> &out) {
        Variant v = get(d, key, Variant::ARRAY);
        if (!error.is_empty())
            return;
        Array a = v;
        if (a.size() != N) {
            error = String("wrong length: ") + key;
            return;
        }
        for (size_t i = 0; i < N; i++)
            out[i] = number(a[i], key);
    }
    bool flag(const Dictionary &d, const char *key, bool fallback) {
        if (!d.has(key))
            return fallback;
        Variant v = get(d, key, Variant::BOOL);
        return error.is_empty() ? bool(v) : fallback;
    }
};
} // namespace body_bridge
class PixelFXBodyRaster : public godot::RefCounted {
    GDCLASS(PixelFXBodyRaster, godot::RefCounted)
    body::Raster raster;
    body::Config c;
    std::vector<body::Primitive> shapes;
    static godot::Dictionary failure(godot::String message) {
        godot::Dictionary out;
        out["ok"] = false;
        out["error"] = message;
        return out;
    }

  protected:
    static void _bind_methods() {
        godot::ClassDB::bind_method(godot::D_METHOD("render", "config", "primitives"),
                                    &PixelFXBodyRaster::render);
    }

  public:
    godot::Dictionary render(godot::Dictionary cfg, godot::Array primitives) {
        using namespace godot;
        body_bridge::Reader r;
        if (primitives.size() > 512)
            return failure("too many primitives");
        Variant mode = cfg.get("mode", "reference");
        c.organic = mode == Variant("organic");
        if (!c.organic && mode != Variant("reference"))
            return failure("unknown raster mode");
        c.smooth = r.number(cfg.get("smooth", 0), "smooth");
        c.joins.clear();
        if (cfg.has("joins")) {
            Variant value = r.get(cfg, "joins", Variant::ARRAY);
            if (!r.error.is_empty())
                return failure(r.error);
            Array joins = value;
            if (joins.size() > 64)
                return failure("too many joins");
            for (int i = 0; i < joins.size(); i++) {
                if (joins[i].get_type() != Variant::ARRAY)
                    return failure("expected join pair");
                Array pair = joins[i];
                if (pair.size() != 2)
                    return failure("expected two indices");
                std::array<int, 2> indices{};
                for (int k = 0; k < 2; k++) {
                    if (pair[k].get_type() != Variant::INT)
                        return failure("expected join index");
                    int64_t index = pair[k];
                    if (index < 0 || index >= primitives.size())
                        return failure("invalid join index");
                    indices[k] = int(index);
                }
                c.joins.push_back(indices);
            }
        }
        c.width = r.integer(cfg, "width", 1, 1024);
        c.height = r.integer(cfg, "height", 1, 1024);
        std::array<double, 2> origin{};
        r.tuple(cfg, "origin", origin);
        c.ox = origin[0];
        c.oy = origin[1];
        r.tuple(cfg, "light", c.light);
        c.density = r.number(cfg.get("density", 1), "density");
        c.outline = r.integer(cfg, "outline", 0, 4, 1);
        c.ink = r.integer(cfg, "ink", 0, UINT32_MAX, 0xff000000);
        c.seam = r.integer(cfg, "seam", 0, UINT32_MAX, 0xff303030);
        c.seams = r.flag(cfg, "seams", true);
        bool debug = r.flag(cfg, "debug", false);
        Variant materials = r.get(cfg, "materials", Variant::ARRAY);
        if (!r.error.is_empty())
            return failure(r.error);
        Array ramps = materials;
        if (ramps.is_empty() || ramps.size() > 256)
            return failure("expected 1..256 material ramps");
        c.materials.clear();
        for (int i = 0; i < ramps.size(); i++) {
            if (ramps[i].get_type() != Variant::ARRAY)
                return failure("expected material ramp");
            Array colors = ramps[i];
            if (colors.size() != 4)
                return failure("expected four colors");
            body::Ramp ramp{};
            for (int j = 0; j < 4; j++) {
                if (colors[j].get_type() != Variant::INT)
                    return failure("expected packed color");
                int64_t color = colors[j];
                if (color < 0 || color > UINT32_MAX)
                    return failure("invalid color");
                ramp[j] = uint32_t(color);
            }
            c.materials.push_back(ramp);
        }
        shapes.clear();
        for (int i = 0; i < primitives.size(); i++) {
            if (primitives[i].get_type() != Variant::DICTIONARY)
                return failure("expected primitive dictionary");
            Dictionary d = primitives[i];
            body::Primitive p;
            p.part = r.integer(d, "part_id", 1, INT32_MAX);
            p.material = r.integer(d, "material_id", 0, 255, -1);
            p.group = r.integer(d, "blend_group", 0, INT32_MAX);
            p.frame = r.integer(d, "frame_id", -1, INT32_MAX, -1);
            p.dim = r.integer(d, "tone_bias", 0, 3);
            Variant type = r.get(d, "type", Variant::STRING);
            if (type == Variant("sweep")) {
                p.shape = body::Shape::Sweep;
                r.tuple(d, "a", p.a);
                r.tuple(d, "b", p.b);
                p.ra = r.number(d.get("ra", Variant()), "ra");
                p.rb = r.number(d.get("rb", Variant()), "rb");
                p.bulge = r.number(d.get("bulge", 0), "bulge");
            } else if (type == Variant("cut_tube")) {
                p.shape = body::Shape::CutTube;
                r.tuple(d,"a",p.a);
                r.tuple(d,"b",p.b);
                p.ra = r.number(d.get("ra",Variant()),"ra");
                p.rb = r.number(d.get("rb",Variant()),"rb");
                p.depth_ratio = r.number(d.get("depth_ratio",1),"depth_ratio");
                p.profile = r.number(d.get("profile",2),"profile");
            } else {
                r.tuple(d, "center", p.a);
                if (type == Variant("sphere"))
                    p.ra = r.number(d.get("radius", Variant()), "radius");
                else if (type == Variant("ellipsoid")) {
                    p.shape = body::Shape::Ellipsoid;
                    r.tuple(d, "basis", p.basis);
                    r.tuple(d, "radii", p.radii);
                } else
                    return failure("unknown primitive type");
            }
            if (!r.error.is_empty())
                return failure(String("primitive ") + String::num_int64(i) + ": " + r.error);
            shapes.push_back(p);
        }
        auto start = std::chrono::steady_clock::now();
        if (const char *error = raster.render(c, shapes))
            return failure(error);
        auto elapsed = std::chrono::steady_clock::now() - start;
        Dictionary out;
        out["cpu_us"] = std::chrono::duration<double, std::micro>(elapsed).count();
        out["buffer_growths"] = raster.buffer_growths;
        out["field_tests"] = int64_t(raster.field_tests);
        out["sample_tests"] = int64_t(raster.samples);
        out["body_pixels"] = int64_t(raster.body_pixels());
        int n = c.width * c.height;
        PackedByteArray rgba;
        rgba.resize(n * 4);
        // Both supported GDExtension targets are x86-64 little endian.
        std::memcpy(rgba.ptrw(), raster.color.data(), n * 4);
        out["rgba"] = rgba;
        out["width"] = c.width;
        out["height"] = c.height;
        out["ok"] = true;
        if (debug) {
            PackedFloat32Array z;
            PackedInt32Array part, mat, frame;
            PackedByteArray tone;
            z.resize(n);
            part.resize(n);
            mat.resize(n);
            frame.resize(n);
            tone.resize(n);
            auto zp = z.ptrw();
            auto pp = part.ptrw();
            auto mp = mat.ptrw();
            auto fp = frame.ptrw();
            auto tp = tone.ptrw();
            for (int i = 0; i < n; i++) {
                const auto &p = raster.pixels[i];
                zp[i] = p.depth;
                pp[i] = p.part;
                mp[i] = p.material;
                fp[i] = p.frame;
                tp[i] = p.tone;
            }
            out["depth"] = z;
            out["part"] = part;
            out["material"] = mat;
            out["frame"] = frame;
            out["tone"] = tone;
        }
        return out;
    }
};
