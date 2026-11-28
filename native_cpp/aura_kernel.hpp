#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

namespace aura002 {
struct Config {
    int w,h,scale,bw,bh,px,py,floor;
    double root_x,facing,tick,velocity,rim,tint;
};
inline double clamp(double x,double a=0.,double b=1.) {return std::max(a,std::min(b,x));}
inline double smooth(double a,double b,double x){double u=clamp((x-a)/(b-a));return u*u*(3.-2.*u);}
inline uint32_t rgba(int r,int g,int b,int a){return uint32_t(r)|(uint32_t(g)<<8)|(uint32_t(b)<<16)|(uint32_t(a)<<24);}
inline uint32_t shade(uint32_t c,double a){return (c&0xffffffu)|(uint32_t(clamp(a)*255.)<<24);}
inline uint32_t light(uint32_t c,double a){return rgba(int((c&255u)*a),int(((c>>8)&255u)*a),int(((c>>16)&255u)*a),255);}
inline void render(const Config& q,uint8_t* frame,const uint8_t* body,const int32_t* seed,const int32_t* detail,
                   int32_t* color,int32_t* lights) {
    const int w=q.w,h=q.h,n=w*h,s=q.scale,fw=w*s;
    std::vector<uint8_t> mask(n,0);
    std::vector<float> dist(n,999.f);
    int x0=w,y0=h,x1=-1,y1=-1;
    const int floor=std::min(h,std::max(0,q.floor));
    for(int y=0;y<floor;++y)for(int x=0;x<w;++x){
        const int sx=x*s+s/2-q.px,sy=y*s+s/2-q.py,i=y*w+x;
        if(sx>=0&&sy>=0&&sx<q.bw&&sy<q.bh)mask[i]=body[(sy*q.bw+sx)*4+3]>63;
        if(mask[i]||seed[i]!=0){
            dist[i]=0.f;
            x0=std::min(x0,x);x1=std::max(x1,x);
            y0=std::min(y0,y);y1=std::max(y1,y);
        }
    }
    if(x1<0)return;
    const int pad=int(std::ceil(q.rim+8.));
    x0=std::max(0,x0-pad);x1=std::min(w-1,x1+pad);
    y0=std::max(0,y0-pad);y1=std::min(floor-1,y1+pad);
    for(int y=y0;y<=y1;++y)for(int x=x0;x<=x1;++x){
        int i=y*w+x;if(dist[i]==0.f)continue;
        if(x>x0)dist[i]=std::min(dist[i],dist[i-1]+1.f);
        if(y>y0){
            dist[i]=std::min(dist[i],dist[i-w]+1.f);
            if(x>x0)dist[i]=std::min(dist[i],dist[i-w-1]+1.4142f);
            if(x<x1)dist[i]=std::min(dist[i],dist[i-w+1]+1.4142f);
        }
    }
    for(int y=y1;y>=y0;--y)for(int x=x1;x>=x0;--x){
        int i=y*w+x;if(dist[i]==0.f)continue;
        if(x<x1)dist[i]=std::min(dist[i],dist[i+1]+1.f);
        if(y<y1){
            dist[i]=std::min(dist[i],dist[i+w]+1.f);
            if(x>x0)dist[i]=std::min(dist[i],dist[i+w-1]+1.4142f);
            if(x<x1)dist[i]=std::min(dist[i],dist[i+w+1]+1.4142f);
        }
    }
    constexpr uint32_t outer=0xff2350f5u,inner=0xff569affu,edge=0xff9fd9ffu;
    for(int y=y0;y<=y1;++y)for(int x=x0;x<=x1;++x){
        int i=y*w+x;double d=dist[i];if(d>q.rim+6.)continue;
        double wave=std::sin(x*.42+y*.24-q.tick*.19)+.55*std::sin(x*.91-y*.54+q.tick*.12);
        double back=clamp((q.root_x-x)*q.facing/25.);
        double rim=q.rim+.65*wave+back*std::min(1.6,std::abs(q.velocity)*.8);
        uint32_t c=0,l=0;
        if(seed[i]!=0){
            // The articulated hand is a translucent mass, not just an outline.
            bool boundary=x==0||x==w-1||y==0||y==floor-1;
            if(!boundary)boundary=seed[i-1]==0||seed[i+1]==0||seed[i-w]==0||seed[i+w]==0;
            c=shade(boundary?edge:inner,boundary?.78:clamp(.49+.065*wave));
            l=light(outer,boundary?.25:.095);
            if(detail[i]!=0)c=shade(edge,.68);
        }else if(mask[i]){
            c=shade(inner,q.tint+.035*std::sin(q.tick*.15+y*.27));
        }else if(d<=rim){
            double e=smooth(std::max(0.,rim-1.3),rim+.1,d);
            double core=.25+.07*std::sin(y*.32-q.tick*.17+x*.18);
            c=shade(e>.55?edge:inner,clamp(core+(.64-core)*e,.08,.72));
            l=light(outer,.13+.15*e);
        }else if(d<rim+3.5){
            double f=1.-(d-rim)/3.5;l=light(outer,.18*f*f);
        }
        color[i]=int32_t(c);lights[i]=int32_t(l);
        if(!c&&!l)continue;
        const int a=int(c>>24);
        for(int dy=0;dy<s;++dy)for(int dx=0;dx<s;++dx){
            uint8_t* p=frame+((y*s+dy)*fw+x*s+dx)*4;
            for(int k=0;k<3;++k){
                int channel=int((c>>(k*8))&255u),add=int((l>>(k*8))&255u);
                p[k]=uint8_t(std::min(255,(int(p[k])*(255-a)+channel*a+127)/255+add));
            }
        }
    }
}
}
