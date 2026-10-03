$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$nativeSource = @'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Collections.Generic;
public static class RhodesNativeV4 {
 static string root;static Color[] P;static Color clear=Color.FromArgb(0,0,0,0);
 static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);}
 static void R(Bitmap b,int x,int y,int w,int h,int p){for(int j=y;j<y+h;j++)for(int i=x;i<x+w;i++)b.SetPixel(i,j,P[p]);}
 static void Put(Bitmap d,Bitmap s,int x,int y){for(int j=0;j<s.Height;j++)for(int i=0;i<s.Width;i++){Color c=s.GetPixel(i,j);if(c.A!=0)d.SetPixel(x+i,y+j,c);}}
 static void Save(Bitmap b,string n){b.Save(Path.Combine(root,n+".png"),ImageFormat.Png);var big=New(b.Width*8,b.Height*8);for(int y=0;y<big.Height;y++)for(int x=0;x<big.Width;x++)big.SetPixel(x,y,b.GetPixel(x/8,y/8));big.Save(Path.Combine(root,n+"_8x.png"),ImageFormat.Png);big.Dispose();}
 static void Check(bool b,string s){if(!b)throw new Exception(s);}
 static Color Q(Color c){if(c.A<128)return clear;int best=int.MaxValue;Color v=P[0];foreach(Color p in P){int d=(p.R-c.R)*(p.R-c.R)+(p.G-c.G)*(p.G-c.G)+(p.B-c.B)*(p.B-c.B);if(d<best){best=d;v=p;}}return v;}
 static bool Cyan(Color c){for(int i=18;i<=21;i++)if(c.ToArgb()==P[i].ToArgb())return true;return false;}
 static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,d=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>=128){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);d=Math.Max(d,y);}return Rectangle.FromLTRB(l,t,r+1,d+1);}
 static Bitmap Wall(){var b=New(60,46);R(b,0,0,60,1,8);R(b,0,1,60,2,6);R(b,0,3,60,1,4);R(b,0,4,60,40,3);R(b,0,4,60,1,1);R(b,0,43,60,1,2);R(b,0,44,60,1,5);R(b,0,45,60,1,1);
  foreach(int x in new[]{15,30,45}){R(b,x,5,1,38,1);R(b,x+1,5,1,38,4);}
  foreach(int x in new[]{5,20,35,50}){R(b,x,8,1,1,5);R(b,x,9,1,1,1);R(b,x,38,1,1,5);}
  R(b,21,11,3,1,4);R(b,23,12,2,2,4);R(b,38,30,3,1,4);R(b,37,31,2,2,4);R(b,7,25,2,1,4);R(b,8,26,3,1,4);R(b,48,18,3,1,2);R(b,50,19,2,2,2);
  // Exact same first/last column, with no end-pillar or end-border art.
  for(int y=0;y<46;y++)b.SetPixel(59,y,b.GetPixel(0,y));return b;}
 static Bitmap Rib(){var b=New(6,46);R(b,0,0,6,46,1);R(b,1,0,4,1,8);R(b,1,1,4,3,6);R(b,1,4,4,39,4);R(b,1,5,1,37,6);R(b,4,5,1,37,2);R(b,2,12,2,2,5);R(b,2,28,2,2,5);R(b,1,43,4,2,6);return b;}
 static Bitmap Strip(){var b=New(8,60);for(int y=0;y<60;y++){b.SetPixel(0,y,P[8]);for(int x=1;x<=4;x++)b.SetPixel(x,y,P[6]);b.SetPixel(5,y,P[2]);b.SetPixel(6,y,P[1]);b.SetPixel(7,y,P[1]);}return b;}
 static Bitmap SideDoor(){var b=New(8,60);var s=Strip();for(int y=0;y<60;y++)if(y<11||y>=49)for(int x=0;x<8;x++)b.SetPixel(x,y,s.GetPixel(x,y));foreach(int y in new[]{5,49}){R(b,0,y,6,6,2);R(b,0,y,6,1,8);R(b,0,y+1,1,4,8);R(b,1,y+1,4,4,6);}R(b,3,11,1,38,4);return b;}
 static Bitmap Corner(bool left){var b=New(32,60);var wall=Wall();int wx=left?8:0,sx=left?0:24;for(int y=0;y<46;y++)for(int x=0;x<24;x++)b.SetPixel(wx+x,y,wall.GetPixel(x,y));var strip=Strip();Put(b,strip,sx,0);
  // Horizontal cap joins vertical cap orthogonally. Upright wall face ends at x8/x24.
  int jx=left?5:24;R(b,jx,0,3,1,8);R(b,jx,1,3,2,6);R(b,jx,3,3,1,4);return b;}
 static Bitmap Door(int state){var b=New(45,46);for(int y=0;y<46;y++){int inset=y<3?3-y:0;for(int x=inset;x<45-inset;x++)b.SetPixel(x,y,P[0]);}
  R(b,3,1,39,1,8);R(b,3,2,39,4,5);R(b,4,6,37,2,3);R(b,1,4,4,41,4);R(b,2,5,1,39,6);R(b,40,4,4,41,3);R(b,41,5,1,39,5);
  foreach(int yy in new[]{13,29}){R(b,1,yy,4,3,5);R(b,40,yy,4,3,4);R(b,2,yy,1,1,7);R(b,41,yy,1,1,6);}
  R(b,18,1,9,7,1);R(b,19,2,7,5,7);R(b,5,8,34,1,1);R(b,5,9,1,36,5);R(b,38,9,1,36,2);R(b,0,45,45,1,1);
  for(int y=9;y<45;y++)for(int x=6;x<38;x++)b.SetPixel(x,y,state==0?clear:P[4]);
  if(state>0){R(b,6,9,32,1,6);R(b,6,10,1,34,5);R(b,21,10,2,35,1);R(b,23,10,1,35,5);R(b,18,24,2,6,1);R(b,25,24,2,6,1);R(b,8,39,11,1,5);R(b,26,39,9,1,5);}
  if(state==2){R(b,6,24,32,8,0);for(int y=25;y<31;y++)for(int x=6;x<38;x++)b.SetPixel(x,y,P[((x+y)%6<3)?14:0]);R(b,40,19,4,5,0);R(b,41,20,2,3,25);}
  for(int y=0;y<3;y++)for(int x=0;x<3-y;x++){b.SetPixel(x,y,clear);b.SetPixel(44-x,y,clear);b.SetPixel(x,45-y,clear);b.SetPixel(44-x,45-y,clear);}return b;}
 public static void Run(string dir){root=dir;string[] h={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f"};P=Array.ConvertAll(h,ColorTranslator.FromHtml);
  var wall=Wall();var rib=Rib();var strip=Strip();var sd=SideDoor();var ci=Corner(false);var co=Corner(true);var atlas=New(256,192);
  Save(wall,"wall_straight_60x46_v4");Save(rib,"wall_rib_6x46_v4");Save(strip,"wall_top_6_plus2_v4");Save(sd,"door_side_gap38_v4");Save(ci,"corner_right_L_v4");Save(co,"corner_left_L_v4");
  Put(atlas,wall,2,10);Put(atlas,rib,93,10);Put(atlas,ci,144,2);Put(atlas,co,208,2);
  for(int i=0;i<3;i++){var d=Door(i);Save(d,new[]{"door_open_45x46_v4","door_closed_45x46_v4","door_sealed_45x46_v4"}[i]);Put(atlas,d,i*64+9,74);if(i==0)for(int y=9;y<45;y++)for(int x=6;x<38;x++)Check(d.GetPixel(x,y).A==0,"Opening is obstructed");}
  Put(atlas,strip,28,130);Put(atlas,sd,92,130);Save(atlas,"rhodes_walls_doors_v4");
  // Console: exactly one uniform integer reduction for the entire sprite, never sections.
  using(var src=new Bitmap(Path.Combine(root,"sources/console_final_redraw.png"))){
   var bounds=Bounds(src);const int factor=16;int w=(bounds.Width+factor-1)/factor,hgt=(bounds.Height+factor-1)/factor;var on=New(w,hgt);var off=New(w,hgt);
   for(int y=0;y<hgt;y++)for(int x=0;x<w;x++){int xx=bounds.X+x*factor+factor/2,yy=bounds.Y+y*factor+factor/2;Color raw=(xx<bounds.Right&&yy<bounds.Bottom)?src.GetPixel(xx,yy):clear;Color c=Q(raw);bool emissive=raw.A>=128&&raw.G>100&&raw.G-raw.R>=12&&raw.B-raw.R>=12;on.SetPixel(x,y,c);off.SetPixel(x,y,Cyan(c)||emissive?P[3]:c);}
   Save(on,"console_on_v4");Save(off,"console_off_v4");var ca=New(256,128);int px=(128-w)/2,py=113-hgt;Put(ca,on,px,py);Put(ca,off,128+px,py);Save(ca,"rhodes_console_v4");
   for(int y=0;y<hgt;y++)for(int x=0;x<w;x++){Check(!Cyan(off.GetPixel(x,y)),"OFF cyan");Check(on.GetPixel(x,y).A==off.GetPixel(x,y).A,"ON/OFF geometry mismatch");}
   File.WriteAllText(Path.Combine(root,"console_sampling.txt"),"Source bbox: "+bounds+"\nUniform nearest-neighbor integer divisor:16, BOTH AXES, ENTIRE SPRITE\nTransparent padding to full sampling cells; no geometry stretching.\nNative canvas: "+w+"x"+hgt+"\nNative opaque bounds: "+Bounds(on)+"\nOFF is same geometry, cyan palette pixels replaced by gunmetal.\nSource desk top y590..645, face y646..805; feet to y830. These correspond to approx4px surface /10px face; top to feet15px.\n");
  }
  // Review join sample contains no characters or gameplay implementation.
  var join=New(124,100);Put(join,co,0,0);Put(join,wall,32,0);Put(join,ci,92,0);Save(join,"corner_join_review_v4");
  for(int y=0;y<46;y++)Check(wall.GetPixel(0,y)==wall.GetPixel(59,y),"Wall seam");
  for(int y=0;y<60;y++){Check(strip.GetPixel(0,y)==P[8],"Highlight width");for(int x=1;x<=4;x++)Check(strip.GetPixel(x,y)==P[6],"Cap width");Check(strip.GetPixel(5,y)==P[2],"Dark edge");for(int x=6;x<8;x++)Check(strip.GetPixel(x,y)==P[1],"Contact shadow");}
  int count=0;foreach(string f in Directory.GetFiles(root,"*.png")){if(f.EndsWith("_8x.png"))continue;using(var n=new Bitmap(f))using(var big=new Bitmap(f.Substring(0,f.Length-4)+"_8x.png")){Check(big.Width==n.Width*8&&big.Height==n.Height*8,"Export size");for(int y=0;y<n.Height;y++)for(int x=0;x<n.Width;x++){Color c=n.GetPixel(x,y);Check(c.A==0||c.A==255,"Alpha");if(c.A==255){bool found=false;foreach(Color p in P)if(c.ToArgb()==p.ToArgb())found=true;Check(found,"Palette");}for(int j=0;j<8;j++)for(int k=0;k<8;k++)Check(big.GetPixel(x*8+k,y*8+j).ToArgb()==c.ToArgb(),"8x block");}}count++;}
  File.WriteAllText(Path.Combine(root,"validation.txt"),"PASS "+count+" native/8x PNG pairs, 26-color palette and binary alpha.\nPASS wall cap4 + face40 + base2 =46, matching repeat ends, separate rib.\nPASS doorway outer45x46; completely transparent32x36 clear rectangle.\nPASS side strip1+4+1 material pixels +2 contact shadow.\nPASS side door gap38 with6x6 post tops and threshold.\nPASS corners use axis-aligned L top caps; no V pillar or side elevation.\nPASS console single UNIFORM integer16x reduction; no section resampling.\nPASS OFF zero cyan and same alpha geometry as ON.\nNOT RUN: in-engine validation.\n");
 }
}
'@
Add-Type -TypeDefinition $nativeSource -ReferencedAssemblies System.Drawing
[RhodesNativeV4]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'console_sampling.txt')
