import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original/pixelfx/src');
const core=await import(pathToFileURL(join(src,'core/index.js')).href);
const cases=[],chunks=[];
for(const [id,mode] of [['lightning/chain-lightning','fx'],['lightning/electrified','fx'],['lightning/ball-lightning','fx'],['melee/sword-slash','act'],['lightning/electrified','act'],['nature/acid-splash','fx'],['explosions/big-explosion','fx']]){
 const m=await import(pathToFileURL(join(src,'fx',id+'.js')).href);
 let [w,h]=m.meta.size,[x,y]=m.meta.origin;
 if(mode==='act'){const b=core.actBounds(m);w=b.x1-b.x0+16;h=b.y1-b.y0+16;x=8-b.x0;y=8-b.y0;}
 const inst=mode==='act'?core.createAct(m,{x,y}):core.createFx(m,{x,y});
 const frames=[];
 for(let i=0;i<60;i++){
  if(i%5===0){const f=core.createFrame(w,h);inst.draw(f);for(const a of [f.color,f.light])chunks.push(Buffer.from(a.buffer,a.byteOffset,a.byteLength));frames.push({index:i,t:inst.t,done:inst.done(),frozen:mode==='act'?inst.frozen:false,shake:mode==='act'?inst.shake:[0,0]});}
  inst.update(1/30);
 }
 cases.push({id,mode,w,h,x,y,frames});
}
const dir=join(root,'godot/tests/fixtures');mkdirSync(dir,{recursive:true});
writeFileSync(join(dir,'original.json'),JSON.stringify(cases));writeFileSync(join(dir,'original.bin'),Buffer.concat(chunks));
console.log('Original engine fixtures:',cases.length,'cases',cases.reduce((n,c)=>n+c.frames.length,0),'frames');
