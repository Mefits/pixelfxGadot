// The actual upstream renderer is the source of every frame. No approximation.
import {readFileSync,writeFileSync,mkdirSync,existsSync,renameSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {verifyOriginal} from './verify_original.mjs';
import {createHash} from 'node:crypto';
import {splitFrame,reconstruct,packPages} from './buffers.mjs';
const root=fileURLToPath(new URL('../',import.meta.url));
const lock=JSON.parse(readFileSync(join(root,'upstream.json'),'utf8'));
const [id,...args]=process.argv.slice(2);
if(!id||!/^[a-z0-9-]+\/[a-z0-9-]+$/.test(id))throw Error('Usage: node tools/export.mjs lightning/chain-lightning [--seed 3] [--fps 30] [--opts JSON] [--name name] [--max 2048]');
const flags={};for(let i=0;i<args.length;i+=2){if(!['--seed','--fps','--opts','--name','--max'].includes(args[i])||args[i+1]===undefined)throw Error('Invalid flag '+args[i]);flags[args[i]]=args[i+1];}
const original=join(root,'original','pixelfx');
if(!existsSync(join(original,'tools/lib/fxlib.mjs')))throw Error('Run npm run setup first.');
verifyOriginal();
const imp=p=>import(pathToFileURL(join(original,p)).href);
const {loadEffect,renderFrames,contactSheet}=await imp('tools/lib/fxlib.mjs');
const {encodePNG}=await imp('tools/lib/png.mjs');
const {composite}=await imp('src/core/index.js');
const fx=await loadEffect(id),options=flags['--opts']?JSON.parse(flags['--opts']):{};
if(!options||typeof options!=='object'||Array.isArray(options))throw Error('opts must be an object');
for(const k of ['x','y','flip','angle','actor'])if(k in options)throw Error('Reserved option '+k);
const fps=flags['--fps']?Number(flags['--fps']):fx.meta.fps,seed=flags['--seed']===undefined?undefined:Number(flags['--seed']),max=Number(flags['--max']??2048);
if(!Number.isInteger(fps)||fps<1||fps>120||!Number.isInteger(max)||max<64||max>4096||(seed!==undefined&&!Number.isSafeInteger(seed)))throw Error('Invalid fps/seed/max');
const result=renderFrames(fx,{fps,seed,options});
let maxError=0;for(const f of result.frames){const s=splitFrame(f.raw,f.light);for(const bg of [[0,0,0],[18,24,36],[190,180,160]]){const b=(0xff000000|bg[0]|bg[1]<<8|bg[2]<<16)>>>0;const ref=composite({w:result.w,h:result.h,color:f.raw,light:f.light},new Uint8ClampedArray(result.w*result.h*4),b);const got=reconstruct(s.color,s.glow,bg);for(let i=0;i<got.length;i++)maxError=Math.max(maxError,Math.abs(got[i]-ref[i]));}}
if(maxError>1)throw Error('Composition parity failed: '+maxError);
const name=flags['--name']??id.replace('/','_');if(!/^[a-zA-Z0-9_-]+$/.test(name))throw Error('Invalid name');
const dir=join(root,'godot','generated',name),tmp=dir+'.tmp';rmSync(tmp,{recursive:true,force:true});mkdirSync(tmp,{recursive:true});
const out=(n,b)=>writeFileSync(join(tmp,n),b),hash=b=>createHash('sha256').update(b).digest('hex');
const pages=[],frames=[];
for(const p of packPages(result.frames,result.w,result.h,max)){const i=pages.length,c='color_'+i+'.png',l='light_'+i+'.png',cb=encodePNG(p.aw,p.ah,p.color),lb=encodePNG(p.aw,p.ah,p.glow);out(c,cb);out(l,lb);pages.push({color:c,light:l,size:[p.aw,p.ah],sha256:{color:hash(cb),light:hash(lb)}});for(const rect of p.rects)frames.push({page:i,rect});}
out('reference.png',contactSheet(fx,result));
const manifest={schema:2,id,upstream:lock.commit,options,seed:seed??fx.meta.options?.seed??null,fps:result.fps,loop:!!fx.meta.loop,duration:fx.meta.duration,pivot:fx.meta.origin,frame_size:[result.w,result.h],frames,pages,actor_dependent:!!fx.meta.actor,parity:{backgrounds:3,frames:result.n,max_channel_error:maxError}};
out('clip.json',JSON.stringify(manifest,null,2));rmSync(dir,{recursive:true,force:true});renameSync(tmp,dir);
console.log('Exported '+id+': '+frames.length+' frames, '+pages.length+' pages, parity max error '+maxError);
