/** Adapt a baked Lab spatial take to the pinned PixelFX three-dimensional solver.
 * Output is a joint track; the comparison images are drawn by the Godot skin.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { skeleton } from '../original/pixelfx/src/core/rig.js';
import { verifyOriginal } from './verify_original.mjs';

const [sourceFile, eventFile, outputFile] = process.argv.slice(2);
if (!outputFile) throw Error('Usage: node tools/upstream_motion.mjs depth.json rd_air_g.json upstream.json');
verifyOriginal();
const source = JSON.parse(readFileSync(sourceFile,'utf8'));
const eventClip = JSON.parse(readFileSync(eventFile,'utf8')).payload.clip;
const jointMap = {hips:'pelvis', chest:'chest',head:'head',shoulder_near:'shoulderN',elbow_near:'elbowN',hand_near:'handN',
  shoulder_far:'shoulderF',elbow_far:'elbowF',hand_far:'handF',thigh_near:'hipN',knee_near:'kneeN',foot_near:'ankleN',
  thigh_far:'hipF',knee_far:'kneeF',foot_far:'ankleF'};
const targets = [
  ['hand_near','fx','fy','fz'], ['hand_far','bx','by','bz'],
  ['foot_near','ffx','ffy','fzz'], ['foot_far','fbx','fby','bzz']
];
const scale = (Math.hypot(4,10)+Math.hypot(1,10))/(7.6+7.4);
const frames=[];
for (const pose of source.frames) {
  const pelvis=pose.hips;
  const dx=pose.chest[0]-pelvis[0], dy=pelvis[1]-pose.chest[1];
  const shoulder=pose.shoulder_near.map((v,i)=>v-pose.shoulder_far[i]);
  const q={lean:Math.max(-13,Math.min(13,13*dx/Math.max(1,dy))),turn:Math.atan2(-shoulder[0],Math.max(4,shoulder[2])),crouch:0};
  let guess=[0,-19.7,0];
  let solved;
  for(let iteration=0;iteration<4;iteration++){
    for (const [name,x,y,z] of targets) {
      q[x]=guess[0]+(pose[name][0]-pelvis[0])/scale;
      q[y]=guess[1]+(pose[name][1]-pelvis[1])/scale-(name.startsWith('foot')?1.8:0);
      q[z]=guess[2]+(pose[name][2]-pelvis[2])/scale;
    }
    solved=skeleton(q).joints;
    guess=solved.pelvis;
  }
  const joints={};
  for(const [lab,upstream] of Object.entries(jointMap))
    joints[lab]=solved[upstream].map((v,i)=>pelvis[i]+(v-solved.pelvis[i])*scale);
  frames.push(joints);
}
function project(p,id){
  const [x,y,z]=p[id], h=p.hips, k=82/(82-z);
  return [h[0]+(x-h[0])*k,h[1]+(y-h[1])*k];
}
const errors=eventClip.events.map(e=>{
  const i=Math.round(e.t*source.hz), a=project(source.frames[i],e.anchor), b=project(frames[i],e.anchor);
  return {tick:i,anchor:e.anchor,projected_offset_px:Math.hypot(a[0]-b[0],a[1]-b[1])};
});
writeFileSync(outputFile,JSON.stringify({format:'lab.joints3.v1',hz:source.hz,events:eventClip.events,frames,source_solver:'patch-gg/pixelfx@5294518',impact_residuals:errors}),{flag:'wx'});
console.log(JSON.stringify(errors));
