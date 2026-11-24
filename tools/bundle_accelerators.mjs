// Assemble both tested platform binaries into the portable toolkit.
import {readFileSync,writeFileSync,mkdirSync,copyFileSync,appendFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const source=resolve(process.argv[2]??'');
const run=process.argv[3];if(!/^\d+$/.test(run??''))throw Error('Expected validated C++ CI run ID');
const root=resolve('dist/PixelFX-Godot-Toolkit');
const addon=join(root,'godot/addons/pixelfx');
const descriptor=readFileSync('native_cpp/pixelfx.gdextension');
const bins=[['Linux','libpixelfx.linux.x86_64.so'],['Windows','pixelfx.windows.x86_64.dll']];
const hashes={};
mkdirSync(join(addon,'bin'),{recursive:true});
for(const [platform,name] of bins){
 const dir=join(source,'pixelfx-cpp-'+platform);
 if(readFileSync(join(dir,'pixelfx.gdextension'),'utf8').replace(/\r\n/g,'\n')!==descriptor.toString('utf8').replace(/\r\n/g,'\n'))throw Error('Descriptor mismatch '+platform);
 const path=join(dir,'bin',name),data=readFileSync(path);
 if(data.length<1024||(platform==='Windows'?data.subarray(0,2).toString()!=='MZ':data.subarray(0,4).toString('hex')!=='7f454c46'))throw Error('Invalid binary '+platform);
 copyFileSync(path,join(addon,'bin',name));hashes[name]=createHash('sha256').update(data).digest('hex');
}
writeFileSync(join(addon,'pixelfx.gdextension'),descriptor);
writeFileSync(join(root,'BUILD.json'),JSON.stringify({godot:'4.4.1',cpp_run:run,architectures:['Windows x86_64','Linux x86_64'],sha256:hashes},null,2)+'\n');
appendFileSync(join(root,'PORTABLE.md'),'\n## Complete bundle\nBoth tested C++ binaries are already installed. Open godot/project.godot in Godot 4.4.1 (Windows/Linux x86-64), then run. L opens the live lab; A switches backend. No manual DLL copy or C++ compiler is required. On unsupported platforms, remove godot/addons/pixelfx/pixelfx.gdextension to use the GDScript reference. See BUILD.json for binary provenance.\n');
console.log('Bundled Windows DLL and Linux SO from verified run',run);
