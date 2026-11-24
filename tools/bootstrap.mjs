import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
for(const args of [['tools/setup.mjs'],...['lightning/chain-lightning','lightning/electrified','lightning/lightning-strike','lightning/charge-up','nature/acid-splash','melee/sword-slash','explosions/big-explosion'].map(id=>['tools/export.mjs',id])]){const r=spawnSync(process.execPath,args,{cwd:root,stdio:'inherit'});if(r.status!==0)process.exit(1);}
