import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original','pixelfx');
const {createFrame,painterFor,Particles,Lights,Rng,hex}=await import(pathToFileURL(join(src,'src/core/index.js')).href);
const sparks=['#ffffff','#c8f8ff','#7ff3ff','#1ab8e6'],col=hex('#a9defe'),seed=81;
const landed=[];const ps=new Particles({rng:new Rng(seed),ground:()=>0,sparks,haze:col,onLand:(x,y)=>landed.push([x,y])}),ls=new Lights();
const specs=[];
for(const k of [0,1,2,3,4,5,6,7,8,9,10,11])for(let i=0;i<4;i++){
 const spec=[k,-16+i*10,-24+i*3, -38+i*25, -64+i*42,0.42+i*.11,(k===8||k===9?0:col>>>0),0.8+i*.6,i===2?.025:0,(i===3?4:0)|(k===9?1:0)|((k===8||k===9)&&i===1?2:0)];
 specs.push(spec);ps.spawn(...spec);
}
ls.add(2,-20,12,col,.7,.5);ls.add(-14,-6,7,col,.8,.35);
const samples=[];let step=0;
for(const until of [0,4,18,36,60,100,160]){
 while(step<until){ps.update(1/120);ls.update(1/120);step++;}
 const f=createFrame(128,96),p=painterFor(f);p.place(64,72);
 ps.draw(p,'back');ps.draw(p,'front');ls.draw(p);
 samples.push({step:until,particles:ps.list.map(x=>({...x,col:x.col>>>0})),landed:landed.map(x=>[...x]),color:Array.from(f.color),light:Array.from(f.light)});
}
const dir=join(root,'godot','tests','fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'particles.json'),JSON.stringify({seed,sparks,col:col>>>0,specs,samples}));
