// Check generated manifests, page sizes, original revision and file hashes.
import {readFileSync,readdirSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),dir=join(root,'godot','generated');
const lock=JSON.parse(readFileSync(join(root,'upstream.json')));
const names=readdirSync(dir,{withFileTypes:true}).filter(x=>x.isDirectory()).map(x=>x.name);
assert.ok(names.length>=7,'expected seven bootstrap clips');
for(const name of names){
 const path=join(dir,name),m=JSON.parse(readFileSync(join(path,'clip.json')));
 assert.equal(m.schema,2);assert.equal(m.upstream,lock.commit);assert.ok(m.frames.length>0);assert.ok(m.parity.max_channel_error<=1);assert.equal(m.parity.frames,m.frames.length);
 for(const page of m.pages)for(const key of ['color','light']){
  const bytes=readFileSync(join(path,page[key]));assert.equal(createHash('sha256').update(bytes).digest('hex'),page.sha256[key]);
  assert.equal(bytes.readUInt32BE(16),page.size[0]);assert.equal(bytes.readUInt32BE(20),page.size[1]);
 }
 for(const f of m.frames){const p=m.pages[f.page];assert.ok(p);const [x,y,w,h]=f.rect;assert.deepEqual([w,h],m.frame_size);assert.ok(x>=0&&y>=0&&x+w<=p.size[0]&&y+h<=p.size[1]);}
 console.log(name,m.frames.length,'frames',m.pages.length,'pages',m.parity.max_channel_error,'max error');
}
