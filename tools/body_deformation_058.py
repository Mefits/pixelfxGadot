"""Reproduce exact historical inputs, Godot A/B/C captures and quantitative review."""
import argparse
import hashlib
import shutil
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT/"godot/tests/fixtures/body_raster/poses.json"
LABELS = ("A   0.54 organic", "B   0.57 C weighted", "C   0.58 anatomical lofts")
# Zero-based primitive indices in the neutral Lab adapter.
LINKS = [(0,1),(1,18)]
for base, hand, shoe in [(2,14,15),(8,16,17)]:
    LINKS.extend([(0,base),(base,base+1),(base+1,base+2),(base+2,hand),
                  (0,base+3),(base+3,base+4),(base+4,base+5),(base+5,shoe)])


def fetch(out, clip):
    target=out/(clip["clip"]+".json")
    shutil.copyfile(FIXTURES.parent/'full_058'/target.name,target)
    assert hashlib.sha256(target.read_bytes()).hexdigest()==clip["sha256"]


def intervals(part,x,y):
    """Independent interval oracle, including both sides of each opaque volume."""
    if part['type']=='ellipsoid':
        cx,cy,cz=part['center']
        rx,ry,rz=part['radii']
        m=part['basis']
        # All rigid Lab details are rotations about z.
        assert m[2]==m[5]==m[6]==m[7]==0 and m[8]==1
        u=(m[0]*(x-cx)+m[3]*(y-cy))/rx
        v=(m[1]*(x-cx)+m[4]*(y-cy))/ry
        k=1-u*u-v*v
        h=rz*np.sqrt(np.maximum(k,0))
        valid=k>=0
        z=cz
    else:
        ax,ay,az=part['a']
        bx,by,bz=part['b']
        dx,dy=bx-ax,by-ay
        length=np.hypot(dx,dy)
        t=((x-ax)*dx+(y-ay)*dy)/length**2
        v=(-(x-ax)*dy+(y-ay)*dx)/length
        rows=np.array(part['sections']).T
        left,right,depth,offset=(np.interp(t,rows[0],values) for values in rows[1:])
        u=(2*v-right+left)/(right+left)
        p=part['profile']
        h=depth*np.maximum(0,1-abs(u)**p)**(1/p)
        z=az+(bz-az)*t+offset
        valid=(t>=rows[0,0])&(t<=rows[0,-1])&(abs(u)<=1)
    return np.where(valid,z-h,1e4),np.where(valid,z+h,-1e4)


def union_volume(lo,hi,density):
    order=np.argsort(lo,axis=0)
    lows=np.take_along_axis(lo,order,axis=0)
    highs=np.take_along_axis(hi,order,axis=0)
    ends=np.maximum.accumulate(highs,axis=0)
    prev=np.concatenate((np.full_like(ends[:1],-1e4),ends[:-1]))
    return np.maximum(0,highs-np.maximum(lows,prev)).sum()/density**2


def stats(values):
    return dict(zip(("min","p50","p95","max"),map(float,np.percentile(values,[0,50,95,100]))))


def labelled(path):
    src=Image.open(path).convert("RGB")
    im=Image.new("RGB",(864,266),"#192632")
    im.paste(src,(0,26))
    d=ImageDraw.Draw(im)
    for i,title in enumerate(LABELS):
        d.text((i*288+12,7),title,fill="white")
    return im


def review(out,dest,clips):
    dest.mkdir(parents=True,exist_ok=True)
    source=json.loads((out/"records.json").read_text())
    rows=source['rows']
    solids=json.loads((out/"solids.json").read_text())
    assert len(rows)==len(solids)==192
    measures=[]
    for row,scene in zip(rows,solids):
        clip,tick=row['clip'],row['tick']
        assert [clip,tick]==[scene['clip'],scene['tick']]
        path=out/f'{clip}-{tick:03}.png'
        rgb=np.array(Image.open(path).convert("RGB")).reshape(240,3,288,3)
        masks=np.any(rgb!=rgb[0,0,0],axis=-1)&np.any(rgb!=0,axis=-1)
        counts=[int(label(masks[:,i])[1]) for i in range(3)]
        # Reuse native visible bounds with a wide guard; an out-of-frame object fails capture.
        yy,xx=np.where(masks[:,2])
        sy=slice(max(0,yy.min()-6),min(240,yy.max()+7))
        sx=slice(max(0,xx.min()-6),min(288,xx.max()+7))
        y,x=np.mgrid[sy,sx]
        density=3
        x=(x-128)/density
        y=(y-200)/density
        bands=[intervals(p,x,y) for p in scene['parts']]
        lo,hi=(np.array(v) for v in zip(*bands))
        overlap=[np.maximum(0,np.minimum(hi[i],hi[j])-np.maximum(lo[i],lo[j])) for i,j in LINKS]
        # Volume in rig px³, integrating the union of depth intervals at each ray.
        pair_vol=[union_volume(lo[[i,i+1]],hi[[i,i+1]],density) for i in [3,6,9,12]]
        raw_lo,raw_hi=(np.array(v) for v in zip(*(intervals(p,x,y) for p in scene['uncorrected'])))
        raw_volume=union_volume(raw_lo,raw_hi,density)
        for i,p in enumerate(scene['covered']):
            if p['material_id']==1:
                cloth_lo,cloth_hi=intervals(p,x,y)
                body=hi[i]>=lo[i]
                assert np.all(cloth_lo[body]<=lo[i][body]+1e-6) and np.all(cloth_hi[body]>=hi[i][body]-1e-6)
        # Opposing distal limbs are independent depth lanes. A projected crossing
        # is legal; a common 3D interval would be a penetration in this proxy.
        penetration=max(np.maximum(0,np.minimum(hi[i],hi[j])-np.maximum(lo[i],lo[j])).sum()/9
                        for i,j in [(4,10),(7,13),(14,16),(15,17)])
        measures.append(dict(distal_penetration=penetration,uncorrected_volume=raw_volume,clip=clip,tick=tick,components=counts,volume=union_volume(lo,hi,density),
            limb_pair_volumes=pair_vol,min_attachment_overlap=min(a.sum()/9 for a in overlap),
            mask_difference=int(np.sum(np.any(hi>=lo,axis=0)!=masks[sy,2,sx]))))
    for name,idx in [('far_elbow',0),('far_knee',1),('near_elbow',2),('near_knee',3)]:
        assert min(m['limb_pair_volumes'][idx] for m in measures)>0,name
    assert all(m['min_attachment_overlap']>0 for m in measures)
    assert all(m['components'][2]==1 for m in measures)
    assert max(m['mask_difference'] for m in measures)<=5
    rest=measures[0]['volume']
    assert min(m['volume']/rest for m in measures)>.90
    for i in range(4):
        assert min(m['limb_pair_volumes'][i]/measures[0]['limb_pair_volumes'][i] for m in measures)>.90
    worst=min(measures,key=lambda m:m['volume'])
    result={'worst_volume_pose':[worst['clip'],worst['tick']],
            'opposing_distal_penetration_peak':max(m['distal_penetration'] for m in measures),
            'poses':len(rows),'fk_max_error':source['max_xy'],'depth_grid_density':3,
            'rest_volume':measures[0]['volume'],'union_volume':stats([m['volume'] for m in measures]),
            'uncorrected_volume':stats([m['uncorrected_volume'] for m in measures]),
            'min_attachment_overlap':min(m['min_attachment_overlap'] for m in measures),
            'mask_difference_max_px':max(m['mask_difference'] for m in measures),
            'disconnected_frames':[sum(m['components'][i]>1 for m in measures) for i in range(3)],
            'pair_volume_ratio_range':[[min(m['limb_pair_volumes'][i]/measures[0]['limb_pair_volumes'][i] for m in measures),
                                      max(m['limb_pair_volumes'][i]/measures[0]['limb_pair_volumes'][i] for m in measures)] for i in range(4)],
            'timings_us':[{k:stats([r['lanes'][i][k] for r in rows[8:]]) for k in
                             ('place_us','emit_us','prepare_us','bridge_us','raster_us')} for i in range(3)],
            'weighted_057_audit':{k:stats([r['lanes'][1]['audit'][k] for r in rows]) for k in rows[0]['lanes'][1]['audit']}}
    (dest/'metrics.json').write_text(json.dumps(result,indent=2)+'\n')
    (dest/'pose-metrics.jsonl').write_text(''.join(json.dumps(m,separators=(',',':'))+'\n' for m in measures))
    sheet=Image.new('RGB',(864,266*5))
    for i,(name,tick) in enumerate([('stand',0),(clips[2]['clip'],0),(clips[0]['clip'],12),(clips[1]['clip'],38),(clips[2]['clip'],50)]):
        tile=labelled(out/f'{name}-{tick:03}.png')
        ImageDraw.Draw(tile).text((707,7),f'{name}  {tick:02}',fill='white')
        sheet.paste(tile,(0,266*i))
    sheet.save(dest/'comparison.png')
    # Concatenate existing clips with separate title/tick labels. Keep even impact
    # ticks and each final interval. GIF delays are rounded cumulatively to 10 ms.
    for speed,filename in [(1.1,'comparison-1p1.gif'),(.5,'comparison-half.gif')]:
        frames=[]; ends=[]; elapsed=0.
        for clip in clips:
            name=clip['clip']
            duration=json.loads((out/(name+'.json')).read_text())['payload']['clip']['duration']
            ticks=round(duration*60)
            for t in range(0,ticks,2):
                img=labelled(out/f'{name}-{t:03}.png')
                ImageDraw.Draw(img).text((690,7),f'{name}  {t:02}',fill='white')
                frames.append(img)
                elapsed+=min(2,ticks-t)/(60*speed)
                ends.append(round(elapsed*100)*10)
        frames[0].save(dest/filename,save_all=True,append_images=frames[1:],
                       duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(dest/filename) as check:
            assert check.n_frames==len(frames)
            delays=[]
            for i in range(check.n_frames):
                check.seek(i);delays.append(check.info['duration'])
            assert sum(delays)==ends[-1] and min(delays)>=20


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',default='godot')
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--results',type=Path,default=ROOT/'docs/body-deformation-058')
    parser.add_argument('--review-only',action='store_true')
    args=parser.parse_args()
    out=args.out.resolve()
    out.mkdir(exist_ok=True,parents=True)
    clips=json.loads(FIXTURES.read_text())['clips']
    for clip in clips:fetch(out,clip)
    if not args.review_only:
        subprocess.run([args.godot,'--path',str(ROOT/'godot'),'--audio-driver','Dummy','--disable-vsync',
                        '--rendering-method','gl_compatibility','--script','res://tests/body_deformation_058.gd',
                        '--',str(out)],check=True,timeout=180)
    review(out,args.results,clips)
