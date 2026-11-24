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
        ClassDB::bind_method(D_METHOD("render_batch","color","light","config","commands"), &PixelFXRaster::render_batch);
        ClassDB::bind_method(D_METHOD("render_bolt","color","light","config","paths","palette","power","scale","options","crackle"), &PixelFXRaster::render_bolt);
    }
public:
    Array render_batch(PackedInt32Array color,PackedInt32Array light,PackedFloat64Array cfg,PackedFloat64Array cmd){
        if(cfg.size()!=11||cmd.size()%8!=0||cmd.size()>8*131072)return Array();
        for(int i=0;i<cfg.size();++i)if(!std::isfinite(cfg[i])||std::abs(cfg[i])>100000)return Array();
        int w=int(cfg[0]),h=int(cfg[1]);
        if(w<=0||h<=0||w>4096||h>4096||color.size()!=int64_t(w)*h||light.size()!=color.size())return Array();
        const double *v=cmd.ptr();
        for(int64_t i=0;i<cmd.size();i+=8){
            for(int j=0;j<8;++j)if(!std::isfinite(v[i+j]))return Array();
            if(v[i]<0||v[i]>5||std::floor(v[i])!=v[i]||v[i+5]<0||v[i+5]>4294967295.||std::abs(v[i+6])>8)return Array();
            for(int j=1;j<=4;++j)if(std::abs(v[i+j])>16384)return Array();
            if(v[i]>=3&&(v[i+3]<0||v[i+3]>1024))return Array();
        }
        pfx::Frame f{w,h,int(cfg[2]),int(cfg[3]),cfg[4],cfg[5],cfg[6],cfg[7],cfg[8],cfg[9],cfg[10],reinterpret_cast<uint32_t*>(color.ptrw()),reinterpret_cast<uint32_t*>(light.ptrw())};
        for(int64_t i=0;i<cmd.size();i+=8){
            double x=v[i+1],y=v[i+2],u=v[i+3],z=v[i+4],a=v[i+6];uint32_t c=uint32_t(v[i+5]);
            switch(int(v[i])){
              case 0:f.put(x,y,c,a);break;
              case 1:f.blend_screen(f.cell_x(x,y),f.cell_y(x,y),c,a);break;
              case 2:f.line(x,y,u,z,c,a);break;
              case 3:f.glow(x,y,u,c,a);break;
              case 4:f.circle(x,y,u,c,a,false);break;
              case 5:f.circle(x,y,u,c,a,true);break;
            }
        }
        Array out;out.append(color);out.append(light);return out;
    }
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
