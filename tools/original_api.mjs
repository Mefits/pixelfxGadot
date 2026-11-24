// Host adapter only. All effect, rig, actor and act logic stays in the locked upstream.
export function installOriginalAPI(core, modules){
 const sessions=new Map();let next=1;
 // Optional host fast paths. Callback-based shapes always keep original JS.
 const proto=core.Painter.prototype;
 const native=globalThis.__pfxNativePrimitive;
 const original={glow:proto.glow,circle:proto.circle,disc:proto.disc,line:proto.line};
 let accelerated=false;
 const stats={calls:0,fallback:0};
 const invoke=(p,op,x,y,u,v,c,a)=>{
   if(typeof c!=='number'||typeof a!=='number')return false;
   if(native.call(p,op,x,y,u,v,c,a)){stats.calls++;return true;}
   stats.fallback++;return false;
 };
 function setAcceleration(enabled){
  if(enabled&&!native)return false;
  if(enabled===accelerated)return true;
  accelerated=enabled;
  if(!enabled){Object.assign(proto,original);return true;}
  proto.glow=function(x,y,r,c,k=.5){if(!invoke(this,0,x,y,r,0,c,k))return original.glow.call(this,x,y,r,c,k);};
  proto.circle=function(x,y,r,c,a=1){if(!invoke(this,1,x,y,r,0,c,a))return original.circle.call(this,x,y,r,c,a);};
  proto.disc=function(x,y,r,c,a){if(!invoke(this,2,x,y,r,0,c,a))return original.disc.call(this,x,y,r,c,a);};
  proto.line=function(x,y,bx,by,c,a=1){if(!invoke(this,3,x,y,bx,by,c,a))return original.line.call(this,x,y,bx,by,c,a);};
  return true;
 }
 function session(id){const s=sessions.get(id);if(!s)throw Error('Unknown instance '+id);return s;}
 function options(raw){const o=JSON.parse(raw);if(o.actor){
  const a=o.actor;if(a.mask)a.mask.data=Uint8Array.from(a.mask.data);
  if(a.pixels)a.pixels=Uint32Array.from(a.pixels);
 }return o;}
 return {
  setAcceleration,
  accelerationStats(){return JSON.stringify(stats);},
  catalog(){return JSON.stringify(Object.entries(modules).map(([id,m])=>({id,meta:m.meta,act:!!m.act})));},
  timing(id){const m=modules[id];if(!m)throw Error('Unknown effect '+id);return JSON.stringify(core.actTiming(m));},
  bounds(id){const m=modules[id];if(!m)throw Error('Unknown effect '+id);return JSON.stringify(core.actBounds(m));},
  pose(poseJson){const p=core.posed(JSON.parse(poseJson));return JSON.stringify({n:p.n,x0:p.x0,y0:p.y0,x1:p.x1,y1:p.y1,xs:Array.from(p.xs).slice(0,p.n),ys:Array.from(p.ys).slice(0,p.n),color:Array.from(p.color).slice(0,p.n),src:Array.from(p.src).slice(0,p.n)});},
  create(id,raw,mode){const m=modules[id];if(!m)throw Error('Unknown effect '+id);if(sessions.size>=128)throw Error('Instance limit 128');
   const o=options(raw),inst=mode==='act'?core.createAct(m,o):core.createFx(m,o);const h=next++;sessions.set(h,{m,inst,mode,frame:null});return h;},
  destroy(id){return sessions.delete(id);},
  update(id,dt){session(id).inst.update(dt);return true;},
  stop(id){session(id).inst.stop();return true;},
  placement(id,raw){const s=session(id);if(s.mode==='act')throw Error('Act placement is fixed at creation');
   const o=JSON.parse(raw);for(const k of ['x','y','flip','angle','light'])if(k in o)s.inst.options[k]=o[k];return true;},
  state(id){const {inst,mode}=session(id);return JSON.stringify({t:inst.t,done:inst.done(),shake:mode==='act'?inst.shake:[0,0],frozen:mode==='act'?inst.frozen:false,pose:mode==='act'?inst.pose:null});},
  render(id,w,h,ox,oy,layer,body,target,color,light){
   const s=session(id),inst=s.inst;
   if(!s.frame||s.frame.w!==w||s.frame.h!==h||s.frame.ox!==ox||s.frame.oy!==oy)s.frame=core.createFrame(w,h,ox,oy);
   const f=s.frame;f.color.set(new Uint32Array(color));f.light.set(new Uint32Array(light));
   if(s.mode==='act'){
    if(layer!=='')throw Error('Act mode requires combined layer');
    inst.draw(f,{body,target});
   }else if(body&&layer===''){
    inst.draw(f,'back');
    const o=inst.options,a=o.actor;
    if(a&&s.m.meta.actor){
     const t=s.m.meta.loop?inst.t%s.m.meta.duration:Math.min(inst.t,s.m.meta.duration);
     core.drawActor(core.painterFor(f).place(o.x??0,o.y??0,!!o.flip,o.angle??0),a,core.actorAlphaOf(s.m,t,o));
    }
    inst.draw(f,'front');
   }else inst.draw(f,layer||undefined);
   const out=new Uint32Array(w*h*2);out.set(f.color);out.set(f.light,w*h);return out.buffer;
  }
 };
}
