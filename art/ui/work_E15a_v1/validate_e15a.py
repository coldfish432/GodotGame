"""Static PNG checks; no claim of art acceptance or engine integration."""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image
from build_e15a import boundary, OUTLINE
B=Path(__file__).resolve().parent

def main():
    manifest=json.loads((B/'manifest.json').read_text(encoding='utf-8'))
    report={'scope':'static PNG checks only','runtime_verified':False,'style_accepted':False,'items':[]}
    for row in manifest['items']:
        path=B/row['file'];im=Image.open(path);a=np.array(im.convert('RGBA'));mask=a[:,:,3]>0
        rgb=a[:,:,:3].astype(float);lum=(rgb@[.2126,.7152,.0722])/255
        bright=float(np.mean(lum[mask]>=.6));colors=len(np.unique(a[mask,:3],axis=0))
        edge=boundary(mask);outline_ok=bool(np.all(a[edge,:3]==OUTLINE))
        isolated=0;eligible=0
        for y,x in zip(*np.where(mask)):
            if tuple(a[y,x,:3])==OUTLINE:continue
            eligible+=1
            sub=a[max(0,y-1):y+2,max(0,x-1):x+2]
            same=(sub[:,:,:3]==a[y,x,:3]).all(axis=2)&(sub[:,:,3]>0)
            isolated+=int(same.sum()==1)
        noise=isolated/max(1,eligible)
        cloth=row['id'] in ['mine_head_2','mine_hands_1','mine_hands_2','mine_legs_1','mine_legs_2','mine_legs_3','mine_feet_2','mine_feet_4']
        checks={'size':list(im.size)==row['size'],'rgba':im.mode=='RGBA','binary_alpha':set(np.unique(a[:,:,3])).issubset({0,255}),'palette_le24':colors<=24,'bright_ge15pct':bright>=.15,'outline_1px':outline_ok,'padding':not(mask[0].any()or mask[-1].any()or mask[:,0].any()or mask[:,-1].any()),'cloth_isolated_le10pct':noise<=.1 if cloth else True,'source_exists':(B/row['source']).is_file(),'hash':hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']}
        yy,xx=np.where(mask)
        result={'id':row['id'],'checks':checks,'colors':colors,'bright_fraction':round(bright,4),'isolated_fraction':round(noise,4),'cloth_noise_enforced':cloth,'bbox':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],'pass':all(checks.values())}
        report['items'].append(result)
        print(f"{row['id']}: {'PASS' if result['pass'] else 'FAIL'} bright={bright:.1%} isolated={noise:.1%} colors={colors}",','.join(k for k,v in checks.items() if not v))
    base=np.array(Image.open(B/'mine_ring_2.png').convert('RGBA'));emit=np.array(Image.open(B/'mine_ring_2_emit.png').convert('RGBA'));m=emit[:,:,3]>0
    report['emit']={'size':emit.shape==base.shape,'nonempty':bool(m.any()),'localized_to_base':bool(np.all(base[m,3]==255)),'same_rgb_as_base':bool(np.all(emit[m]==base[m])),'binary_alpha':set(np.unique(emit[:,:,3])).issubset({0,255}),'glowing_pixels':int(m.sum()),'not_full_silhouette':int(m.sum())<int((base[:,:,3]>0).sum())*.1}
    report['pass']=len(report['items'])==20 and all(x['pass'] for x in report['items']) and all(v for k,v in report['emit'].items() if k!='glowing_pixels')
    (B/'qa_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('STATIC', 'PASS' if report['pass'] else 'FAIL',report['emit'])
    return 0 if report['pass'] else 1
if __name__=='__main__':sys.exit(main())
