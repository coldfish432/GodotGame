$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$code = @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
public static class RhodesFinish {
 static Color[] pal;
 static string root;
 static Color C(string s) { return ColorTranslator.FromHtml(s); }
 static Bitmap Blank(int w,int h) {return new Bitmap(w,h,PixelFormat.Format32bppArgb);}
 static Color Quant(Color c,bool off=false) {
  if(c.A<128)return Color.FromArgb(0,0,0,0);
  int best=int.MaxValue; Color pick=pal[0];
  for(int i=0;i<pal.Length;i++) { if(off && i>=18 && i<=21)continue; Color p=pal[i]; int d=(c.R-p.R)*(c.R-p.R)+(c.G-p.G)*(c.G-p.G)+(c.B-p.B)*(c.B-p.B); if(d<best){best=d;pick=p;} }
  return pick;
 }
 static Rectangle Bounds(Bitmap b,Rectangle r) {
  int x0=r.Right,y0=r.Bottom,x1=-1,y1=-1;
  for(int y=r.Top;y<r.Bottom;y++)for(int x=r.Left;x<r.Right;x++)if(b.GetPixel(x,y).A>=128){x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);}
  if(x1<0)throw new Exception("Empty crop");return Rectangle.FromLTRB(x0,y0,x1+1,y1+1);
 }
 static Bitmap Sample(Bitmap b,Rectangle r,int w,int h,bool off=false) {
  var d=Blank(w,h); for(int y=0;y<h;y++)for(int x=0;x<w;x++) d.SetPixel(x,y,Quant(b.GetPixel(r.X+Math.Min(r.Width-1,(int)((x+.5)*r.Width/w)),r.Y+Math.Min(r.Height-1,(int)((y+.5)*r.Height/h))),off)); return d;
 }
 static Bitmap Crop(Bitmap b,int x,int y,int w,int h,int dw,int dh) {return Sample(b,Bounds(b,new Rectangle(x,y,w,h)),dw,dh);}
 static void Put(Bitmap dst,Bitmap src,int x,int y) {for(int j=0;j<src.Height;j++)for(int i=0;i<src.Width;i++)dst.SetPixel(x+i,y+j,src.GetPixel(i,j));}
 static void Save(Bitmap b,string name) {b.Save(Path.Combine(root,name+".png"),ImageFormat.Png);var big=Blank(b.Width*8,b.Height*8);for(int y=0;y<big.Height;y++)for(int x=0;x<big.Width;x++)big.SetPixel(x,y,b.GetPixel(x/8,y/8));big.Save(Path.Combine(root,name+"_8x.png"),ImageFormat.Png);big.Dispose();}
 static void Check(bool ok,string msg){if(!ok)throw new Exception(msg);}
 public static void Run(string dir) {
  root=dir;string[] hex={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f"};pal=Array.ConvertAll(hex,C);
  using(var source=new Bitmap(Path.Combine(root,"sources/walls_doors_generated.png"))) {
   Check(source.Width==1448&&source.Height==1086,"Unexpected walls source size");
   var atlas=Blank(256,192);var wall=Blank(60,36);
   Put(wall,Sample(source,new Rectangle(87,132,500,47),60,4),0,0);
   Put(wall,Sample(source,new Rectangle(87,180,500,115),60,30),0,4);
   Put(wall,Sample(source,new Rectangle(87,299,500,39),60,2),0,34);
   // Flush continuous junctions, matching edge columns without terminal pillars.
   for(int y=0;y<36;y++){Color c=wall.GetPixel(3,y);wall.SetPixel(0,y,c);wall.SetPixel(59,y,c);}
   Put(atlas,wall,2,20);Save(wall,"wall_straight_60x36_v3");
   var rib=Crop(source,680,75,110,295,6,36);Put(atlas,rib,93,20);Save(rib,"wall_rib_6x36_v3");
   Put(atlas,Crop(source,830,70,290,300,26,36),147,20);
   Put(atlas,Crop(source,1170,65,230,315,26,36),211,20);
   int[] starts={55,440,825};int[] widths={360,365,375};
   for(int i=0;i<3;i++){var door=Crop(source,starts[i],410,widths[i],290,45,36);Put(atlas,door,i*64+9,84);Save(door,new[]{"door_open_45x36_v3","door_closed_45x36_v3","door_sealed_45x36_v3"}[i]);}
   Put(atlas,Crop(source,1240,415,140,295,8,36),220,84);
   // Top-down modules: normalize the generated strip and post tops to exact geometry.
   var strip=Crop(source,190,730,65,300,4,60);
   for(int y=0;y<60;y++){strip.SetPixel(0,y,pal[1]);for(int x=1;x<4;x++)if(strip.GetPixel(x,y).A==0)strip.SetPixel(x,y,pal[5]);}
   Put(atlas,strip,30,130);Save(strip,"wall_top_4x60_v3");
   var opening=Blank(6,60);
   for(int y=0;y<60;y++)if(y<11||y>=49)for(int x=0;x<4;x++)opening.SetPixel(x+1,y,strip.GetPixel(x,y));
   var post=Crop(source,545,734,80,72,6,6);
   for(int y=0;y<6;y++)for(int x=0;x<6;x++)if(post.GetPixel(x,y).A==0)post.SetPixel(x,y,pal[0]);
   Put(opening,post,0,5);Put(opening,post,0,49);
   for(int y=11;y<49;y++)opening.SetPixel(3,y,pal[5]);
   Put(atlas,opening,93,130);Save(opening,"door_top_gap38_posts6_v3");Save(atlas,"rhodes_walls_doors_v3");
   for(int y=0;y<36;y++)Check(wall.GetPixel(0,y)==wall.GetPixel(59,y),"Wall seam mismatch");
  }
  using(var source=new Bitmap(Path.Combine(root,"sources/console_generated.png"))) {
   Check(source.Width==1774&&source.Height==887,"Unexpected console source size");
   var atlas=Blank(256,128);
   for(int i=0;i<2;i++) {
    Rectangle bbox=Bounds(source,new Rectangle(i*887,160,887,600));
    var console=Blank(90,50);int deskStart=433;
    Put(console,Sample(source,Rectangle.FromLTRB(bbox.Left,bbox.Top,bbox.Right,deskStart),90,35,i==1),0,0);
    Put(console,Sample(source,Rectangle.FromLTRB(bbox.Left,deskStart,bbox.Right,bbox.Bottom),90,15,i==1),0,35);
    if(i==1)for(int y=0;y<50;y++)for(int x=0;x<90;x++){Color c=console.GetPixel(x,y);for(int k=18;k<=21;k++)Check(c.ToArgb()!=pal[k].ToArgb(),"Cyan in OFF");}
    Put(atlas,console,19+128*i,63);Save(console,i==0?"console_on_90x50_v3":"console_off_90x50_v3");
   }
   Save(atlas,"rhodes_console_v3");
  }
  // Inspect saved artifacts, including every block in the 8x outputs.
  int checkedFiles=0;
  foreach(string file in Directory.GetFiles(root,"*.png")) {
   if(file.EndsWith("_8x.png"))continue;
   using(var small=new Bitmap(file))using(var big=new Bitmap(file.Substring(0,file.Length-4)+"_8x.png")) {
    Check(big.Width==small.Width*8&&big.Height==small.Height*8,"Upscale dimensions");
    for(int y=0;y<small.Height;y++)for(int x=0;x<small.Width;x++){
     Color c=small.GetPixel(x,y);Check(c.A==0||c.A==255,"Nonbinary alpha");
     if(c.A==255){bool found=false;foreach(Color p in pal)if(c.ToArgb()==p.ToArgb())found=true;Check(found,"Color outside palette");}
     for(int j=0;j<8;j++)for(int k=0;k<8;k++)Check(big.GetPixel(x*8+k,y*8+j).ToArgb()==c.ToArgb(),"Nonuniform 8x block");
    }
   }checkedFiles++;
  }
  File.WriteAllText(Path.Combine(root,"validation.txt"),"PASS: "+checkedFiles+" native PNGs and matching exact 8x PNGs.\nPASS: palette membership, binary alpha, all 8x blocks uniform.\nPASS: wall matching left/right edge columns; no end pillars.\nPASS: wall cap 4 + face 30 + baseboard 2 = 36 px.\nPASS: front door module width 45 px.\nPASS: top wall width 4 px; gap 38 px between 6x6 post tops.\nPASS: console bounding canvas 90x50; desk section 15 px.\nPASS: OFF has zero cyan palette pixels.\nNOT RUN: in-engine scale and visual acceptance.\n");
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[RhodesFinish]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')
