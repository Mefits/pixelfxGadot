// Ground truth from actual upstream composite; no Godot implementation involved.
import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'original','pixelfx');
const imp=p=>import(pathToFileURL(join(src,p)).href);
const {loadEffect,renderFrames}=await imp('tools/lib/fxlib.mjs');
const {composite}=await imp('src/core/index.js');
const {encodePNG}=await imp('tools/lib/png.mjs');
const dir=join(root,'godot','tests','fixtures');mkdirSync(dir,{recursive:true});
const fx=await loadEffect('lightning/chain-lightning'),r=renderFrames(fx);
const indices=[6,12,20];
for(const i of indices)for(const bg of [[18,24,36],[190,180,160]]){
 const f=r.frames[i],b=(0xff000000|bg[0]|bg[1]<<8|bg[2]<<16)>>>0;
 const rgba=composite({w:r.w,h:r.h,color:f.raw,light:f.light},new Uint8ClampedArray(r.w*r.h*4),b);
 writeFileSync(join(dir,'chain_'+i+'_'+bg[0]+'.png'),encodePNG(r.w,r.h,rgba));
}
