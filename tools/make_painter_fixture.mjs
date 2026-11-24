import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const {createFrame,painterFor,hex}=await import(pathToFileURL(join(root,'original/pixelfx/src/core/index.js')).href);
const C= ['#14243b','#3468a0','#65b8dd','#ffffff'].map(hex), cases=[];
for(let i=0;i<3;i++){
 const f=createFrame(104,88,-3,-5),p=painterFor(f);p.place(48,40,i===1,i===2?.34:0);p.fade=.91;p.lightK=.8;
 const col=(u,v)=>u<.5?C[1]:C[2],alpha=(u,v)=>.35+.6*u;
 p.disc(-22,-14,8,col,alpha);p.circle(-2,-14,9,col,alpha);p.ellipse(21,-14,9,5,col,alpha);p.ring(-22,8,8,4,col,alpha);
 p.arc(0,6,10,u=>2+4*Math.sin(Math.PI*u),-.7,3.4,col,alpha);
 p.beam(12,1,29,11,5,col,alpha);p.line(-30,19,-10,25,u=>u<.5?C[2]:C[3],u=>.3+.7*u);
 p.poly([[-8,20],[7,18],[1,30],[-10,28]],C[2],.86);p.tri(13,18,25,20,21,29,C[3],.72);
 p.shade(-5,-5,5,5,(x,y,o)=>{if(x*x+y*y>20)return;o.c=C[3];o.a=.7;o.l=C[2];o.k=.4;});
 p.glowLine(-15,-7,17,13,5,C[2],.55);p.glowRing(2,1,15,5,C[1],.65);
 const m={w:3,h:3,data:[0,1,0,1,1,1,0,1,0]};p.outline(m,-32,-32,C[1]);p.mask(m,-32,-32,(x,y)=>C[(x+y)%4]);
 p.sprite(['.#o','o##'],{'#':'#ffffff',o:'#65b8dd'},22,-32,{scale:2,flip:true,flipY:i===1});
 p.text('FX 21',0,-37,C[3],{font:'mini',align:'center',outline:C[0],shadow:C[1]});
 p.text('x!',26,29,C[2],{font:'big',align:'right'});
 cases.push({color:Array.from(f.color),light:Array.from(f.light),measure:p.measure('FX 21'),read:p.get(0,0)>>>0});
}
const dir=join(root,'godot/tests/fixtures');mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'painter.json'),JSON.stringify(cases));
