import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original','pixelfx');
const {createFrame,painterFor,Bits,hex}=await import(pathToFileURL(join(src,'src/core/index.js')).href);
const bits=new Bits({ground:()=>0}),specs=[],samples=[];
for(const kind of [0,1,2])for(let i=0;i<4;i++){
 const s={kind,x:-15+i*10,y:-22-i*3,vx:-35+20*i,vy:-40+i*50,a:i*.7,va:1+i*2,s:1+i*.5,c:hex('#5eb9c1')>>>0,g:1,drag:.8,bounce:.45,life:.6+i*.2};
 specs.push(s);bits.add(s);
}
let step=0;
for(const until of [0,12,36,60,100,160]){
 while(step<until){bits.update(1/120);step++;}
 const f=createFrame(128,96),p=painterFor(f);p.place(64,72);bits.draw(p);
 samples.push({step:until,bits:bits.list.map(b=>({...b,c:b.c>>>0})),color:Array.from(f.color)});
}
const dir=join(root,'godot','tests','fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'bits.json'),JSON.stringify({specs,samples}));
