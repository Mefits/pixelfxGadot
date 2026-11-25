// Exercise private primitive and finish routines from the immutable MIT source.
// Patch and Hugo Duprez, 2026. See LICENSE-PixelFX.txt at repository root.
import {readFileSync, writeFileSync} from "node:fs";
import {createHash} from "node:crypto";
import vm from "node:vm";
const rig = new URL("../../original/pixelfx/src/core/rig.js", import.meta.url);
const source = readFileSync(rig, "utf8");
if (createHash("sha256").update(source).digest("hex") !== "5af3f455b18f9feb9f060732fb457529c6c76975a309c72171aa4e88b31aa70c") throw Error("unexpected rig.js revision");
const extract = (a,b) => source.slice(source.indexOf(a),source.indexOf(b,source.indexOf(a)));
const vectors = extract("const add =", "const rotY");
const raster = extract("const BW =", "// parts:");
const finish = extract("function finish(", "  // the mark on his chest");
const ring = extract("  const list = touched.slice()", "  const n = list");
const results = vm.runInNewContext(`
${vectors}
${raster}
const PART={upperF:11,handF:14,thighF:19,footF:22};
const SHELL=[0xff102030,0xff203040,0xff304050,0xff405060];
const CORE=SHELL.map(x=>x+5), INK=0xff000001, SEAM=0xff000002;
${finish}
${ring}
return [...list.map(i=>[i,Part[i],Mat[i],tones.get(i),Zb[i],Col[i]]),
 ...[...ring.keys()].map(i=>[i,0,0,0,0,INK])].map(([i,...p])=>[i%BW-OX+16,Math.floor(i/BW)-OY+16,...p]);
}
let scenes=[];
function record(){ scenes.push(finish()); Part.fill(0); touched.length=0; }
sphere([0,0,0],4,1,0); sphere([0,0,0],4,2,1); record();
sweep([-5.2,-2,1],[4.1,2.6,-1],2.25,1.15,3,1,0.7); record();
ellipsoid([1.3,-.7,1],[.8,0,.6,0,1,0,-.6,0,.8],[2,3.5,4],4,0); record();
sphere([-1,0,-1],4,1,0); sphere([2,1,2],3,2,1); record();
scenes
`);
writeFileSync(new URL("oracle.txt",import.meta.url), results.flatMap((rows,index)=>rows.map(row=>[index,...row].join(" "))).join("\n")+"\n");
