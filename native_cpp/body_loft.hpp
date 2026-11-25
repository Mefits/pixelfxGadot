// A sectioned 2.5D solid in a bone's projected axial/transverse frame.
// Units are rig pixels. The height interval also defines the hidden back surface.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <vector>
namespace body {
struct Section {
    double t, left, right, depth, offset_z;
};
struct LoftHit {
    double back, front;
    std::array<double,3> normal;
};
struct LoftSpan {
    double length, ux, uy, z0, z1, exponent;
    Section a, b;
    // s and v are local axial and transverse distances from the bone origin.
    bool sample(double s,double v,LoftHit &hit) const {
        double f=(s/length-a.t)/(b.t-a.t);
        if(f<0 || f>1)return false;
        const double left=a.left+(b.left-a.left)*f;
        const double right=a.right+(b.right-a.right)*f;
        const double width=(right+left)*.5, mid=(right-left)*.5;
        const double u=(v-mid)/width;
        if(std::abs(u)>1)return false;
        const double h=a.depth+(b.depth-a.depth)*f;
        const double z=z0+(z1-z0)*(s/length)+a.offset_z+(b.offset_z-a.offset_z)*f;
        const bool ellipse=exponent==2;
        const double k=ellipse?std::sqrt(std::max(0.,1-u*u)):
            std::pow(std::max(0.,1-std::pow(std::abs(u),exponent)),1/exponent);
        hit.back=z-h*k; hit.front=z+h*k;
        const double inv=1/((b.t-a.t)*length);
        const double dw=(b.right-a.right+b.left-a.left)*.5*inv;
        const double dm=(b.right-a.right-b.left+a.left)*.5*inv;
        const double dh=(b.depth-a.depth)*inv;
        const double dz=(z1-z0)/length+(b.offset_z-a.offset_z)*inv;
        const double nv=(ellipse?u:std::copysign(std::pow(std::abs(u),exponent-1),u))/width;
        const double nz=(ellipse?k:std::pow(k,exponent-1))/h;
        const double ns=-nv*(dm+u*dw)-nz*(dz+k*dh);
        const double norm=std::hypot(ns,nv,nz);
        hit.normal={(ns*ux-nv*uy)/norm,(ns*uy+nv*ux)/norm,nz/norm};
        return true;
    }
};
}
