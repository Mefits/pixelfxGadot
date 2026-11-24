// Standalone kernel golden fixtures, produced by the locked upstream JS.
import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original','pixelfx');
const imp=p=>import(pathToFileURL(join(src,p)).href);
const {createFrame,painterFor,Rng,fit}=await imp('src/core/index.js');
const {zigzag,bowed,stroke,crackle,VOLT}=await imp('src/fx/lightning/_lib.js');
const parts=[];
function i(v){const b=Buffer.alloc(4);b.writeInt32LE(v);parts.push(b);}
function u(v){const b=Buffer.alloc(4);b.writeUInt32LE(v>>>0);parts.push(b);}
function d(v){const b=Buffer.alloc(8);b.writeDoubleLE(v);parts.push(b);}
const count=32,C=fit(VOLT,8);
i(count);
for(let j=0;j<count;j++){
 const r=new Rng(j+17),w=160,h=112,ox=-8,oy=-6,tx=j%2===0?124:14,ty=50,flip=j%2===0,angle=(j-16)*.031,fade=.58+(j%5)*.09,gain=.67+(j%6)*.08;
 const f=createFrame(w,h,ox,oy),p=painterFor(f).place(tx,ty,flip,angle);p.fade=fade;p.lightK=gain;
 const k=[.25,.35,.49,.51,.6,.61,.85,1][j%8],s=.85;
 const a=zigzag(r,-5,0,80+j,-13,.27,.8),b=bowed(r,3,3,58,10,-9,.22,.4);
 const opts={a:.75,light:.8,hero:j%3===0,core:j%4===0?1.1:0,upTo:j%5===0?.58:1};
 if(j%3===0)opts.minY=-7;
 // Existing writes, shared buffers and saturation.
 p.glow(4,5,17,C[5],.7);p.line(-6,0,25,8,C[4],.8);
 i(w);i(h);i(ox);i(oy);
 for(const v of [tx,ty,flip?-1:1,Math.cos(angle),Math.sin(angle),fade,gain])d(v);
 for(const v of C)u(v);
 for(const buf of [f.color,f.light])for(const v of buf)u(v);
 i(2);
 function op(kind,paths,power,scale,o){
  i(kind);d(power);d(scale);
  for(const v of [o.light??.5,o.a??1,o.core??0,o.upTo??1,o.minY??0])d(v);
  i(o.hero?1:0);i('upTo'in o?1:0);i('minY'in o?1:0);
  i(paths.paths.length);
  for(const path of paths.paths){d(path.w);i(path.pts.length);for(const [x,y] of path.pts){d(x);d(y);}}
 }
 op(0,a,k,s,opts);stroke(p,a,k,C,s,opts);
 op(1,b,k,1,{light:.4,a:.8});crackle(p,b,k,C,.4,.8);
 for(const buf of [f.color,f.light])for(const v of buf)u(v);
}
const dir=join(root,'godot','tests','fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'cpp.bin'),Buffer.concat(parts));
console.log('Standalone original fixtures:',count);
