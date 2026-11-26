// Lab-only Box2D 3.1.1 adapter. MIT dependency fetched in CI.
// Common model exported by Godot in art units, converted to meters.
#include <box2d/box2d.h>
#include <algorithm>
#include <cmath>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>
struct Spec {
    int parent, count; float x,y,a,m,I,cx,cy,ox,oy,lo,hi,goal,bl,bh,k,damp,cap;
    struct Circle {float x,y,r;}; std::vector<Circle> circles;
};
constexpr float S=.05f,H=1.f/120.f, PI=3.14159265358979323846f;
float wrap(float x) {return std::remainder(x,2*PI);}
float blend(float t){float x=std::clamp((t-.06f)/.18f,0.f,1.f);return 1-x*x*(3-2*x);}
float angle(b2BodyId id){auto r=b2Body_GetRotation(id);return std::atan2(r.s,r.c);}
int main(int argc,char**argv){
    if(argc!=3)return 2;
    std::ifstream in(argv[1]);std::ofstream out(argv[2]);
    int n,frames,hit;float floor,hx,hy,jx,jy;
    if(!(in>>n>>frames>>floor>>hit>>hx>>hy>>jx>>jy)||n<2||n>64)return 3;
    std::vector<Spec> specs(n);
    for(auto& b:specs){
        if(!(in>>b.parent>>b.x>>b.y>>b.a>>b.m>>b.I>>b.cx>>b.cy>>b.ox>>b.oy>>b.lo>>b.hi>>b.goal>>b.bl>>b.bh>>b.k>>b.damp>>b.cap>>b.count))return 4;
        b.circles.resize(b.count);for(auto& c:b.circles)if(!(in>>c.x>>c.y>>c.r))return 5;
    }
    auto wd=b2DefaultWorldDef();wd.gravity={0,180*S};wd.enableSleep=false;
    b2WorldId world=b2CreateWorld(&wd);
    auto sd=b2DefaultShapeDef();sd.material.friction=.22f;sd.material.restitution=0;
    auto groundDef=b2DefaultBodyDef();groundDef.position={0,(floor+50)*S};
    auto ground=b2CreateBody(world,&groundDef);
    sd.filter.categoryBits=1;sd.filter.maskBits=2;
    auto box=b2MakeBox(10000*S,50*S);b2CreatePolygonShape(ground,&sd,&box);
    std::vector<b2BodyId> ids;
    for(const auto& b:specs){
        auto bd=b2DefaultBodyDef();bd.type=b2_dynamicBody;bd.position={b.x*S,b.y*S};bd.rotation=b2MakeRot(b.a);
        bd.linearDamping=.9f;bd.angularDamping=.9f;bd.enableSleep=false;
        auto id=b2CreateBody(world,&bd);ids.push_back(id);
        sd.filter.categoryBits=2;sd.filter.maskBits=1;sd.density=1;
        for(auto c:b.circles){b2Circle circle={{(c.x-b.cx)*S,(c.y-b.cy)*S},c.r*S};b2CreateCircleShape(id,&sd,&circle);}
        b2MassData md{};md.mass=b.m;md.center={0,0};md.rotationalInertia=b.I*S*S;b2Body_SetMassData(id,md);
    }
    for(int i=1;i<n;i++){
        const auto& b=specs[i];const auto& a=specs[b.parent];
        auto jd=b2DefaultRevoluteJointDef();jd.bodyIdA=ids[b.parent];jd.bodyIdB=ids[i];
        jd.localAnchorA={(b.ox-a.cx)*S,(b.oy-a.cy)*S};jd.localAnchorB={-b.cx*S,-b.cy*S};
        jd.referenceAngle=0;jd.enableLimit=true;jd.lowerAngle=std::max(b.lo,-.99f*PI);jd.upperAngle=std::min(b.hi,.99f*PI);
        jd.collideConnected=false;b2CreateRevoluteJoint(world,&jd);
    }
    b2Body_ApplyLinearImpulse(ids[hit],{jx*S,jy*S},{hx*S,hy*S},true);
    out<<std::setprecision(10)<<"[";
    for(int step=0;step<2*frames;step++){
        auto start=std::chrono::steady_clock::now();
        for(int i=1;i<n;i++){
            const auto& b=specs[i];const auto& a=specs[b.parent];
            float rel=wrap(angle(ids[i])-angle(ids[b.parent]));
            float speed=b2Body_GetAngularVelocity(ids[i])-b2Body_GetAngularVelocity(ids[b.parent]);
            float eff=1/(1/a.I+1/b.I);
            float act=std::clamp((360*wrap(b.goal-rel)-24*speed)*eff,-480.f,480.f);
            float residual=std::clamp(-b.k*(rel-std::clamp(rel,b.bl,b.bh))-b.damp*eff*speed,-b.cap,b.cap);
            float outside=rel-std::clamp(rel,b.lo,b.hi);
            float stop=std::abs(outside)>.00001f?std::clamp(-2400*outside-28*eff*speed,-1800.f,1800.f):0;
            float j=((residual+(act-residual)*blend(step*H))+stop)*H*S*S;
            b2Body_ApplyAngularImpulse(ids[b.parent],-j,true);b2Body_ApplyAngularImpulse(ids[i],j,true);
        }
        b2World_Step(world,H,1);
        double us=std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-start).count();
        if(step)out<<",";
        out<<"{\"us\":"<<us<<",\"state\":[";
        for(int i=0;i<n;i++){
            auto p=b2Body_GetPosition(ids[i]),v=b2Body_GetLinearVelocity(ids[i]);
            float a=angle(ids[i]),w=b2Body_GetAngularVelocity(ids[i]);
            if(!std::isfinite(p.x)||!std::isfinite(p.y)||!std::isfinite(a)||!std::isfinite(v.x)||!std::isfinite(v.y)||!std::isfinite(w))return 6;
            if(i)out<<",";
            out<<"["<<p.x/S<<","<<p.y/S<<","<<a<<","<<v.x/S<<","<<v.y/S<<","<<w<<"]";
        }
        out<<"]}";
    }
    out<<"]";b2DestroyWorld(world);
    std::cout<<"BOX2D_099_SIM_OK\n";return 0;
}
