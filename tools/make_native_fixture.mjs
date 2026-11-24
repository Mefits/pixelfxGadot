// Fixtures are generated directly by the locked original, not by the port.
import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original','pixelfx');
const imp=p=>import(pathToFileURL(join(src,p)).href);
const {createFrame,painterFor,Rng,hash,fit,hex}=await imp('src/core/index.js');
const {zigzag,bowed,stroke,crackle,VOLT}=await imp('src/fx/lightning/_lib.js');
const rngs=[0,1,3,4294967295,-17].map(seed=>{const r=new Rng(seed);return {seed,values:Array.from({length:32},()=>r.next()*4294967296)};});
const hashes=[[1,2,3],[-3,4,4294967295],[],[17,0,-42]].map(ns=>({ns,value:hash(...ns)}));
const frame=createFrame(80,64,-8,-8),p=painterFor(frame),c=fit(VOLT,8);
p.place(10,12,true,0.23);p.fade=.76;p.lightK=.84;
p.dot(5,5,c[5],.8);p.line(-12,-4,13,15,c[7],.6);p.blend(1,1,c[4],.3);p.blend(1,1,c[5],.45);p.glow(2,3,9,c[4],.7);
const painter={color:Array.from(frame.color),light:Array.from(frame.light)};
const bolts=[];
for(const seed of [1,3,51]){
 const f=createFrame(128,96),p=painterFor(f),r=new Rng(seed);
 p.place(12,48);
 const a=zigzag(r,0,0,77,-13,.27,.7);
 stroke(p,a,.85,c,.85,{a:.86});
 const b=bowed(r,3,3,58,10,-9,.22,.4);
 crackle(p,b,.9,c,.35,.8);
 bolts.push({seed,paths:a.paths,color:Array.from(f.color),light:Array.from(f.light)});
}
const dir=join(root,'godot','tests','fixtures');mkdirSync(dir,{recursive:true});
writeFileSync(join(dir,'native.json'),JSON.stringify({rngs,hashes,painter,bolts}));
