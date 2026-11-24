// Convert the upstream packed RGBA and additive RGB without changing the pixels.
export function splitFrame(raw,light){
 if(raw.length!==light.length)throw Error('Buffer size mismatch');
 const color=new Uint8ClampedArray(raw.length*4),glow=new Uint8ClampedArray(raw.length*4);
 for(let i=0;i<raw.length;i++){const c=raw[i],l=light[i],j=i*4;color[j]=c&255;color[j+1]=(c>>>8)&255;color[j+2]=(c>>>16)&255;color[j+3]=c>>>24;glow[j]=l&255;glow[j+1]=(l>>>8)&255;glow[j+2]=(l>>>16)&255;glow[j+3]=255;}
 return {color,glow};
}
export function reconstruct(color,glow,bg){
 if(color.length!==glow.length||color.length%4)throw Error('Buffer size mismatch');
 const out=new Uint8ClampedArray(color.length);for(let j=0;j<out.length;j+=4){const a=color[j+3]/255;for(let c=0;c<3;c++)out[j+c]=Math.min(255,color[j+c]*a+bg[c]*(1-a)+glow[j+c]);out[j+3]=255;}return out;
}
export function* packPages(frames,w,h,max=2048){
 if(!frames.length||![w,h,max].every(Number.isInteger)||w<=0||h<=0||w>max||h>max)throw Error('Unsupported frame size');
 const maxCols=Math.floor(max/w),maxRows=Math.floor(max/h),capacity=maxCols*maxRows;
 for(let offset=0;offset<frames.length;offset+=capacity){
  const count=Math.min(capacity,frames.length-offset);
  const cols=Math.max(Math.ceil(count/maxRows),Math.min(maxCols,Math.ceil(Math.sqrt(count*h/w))));
  const rows=Math.ceil(count/cols),aw=cols*w,ah=rows*h;
  const color=new Uint8ClampedArray(aw*ah*4),glow=new Uint8ClampedArray(aw*ah*4),rects=[];
  for(let i=0;i<count;i++){const x=(i%cols)*w,y=Math.floor(i/cols)*h,f=frames[offset+i];if(f.raw.length!==w*h||f.light.length!==w*h)throw Error('Frame size mismatch');rects.push([x,y,w,h]);const p=splitFrame(f.raw,f.light);for(let row=0;row<h;row++){const a=row*w*4,b=((y+row)*aw+x)*4;color.set(p.color.subarray(a,a+w*4),b);glow.set(p.glow.subarray(a,a+w*4),b);}}
  yield {aw,ah,color,glow,rects,offset};
 }
}
