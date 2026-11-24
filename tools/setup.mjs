import {existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {root,lock,original,verifyOriginal} from './verify_original.mjs';
function git(args,cwd=root){const r=spawnSync('git',args,{cwd,stdio:'inherit'});if(r.status!==0)throw Error('git failed: '+args.join(' '));}
if(existsSync(join(root,'original','snapshot.json'))||existsSync(join(original,'.git'))){
 console.log('Original PixelFX ready:',verifyOriginal(),lock.commit);
}else{
 if(existsSync(join(root,'.git')))git(['submodule','update','--init','--recursive','original/pixelfx']);
 else{git(['clone','--no-checkout',lock.url,original]);git(['checkout','--detach',lock.commit],original);}
 console.log('Original PixelFX ready:',verifyOriginal(),lock.commit);
}
