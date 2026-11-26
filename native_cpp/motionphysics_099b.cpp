// Isolated MotionPhysics experiment. Box2D v3.2.0, MIT.
// Art-unit boundary; the library performs constraints, contacts and integration.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <box2d/box2d.h>
#include <algorithm>
#include <cmath>
#include <sstream>
#include <vector>
using namespace godot;
namespace {
constexpr float S=.05f,H=1.f/120.f,PI=3.14159265358979323846f;
struct Spec {
    int parent,count;
    float x,y,a,m,I,cx,cy,ox,oy,lo,hi,goal,bl,bh,k,damp,cap;
    struct Circle{float x,y,r;};
    std::vector<Circle> circles;
};
float angle(b2BodyId id){auto r=b2Body_GetRotation(id);return std::atan2(r.s,r.c);}
float wrap(float x){return std::remainder(x,2*PI);}
}
class MotionPhysics099B:public RefCounted {
    GDCLASS(MotionPhysics099B,RefCounted)
    b2WorldId world=b2_nullWorldId;
    std::vector<Spec> specs;
    std::vector<b2BodyId> ids;
    int substeps=4;
    bool live()const{return !B2_IS_NULL(world)&&b2World_IsValid(world);}
    void clear(){if(live())b2DestroyWorld(world);world=b2_nullWorldId;ids.clear();specs.clear();}
    void mass(b2BodyId id,const Spec& b){b2MassData md{};md.mass=b.m;md.center={0,0};md.rotationalInertia=b.I*S*S;b2Body_SetMassData(id,md);}
protected:
    static void _bind_methods(){
        ClassDB::bind_method(D_METHOD("setup","specification","substeps","copies"),&MotionPhysics099B::setup);
        ClassDB::bind_method(D_METHOD("state"),&MotionPhysics099B::state);
        ClassDB::bind_method(D_METHOD("step","weights"),&MotionPhysics099B::step);
        ClassDB::bind_method(D_METHOD("impulse","body","impulse","point"),&MotionPhysics099B::impulse);
        ClassDB::bind_method(D_METHOD("set_kinematic","body","kinematic"),&MotionPhysics099B::set_kinematic);
        ClassDB::bind_method(D_METHOD("set_velocity","body","velocity","angular_velocity"),&MotionPhysics099B::set_velocity);
        ClassDB::bind_method(D_METHOD("snapshot"),&MotionPhysics099B::snapshot);
        ClassDB::bind_method(D_METHOD("restore","bytes"),&MotionPhysics099B::restore);
        ClassDB::bind_method(D_METHOD("state_hash"),&MotionPhysics099B::state_hash);
    }
public:
    ~MotionPhysics099B(){clear();}
    bool setup(String specification,int passes,int copies){
        clear();
        if(passes<1||passes>12||copies<1||copies>2)return false;
        std::istringstream in(specification.utf8().get_data());
        int n,frames,hit;float floor,hx,hy,jx,jy;
        if(!(in>>n>>frames>>floor>>hit>>hx>>hy>>jx>>jy)||n<2||n>64||!std::isfinite(floor))return false;
        specs.resize(n);
        for(int i=0;i<n;i++){
            auto& b=specs[i];
            if(!(in>>b.parent>>b.x>>b.y>>b.a>>b.m>>b.I>>b.cx>>b.cy>>b.ox>>b.oy>>b.lo>>b.hi>>b.goal>>b.bl>>b.bh>>b.k>>b.damp>>b.cap>>b.count))return false;
            if((i==0?b.parent!=-1:b.parent<0||b.parent>=i)||b.count<1||b.count>16||b.m<=0||b.I<=0||b.lo>b.hi||b.bl>b.bh)return false;
            for(float v:{b.x,b.y,b.a,b.m,b.I,b.cx,b.cy,b.ox,b.oy,b.lo,b.hi,b.goal,b.bl,b.bh,b.k,b.damp,b.cap})if(!std::isfinite(v)||std::abs(v)>100000)return false;
            b.circles.resize(b.count);
            for(auto& c:b.circles)if(!(in>>c.x>>c.y>>c.r)||!std::isfinite(c.x)||!std::isfinite(c.y)||!std::isfinite(c.r)||c.r<=0||c.r>100)return false;
        }
        substeps=passes;
        auto wd=b2DefaultWorldDef();wd.gravity={0,180*S};wd.enableSleep=false;wd.workerCount=1;
        world=b2CreateWorld(&wd);
        auto sd=b2DefaultShapeDef();sd.material.friction=.22f;sd.material.restitution=0;
        auto groundDef=b2DefaultBodyDef();groundDef.position={0,(floor+50)*S};
        auto ground=b2CreateBody(world,&groundDef);
        sd.filter.categoryBits=1;sd.filter.maskBits=2;
        auto box=b2MakeBox(10000*S,50*S);b2CreatePolygonShape(ground,&sd,&box);
        for(int c=0;c<copies;c++){
            for(const auto& b:specs){
                auto bd=b2DefaultBodyDef();bd.type=b2_dynamicBody;bd.position={(b.x+200*c)*S,b.y*S};bd.rotation=b2MakeRot(b.a);
                bd.linearDamping=.9f;bd.angularDamping=.9f;bd.enableSleep=false;
                auto id=b2CreateBody(world,&bd);ids.push_back(id);
                sd.filter.categoryBits=2;sd.filter.maskBits=1;sd.density=1;
                for(auto q:b.circles){b2Circle circle={{(q.x-b.cx)*S,(q.y-b.cy)*S},q.r*S};b2CreateCircleShape(id,&sd,&circle);}
                mass(id,b);
            }
            for(int i=1;i<n;i++){
                const auto& b=specs[i];const auto& a=specs[b.parent];
                auto jd=b2DefaultRevoluteJointDef();
                jd.base.bodyIdA=ids[c*n+b.parent];jd.base.bodyIdB=ids[c*n+i];
                jd.base.localFrameA.p={(b.ox-a.cx)*S,(b.oy-a.cy)*S};
                jd.base.localFrameB.p={-b.cx*S,-b.cy*S};
                jd.base.localFrameA.q=b2MakeRot(0);jd.base.localFrameB.q=b2MakeRot(0);
                jd.base.collideConnected=false;
                jd.enableLimit=true;jd.lowerAngle=std::max(b.lo,-.99f*PI);jd.upperAngle=std::min(b.hi,.99f*PI);
                auto j=b2CreateRevoluteJoint(world,&jd);
                // Match 099 joint model; use native constraints only.
                // More internal substeps improve stiffness, no projection of poses.
                b2Joint_SetConstraintTuning(j,60.f,1.f);
            }
        }
        return live();
    }
    Array state()const{
        Array rows;
        if(!live())return rows;
        for(auto id:ids){
            auto p=b2Body_GetPosition(id);auto v=b2Body_GetLinearVelocity(id);
            Array row;row.append(p.x/S);row.append(p.y/S);row.append(angle(id));row.append(v.x/S);row.append(v.y/S);row.append(b2Body_GetAngularVelocity(id));rows.append(row);
        }
        return rows;
    }
    bool impulse(int i,Vector2 j,Vector2 pt){
        if(!live()||i<0||i>=int(ids.size())||!j.is_finite()||!pt.is_finite()||j.length()>100000)return false;
        b2Body_ApplyLinearImpulse(ids[i],{float(j.x)*S,float(j.y)*S},{float(pt.x)*S,float(pt.y)*S},true);return true;
    }
    bool set_velocity(int i,Vector2 v,double w){
        if(!live()||i<0||i>=int(ids.size())||!v.is_finite()||!std::isfinite(w)||v.length()>1000||std::abs(w)>100)return false;
        b2Body_SetLinearVelocity(ids[i],{float(v.x)*S,float(v.y)*S});b2Body_SetAngularVelocity(ids[i],float(w));return true;
    }
    bool set_kinematic(int i,bool k){
        if(!live()||i<0||i>=int(ids.size()))return false;
        auto id=ids[i];auto v=b2Body_GetLinearVelocity(id);float w=b2Body_GetAngularVelocity(id);
        b2Body_SetType(id,k?b2_kinematicBody:b2_dynamicBody);
        if(!k)mass(id,specs[i%specs.size()]);
        b2Body_SetLinearVelocity(id,v);b2Body_SetAngularVelocity(id,w);return true;
    }
    bool step(PackedFloat64Array weights){
        if(!live()||weights.size()!=int64_t(ids.size()))return false;
        for(int i=0;i<weights.size();i++)if(!std::isfinite(weights[i])||weights[i]<0||weights[i]>1)return false;
        const int n=int(specs.size());
        for(int i=0;i<int(ids.size());i++){
            const auto& b=specs[i%n];if(b.parent<0)continue;
            int parent=(i/n)*n+b.parent;auto ia=ids[parent],ib=ids[i];
            bool da=b2Body_GetType(ia)==b2_dynamicBody,db=b2Body_GetType(ib)==b2_dynamicBody;
            if(!da&&!db)continue;
            const auto& a=specs[b.parent];float eff=1/((da?1/a.I:0)+(db?1/b.I:0));
            float rel=wrap(angle(ib)-angle(ia)),speed=b2Body_GetAngularVelocity(ib)-b2Body_GetAngularVelocity(ia);
            float act=std::clamp((360*wrap(b.goal-rel)-24*speed)*eff,-480.f,480.f);
            float residual=std::clamp(-b.k*(rel-std::clamp(rel,b.bl,b.bh))-b.damp*eff*speed,-b.cap,b.cap);
            float outside=rel-std::clamp(rel,b.lo,b.hi);
            float stop=std::abs(outside)>.00001f?std::clamp(-2400*outside-28*eff*speed,-1800.f,1800.f):0;
            float j=(residual+(act-residual)*float(weights[i])+stop)*H*S*S;
            if(da)b2Body_ApplyAngularImpulse(ia,-j,true);
            if(db)b2Body_ApplyAngularImpulse(ib,j,true);
        }
        b2World_Step(world,H,substeps);return true;
    }
    PackedByteArray snapshot()const{
        PackedByteArray data;if(!live())return data;
        int n=b2World_GetSnapshot(world,nullptr,0);if(n<=0||n>64*1024*1024)return data;
        data.resize(n);if(b2World_GetSnapshot(world,data.ptrw(),n)!=n)data.clear();return data;
    }
    bool restore(PackedByteArray data){
        // Only trusted in-process snapshots from this same instance/layout.
        // Never load a network-provided byte image.
        if(!live()||data.size()<=0||data.size()>64*1024*1024)return false;
        if(!b2World_RestoreFromSnapshot(world,data.ptr(),int(data.size()))){clear();return false;}return true;
    }
    String state_hash()const{
        if(!live())return "";
        return String::num_uint64(b2World_GetStateHash(world),16);
    }
};
void mp_init(ModuleInitializationLevel l){if(l==MODULE_INITIALIZATION_LEVEL_SCENE)GDREGISTER_CLASS(MotionPhysics099B);}
void mp_uninit(ModuleInitializationLevel){}
extern "C" GDExtensionBool GDE_EXPORT motionphysics_099b_init(GDExtensionInterfaceGetProcAddress p,GDExtensionClassLibraryPtr l,GDExtensionInitialization*i){
    GDExtensionBinding::InitObject o(p,l,i);o.register_initializer(mp_init);o.register_terminator(mp_uninit);o.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return o.init();
}
