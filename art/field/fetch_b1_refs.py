"""Fetch PRTS costume references only. Never used as finished character art."""
from pathlib import Path
import hashlib
import json
import requests
from urllib.parse import urlparse

ROOT=Path(__file__).resolve().parent/'refs_B1'
NAMES={'patriot':['爱国者'],'rat_king':['鼠王','“鼠王”'],'eikthyrnir':['“木裂”埃克提尔尼尔','埃克提尔尼尔'],'zaro':['扎罗，“狼之主”','扎罗','“狼之主”'],'crownslayer':['弑君者'],'skullshatterer':['碎骨'],'hollow_snowpriest':['空洞雪祀'],'father_agnir':['阿格尼尔神父']}

def main():
    ROOT.mkdir(exist_ok=True)
    (ROOT/'prts').mkdir(exist_ok=True)
    session=requests.Session()
    session.headers['User-Agent']='B1ArtReferenceFetch/1.0 (costume reference; personal project)'
    report={}
    for ident,names in NAMES.items():
        titles='|'.join('文件:头像_敌人_'+name+'.png' for name in names)
        response=session.get('https://prts.wiki/api.php',params={'action':'query','format':'json','titles':titles,'prop':'imageinfo','iiprop':'url','redirects':1},timeout=45)
        response.raise_for_status()
        pages=response.json().get('query',{}).get('pages',{})
        found=[p for p in pages.values() if p.get('imageinfo')]
        if not found:
            report[ident]={'status':'MISSING','tried':names}
            print(ident,'MISSING')
            continue
        entry=found[0]
        info=entry['imageinfo'][0]
        image=None
        for url in ['https://prts.wiki/images'+urlparse(info['url']).path,info['url'],'http://media.prts.wiki'+urlparse(info['url']).path]:
            try:
                candidate=session.get(url,timeout=(5,15))
                if candidate.status_code==200 and candidate.content.startswith(b'\x89PNG'):
                    image=candidate
                    break
            except requests.RequestException: pass
        if image is None:
            report[ident]={'status':'DOWNLOAD_FAILED','file_title':entry['title'],'page':info['descriptionurl'],'image_url':info['url']}
            print(ident,'DOWNLOAD_FAILED',info['url'],flush=True)
            continue
        path=ROOT/'prts'/f'enemy_{ident}.png'
        if not image.content.startswith(b'\x89PNG'): raise ValueError(f'{ident}: expected PNG')
        path.write_bytes(image.content)
        report[ident]={'status':'OK','file':str(path.relative_to(ROOT)),'file_title':entry['title'],'page':info['descriptionurl'],'image_url':info['url'],'sha256':hashlib.sha256(image.content).hexdigest()}
        print(ident,'OK',info['url'])
    (ROOT/'reference_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    (ROOT/'prts_sources.md').write_text('# B1 PRTS references\n\nFetched 2026-10-19 after user authorization. Costume, silhouette and colour reference only; do not trace or copy into finished sprites.\n\n'+'\n'.join(f"- {ident}: {entry.get('page','MISSING')}\n  - Image: {entry.get('image_url','MISSING')}" for ident,entry in report.items()),encoding='utf-8')

if __name__=='__main__': main()
