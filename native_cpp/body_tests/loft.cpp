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
    std::cout<<"LOFT_OK gradients, axial width, rotation, depth swap, full fold, invalid profiles\n";
}
