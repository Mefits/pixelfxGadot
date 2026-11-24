// Optional native fast paths for the original JS Painter. MIT PixelFX / Patch / Hugo Duprez.
// The JS source remains unchanged. Only constant-color primitives use this adapter.
#pragma once
#include "kernel.hpp"
#include <quickjs.h>
#include <cstdint>
#include <cmath>

namespace pfx_original {
struct TypedBuffer {
    JSContext *ctx;
    JSValue array=JS_UNDEFINED,buffer=JS_UNDEFINED;
    uint32_t *ptr=nullptr;
    TypedBuffer(JSContext *c):ctx(c){}
    ~TypedBuffer(){JS_FreeValue(ctx,buffer);JS_FreeValue(ctx,array);}
    bool open(JSValueConst painter,const char *name,size_t cells){
        array=JS_GetPropertyStr(ctx,painter,name);
        if(JS_IsException(array))return false;
        size_t off=0,len=0,elem=0,bytes=0;
        buffer=JS_GetTypedArrayBuffer(ctx,array,&off,&len,&elem);
        if(JS_IsException(buffer))return false;
        auto *data=JS_GetArrayBuffer(ctx,&bytes,buffer);
        if(!data||elem!=4||len!=cells*4||off>bytes||len>bytes-off||off%4)return false;
        ptr=reinterpret_cast<uint32_t*>(data+off);
        return true;
    }
};
inline bool number_prop(JSContext *ctx,JSValueConst o,const char *key,double &v){
    JSValue a=JS_GetPropertyStr(ctx,o,key);
    bool ok=JS_IsNumber(a)&&JS_ToFloat64(ctx,&v,a)==0&&std::isfinite(v)&&std::abs(v)<=100000.;
    JS_FreeValue(ctx,a);return ok;
}
// Called with Painter as this. op 0 glow, 1 circle, 2 disc, 3 line.
inline JSValue primitive(JSContext *ctx,JSValueConst painter,int argc,JSValueConst *argv){
    if(argc!=7)return JS_FALSE;
    double v[7];
    for(int i=0;i<7;++i)if(!JS_IsNumber(argv[i])||JS_ToFloat64(ctx,&v[i],argv[i])<0||!std::isfinite(v[i]))return JS_FALSE;
    if(v[0]<0||v[0]>3||v[0]!=std::floor(v[0]))return JS_FALSE;
    int op=int(v[0]);
    for(int i=1;i<=4;++i)if(std::abs(v[i])>16384.)return JS_FALSE;
    if(op!=3&&(v[3]<0||v[3]>1024))return JS_FALSE;
    if(std::abs(v[6])>8)return JS_FALSE;
    uint32_t color=0;
    if(JS_ToUint32(ctx,&color,argv[5])<0)return JS_EXCEPTION;
    const char *keys[]={"w","h","ox","oy","tx","ty","fx","cs","sn","fade","lightK"};
    double q[11];
    for(int i=0;i<11;++i)if(!number_prop(ctx,painter,keys[i],q[i]))return JS_FALSE;
    if(q[0]<1||q[1]<1||q[0]>2048||q[1]>2048||q[0]*q[1]>1048576||q[0]!=std::floor(q[0])||q[1]!=std::floor(q[1]))return JS_FALSE;
    if(std::abs(q[6])!=1||std::abs(q[7])>1||std::abs(q[8])>1||q[9]<0||q[9]>1||q[10]<0||q[10]>8)return JS_FALSE;
    TypedBuffer c(ctx),l(ctx);
    size_t n=size_t(q[0])*size_t(q[1]);
    if(!c.open(painter,"C",n)||!l.open(painter,"L",n))return JS_ThrowTypeError(ctx,"Invalid original Painter buffers");
    pfx::Frame f{int(q[0]),int(q[1]),int(q[2]),int(q[3]),q[4],q[5],q[6],q[7],q[8],q[9],q[10],c.ptr,l.ptr};
    switch(op){
      case 0:f.glow(v[1],v[2],v[3],color,v[6]);break;
      case 1:f.circle(v[1],v[2],v[3],color,v[6],false);break;
      case 2:f.circle(v[1],v[2],v[3],color,v[6],true);break;
      case 3:f.line(v[1],v[2],v[3],v[4],color,v[6]);break;
    }
    return JS_TRUE;
}
}
