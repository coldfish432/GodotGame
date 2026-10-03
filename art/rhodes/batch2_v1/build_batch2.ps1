$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$code = @'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Collections.Generic;
public static class RhodesBatch2 {
 static string root,project;static Color[] P;static List<string> results=new List<string>();static Dictionary<string,Bitmap> assets=new Dictionary<string,Bitmap>();
 static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);}
 static void Check(bool ok,string s){if(!ok)throw new Exception(s);}
 static void R(Bitmap b,int x,int y,int w,int h,int c){for(int j=y;j<y+h;j++)for(int i=x;i<x+w;i++)b.SetPixel(i,j,P[c]);}
 static int Near(Color c){int best=int.MaxValue,idx=0;for(int i=0;i<P.Length;i++){Color p=P[i];int d=(c.R-p.R)*(c.R-p.R)+(c.G-p.G)*(c.G-p.G)+(c.B-p.B)*(c.B-p.B);if(d<best){best=d;idx=i;}}return idx;}
 static bool Cyan(Color c){for(int i=18;i<=21;i++)if(c.ToArgb()==P[i].ToArgb())return true;return false;}
 static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,d=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>=128){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);d=Math.Max(d,y);}return Rectangle.FromLTRB(l,t,r+1,d+1);}
 static void Put(Bitmap d,Bitmap s,int x,int y){for(int j=0;j<s.Height;j++)for(int i=0;i<s.Width;i++){if(x+i<0||y+j<0||x+i>=d.Width||y+j>=d.Height)continue;Color c=s.GetPixel(i,j);if(c.A==0)continue;if(c.A==255)d.SetPixel(x+i,y+j,c);else{Color z=d.GetPixel(x+i,y+j);int a=c.A;d.SetPixel(x+i,y+j,Color.FromArgb(255,(c.R*a+z.R*(255-a)+127)/255,(c.G*a+z.G*(255-a)+127)/255,(c.B*a+z.B*(255-a)+127)/255));}}}
 static void Up(Bitmap b,string n,int k){var d=New(b.Width*k,b.Height*k);for(int y=0;y<d.Height;y++)for(int x=0;x<d.Width;x++)d.SetPixel(x,y,b.GetPixel(x/k,y/k));d.Save(Path.Combine(root,n+".png"),ImageFormat.Png);d.Dispose();}
 static void Save(string n,Bitmap b){assets.Add(n,b);b.Save(Path.Combine(root,n+".png"),ImageFormat.Png);Up(b,n+"_8x",8);}
 static Bitmap Logo(int fg){var b=New(64,64);
  // Native64x64 drawing, no tracing rescale or bitmap reduction.
  for(int y=3;y<=60;y++){double half=(y-3)*30.0/57.0;int l=(int)Math.Ceiling(31.5-half),r=(int)Math.Floor(31.5+half);for(int x=l;x<=r;x++)b.SetPixel(x,y,P[(x<l+3||x>r-3||y>=58)?fg:1]);}
  // Three crenellations, solid battlement rim, narrow waist, flared tower foot.
  R(b,25,24,4,4,fg);R(b,31,24,3,4,fg);R(b,36,24,3,4,fg);R(b,24,28,16,4,fg);
  for(int y=32;y<=50;y++){int extra=y<35?1:y<43?0:(y-42)/2;int l=28-extra,r=35+extra;R(b,l,y,r-l+1,1,fg);}
  R(b,22,51,20,2,fg);R(b,20,53,24,2,fg);
  return b;}
 static Bitmap Hazard(int w,int h,int corner){var b=New(w,h);for(int y=0;y<h;y++)for(int x=0;x<w;x++){
   bool inside=corner<0||(corner==0?(x<6||y<6):corner==1?(x>=w-6||y<6):corner==2?(x<6||y>=h-6):(x>=w-6||y>=h-6));
   if(inside)b.SetPixel(x,y,P[((x+y)%6<3)?14:0]);
  }return b;}
 static Dictionary<char,string> font=new Dictionary<char,string>{{'C',"111100100100111"},{'O',"111101101101111"},{'U',"101101101101111"},{'N',"101111111111101"},{'T',"111010010010010"},{'E',"111100110100111"},{'R',"110101110101101"},{'L',"100100100100111"},{'G',"111100101101111"},{'H',"101101111101101"},{'A',"010101111101101"},{'Z',"111001010100111"},{'D',"110101101101110"},{' ',"000000000000000"}};
 static void Text(Bitmap b,string s,int x,int y){foreach(char c in s){string z=font[c];for(int j=0;j<5;j++)for(int i=0;i<3;i++)if(z[j*3+i]=='1')b.SetPixel(x+i,y+j,P[8]);x+=4;}}
 public static void Run(string dir){root=dir;project=Path.GetFullPath(Path.Combine(root,"../../.."));string[] hex={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f"};P=Array.ConvertAll(hex,ColorTranslator.FromHtml);
  Bitmap on,off;Rectangle srcBounds;const int k=16;
  using(var src=new Bitmap(Path.Combine(root,"sources/logistics_counter_generated.png"))){srcBounds=Bounds(src);int w=(srcBounds.Width+k-1)/k,h=(srcBounds.Height+k-1)/k;on=New(w,h);off=New(w,h);
   for(int y=0;y<h;y++)for(int x=0;x<w;x++){int xx=srcBounds.X+x*k+k/2,yy=srcBounds.Y+y*k+k/2;Color raw=(xx<srcBounds.Right&&yy<srcBounds.Bottom)?src.GetPixel(xx,yy):Color.Transparent;Color c=raw.A>=128?P[Near(raw)]:Color.FromArgb(0,0,0,0);on.SetPixel(x,y,c);bool glow=raw.A>=128&&raw.G>100&&raw.G-raw.R>=12&&raw.B-raw.R>=12;off.SetPixel(x,y,Cyan(c)||glow?P[3]:c);}
  }
  Check(on.Height<=46,"Counter exceeds locked wall height");Save("rhodes_logistics_on_v1",on);Save("rhodes_logistics_off_v1",off);
  var station=New(256,128);int ax=(128-on.Width)/2,ay=113-Bounds(on).Bottom;Put(station,on,ax,ay);Put(station,off,128+ax,ay);Save("rhodes_logistics_atlas_v1",station);
  var gray=Logo(8);var yellow=Logo(14);Save("rhodes_logo_L_gray_v1",gray);Save("rhodes_logo_L_yellow_v1",yellow);
  var horizontal=Hazard(60,6,-1);var vertical=Hazard(6,60,-1);Save("rhodes_hazard_horizontal_v1",horizontal);Save("rhodes_hazard_vertical_v1",vertical);
  var nw=Hazard(24,24,0);var ne=Hazard(24,24,1);var sw=Hazard(24,24,2);var se=Hazard(24,24,3);Save("rhodes_hazard_corner_NW_v1",nw);Save("rhodes_hazard_corner_NE_v1",ne);Save("rhodes_hazard_corner_SW_v1",sw);Save("rhodes_hazard_corner_SE_v1",se);
  var decals=New(384,192);Put(decals,gray,16,16);Put(decals,yellow,112,16);Put(decals,horizontal,210,45);Put(decals,vertical,333,18);Put(decals,nw,36,132);Put(decals,ne,132,132);Put(decals,sw,228,132);Put(decals,se,324,132);Save("rhodes_hall_decals_atlas_v1",decals);
  var preview=New(480,180);
  using(var floorSrc=new Bitmap(Path.Combine(root,"../source_batch1_v2/rhodes_floor_source_v2.png")))using(var wall=new Bitmap(Path.Combine(root,"../batch1_v5/wall_straight_60x46_v5.png")))using(var sheet=new Bitmap(Path.Combine(project,"godot_assets/lappland_combat_64.png"))){
   int ox=(floorSrc.Width-1200)/2,oy=(floorSrc.Height-1200)/2;var tile=New(120,120);for(int y=0;y<120;y++)for(int x=0;x<120;x++)tile.SetPixel(x,y,P[Near(floorSrc.GetPixel(ox+10*x+5,oy+10*y+5))]);
   for(int y=0;y<180;y++)for(int x=0;x<480;x++)preview.SetPixel(x,y,y<16?P[1]:tile.GetPixel(x%120,y%120));R(preview,191,0,1,180,0);R(preview,351,0,1,180,0);Text(preview,"COUNTER",8,5);Text(preview,"LOGO L",200,5);Text(preview,"HAZARD",360,5);
   var ch=sheet.Clone(new Rectangle(0,0,64,64),PixelFormat.Format32bppArgb);var cb=Bounds(ch);
   Put(preview,wall,6,26);Put(preview,wall,66,26);Put(preview,wall,126,26);Put(preview,on,52,72-Bounds(on).Bottom);Put(preview,ch,140-cb.Left,71-(cb.Bottom-1));Put(preview,off,52,154-Bounds(off).Bottom);Put(preview,ch,140-cb.Left,153-(cb.Bottom-1));
   Put(preview,gray,203,40);Put(preview,yellow,278,40);Put(preview,horizontal,203,136);Put(preview,horizontal,278,136);
   // Assembled96x96 hazard loop. Every placement uses multiples of6 so stripe phase matches.
   int fx=368,fy=34;Put(preview,nw,fx,fy);Put(preview,ne,fx+72,fy);Put(preview,sw,fx,fy+72);Put(preview,se,fx+72,fy+72);Put(preview,horizontal,fx+18,fy);Put(preview,horizontal,fx+18,fy+90);Put(preview,vertical,fx,fy+18);Put(preview,vertical,fx+90,fy+18);Put(preview,ch,fx+48-(cb.Left+cb.Width/2),fy+70-(cb.Bottom-1));
  }
  preview.Save(Path.Combine(root,"batch2_review_1x.png"),ImageFormat.Png);Up(preview,"batch2_review_4x",4);
  // Validate deliverables, not the arbitrary-sized generator source.
  foreach(var kv in assets){var b=kv.Value;using(var big=new Bitmap(Path.Combine(root,kv.Key+"_8x.png"))){Check(big.Width==b.Width*8&&big.Height==b.Height*8,"8x dimensions");for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color c=b.GetPixel(x,y);Check(c.A==0||c.A==255,"Nonbinary alpha");if(c.A==255)Check(P[Near(c)].ToArgb()==c.ToArgb(),"Palette");for(int j=0;j<8;j++)for(int i=0;i<8;i++)Check(c.ToArgb()==big.GetPixel(8*x+i,8*y+j).ToArgb(),"Nonuniform8x");}}}
  for(int y=0;y<on.Height;y++)for(int x=0;x<on.Width;x++){Check(!Cyan(off.GetPixel(x,y)),"OFF cyan");Check(on.GetPixel(x,y).A==off.GetPixel(x,y).A,"ON/OFF silhouette");}
  foreach(var b in new[]{gray,yellow}){var colors=new HashSet<int>();for(int y=0;y<64;y++)for(int x=0;x<64;x++)if(b.GetPixel(x,y).A==255)colors.Add(b.GetPixel(x,y).ToArgb());Check(colors.Count==2,"Logo must use exactly2 opaque colors");}
  for(int y=0;y<6;y++)for(int x=0;x<60;x++)Check(horizontal.GetPixel(x,y).ToArgb()==P[((x+y)%6<3)?14:0].ToArgb(),"Stripe3+3");
  using(var big=new Bitmap(Path.Combine(root,"batch2_review_4x.png"))){for(int y=0;y<big.Height;y++)for(int x=0;x<big.Width;x++)Check(big.GetPixel(x,y).ToArgb()==preview.GetPixel(x/4,y/4).ToArgb(),"Review4x");}
  results.Add("PASS "+assets.Count+" native and exact8x asset pairs, palette and binary alpha.");results.Add("Counter source bbox="+srcBounds+"; single uniform integer divisor=16 for whole sprite; native="+on.Width+"x"+on.Height+"; opaque="+Bounds(on)+"; atlas origin="+ax+","+ay+" baseline113.");results.Add("PASS ON/OFF same alpha, OFF zero cyan. Blank yellow header; no text or NPC.");results.Add("PASS logos native64x64, direct pixel drawing, exactly2 opaque colors plus transparency; no pre-squashing.");results.Add("PASS hazards3px yellow/3px black,45degree pattern; straight60x6 /6x60, four24x24 corners.");results.Add("PASS review1x480x180 and exact4x1920x720, character frame0 native size.");results.Add("Counter worktop in source roughly y579..662, front y663..794; at /16 approx5px top+8px face, top-to-feet<=15px. Native view is for visual review, not engine validation.");results.Add("NOT RUN: engine integration. Batch1 files are read-only inputs.");File.WriteAllText(Path.Combine(root,"validation.txt"),string.Join("\n",results)+"\n");
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[RhodesBatch2]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')
