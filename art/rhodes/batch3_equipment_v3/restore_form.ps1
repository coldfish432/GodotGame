$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$code = @'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Collections.Generic;
public static class EquipmentV3 {
 static string root; static Color[] p; static Dictionary<string,Bitmap> a=new Dictionary<string,Bitmap>(); static List<string> report=new List<string>();
 static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);}
 static void Check(bool b,string m){if(!b)throw new Exception(m);}
 static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,d=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>=128){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);d=Math.Max(d,y);}return Rectangle.FromLTRB(l,t,r+1,d+1);}
 static int Near(Color c){int best=int.MaxValue,n=0;for(int i=0;i<p.Length;i++){int d=(c.R-p[i].R)*(c.R-p[i].R)+(c.G-p[i].G)*(c.G-p[i].G)+(c.B-p[i].B)*(c.B-p[i].B);if(d<best){best=d;n=i;}}return n;}
 static bool Cyan(Color c){return c.A!=0&&Near(c)>=18&&Near(c)<=21;}
 static void Put(Bitmap d,Bitmap s,int x,int y){for(int j=0;j<s.Height;j++)for(int i=0;i<s.Width;i++){if(x+i<0||y+j<0||x+i>=d.Width||y+j>=d.Height)continue;Color c=s.GetPixel(i,j);if(c.A==0)continue;if(c.A==255)d.SetPixel(x+i,y+j,c);else{Color z=d.GetPixel(x+i,y+j);int al=c.A;d.SetPixel(x+i,y+j,Color.FromArgb(255,(c.R*al+z.R*(255-al)+127)/255,(c.G*al+z.G*(255-al)+127)/255,(c.B*al+z.B*(255-al)+127)/255));}}}
 static void Up(Bitmap b,string name,int k){using(var d=New(b.Width*k,b.Height*k)){for(int y=0;y<d.Height;y++)for(int x=0;x<d.Width;x++)d.SetPixel(x,y,b.GetPixel(x/k,y/k));d.Save(Path.Combine(root,name+".png"),ImageFormat.Png);}}
 static void Save(string n,Bitmap b){a.Add(n,b);b.Save(Path.Combine(root,n+".png"),ImageFormat.Png);Up(b,n+"_8x",8);}
 static void Cell(Bitmap atlas,Bitmap b,int col,int row,int size){int x=col*size+(size-b.Width)/2;int y=row*size+(int)Math.Round(size*.88)-Bounds(b).Bottom;Put(atlas,b,x,y);report.Add("atlas "+atlas.Width+"x"+atlas.Height+" cell="+col+","+row+" origin="+x+","+y+" feet baseline="+((row*size)+(int)Math.Round(size*.88)));}
 static void Ground(Bitmap d,Bitmap s,int x,int baseline){Put(d,s,x,baseline-Bounds(s).Bottom);}

 static int Index(Color c){for(int i=0;i<p.Length;i++)if(c.ToArgb()==p[i].ToArgb())return i;return -1;}
 static double Lum(Color c){return (.2126*c.R+.7152*c.G+.0722*c.B)/255.0;}
 static double Linear(double c){c/=255;return c<=.04045?c/12.92:Math.Pow((c+.055)/1.055,2.4);}
 static double LinLum(Color c){return .2126*Linear(c.R)+.7152*Linear(c.G)+.0722*Linear(c.B);}
 static void SameAlpha(Bitmap s,Bitmap d,string n){Check(s.Size==d.Size,n+" size changed");for(int y=0;y<s.Height;y++)for(int x=0;x<s.Width;x++)Check(s.GetPixel(x,y).A==d.GetPixel(x,y).A,n+" alpha changed");report.Add("PASS unchanged canvas and every alpha byte: "+n);}
 static bool Edge(Bitmap b,int x,int y){return x==0||y==0||x==b.Width-1||y==b.Height-1||b.GetPixel(x-1,y).A==0||b.GetPixel(x+1,y).A==0||b.GetPixel(x,y-1).A==0||b.GetPixel(x,y+1).A==0;}
 static bool OrangePart(string n,int x,int y){
  if(n=="crate_single")return y==3&&x>=7&&x<=18;
  if(n=="crate_stack")return (y==3&&x>=14&&x<=26)||(y==14&&((x>=5&&x<=15)||(x>=24&&x<=34)));
  if(n=="workbench")return y==9&&x>=53&&x<=67;
  if(n=="weapon_cabinet")return y==39&&x>=4&&x<=16;
  if(n=="crane_hook")return y==27&&x>=14&&x<=20;
  if(n=="robotic_arm")return y>=12&&y<=18&&x<=8;
  return false;
 }

 static bool Joint(int x,int y,int cx,int cy,int r2){return (x-cx)*(x-cx)+(y-cy)*(y-cy)<=r2;}
 static Bitmap Recolor(string name,int unused){
  string stem=name=="crate_single"?"rhodes_supply_crate":name=="crate_stack"?"rhodes_supply_crates_stack":"rhodes_"+name;
  string state=name=="workbench"||name=="weapon_cabinet"||name=="robotic_arm"?"_on":"";
  using(var s=new Bitmap(Path.Combine(root,"../batch3_equipment_v2/"+stem+state+"_v2.png")))
  using(var original=new Bitmap(Path.Combine(root,"../batch3_equipment_v1/"+stem+state+"_v1.png"))){
   var b=New(s.Width,s.Height);
   for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){
    Color c=s.GetPixel(x,y);if(c.A==0){b.SetPixel(x,y,c);continue;}
    int i=Index(c),old=Index(original.GetPixel(x,y)),q=i;
    bool accent=(i>=12&&i<=21)||i==25;
    if(!accent){
     if((i==7||i==9)&&name!="crate_single"&&name!="crate_stack")q=8;
     bool recess=false,joint=false,blade=false;
     if(name=="weapon_cabinet"){
      recess=(x>=4&&x<=16&&y>=8&&y<=36)||(x>=19&&y>=9&&y<=35&&old==0);
      blade=y>=10&&y<=35&&((x>=5&&x<=7)||(x>=10&&x<=12));
      if(recess&&old<=3)q=old<=1?4:5;
      if(blade&&old>=12)q=5; if(y>=14&&y<=34&&(x==6||x==11))q=5;
      if(y==6&&x>=3&&x<=17)q=4;
     }
     if(name=="robotic_arm"){
      joint=Joint(x,y,7,7,8)||Joint(x,y,22,6,10)||Joint(x,y,25,20,12);
      if(joint)q=old<=3?4:old<=5?5:8; if(Joint(x,y,7,7,4)||Joint(x,y,22,6,4)||Joint(x,y,25,20,4))q=4; if((x==7&&y==7)||(x==22&&y==6)||(x==25&&y==20))q=8;
      recess=(y>=27&&y<=30&&x>=18&&x<=28)||(y>=9&&y<=11&&x>=9&&x<=20);
      if(recess&&old<=3)q=4;
     }
     if(name=="workbench"){
      recess=y>=16||(x>=22&&x<=38&&y>=1&&y<=10);
      if(recess&&old<=2)q=old==0?4:5;
     }
     if(name=="crane_hook"){
      recess=(y>=5&&y<=9&&x>=12&&x<=21)||(y>=28&&y<=32&&x>=15&&x<=19);
      if(recess&&old<=3)q=old<=1?4:5;
      if(y>=36&&old<=3)q=5;
     }
     // Preserve the accepted near-black silhouette exactly.
     if(i==0)q=0;
    }
    b.SetPixel(x,y,p[q]);
    Check(!accent||b.GetPixel(x,y).ToArgb()==c.ToArgb(),"accent changed");
   }
   SameAlpha(s,b,name+" vs v2");Metrics(name+" V2",s,false);Metrics(name+" V3",b,false);
   return b;
  }
 }
 static Bitmap Off(Bitmap b){var c=New(b.Width,b.Height);for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color v=b.GetPixel(x,y);int i=Index(v);c.SetPixel(x,y,v.A==0?v:i==18?p[5]:i==19?p[6]:i==20?p[7]:i==21?p[8]:v);}return c;}
 static void Metrics(string n,Bitmap b,bool enforce){
  int count=0,light=0;int[] accent=new int[4];double sum=0,lin=0;var hist=new int[26];
  for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color c=b.GetPixel(x,y);if(c.A==0)continue;int i=Index(c);Check(c.A==255&&i>=0,"palette/alpha");count++;hist[i]++;sum+=Lum(c);lin+=LinLum(c);if(Lum(c)>=.5)light++;if(i>=15&&i<=17)accent[0]++;if(i>=12&&i<=14)accent[1]++;if(i>=18&&i<=21)accent[2]++;if(i==25)accent[3]++;}
  int total=accent[0]+accent[1]+accent[2]+accent[3],dominant=0;for(int i=1;i<26;i++)if(hist[i]>hist[dominant])dominant=i;
  report.Add(string.Format(System.Globalization.CultureInfo.InvariantCulture,"{0}: opaque={1}; mean_luminance_sRGB={2:F6}; linear_relative_luminance={3:F6}; light_pixels_Yprime>=0.5={4:F3}%; orange={5:F3}%; yellow={6:F3}%; cyan={7:F3}%; red={8:F3}%; accents_total={9:F3}%; dominant=#{10:x2}{11:x2}{12:x2}",n,count,sum/count,lin/count,100.0*light/count,100.0*accent[0]/count,100.0*accent[1]/count,100.0*accent[2]/count,100.0*accent[3]/count,100.0*total/count,p[dominant].R,p[dominant].G,p[dominant].B));
  if(enforce){Check(dominant>=7&&dominant<=10,n+" dominant body color");Check(sum/count>=.50&&sum/count<=.65,n+" mean luminance");Check(total<=count*.10,n+" total accent");foreach(int v in accent)Check(v<=count*.06,n+" single accent");}
 }
 static void Shell(){
  string[] names={"wall_straight_60x46","wall_rib_6x46","wall_top_6_plus2","door_side_gap38","corner_right_L","corner_left_L","door_open_45x46","door_closed_45x46","door_sealed_45x46","wall_floor_contact_shadow_60x2"};
  int[] map={0,2,5,7,7,6,8,8,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25};
  foreach(string name in names)using(var s=new Bitmap(Path.Combine(root,"../batch1_v5/"+name+"_v5.png"))){
   var b=New(s.Width,s.Height);
   for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var c=s.GetPixel(x,y);b.SetPixel(x,y,c.A==0?c:p[y<4&&Index(c)==4?9:map[Index(c)]]);}
   SameAlpha(s,b,name);Save(name+"_light_v2",b);
  }
  var atlas=New(256,192);Put(atlas,a["wall_straight_60x46_light_v2"],2,10);Put(atlas,a["wall_rib_6x46_light_v2"],93,10);Put(atlas,a["corner_right_L_light_v2"],144,2);Put(atlas,a["corner_left_L_light_v2"],208,2);Put(atlas,a["door_open_45x46_light_v2"],9,74);Put(atlas,a["door_closed_45x46_light_v2"],73,74);Put(atlas,a["door_sealed_45x46_light_v2"],137,74);Put(atlas,a["wall_top_6_plus2_light_v2"],28,130);Put(atlas,a["door_side_gap38_light_v2"],92,130);
  using(var old=new Bitmap(Path.Combine(root,"../batch1_v5/rhodes_walls_doors_v5.png")))SameAlpha(old,atlas,"wall atlas");
  Save("rhodes_walls_light_v2",atlas);
  var door=a["door_open_45x46_light_v2"];for(int y=9;y<45;y++)for(int x=6;x<38;x++)Check(door.GetPixel(x,y).A==0,"door32x36");
  var wall=a["wall_straight_60x46_light_v2"];for(int y=0;y<46;y++)Check(wall.GetPixel(0,y)==wall.GetPixel(59,y),"wall horizontal seam");
  using(var s=new Bitmap(Path.Combine(root,"../rhodes_floor_v1.png"))){
   int[] fm={1,2,4,5,6,7,7,7,7,7,7,7,5,5,6,5,5,6,4,5,6,7,5,6,7,4};
   var floor=New(s.Width,s.Height);
   for(int y=0;y<s.Height;y++)for(int x=0;x<s.Width;x++){var c=s.GetPixel(x,y);floor.SetPixel(x,y,p[fm[Index(c)]]);Check(Lum(floor.GetPixel(x,y))<=Lum(p[7]),"floor max");}
   SameAlpha(s,floor,"floor same120x120 plate pattern");
   for(int i=0;i<120;i++){Check(floor.GetPixel(0,i)==floor.GetPixel(119,i),"floor EW seam");Check(floor.GetPixel(i,0)==floor.GetPixel(i,119),"floor NS seam");}
   Save("rhodes_floor_equipment_v1",floor);Metrics("equipment FLOOR",floor,false);
   for(int row=0;row<2;row++)for(int col=0;col<2;col++)Save("rhodes_floor_equipment_quadrant_"+(row*2+col)+"_v1",floor.Clone(new Rectangle(col*60,row*60,60,60),PixelFormat.Format32bppArgb));
   var tile=New(360,360);for(int y=0;y<360;y+=120)for(int x=0;x<360;x+=120)Put(tile,floor,x,y);tile.Save(Path.Combine(root,"floor_tiling_3x3_1x.png"));Up(tile,"floor_tiling_3x3_4x",4);
  }
 }
 public static void Run(string dir){root=dir;report.Add("Form-contrast revision v3 of spec v1.0.5: wall face dominant #98a2a6, cap #c3cacc; prop bodies #c3cacc/#d4dadb; localized recess/joint/blade colors #3d4448/#566064. Geometry and alpha unchanged from v2. All statistics use opaque pixels only. mean_luminance_sRGB is Yprime=(0.2126R+0.7152G+0.0722B)/255; target0.50..0.65 uses this display-value metric. Linearized sRGB relative luminance is also reported, separately. Light pixels means Yprime>=0.50. Accents counted by complete palette ramps: orange15..17, yellow12..14, cyan18..21, red25; no screen exemption used. Enforced on EVERY final individual prop including OFF: mean0.50..0.65, accent total<=10%, each ramp<=6%, most frequent opaque color in cold-grey/white range7..10.");string[] hex={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f"};p=Array.ConvertAll(hex,ColorTranslator.FromHtml);
  Shell();var bench=Recolor("workbench",24);var cabinet=Recolor("weapon_cabinet",28);var hook=Recolor("crane_hook",30);var arm=Recolor("robotic_arm",26);var single=Recolor("crate_single",48);var stack=Recolor("crate_stack",30);
  Save("rhodes_workbench_on_v3",bench);Save("rhodes_workbench_off_v3",Off(bench));Save("rhodes_weapon_cabinet_on_v3",cabinet);Save("rhodes_weapon_cabinet_off_v3",Off(cabinet));Save("rhodes_crane_hook_v3",hook);Save("rhodes_robotic_arm_on_v3",arm);Save("rhodes_robotic_arm_off_v3",Off(arm));Save("rhodes_supply_crate_v3",single);Save("rhodes_supply_crates_stack_v3",stack);
  var stations=New(512,256);Cell(stations,bench,0,0,128);Cell(stations,cabinet,1,0,128);Cell(stations,a["rhodes_workbench_off_v3"],0,1,128);Cell(stations,a["rhodes_weapon_cabinet_off_v3"],1,1,128);Save("rhodes_equipment_stations_v3",stations);
  var props=New(256,192);Cell(props,single,0,0,64);Cell(props,stack,1,0,64);Cell(props,hook,2,0,64);Cell(props,arm,3,0,64);Cell(props,a["rhodes_robotic_arm_off_v3"],3,1,64);Save("rhodes_equipment_props_v3",props);
  using(var floor=new Bitmap(Path.Combine(root,"rhodes_floor_equipment_v1.png")))using(var wall=new Bitmap(Path.Combine(root,"wall_straight_60x46_light_v2.png")))using(var side=new Bitmap(Path.Combine(root,"wall_top_6_plus2_light_v2.png")))using(var shadow=new Bitmap(Path.Combine(root,"wall_floor_contact_shadow_60x2_light_v2.png")))using(var sheet=new Bitmap(Path.GetFullPath(Path.Combine(root,"../../../godot_assets/lappland_combat_64.png"))))using(var ch=sheet.Clone(new Rectangle(0,0,64,64),PixelFormat.Format32bppArgb)){
   var room=New(196,169);for(int y=0;y<room.Height;y++)for(int x=0;x<room.Width;x++)room.SetPixel(x,y,x>=8&&x<188&&y>=46&&y<161?floor.GetPixel((x-8)%120,(y-46)%120):p[1]);for(int x=8;x<188;x+=60){Put(room,wall,x,0);Put(room,shadow,x,46);}for(int y=46;y<161;y+=60){Put(room,side,0,y);Put(room,side,188,y);}using(var cl=new Bitmap(Path.Combine(root,"corner_left_L_light_v2.png")))using(var cr=new Bitmap(Path.Combine(root,"corner_right_L_light_v2.png"))){Put(room,cl,0,0);Put(room,cr,164,0);}Ground(room,bench,19,74);Ground(room,cabinet,151,74);Put(room,hook,106,3);Ground(room,arm,126,122);Ground(room,stack,21,144);Ground(room,single,68,145);Ground(room,ch,78-Bounds(ch).Left,122);room.Save(Path.Combine(root,"equipment_bay_lappland_1x.png"));Up(room,"equipment_bay_lappland_4x",4);
   var review=New(480,150);for(int y=0;y<review.Height;y++)for(int x=0;x<review.Width;x++)review.SetPixel(x,y,floor.GetPixel(x%120,y%120));for(int x=0;x<480;x+=60)Put(review,wall,x,4);Ground(review,bench,8,76);Ground(review,ch,86-Bounds(ch).Left,76);Ground(review,cabinet,144,76);Ground(review,ch,182-Bounds(ch).Left,76);Put(review,hook,240,8);Ground(review,ch,283-Bounds(ch).Left,76);Ground(review,arm,343,76);Ground(review,ch,395-Bounds(ch).Left,76);Ground(review,stack,20,140);Ground(review,single,69,140);Ground(review,ch,104-Bounds(ch).Left,140);Ground(review,a["rhodes_workbench_off_v3"],172,140);Ground(review,a["rhodes_weapon_cabinet_off_v3"],275,140);Ground(review,a["rhodes_robotic_arm_off_v3"],345,140);review.Save(Path.Combine(root,"equipment_scale_review_1x.png"));Up(review,"equipment_scale_review_4x",4);
   report.Add("PASS static room composite196x169 (interior180x115), scale review480x150, both exact4x. Lappland frame0 copied at1:1, actual alpha>=128 height="+Bounds(ch).Height+". Composite retains character original colors.");
  }
  foreach(var kv in a){var b=kv.Value;if(kv.Key.StartsWith("rhodes_")&&kv.Key.EndsWith("_v3")&&!kv.Key.Contains("equipment_"))Metrics(kv.Key,b,true);var colors=new HashSet<int>();int cyan=0;using(var big=new Bitmap(Path.Combine(root,kv.Key+"_8x.png"))){Check(big.Width==b.Width*8&&big.Height==b.Height*8,"8x size");for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var c=b.GetPixel(x,y);Check(c.A==0||c.A==255,"binary alpha");if(c.A==255){Check(p[Near(c)].ToArgb()==c.ToArgb(),"palette");colors.Add(c.ToArgb());if(Cyan(c))cyan++;}for(int j=0;j<8;j++)for(int i=0;i<8;i++)Check(big.GetPixel(x*8+i,y*8+j).ToArgb()==c.ToArgb(),"8x blocks");}}if(kv.Key.Contains("_off_"))Check(cyan==0,"OFF cyan");report.Add("PASS "+kv.Key+": "+b.Width+"x"+b.Height+", colors="+colors.Count+", cyan="+cyan+", binary alpha, palette and exact8x");}
  foreach(string s in new[]{"workbench","weapon_cabinet","robotic_arm"}){var on=a["rhodes_"+s+"_on_v3"];var off=a["rhodes_"+s+"_off_v3"];for(int y=0;y<on.Height;y++)for(int x=0;x<on.Width;x++)Check(on.GetPixel(x,y).A==off.GetPixel(x,y).A,"ON/OFF alpha");}
  Check(bench.Height<=50&&cabinet.Height<=46&&arm.Height<=50,"prop heights");report.Add("Recolor only at native1:1. No resampling; original v1 dimensions, alpha masks, atlas origins, workbench surface height, composition, and crane anchor(17,0) preserved.");report.Add("Crane atlas baseline aligns hook tip ONLY; scene pivot is rail top midpoint, suspended with tip above floor. Empty slots intentional. NOT RUN: engine integration; visual acceptance pending.");File.WriteAllText(Path.Combine(root,"validation.txt"),string.Join("\n",report)+"\n");
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[EquipmentV3]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')



