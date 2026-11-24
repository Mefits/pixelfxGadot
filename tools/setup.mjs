import {readFileSync,existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
const root=fileURLToPath(new URL('../',import.meta.url));
const lock=JSON.parse(readFileSync(join(root,'upstream.json'),'utf8'));
const dest=join(root,'original','pixelfx');
function git(args,cwd=root){const r=spawnSync('git',args,{cwd,stdio:'inherit'});if(r.status!==0)throw Error('git failed: '+args.join(' '));}
if(existsSync(join(root,'.git')))git(['submodule','update','--init','--recursive','original/pixelfx']);
else if(!existsSync(join(dest,'.git'))){git(['clone','--no-checkout',lock.url,dest]);git(['checkout','--detach',lock.commit],dest);}
const r=spawnSync('git',['rev-parse','HEAD'],{cwd:dest,encoding:'utf8'});
const s=spawnSync('git',['status','--porcelain'],{cwd:dest,encoding:'utf8'});
if(r.status!==0||r.stdout.trim()!==lock.commit||s.status!==0||s.stdout.trim())throw Error('Original must be clean and match upstream.json');
console.log('Original PixelFX ready:',lock.commit);
