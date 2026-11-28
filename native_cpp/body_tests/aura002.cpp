#include "../aura_kernel.hpp"
#include <cassert>
#include <iostream>
int main(){
    aura002::Config q{40,40,3,30,30,20,30,30,15.,1.,13.,0.,2.3,.15};
    std::vector<uint8_t> base(40*40*9*4,32),body(30*30*4,0);
    for(int i=0;i<30*30;++i)body[i*4+3]=255;
    for(size_t i=3;i<base.size();i+=4)base[i]=255;
    std::vector<int32_t> seed(1600,0),detail(1600,0),c(1600,0),l(1600,0),c2=c,l2=l;
    seed[14*40+20]=-1;detail[14*40+20]=-1;
    auto a=base,b=base;
    aura002::render(q,a.data(),body.data(),seed.data(),detail.data(),c.data(),l.data());
    aura002::render(q,b.data(),body.data(),seed.data(),detail.data(),c2.data(),l2.data());
    assert(a==b&&a!=base&&c==c2&&l==l2);
    assert(c[14*40+20]!=0&&c[11*40+8]!=0);
    for(int y=30;y<40;++y)for(int x=0;x<40;++x)assert(c[y*40+x]==0&&l[y*40+x]==0);
    for(size_t i=30*3*40*3*4;i<a.size();++i)assert(a[i]==base[i]);
    std::cout<<"AURA_NATIVE_002 OK\n";
}
