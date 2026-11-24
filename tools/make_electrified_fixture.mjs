import {writeFileSync,mkdirSync} from 'node:fs';import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original/pixelfx/src');
const core=await import(pathToFileURL(join(src,'core/index.js')).href),mod=await import(pathToFileURL(join(src,'fx/lightning/electrified.js')).href);
const chunks=[];
for(const k of [2,1]){
 const o={...mod.meta.options,actor:core.stockActor(k)};
 for(let i=0;i<60;i++){
  const frame=core.createFrame(108,92),p=core.painterFor(frame);p.place(54,76);
  mod.drawBack(p,i/30,o);mod.draw(p,i/30,o);
  for(const b of [frame.color,frame.light])chunks.push(Buffer.from(b.buffer,b.byteOffset,b.byteLength));
 }
}
const dir=join(root,'godot/tests/fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'electrified.bin'),Buffer.concat(chunks));
