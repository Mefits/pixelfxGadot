#include "../body_raster.hpp"
#include <cassert>
#include <iostream>
#include <limits>
#ifdef NDEBUG
#error Run with assertions enabled
#endif
using namespace body;

int main(){
    // Tilted depth, asymmetric contour, changing radii/offset and a flat profile.
    const Section start{0,1,3,2,.5}, end{1,2,4,3,1};
    LoftSpan span{8,1,0,-2,2,4,start,end};
    LoftHit hit{};
    assert(span.sample(4,1,hit));
    assert(std::abs(hit.front-3.25)<1e-12 && std::abs(hit.back+1.75)<1e-12);
    for(double s:{1.,4.,7.})for(double v:{-.5,1.,2.4}){
        LoftHit x0,x1,y0,y1;
        const double eps=.0001;
        assert(span.sample(s,v,hit) && span.sample(s-eps,v,x0) && span.sample(s+eps,v,x1));
        assert(span.sample(s,v-eps,y0) && span.sample(s,v+eps,y1));
        assert(std::abs((x1.front-x0.front)/(2*eps)+hit.normal[0]/hit.normal[2])<1e-6);
        assert(std::abs((y1.front-y0.front)/(2*eps)+hit.normal[1]/hit.normal[2])<1e-6);
        assert(std::abs(dot(hit.normal,hit.normal)-1)<1e-12);
    }
    Config c;c.ox=c.oy=24;c.width=c.height=49;c.outline=0;
    c.materials.push_back({0xffffffff,0xffcccccc,0xff777777,0xff444444});
    Primitive p;p.shape=Shape::Loft;p.a={-6,0,0};p.b={6,0,0};
    p.sections={{-.1,1,1,1,0},{0,2,2,2,0},{.5,3,3,3,0},{1,2,2,2,0},{1.1,1,1,1,0}};
    Raster r;assert(!r.render(c,{p}));
    const int center=24*49+24;
    assert(r.pixels[center].depth==3);
    const auto size=r.body_pixels();
    Primitive q=p;q.a={0,-6,1};q.b={0,6,1};q.part=2;
    assert(!r.render(c,{q}) && size==r.body_pixels());
    assert(!r.render(c,{q,p})&&r.pixels[center].part==2);
    q.a[2]=q.b[2]=-1;
    assert(!r.render(c,{p,q})&&r.pixels[center].part==1);
    // Fully folded limbs: pivot is shared; lifted end remains in front of upper arm.
    q.a=p.b;q.b=p.a;q.b[2]=4;
    assert(!r.render(c,{p,q}) && r.pixels[center-6].part==2);
    Primitive invalid=p;invalid.sections[2].depth=0;assert(r.render(c,{invalid}));
    invalid=p;invalid.sections[2].t=0;assert(r.render(c,{invalid}));
    invalid=p;invalid.b=invalid.a;assert(r.render(c,{invalid}));
    invalid=p;invalid.sections[2].offset_z=std::numeric_limits<double>::infinity();
    assert(r.render(c,{invalid}));
    // Same-ray normal blend must never change geometric buffers or unlinked pixels.
    q=p;q.part=2;q.a={0,-6,.2};q.b={0,6,.2};
    c.light={.6,0,.8};
    assert(!r.render(c,{p,q}));
    auto orig=r.pixels;auto colors=r.color;
    c.normal_blend=1.4;c.normal_links={{0,1}};
    assert(!r.render(c,{p,q}) && r.normal_pixels>0);
    bool changed=false;
    for(size_t i=0;i<orig.size();++i){
        assert(orig[i].depth==r.pixels[i].depth && orig[i].part==r.pixels[i].part &&
               orig[i].material==r.pixels[i].material);
        if(orig[i].light!=r.pixels[i].light)changed=true;
    }
    assert(changed);
    auto blended=r.color;
    assert(!r.render(c,{p,q}) && blended==r.color);
    c.normal_links.clear();c.normal_blend=0;
    assert(!r.render(c,{p,q}) && colors==r.color);
    q.a[2]=q.b[2]=10;
    assert(!r.render(c,{p,q}));colors=r.color;
    c.normal_links={{0,1}};c.normal_blend=1.4;
    assert(!r.render(c,{p,q}) && r.normal_pixels==0 && colors==r.color);
    c.normal_links={{0,1},{1,0}};assert(r.render(c,{p,q}));
    c.normal_links={{0,1}};q.material=1;c.materials.push_back(c.materials[0]);assert(r.render(c,{p,q}));
    // 0.62: geometric depth gain, original owners/mask, no disconnected fusion.
    c.normal_blend=0;c.normal_links.clear();q.material=0;
    q.a={0,-6,.2};q.b={0,6,.2};
    assert(!r.render(c,{p,q}));orig=r.pixels;colors=r.color;
    c.union_band=1.4;c.union_links={{0,1}};
    assert(!r.render(c,{p,q}) && r.union_pixels>0);
    double maxgain=0;
    for(size_t i=0;i<orig.size();++i){
        assert(orig[i].part==r.pixels[i].part && orig[i].material==r.pixels[i].material);
        double gain=r.pixels[i].depth-orig[i].depth;
        assert(gain>=0 && gain<=c.union_band/4+1e-5);
        maxgain=std::max(maxgain,gain);
    }
    assert(maxgain>0);
    auto depth=r.pixels;auto united=r.color;
    assert(!r.render(c,{p,q}) && united==r.color);
    for(size_t i=0;i<depth.size();++i)assert(depth[i].depth==r.pixels[i].depth);
    Primitive occluder;occluder.part=3;occluder.a={0,0,8};occluder.ra=3;
    assert(!r.render(c,{p,q,occluder})&&r.pixels[center].part==3&&r.pixels[center].depth==11);
    q.a[2]=q.b[2]=10;
    assert(!r.render(c,{p,q}) && r.union_pixels==0);
    c.union_links={{0,1},{1,0}};assert(r.render(c,{p,q}));
    c.union_links={{0,1}};q.material=1;assert(r.render(c,{p,q}));
    c.union_links.clear();c.union_band=0;q.material=0;
    q.a[2]=q.b[2]=.2;
    assert(!r.render(c,{p,q}) && r.color==colors);
    std::cout<<"FRONT_UNION_062_OK bounded depth, ownership, occlusion, determinism, depth gate\n";
    std::cout<<"NORMAL_BLEND_OK immutable geometry, determinism, depth gate, material and link validation\n";
    std::cout<<"LOFT_OK gradients, axial width, rotation, depth swap, full fold, invalid profiles\n";
}
