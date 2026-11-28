#pragma once
#include "aura_kernel.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

class PixelFXAuraRaster : public godot::RefCounted {
    GDCLASS(PixelFXAuraRaster,godot::RefCounted)
protected:
    static void _bind_methods(){
        godot::ClassDB::bind_method(godot::D_METHOD("render","frame","body","seed","detail","config"),&PixelFXAuraRaster::render);
    }
public:
    godot::Array render(godot::PackedByteArray frame,godot::PackedByteArray body,godot::PackedInt32Array seed,godot::PackedInt32Array detail,godot::PackedFloat64Array cfg){
        using namespace godot;
        if(cfg.size()!=14)return Array();
        for(int i=0;i<14;++i)if(!std::isfinite(cfg[i])||std::abs(cfg[i])>1000000.)return Array();
        for(int i=0;i<8;++i)if(std::floor(cfg[i])!=cfg[i])return Array();
        aura002::Config q{int(cfg[0]),int(cfg[1]),int(cfg[2]),int(cfg[3]),int(cfg[4]),int(cfg[5]),int(cfg[6]),int(cfg[7]),cfg[8],cfg[9],cfg[10],cfg[11],cfg[12],cfg[13]};
        if(q.w<1||q.w>512||q.h<1||q.h>512||q.scale<1||q.scale>4||q.bw<1||q.bw>1024||q.bh<1||q.bh>1024||q.floor<0||q.floor>q.h||std::abs(q.facing)!=1.||q.rim<0.||q.rim>12.||q.tint<0.||q.tint>.8)return Array();
        if(frame.size()!=int64_t(q.w)*q.h*q.scale*q.scale*4||body.size()!=int64_t(q.bw)*q.bh*4||seed.size()!=q.w*q.h||detail.size()!=seed.size())return Array();
        PackedInt32Array color,light;color.resize(seed.size());light.resize(seed.size());color.fill(0);light.fill(0);
        aura002::render(q,frame.ptrw(),body.ptr(),seed.ptr(),detail.ptr(),color.ptrw(),light.ptrw());
        Array out;out.append(frame);out.append(color);out.append(light);return out;
    }
};
