// Full 120-frame reference from actual original effect; packed RGBA/light.
import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original','pixelfx');
const imp=p=>import(pathToFileURL(join(src,p)).href);
const {createFrame,painterFor}=await imp('src/core/index.js');
const {meta,draw}=await imp('src/fx/lightning/ball-lightning.js');
const parts=[];
for(let i=0;i<120;i++){const f=createFrame(...meta.size),p=painterFor(f);p.place(...meta.origin);draw(p,i/30,meta.options);for(const buf of [f.color,f.light])parts.push(Buffer.from(buf.buffer,buf.byteOffset,buf.byteLength));}
const dir=join(root,'godot','tests','fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'ball.bin'),Buffer.concat(parts));
