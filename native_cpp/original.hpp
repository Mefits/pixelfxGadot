// QuickJS-NG adapter. All original authored behavior runs in the bundled JS.
// No standard-library modules or filesystem/network bindings are exposed to JS.
#pragma once
#include <quickjs.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <chrono>
#include <vector>
#include <cstring>
#include <cmath>
using namespace godot;
class PixelFXOriginal : public RefCounted {
    GDCLASS(PixelFXOriginal, RefCounted)
    JSRuntime *rt=nullptr;
    JSContext *ctx=nullptr;
    JSValue api=JS_UNDEFINED;
    String error;
    using Clock=std::chrono::steady_clock;
    Clock::time_point deadline;
    static int interrupted(JSContext*,void* p){return Clock::now()>static_cast<PixelFXOriginal*>(p)->deadline;}
    void budget(){deadline=Clock::now()+std::chrono::seconds(2);}
    void close(){
        if(ctx){JS_FreeValue(ctx,api);JS_FreeContext(ctx);}
        if(rt)JS_FreeRuntime(rt);
        ctx=nullptr;rt=nullptr;api=JS_UNDEFINED;
    }
    String str(JSValueConst v){
        size_t n=0;const char *s=JS_ToCStringLen(ctx,&n,v);
        if(!s)return String();
        String out=String::utf8(s,int64_t(n));JS_FreeCString(ctx,s);return out;
    }
    void exception(){
        JSValue e=JS_GetException(ctx);
        error=str(e);JSValue stack=JS_GetPropertyStr(ctx,e,"stack");
        if(!JS_IsException(stack)&&!JS_IsUndefined(stack)){String s=str(stack);if(!s.is_empty())error+=String("\n")+s;}
        JS_FreeValue(ctx,stack);JS_FreeValue(ctx,e);
    }
    JSValue jsstr(const String &v){CharString s=v.utf8();return JS_NewStringLen(ctx,s.get_data(),s.length());}
    JSValue integer(int v){return JS_NewInt32(ctx,v);}
    JSValue call(const char* name,std::vector<JSValue> args={}){
        budget();error=String();
        JSValue fn=JS_GetPropertyStr(ctx,api,name);
        JSValue result=JS_Call(ctx,fn,api,int(args.size()),args.data());
        JS_FreeValue(ctx,fn);for(auto a:args)JS_FreeValue(ctx,a);
        if(JS_IsException(result))exception();
        return result;
    }
    String string_call(const char* name,std::vector<JSValue> args={}){
        JSValue v=call(name,std::move(args));
        String out=JS_IsException(v)?String():str(v);JS_FreeValue(ctx,v);return out;
    }
    bool bool_call(const char* name,std::vector<JSValue> args={}){
        JSValue v=call(name,std::move(args));bool out=!JS_IsException(v)&&JS_ToBool(ctx,v)>0;JS_FreeValue(ctx,v);return out;
    }
protected:
    static void _bind_methods(){
        ClassDB::bind_method(D_METHOD("load_bundle","source"),&PixelFXOriginal::load_bundle);
        ClassDB::bind_method(D_METHOD("last_error"),&PixelFXOriginal::last_error);
        ClassDB::bind_method(D_METHOD("catalog_json"),&PixelFXOriginal::catalog_json);
        ClassDB::bind_method(D_METHOD("timing_json","id"),&PixelFXOriginal::timing_json);
        ClassDB::bind_method(D_METHOD("bounds_json","id"),&PixelFXOriginal::bounds_json);
        ClassDB::bind_method(D_METHOD("pose_json","pose"),&PixelFXOriginal::pose_json);
        ClassDB::bind_method(D_METHOD("create_effect","id","options_json","mode"),&PixelFXOriginal::create_effect);
        ClassDB::bind_method(D_METHOD("destroy_effect","handle"),&PixelFXOriginal::destroy_effect);
        ClassDB::bind_method(D_METHOD("update_effect","handle","dt"),&PixelFXOriginal::update_effect);
        ClassDB::bind_method(D_METHOD("stop_effect","handle"),&PixelFXOriginal::stop_effect);
        ClassDB::bind_method(D_METHOD("placement","handle","options_json"),&PixelFXOriginal::placement);
        ClassDB::bind_method(D_METHOD("state_json","handle"),&PixelFXOriginal::state_json);
        ClassDB::bind_method(D_METHOD("render","handle","width","height","ox","oy","layer","body","target","color","light"),&PixelFXOriginal::render);
    }
public:
    ~PixelFXOriginal(){close();}
    String last_error() const{return error;}
    bool load_bundle(String source){
        close();error=String();CharString utf=source.utf8();
        if(utf.length()<=0||utf.length()>16*1024*1024){error="Invalid bundle size";return false;}
        rt=JS_NewRuntime();if(!rt){error="Cannot allocate JS runtime";return false;}
        JS_SetMemoryLimit(rt,256*1024*1024);JS_SetMaxStackSize(rt,2*1024*1024);
        JS_SetInterruptHandler(rt,interrupted,this);ctx=JS_NewContext(rt);
        if(!ctx){error="Cannot allocate JS context";close();return false;}
        budget();
        JSValue v=JS_Eval(ctx,utf.get_data(),utf.length(),"pixelfx.bundle",JS_EVAL_TYPE_GLOBAL);
        if(JS_IsException(v)){exception();JS_FreeValue(ctx,v);close();return false;}
        JS_FreeValue(ctx,v);
        JSValue global=JS_GetGlobalObject(ctx);api=JS_GetPropertyStr(ctx,global,"__pfx");JS_FreeValue(ctx,global);
        JSValue f=JS_GetPropertyStr(ctx,api,"catalog");bool ok=JS_IsFunction(ctx,f);JS_FreeValue(ctx,f);
        if(!ok){error="Missing PixelFX API";close();return false;}return true;
    }
    String catalog_json(){return ctx?string_call("catalog"):String();}
    String timing_json(String id){return ctx?string_call("timing",{jsstr(id)}):String();}
    String bounds_json(String id){return ctx?string_call("bounds",{jsstr(id)}):String();}
    String pose_json(String pose){return ctx?string_call("pose",{jsstr(pose)}):String();}
    int create_effect(String id,String options,String mode){
        if(!ctx||(mode!="fx"&&mode!="act"))return 0;
        JSValue v=call("create",{jsstr(id),jsstr(options),jsstr(mode)});int32_t h=0;
        if(!JS_IsException(v)&&JS_ToInt32(ctx,&h,v)<0)h=0;
        JS_FreeValue(ctx,v);return h;
    }
    bool destroy_effect(int h){return ctx&&bool_call("destroy",{integer(h)});}
    bool update_effect(int h,double dt){return ctx&&std::isfinite(dt)&&dt>=0&&dt<=1&&bool_call("update",{integer(h),JS_NewFloat64(ctx,dt)});}
    bool stop_effect(int h){return ctx&&bool_call("stop",{integer(h)});}
    bool placement(int h,String options){return ctx&&bool_call("placement",{integer(h),jsstr(options)});}
    String state_json(int h){return ctx?string_call("state",{integer(h)}):String();}
    Array render(int handle,int w,int h,int ox,int oy,String layer,bool body,bool target,PackedInt32Array color,PackedInt32Array light){
        if(!ctx||w<=0||h<=0||w>2048||h>2048||int64_t(w)*h>1048576||color.size()!=int64_t(w)*h||light.size()!=color.size())return Array();
        size_t bytes=size_t(color.size())*4;
        JSValue c=JS_NewArrayBufferCopy(ctx,reinterpret_cast<const uint8_t*>(color.ptr()),bytes);
        JSValue l=JS_NewArrayBufferCopy(ctx,reinterpret_cast<const uint8_t*>(light.ptr()),bytes);
        if(JS_IsException(c)||JS_IsException(l)){JS_FreeValue(ctx,c);JS_FreeValue(ctx,l);exception();return Array();}
        JSValue out=call("render",{integer(handle),integer(w),integer(h),integer(ox),integer(oy),jsstr(layer),JS_NewBool(ctx,body),JS_NewBool(ctx,target),c,l});
        Array a;
        if(!JS_IsException(out)){
            size_t n=0;uint8_t* p=JS_GetArrayBuffer(ctx,&n,out);
            if(p&&n==bytes*2){std::memcpy(color.ptrw(),p,bytes);std::memcpy(light.ptrw(),p+bytes,bytes);a.append(color);a.append(light);}
            else error="Invalid original render buffer";
        }
        JS_FreeValue(ctx,out);return a;
    }
};
