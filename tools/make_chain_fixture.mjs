import {writeFileSync,mkdirSync} from 'node:fs';import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original/pixelfx/src');
const core=await import(pathToFileURL(join(src,'core/index.js')).href),mod=await import(pathToFileURL(join(src,'fx/lightning/chain-lightning.js')).href);
const parts=[];const fx=core.createFx(mod,{x:40,y:82});
for(let i=0;i<54;i++){const frame=core.createFrame(248,104);fx.draw(frame);for(const b of [frame.color,frame.light])parts.push(Buffer.from(b.buffer,b.byteOffset,b.byteLength));fx.update(1/30);}
const dir=join(root,'godot/tests/fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'chain.bin'),Buffer.concat(parts));
