// Create an offline handoff folder with every original effect source, toolkit and generated assets.
import {mkdirSync,readFileSync,writeFileSync,cpSync,rmSync,existsSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {root,original,lock,verifyOriginal} from './verify_original.mjs';
if(verifyOriginal()!=='git')throw Error('Package from locked Git checkout.');
const dest=join(root,'dist','PixelFX-Godot-Toolkit');
rmSync(dest,{recursive:true,force:true});mkdirSync(dest,{recursive:true});
function tracked(cwd){const r=spawnSync('git',['ls-files','-z'],{cwd,encoding:'utf8'});if(r.status!==0)throw Error('git ls-files failed');return r.stdout.split('\0').filter(Boolean);}
function copy(src,dst){mkdirSync(dirname(dst),{recursive:true});cpSync(src,dst);}
for(const p of tracked(root)){if(p==='original/pixelfx'||p.startsWith('.github/')||p==='.gitmodules')continue;copy(join(root,p),join(dest,p));}
const files=[];
for(const p of tracked(original)){
 if(!(/^(src\/|tools\/|skills\/|docs\/[^/]+\.md$)/.test(p)||['README.md','LICENSE','package.json'].includes(p)))continue;
 const src=join(original,p);copy(src,join(dest,'original','pixelfx',p));
 files.push({path:p,sha256:createHash('sha256').update(readFileSync(src)).digest('hex')});
}
writeFileSync(join(dest,'original','snapshot.json'),JSON.stringify({commit:lock.commit,files},null,2));
for(const p of ['godot/generated','godot/tests/fixtures'])if(existsSync(join(root,p)))cpSync(join(root,p),join(dest,p),{recursive:true,filter:x=>!x.endsWith('.import')});
writeFileSync(join(dest,'PORTABLE.md'),'# Portable handoff\nThis package includes the original code, tools, documentation and all effect source modules at the locked revision, plus seven generated clips. Upstream gallery media and git history are omitted. No network or Node is needed to play the included clips in Godot. Node 18+ is needed to export new clips; no Git or network needed for exports from this snapshot. Do not modify original/pixelfx or snapshot.json.\n');
console.log('Portable package:',files.length,'original files',dest);
