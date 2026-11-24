// Direct port of PixelFX lightning/_lib.js and core/painter.js.
// MIT, Patch and Hugo Duprez, 2026. See LICENSE-PixelFX.txt.
// Keep double precision and operation order; compile without FP contraction.
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

namespace pfx {
struct Point { double x,y; };
struct Path { std::vector<Point> pts; double w=1; };
struct Frame {
    int w,h,ox,oy;
    double tx,ty,mirror,cs,sn,fade,light_k;
    uint32_t *color,*light;
    static constexpr int bayer[16]={0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
    double to_x(double x,double y) const {return tx+x*mirror*cs-y*sn;}
    double to_y(double x,double y) const {return ty+x*mirror*sn+y*cs;}
    void put(double x,double y,uint32_t c,double a) {
        if(!c || a<=0) return;
        int sx=int(std::floor(to_x(std::floor(x)+.5,std::floor(y)+.5)));
        int sy=int(std::floor(to_y(std::floor(x)+.5,std::floor(y)+.5)));
        a*=fade;
        if(a<1 && a<=(bayer[((sy&3)<<2)|(sx&3)]+.5)/16.) return;
        int ix=sx-ox,iy=sy-oy;
        if(ix>=0&&iy>=0&&ix<w&&iy<h) color[iy*w+ix]=c;
    }
    void glow(double x,double y,double r,uint32_t c,double k) {
        if(r<1||k<=.004) return;
        double cx=to_x(x,y),cy=to_y(x,y);
        int sx0=std::max(ox,int(std::floor(cx-r))),sx1=std::min(ox+w-1,int(std::ceil(cx+r)));
        int sy0=std::max(oy,int(std::floor(cy-r))),sy1=std::min(oy+h-1,int(std::ceil(cy+r)));
        double factor=fade*light_k;
        for(int sy=sy0;sy<=sy1;++sy) {
            double dy=(sy+.5-cy)/r,dy2=dy*dy;
            for(int sx=sx0;sx<=sx1;++sx) {
                double dx=(sx+.5-cx)/r,d=dx*dx+dy2;
                if(d>=1) continue;
                double f=1-std::sqrt(d),strength=f*f*k; strength*=factor;
                if(strength<=.004) continue;
                auto &prior=light[(sy-oy)*w+sx-ox];
                auto channel=[&](int shift){return uint32_t(std::min(255.,double((prior>>shift)&255)+double((c>>shift)&255)*strength));};
                prior=0xff000000u|(channel(16)<<16)|(channel(8)<<8)|channel(0);
            }
        }
    }
};
struct Options {double light=.5,a=1,core=0,up_to=1,min_y=0; bool hero=false,limit=false,has_min_y=false;};
class Raster {
    static constexpr int N=1024,H=512;
    std::vector<uint8_t> grid=std::vector<uint8_t>(N*N);
    std::vector<int> hits;
    void mark(double x,double y,uint8_t level) {
        int X=int(std::floor(x))+H,Y=int(std::floor(y))+H;
        if(X<0||Y<0||X>=N||Y>=N) return;
        int i=Y*N+X;
        if(!grid[i]) hits.push_back(i);
        grid[i]=std::max(grid[i],level);
    }
    void stamp(double x,double y,double r,uint8_t level) {
        if(r<=.5){mark(std::floor(x+.5),std::floor(y+.5),level);return;}
        double r2=r*r;
        for(int py=int(std::floor(y-r));py<=int(std::ceil(y+r));++py){
            double dy=py+.5-y;
            for(int px=int(std::floor(x-r));px<=int(std::ceil(x+r));++px){
                double dx=px+.5-x;
                if(dx*dx+dy*dy<=r2)mark(px,py,level);
            }
        }
    }
    template<class Fn> void walk(const std::vector<Point>& pts,size_t n,Fn fn){
        for(size_t i=0;i+1<n;++i){
            double ax=pts[i].x,ay=pts[i].y,bx=pts[i+1].x,by=pts[i+1].y;
            double dx=bx-ax,dy=by-ay,l=std::max(1.,std::sqrt(dx*dx+dy*dy));
            for(double d=0;d<=l;d+=.5)fn(ax+dx*d/l,ay+dy*d/l);
        }
    }
    void flush(Frame& f,const uint32_t cols[4],const double alpha[4]){
        for(int i:hits){int v=grid[i];grid[i]=0;f.put(i%N-H,i/N-H,cols[v-1],alpha[v-1]);}
        hits.clear();
    }
public:
    Raster(){hits.reserve(8192);}
    void stroke(Frame& f,const std::vector<Path>& paths,double k,const uint32_t* C,double s,const Options& o){
        if(k<=.02)return;
        for(auto& q:paths){
            bool trunk=q.w>=1;
            if(!trunk&&k<.5)continue;
            double rh=(trunk?(k>.6?2.1:1.6):1.1)*s,rb=(trunk?(k>.6?1.3:.8):.5)*s;
            size_t n=q.pts.size();
            if(o.limit&&trunk)n=std::min(n,size_t(std::max(2.,std::ceil(n*o.up_to))));
            walk(q.pts,n,[&](double x,double y){
                stamp(x,y,rh,1);stamp(x,y,rb,trunk?3:2);
                if(trunk&&k>.3){if(o.core!=0)stamp(x,y,o.core,4);else mark(x,y,4);}
            });
            for(size_t i=0;i+1<n;i+=3)if(!o.has_min_y||q.pts[i].y>o.min_y)
                f.glow(q.pts[i].x,q.pts[i].y,(trunk?14.:7.)*s,C[4],o.light*k*q.w);
        }
        uint32_t cols[4]={o.hero?C[3]:C[2],o.hero?C[6]:C[4],o.hero?C[7]:C[5],C[7]};
        double alpha[4]={o.a,o.a,o.a,o.a};flush(f,cols,alpha);
    }
    void crackle(Frame& f,const std::vector<Path>& paths,double k,const uint32_t* C,double glow_k,double a){
        if(k<=.02)return;
        for(auto& q:paths){
            bool thick=q.w>=1;
            walk(q.pts,q.pts.size(),[&](double x,double y){
                if(k>.45&&thick){mark(x+1.5,y,1);mark(x-1.5,y,1);mark(x,y+1.5,1);mark(x,y-1.5,1);}
                if(k>.25&&(thick||q.w>.4)){mark(x+1,y,2);mark(x,y+1,2);}
                mark(x,y,thick&&k>.3?4:3);
            });
            for(size_t i=0;i+1<q.pts.size();i+=3)f.glow(q.pts[i].x,q.pts[i].y,(thick?9.:5.)*(.5+k*.5),C[4],glow_k*k*q.w);
        }
        uint32_t cols[4]={C[3],C[5],C[5],C[7]};
        double alpha[4]={std::min(1.,(k-.45)*1.6)*a,a,a,a};flush(f,cols,alpha);
    }
};
}
