import {writeFileSync,mkdirSync} from 'node:fs';import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original/pixelfx/src/core');
const c=await import(pathToFileURL(join(src,'index.js')).href);
const ps=new c.Particles({rng:new c.Rng(37),ground:()=>0}),b=new c.Blazes(ps);b.add(-13,0,1.2,.8);b.add(16,0,.8,1.1);
const samples=[];let step=0;
for(const until of [0,12,36,60,100,150]){
 while(step<until){b.update(1/120);ps.update(1/120);step++;}
 const f=c.createFrame(144,104),p=c.painterFor(f);p.place(72,78);
 c.flare(p,-36,-34,14,.75,c.PAL.ice);
 c.band(p,10,-38,19,.45,4,.72,c.PAL.ice,a=>Math.sin(a)>0,true);
 c.crystal(p,39,-2,30,12,-6,c.PAL.ice,{glint:.5,a:.9});
 b.drawBack(p);ps.draw(p);
 samples.push({step:until,blazes:b.list.length,particles:ps.list.length,color:Array.from(f.color),light:Array.from(f.light)});
}
const dir=join(root,'godot/tests/fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'sim_helpers.json'),JSON.stringify(samples));
