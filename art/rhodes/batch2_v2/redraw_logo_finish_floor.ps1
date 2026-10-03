$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$code = @'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Collections.Generic;
public static class RhodesLogoFloorV2 {
 static string root;static Color[] P;static List<string> log=new List<string>();
 static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);}
 static void Check(bool ok,string s){if(!ok)throw new Exception(s);}
 static void R(Bitmap b,int x,int y,int w,int h,int p){for(int yy=y;yy<y+h;yy++)for(int xx=x;xx<x+w;xx++)b.SetPixel(xx,yy,P[p]);}
 static int Near(Color c){int best=int.MaxValue,index=0;for(int i=0;i<P.Length;i++){Color q=P[i];int d=(c.R-q.R)*(c.R-q.R)+(c.G-q.G)*(c.G-q.G)+(c.B-q.B)*(c.B-q.B);if(d<best){best=d;index=i;}}return index;}
 static void Put(Bitmap d,Bitmap s,int x,int y){for(int j=0;j<s.Height;j++)for(int i=0;i<s.Width;i++){Color c=s.GetPixel(i,j);if(c.A>0)d.SetPixel(x+i,y+j,c);}}
 static void Up(Bitmap b,string n,int k){var d=New(b.Width*k,b.Height*k);for(int y=0;y<d.Height;y++)for(int x=0;x<d.Width;x++)d.SetPixel(x,y,b.GetPixel(x/k,y/k));d.Save(Path.Combine(root,n+".png"),ImageFormat.Png);d.Dispose();}
 static void Save(Bitmap b,string n){b.Save(Path.Combine(root,n+".png"),ImageFormat.Png);Up(b,n+"_8x",8);}
 static Bitmap Logo(int light){var b=New(64,64);
  // The silhouette is drawn natively at64x64. No image reduction or resampling.
  for(int y=3;y<=60;y++){double half=(y-3)*30.0/57.0;int l=(int)Math.Ceiling(31.5-half),r=(int)Math.Floor(31.5+half);for(int x=l;x<=r;x++)b.SetPixel(x,y,P[light]);}
  // Broad crenellated head; a slight neck; immediate continuously widening cone.
  R(b,24,24,4,5,1);R(b,30,24,4,5,1);R(b,36,24,4,5,1);
  R(b,24,29,16,4,1);R(b,27,33,10,2,1);
  for(int y=35;y<=47;y++){int e=(y-35)/2;R(b,27-e,y,10+2*e,1,1);}
  // Four short steps form the mound, distinct from the sloping tower body.
  R(b,19,48,26,2,1);R(b,17,50,30,1,1);R(b,15,51,34,1,1);R(b,13,52,38,1,1);
  // Original text-band position becomes a single uninterrupted dark bar, no letters.
  R(b,7,56,50,2,1);
  return b;}
 static int EdgeDiff(Bitmap b,bool vertical){int n=0;for(int i=0;i<120;i++){Color a=vertical?b.GetPixel(0,i):b.GetPixel(i,0);Color z=vertical?b.GetPixel(119,i):b.GetPixel(i,119);if(a.ToArgb()!=z.ToArgb())n++;}return n;}
 static Color Pair(Color a,Color b){return P[Near(Color.FromArgb((a.R+b.R)/2,(a.G+b.G)/2,(a.B+b.B)/2))];}
 static void PaletteCheck(Bitmap b,bool opaque){for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color c=b.GetPixel(x,y);Check(c.A==0||c.A==255,"Fractional alpha");if(opaque)Check(c.A==255,"Floor transparency");if(c.A==255)Check(c.ToArgb()==P[Near(c)].ToArgb(),"Color outside palette");}}
 public static void Run(string dir){root=dir;string[] hex={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f"};P=Array.ConvertAll(hex,ColorTranslator.FromHtml);
  var gray=Logo(8);var yellow=Logo(14);Save(gray,"rhodes_logo_L_gray_v2");Save(yellow,"rhodes_logo_L_yellow_v2");
  foreach(var b in new[]{gray,yellow}){PaletteCheck(b,false);var colors=new HashSet<int>();for(int y=0;y<64;y++)for(int x=0;x<64;x++)if(b.GetPixel(x,y).A==255)colors.Add(b.GetPixel(x,y).ToArgb());Check(colors.Count==2,"Logo not exactly2 colors");for(int y=35;y<47;y++){int w=0,next=0;for(int x=0;x<64;x++){if(b.GetPixel(x,y).ToArgb()==P[1].ToArgb())w++;if(b.GetPixel(x,y+1).ToArgb()==P[1].ToArgb())next++;}Check(next>=w,"Cone narrows downward");}for(int x=7;x<57;x++)for(int y=56;y<58;y++)Check(b.GetPixel(x,y).ToArgb()==P[1].ToArgb(),"Missing base bar");}
  // Full source ->120x120, same scale on both axes, no crop or segmented scaling.
  var floor=New(120,120);using(var src=new Bitmap(Path.Combine(root,"../source_batch1_v2/rhodes_floor_source_v2.png"))){Check(src.Width==src.Height,"Floor source not square");for(int y=0;y<120;y++)for(int x=0;x<120;x++){int sx=(int)Math.Floor((x+.5)*src.Width/120.0),sy=(int)Math.Floor((y+.5)*src.Height/120.0);floor.SetPixel(x,y,P[Near(src.GetPixel(sx,sy))]);}log.Add("Full-source uniform nearest-neighbor reduction: "+src.Width+"x"+src.Height+" ->120x120; divisor="+(src.Width/120.0)+" on BOTH axes. Source is preserved.");}
  var raw=(Bitmap)floor.Clone();raw.Save(Path.Combine(root,"diagnostics/floor_quantized_before_edge_repair.png"),ImageFormat.Png);int beforeX=EdgeDiff(raw,true),beforeY=EdgeDiff(raw,false);
  // Only the outermost row/column are reconciled. Interior pixels remain untouched.
  for(int y=0;y<120;y++){Color c=Pair(floor.GetPixel(0,y),floor.GetPixel(119,y));floor.SetPixel(0,y,c);floor.SetPixel(119,y,c);}
  for(int x=0;x<120;x++){Color c=Pair(floor.GetPixel(x,0),floor.GetPixel(x,119));floor.SetPixel(x,0,c);floor.SetPixel(x,119,c);}
  int changed=0;var mask=New(120,120);for(int y=0;y<120;y++)for(int x=0;x<120;x++){if(raw.GetPixel(x,y).ToArgb()!=floor.GetPixel(x,y).ToArgb()){changed++;mask.SetPixel(x,y,P[14]);Check(x==0||x==119||y==0||y==119,"Interior touched");}}
  mask.Save(Path.Combine(root,"diagnostics/floor_edge_repair_mask.png"),ImageFormat.Png);Check(EdgeDiff(floor,true)==0&&EdgeDiff(floor,false)==0,"Unmatched repeat edges");PaletteCheck(floor,true);Save(floor,"rhodes_floor_v1");
  var mosaic=New(360,360);var offset=New(120,120);for(int y=0;y<360;y++)for(int x=0;x<360;x++)mosaic.SetPixel(x,y,floor.GetPixel(x%120,y%120));for(int y=0;y<120;y++)for(int x=0;x<120;x++)offset.SetPixel(x,y,floor.GetPixel((x+60)%120,(y+60)%120));mosaic.Save(Path.Combine(root,"floor_tiling_3x3_1x.png"),ImageFormat.Png);Up(mosaic,"floor_tiling_3x3_4x",4);offset.Save(Path.Combine(root,"floor_wrap_offset_60px.png"),ImageFormat.Png);Up(offset,"floor_wrap_offset_60px_4x",4);
  // Review logos on the intake floor. Ground assets remain unprojected here.
  var logoReview=New(160,88);for(int y=0;y<88;y++)for(int x=0;x<160;x++)logoReview.SetPixel(x,y,floor.GetPixel(x%120,y%120));Put(logoReview,gray,8,12);Put(logoReview,yellow,88,12);logoReview.Save(Path.Combine(root,"logo_review_1x.png"),ImageFormat.Png);Up(logoReview,"logo_review_4x",4);
  // Replace ONLY the two logo cells in a new copy of the accepted decal atlas.
  using(var atlas=new Bitmap(Path.Combine(root,"../batch2_v1/rhodes_hall_decals_atlas_v1.png"))){for(int y=0;y<96;y++)for(int x=0;x<192;x++)atlas.SetPixel(x,y,Color.FromArgb(0,0,0,0));Put(atlas,gray,16,16);Put(atlas,yellow,112,16);Save(atlas,"rhodes_hall_decals_atlas_v2");using(var old=new Bitmap(Path.Combine(root,"../batch2_v1/rhodes_hall_decals_atlas_v1.png"))){for(int y=0;y<192;y++)for(int x=0;x<384;x++)if(y>=96||x>=192)Check(atlas.GetPixel(x,y).ToArgb()==old.GetPixel(x,y).ToArgb(),"Accepted hazards changed");}}
  var used=new HashSet<int>();for(int y=0;y<120;y++)for(int x=0;x<120;x++)used.Add(floor.GetPixel(x,y).ToArgb());
  log.Add("PASS logos: native64x64, exactly2 colors, light triangle/dark tower+bar, transparent outside. Three crenellations, short neck, monotonically widening stepped-pixel cone, stepped mound,50x2 base bar.");
  log.Add("Floor palette colors used="+used.Count+" of26; alpha255 throughout.");log.Add("Before repair: left/right mismatches="+beforeX+" of120, top/bottom="+beforeY+" of120.");log.Add("Edge-only repair changed="+changed+" of14400 pixels ("+(changed*100.0/14400).ToString("F2")+"%); interior unchanged.");log.Add("PASS after repair: left/right mismatches=0, top/bottom=0, four corners match.");log.Add("PASS new decal atlas leaves every accepted hazard pixel unchanged. Counter unchanged/read-only.");log.Add("Review:3x3 tiling and60px wrap-offset images. Visual inspection required in addition to edge checks; no engine claim.");File.WriteAllText(Path.Combine(root,"validation.txt"),string.Join("\n",log)+"\n");
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[RhodesLogoFloorV2]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')
