import {existsSync,readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
export const root=fileURLToPath(new URL('../',import.meta.url));
export const lock=JSON.parse(readFileSync(join(root,'upstream.json'),'utf8'));
export const original=join(root,'original','pixelfx');
export function verifyOriginal(){
 if(existsSync(join(original,'.git'))){
  const r=spawnSync('git',['rev-parse','HEAD'],{cwd:original,encoding:'utf8'});
  const s=spawnSync('git',['status','--porcelain','--untracked-files=no'],{cwd:original,encoding:'utf8'});
  if(r.status!==0||r.stdout.trim()!==lock.commit||s.status!==0||s.stdout.trim())throw Error('Original checkout is modified or does not match upstream.json');
  return 'git';
 }
 const path=join(root,'original','snapshot.json');
 if(!existsSync(path))throw Error('Original not installed. Run npm run setup.');
 const manifest=JSON.parse(readFileSync(path,'utf8'));
 if(manifest.commit!==lock.commit||!Array.isArray(manifest.files)||manifest.files.length<250)throw Error('Invalid original snapshot');
 const seen=new Set();
 for(const f of manifest.files){
  if(typeof f.path!=='string'||f.path.split('/').some(s=>!s||s==='..'||s==='.')||f.path.includes('\\')||f.path.includes(':')||seen.has(f.path))throw Error('Invalid snapshot path');
  seen.add(f.path);const actual=createHash('sha256').update(readFileSync(join(original,f.path))).digest('hex');
  if(actual!==f.sha256)throw Error('Original snapshot changed: '+f.path);
 }
 for(const path of ['LICENSE','package.json','src/core/index.js','tools/lib/fxlib.mjs','docs/CATALOG.md','skills/pixelfx/SKILL.md'])if(!seen.has(path))throw Error('Snapshot missing '+path);
 return 'snapshot';
}
