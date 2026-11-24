#include "kernel.hpp"
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <chrono>
#include <string>
#include <iomanip>
template<class T> T read(std::ifstream& f){T v{};if(!f.read(reinterpret_cast<char*>(&v),sizeof(v)))throw std::runtime_error("truncated fixture");return v;}
struct Op {int kind;double k,s;pfx::Options opts;std::vector<pfx::Path> paths;};
int main(int argc,char**argv){
 if(argc!=2)return 2;
 std::ifstream in(argv[1],std::ios::binary);if(!in)return 2;
 pfx::Raster r;int count=read<int32_t>(in);int bad=0;
 std::vector<double> times;
 for(int j=0;j<count;++j){
  pfx::Frame f{};f.w=read<int32_t>(in);f.h=read<int32_t>(in);f.ox=read<int32_t>(in);f.oy=read<int32_t>(in);
  f.tx=read<double>(in);f.ty=read<double>(in);f.mirror=read<double>(in);f.cs=read<double>(in);f.sn=read<double>(in);f.fade=read<double>(in);f.light_k=read<double>(in);
  uint32_t C[8];for(auto& v:C)v=read<uint32_t>(in);
  size_t n=size_t(f.w)*f.h;std::vector<uint32_t> color(n),light(n);
  for(auto& v:color)v=read<uint32_t>(in);
  for(auto& v:light)v=read<uint32_t>(in);
  f.color=color.data();f.light=light.data();
  std::vector<Op> ops;int no=read<int32_t>(in);
  for(int i=0;i<no;++i){
   Op o{};o.kind=read<int32_t>(in);o.k=read<double>(in);o.s=read<double>(in);
   o.opts.light=read<double>(in);o.opts.a=read<double>(in);o.opts.core=read<double>(in);o.opts.up_to=read<double>(in);o.opts.min_y=read<double>(in);
   o.opts.hero=read<int32_t>(in)!=0;o.opts.limit=read<int32_t>(in)!=0;o.opts.has_min_y=read<int32_t>(in)!=0;
   int np=read<int32_t>(in);
   for(int k=0;k<np;++k){pfx::Path p;p.w=read<double>(in);int len=read<int32_t>(in);for(int z=0;z<len;++z)p.pts.push_back({read<double>(in),read<double>(in)});o.paths.push_back(std::move(p));}
   ops.push_back(std::move(o));
  }
  auto start=std::chrono::steady_clock::now();
  for(auto& o:ops){if(o.kind)r.crackle(f,o.paths,o.k,C,o.opts.light,o.opts.a);else r.stroke(f,o.paths,o.k,C,o.s,o.opts);}
  times.push_back(std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count());
  int diff=0;for(auto v:color)if(v!=read<uint32_t>(in))++diff;for(auto v:light)if(v!=read<uint32_t>(in))++diff;
  if(diff){std::cerr<<"case "<<j<<" differs in "<<diff<<" packed pixels\n";bad+=diff;}
 }
 std::sort(times.begin(),times.end());
 std::cout<<"Standalone C++ parity: "<<count<<" fixtures, "<<bad<<" mismatched pixels; kernel-only p95 "<<std::fixed<<std::setprecision(3)<<times[size_t(std::ceil(count*.95))-1]<<" ms\n";
 return bad?1:0;
}
