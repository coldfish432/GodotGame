$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$code=@'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Collections.Generic;using System.Linq;using System.Globalization;
public static class RepairSetpiece{
static string root;static Color[] p;static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);}static void C(bool b,string m){if(!b)throw new Exception(m);}
static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,d=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>=128){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);d=Math.Max(d,y);}return Rectangle.FromLTRB(l,t,r+1,d+1);}
static int Near(Color c){int bi=int.MaxValue,idx=0;for(int i=0;i<p.Length;i++){int d=(c.R-p[i].R)*(c.R-p[i].R)+(c.G-p[i].G)*(c.G-p[i].G)+(c.B-p[i].B)*(c.B-p[i].B);if(d<bi){bi=d;idx=i;}}return idx;}
static int Id(Color c){for(int i=0;i<p.Length;i++)if(c.ToArgb()==p[i].ToArgb())return i;return -1;}
static void Put(Bitmap d,Bitmap s,int x,int y){for(int j=0;j<s.Height;j++)for(int i=0;i<s.Width;i++){int xx=x+i,yy=y+j;if(xx<0||yy<0||xx>=d.Width||yy>=d.Height)continue;Color c=s.GetPixel(i,j);if(c.A!=0)d.SetPixel(xx,yy,c);}}
static void Up(Bitmap b,string name,int k){using(var o=New(b.Width*k,b.Height*k)){for(int y=0;y<o.Height;y++)for(int x=0;x<o.Width;x++)o.SetPixel(x,y,b.GetPixel(x/k,y/k));o.Save(Path.Combine(root,name),ImageFormat.Png);}}
static void Save(Bitmap b,string name,int k){b.Save(Path.Combine(root,name),ImageFormat.Png);Up(b,Path.GetFileNameWithoutExtension(name)+"_"+k+"x.png",k);}
static double Y(Color c){return (.2126*c.R+.7152*c.G+.0722*c.B)/255.0;}
static void Stats(string name,Bitmap b,bool enforce,StreamWriter w){int n=0,nearblack=0;double l=0;int[] acc=new int[5];for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color c=b.GetPixel(x,y);if(c.A==0)continue;int i=Id(c);C(i>=0,"29-color palette");n++;l+=Y(c);if(i==0)nearblack++;if(i>=15&&i<=17)acc[0]++;if(i>=12&&i<=14)acc[1]++;if(i>=18&&i<=21)acc[2]++;if(i==25)acc[3]++;if(i>=26&&i<=28)acc[4]++;}string row=string.Format(CultureInfo.InvariantCulture,"{0}: opaque={1}; mean Y'={2:F4}; near-black={3:F3}%; orange={4:F3}%; yellow={5:F3}%; cyan={6:F3}%; red={7:F3}%; Rhodes-blue={8:F3}%; total accents={9:F3}%",name,n,l/n,100.0*nearblack/n,100.0*acc[0]/n,100.0*acc[1]/n,100.0*acc[2]/n,100.0*acc[3]/n,100.0*acc[4]/n,100.0*acc.Sum()/n);w.WriteLine(row);if(enforce){C(l/n>=.50&&l/n<=.65,"mean brightness "+name);C(nearblack<=.03*n,"near black<=3% "+name);foreach(int v in acc)C(v<=.06*n,"accent<=6% "+name);C(acc.Sum()<=.10*n,"accent total<=10% "+name);}}
static void CheckOpaquePalette(Bitmap b){for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color c=b.GetPixel(x,y);C(c.A==0||c.A==255,"binary alpha");C(c.A==0||Id(c)>=0,"palette");}}
public static void Run(string dir){root=dir;string[] hex={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f","#385878","#5888a8","#78b8e8"};p=Array.ConvertAll(hex,ColorTranslator.FromHtml);
using(var log=new StreamWriter(Path.Combine(root,"validation.txt"))){
 log.WriteLine("Set-piece A: Repair Station; spec v1.0.7 §§2.4, 3.1, 3.5. Mean Y' is display luma (.2126R+.7152G+.0722B)/255 over opaque pixels only. Accent ramps orange15-17, yellow12-14, cyan18-21, red25, Rhodes blue26-28. Screen, functional hazard pedestal, graphic signage band and floor frame are recorded in total, even where signage may be exempt. Near-black is palette index0 / #0b0c0d.");
 using(var s=new Bitmap(Path.Combine(root,"sources/repair_station_generated.png"))){var r=Bounds(s);int k=12;int w=(r.Width+k-1)/k,h=(r.Height+k-1)/k;C(w<=128&&h<=65,"group too large; regenerate, never nonuniform fit");var sprite=New(128,80);int ox=(128-w)/2,oy=70-h;
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){int sx=r.X+x*k+k/2,sy=r.Y+y*k+k/2;Color c=sx<r.Right&&sy<r.Bottom?s.GetPixel(sx,sy):Color.Transparent;sprite.SetPixel(ox+x,oy+y,c.A>=128?p[Near(c)]:Color.FromArgb(0,0,0,0));}
  var opaque=new List<Point>();for(int y=0;y<80;y++)for(int x=0;x<128;x++)if(sprite.GetPixel(x,y).A==255&&sprite.GetPixel(x,y).ToArgb()==p[0].ToArgb())opaque.Add(new Point(x,y));
  int keep=(int)Math.Floor(sprite.Width*sprite.Height*.03);if(opaque.Count>keep){var dist=opaque.Select(pt=>{int n=0;foreach(var d in new[]{new Point(-1,0),new Point(1,0),new Point(0,-1),new Point(0,1)}){int xx=pt.X+d.X,yy=pt.Y+d.Y;if(xx>=0&&yy>=0&&xx<128&&yy<80&&sprite.GetPixel(xx,yy).A==0)n++;}return new{pt,n};}).OrderByDescending(z=>z.n).ThenBy(z=>(z.pt.X*73+z.pt.Y*151)%997).ToList();var retain=new HashSet<Point>(dist.Take(keep).Select(z=>z.pt));foreach(Point pt in opaque)if(!retain.Contains(pt))sprite.SetPixel(pt.X,pt.Y,p[5]);}
  CheckOpaquePalette(sprite);Stats("REPAIR STATION GROUP (signage and hazard included)",sprite,false,log);log.WriteLine("Source="+s.Width+"x"+s.Height+"; alpha>=128 bbox="+r+"; uniform integer nearest reduction /"+k+"; sampled artwork="+w+"x"+h+"; centered sprite canvas128x80; feet baseline70; placed at "+ox+","+oy+". Semi-transparent pixels thresholded at50%; no sections scaled separately.");
  sprite.Save(Path.Combine(root,"rhodes_repair_station_A_v1.png"),ImageFormat.Png);Up(sprite,"rhodes_repair_station_A_8x.png",8);
  using(var floor=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/rhodes_floor_equipment_v1.png")))using(var wall=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/wall_straight_60x46_light_v2.png")))using(var side=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/wall_top_6_plus2_light_v2.png")))using(var cornerL=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/corner_left_L_light_v2.png")))using(var cornerR=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/corner_right_L_light_v2.png")))using(var sheet=new Bitmap(Path.GetFullPath(Path.Combine(root,"../../../godot_assets/lappland_combat_64.png"))))using(var ch=sheet.Clone(new Rectangle(0,0,64,64),PixelFormat.Format32bppArgb)){
   var room=New(196,169);for(int y=0;y<169;y++)for(int x=0;x<196;x++)room.SetPixel(x,y,x>=8&&x<188&&y>=46&&y<161?floor.GetPixel((x-8)%120,(y-46)%120):p[2]);for(int x=8;x<188;x+=60)Put(room,wall,x,0);for(int y=46;y<161;y+=60){Put(room,side,0,y);Put(room,side,188,y);}Put(room,cornerL,0,0);Put(room,cornerR,164,0);
   // One unified grouped work area, baseline colocated with rear edge of floor at y=70.
   Put(room,sprite,34,0);
   // Native 1:1 Lappland frame, in clear foreground aisle.
   Rectangle cb=Bounds(ch);int cx=95-cb.Left,cy=145-(cb.Bottom-1);Put(room,ch,cx,cy);
   // Clean light patch from the room variant; graphic yellow boundary is part of the group itself.
   room.Save(Path.Combine(root,"equipment_bay_A_lappland_1x.png"),ImageFormat.Png);Up(room,"equipment_bay_A_lappland_4x.png",4);
   SaveFloorPreviews(floor);
   log.WriteLine("Composite=196x169; repair sprite origin=(34,0), atlas cell128x80, group baseline70 and group width="+w+". Wall shell is exact accepted v3 light module sizes. Lappland frame0 64x64 sampled from source at native scale; visible source bounds="+cb+"; feet baseline145. Floor path clear apart from access-zone edge. Static art composite; not an engine screenshot.");
  }
 }
 }
}
static void SaveFloorPreviews(Bitmap floor){var t=New(360,360);for(int y=0;y<360;y+=120)for(int x=0;x<360;x+=120)Put(t,floor,x,y);t.Save(Path.Combine(root,"repair_room_floor_3x3_1x.png"),ImageFormat.Png);Up(t,"repair_room_floor_3x3_4x.png",4);}
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[RepairSetpiece]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')


