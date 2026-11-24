import {writeFileSync,mkdirSync} from 'node:fs';import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original/pixelfx/src/core');
const m=await import(pathToFileURL(join(src,'math.js')).href),s=await import(pathToFileURL(join(src,'shapes.js')).href),a=await import(pathToFileURL(join(src,'actor.js')).href),p=await import(pathToFileURL(join(src,'particles.js')).href);
const values=[];for(const t of [-1.23,-.1,0,.37,1.9,12.4])values.push([t,m.noise(t,31),m.noise2(t,t*.8,31),m.fbm(t,t*.8,31),m.tileNoise(t,t*.8,4,7,31),m.tileFbm(t,t*.8,4,7,31),m.loopNoise(t,2,31)]);
const r=new m.Rng(101),bolt=s.bolt(r,0,0,40,12),forks=s.forks(r,bolt);
const emissions=[];p.cycle(.8,1.2,12,44,r=>r.range(.1,.8),(age,life,r,i)=>emissions.push([age,life,r.next(),i]));
const actors=[1,2].map(k=>{const v=a.stockActor(k);return {data:Array.from(v.mask.data),pixels:Array.from(v.pixels),x:v.x,y:v.y};});
const easings=Object.keys(m.ease).map(name=>[name,[0,.13,.49,.7,.99,1].map(t=>m.ease[name](t))]);
const dir=join(root,'godot/tests/fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'core.json'),JSON.stringify({values,bolt,forks,emissions,actors,easings}));
