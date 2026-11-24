// Bundle all original modules with esbuild. Never rewrite upstream code.
import {build} from 'esbuild';
import {readdirSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {join,relative,dirname,sep} from 'node:path';
import {root,original,verifyOriginal,lock} from './verify_original.mjs';
verifyOriginal();
const {allIds}=await import(new URL('../original/pixelfx/tools/lib/fxlib.mjs',import.meta.url));
const ids=allIds();
const dir=join(root,'godot','generated','original_runtime');mkdirSync(dir,{recursive:true});
const entry=join(root,'tools','.original-entry.mjs');
const lines=['import * as core from "../original/pixelfx/src/core/index.js";','import {installOriginalAPI} from "./original_api.mjs";'];
ids.forEach((id,i)=>lines.push('import * as E'+i+' from '+JSON.stringify('../original/pixelfx/src/fx/'+id+'.js')+';'));
lines.push('globalThis.__pfx = installOriginalAPI(core,{'+ids.map((id,i)=>JSON.stringify(id)+':E'+i).join(',')+'});');
writeFileSync(entry,lines.join('\n'));
try{await build({entryPoints:[entry],bundle:true,format:'iife',platform:'neutral',target:'es2020',outfile:join(dir,'bundle.txt'),legalComments:'inline',charset:'ascii'});}
finally{rmSync(entry,{force:true});}
writeFileSync(join(dir,'manifest.json'),JSON.stringify({upstream:lock.commit,effects:ids},null,2));
console.log('Original runtime bundle:',ids.length,'effect modules');
