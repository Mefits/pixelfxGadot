// Godot adapter for the independent C++ kernel.
#include "kernel.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <cstring>
using namespace godot;
class PixelFXRaster : public RefCounted {
    GDCLASS(PixelFXRaster, RefCounted)
    pfx::Raster raster;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("render_bolt","color","light","config","paths","palette","power","scale","options","crackle"), &PixelFXRaster::render_bolt);
    }
public:
    Array render_bolt(PackedInt32Array color,PackedInt32Array light,PackedFloat64Array cfg,Array paths,Array palette,double k,double s,Dictionary opts,bool crackle){
        if(cfg.size()!=11||palette.size()<8)return Array();
        int w=int(cfg[0]),h=int(cfg[1]);
        if(w<=0||h<=0||w>4096||h>4096||color.size()!=int64_t(w)*h||light.size()!=color.size())return Array();
        if(!std::isfinite(k)||!std::isfinite(s)||s<=0||s>32)return Array();
        for(int i=0;i<cfg.size();++i)if(!std::isfinite(cfg[i])||std::abs(cfg[i])>100000)return Array();
        std::vector<pfx::Path> converted; converted.reserve(paths.size());
        size_t points=0;
        for(int i=0;i<paths.size();++i){
            Dictionary q=paths[i];Array pts=q["pts"];pfx::Path path;path.w=double(q["w"]);
            if(!std::isfinite(path.w)||path.w<0||path.w>1)return Array();
            points+=pts.size();if(points>65536)return Array();
            path.pts.reserve(pts.size());
            for(int j=0;j<pts.size();++j){Array pt=pts[j];if(pt.size()!=2)return Array();double x=pt[0],y=pt[1];if(!std::isfinite(x)||!std::isfinite(y)||std::abs(x)>4096||std::abs(y)>4096)return Array();path.pts.push_back({x,y});}
            converted.push_back(std::move(path));
        }
        uint32_t C[8];for(int i=0;i<8;++i)C[i]=uint32_t(int64_t(palette[i]));
        pfx::Options o;
        o.light=double(opts.get("light",.5));o.a=double(opts.get("a",1.));o.core=double(opts.get("core",0.));o.hero=bool(opts.get("hero",false));o.limit=opts.has("upTo");o.up_to=double(opts.get("upTo",1.));o.has_min_y=opts.has("minY");o.min_y=double(opts.get("minY",0.));
        if(!std::isfinite(o.light)||!std::isfinite(o.a)||!std::isfinite(o.core)||!std::isfinite(o.up_to)||!std::isfinite(o.min_y)||o.core<0||o.core>64||o.up_to>1||o.up_to<0)return Array();
        // int32_t and its corresponding unsigned type may alias in C++.
        pfx::Frame f{w,h,int(cfg[2]),int(cfg[3]),cfg[4],cfg[5],cfg[6],cfg[7],cfg[8],cfg[9],cfg[10],reinterpret_cast<uint32_t*>(color.ptrw()),reinterpret_cast<uint32_t*>(light.ptrw())};
        if(crackle)raster.crackle(f,converted,k,C,o.light,o.a);else raster.stroke(f,converted,k,C,s,o);
        Array out;out.append(color);out.append(light);return out;
    }
};
void init(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE)GDREGISTER_CLASS(PixelFXRaster);}
void uninit(ModuleInitializationLevel){}
extern "C" GDExtensionBool GDE_EXPORT pixelfx_init(GDExtensionInterfaceGetProcAddress p,GDExtensionClassLibraryPtr l,GDExtensionInitialization *i){
    GDExtensionBinding::InitObject obj(p,l,i);obj.register_initializer(init);obj.register_terminator(uninit);obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return obj.init();
}
