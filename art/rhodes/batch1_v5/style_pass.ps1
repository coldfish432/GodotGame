$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$source = @'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Collections.Generic;using System.Text;
public static class RhodesStyleV5 {
 static string root,prev,project;static Color[] P;static List<string> notes=new List<string>();
 static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);}
 static Bitmap Load(string n){return new Bitmap(Path.Combine(prev,n+"_v4.png"));}
 static void R(Bitmap b,int x,int y,int w,int h,int c){for(int j=y;j<y+h;j++)for(int i=x;i<x+w;i++)b.SetPixel(i,j,P[c]);}
 static void Pixel(Bitmap b,int x,int y,int c){if(b.GetPixel(x,y).A==255)b.SetPixel(x,y,P[c]);}
 static void Put(Bitmap d,Bitmap s,int x,int y){for(int j=0;j<s.Height;j++)for(int i=0;i<s.Width;i++){if(x+i<0||y+j<0||x+i>=d.Width||y+j>=d.Height)continue;Color c=s.GetPixel(i,j);if(c.A==0)continue;if(c.A==255)d.SetPixel(x+i,y+j,c);else{Color z=d.GetPixel(x+i,y+j);int a=c.A;d.SetPixel(x+i,y+j,Color.FromArgb(255,(c.R*a+z.R*(255-a)+127)/255,(c.G*a+z.G*(255-a)+127)/255,(c.B*a+z.B*(255-a)+127)/255));}}}
 static void Check(bool ok,string s){if(!ok)throw new Exception(s);}
 static void ScaleSave(Bitmap b,string name,int k){var outb=New(b.Width*k,b.Height*k);for(int y=0;y<outb.Height;y++)for(int x=0;x<outb.Width;x++)outb.SetPixel(x,y,b.GetPixel(x/k,y/k));outb.Save(Path.Combine(root,name+".png"),ImageFormat.Png);outb.Dispose();}
 static void Save(Bitmap b,string name){b.Save(Path.Combine(root,name+"_v5.png"),ImageFormat.Png);ScaleSave(b,name+"_v5_8x",8);}
 static void AlphaSame(Bitmap a,Bitmap b,string n){Check(a.Size==b.Size,n+" size changed");for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++)Check(a.GetPixel(x,y).A==b.GetPixel(x,y).A,n+" silhouette changed");}
 static void PixelSame(Bitmap a,Bitmap b,string n){Check(a.Size==b.Size,n+" size");for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++)Check(a.GetPixel(x,y).ToArgb()==b.GetPixel(x,y).ToArgb(),n+" pixels changed");}
 static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,d=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>=128){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);d=Math.Max(d,y);}return Rectangle.FromLTRB(l,t,r+1,d+1);}
 static int Nearest(Color c){int best=int.MaxValue,index=0;for(int i=0;i<P.Length;i++){Color p=P[i];int d=(c.R-p.R)*(c.R-p.R)+(c.G-p.G)*(c.G-p.G)+(c.B-p.B)*(c.B-p.B);if(d<best){best=d;index=i;}}return index;}
 static Bitmap Wall(){var b=Load("wall_straight_60x46");for(int y=5;y<44;y++)for(int x=0;x<60;x++){Color c=b.GetPixel(x,y);if(c.ToArgb()==P[3].ToArgb())b.SetPixel(x,y,P[4]);else if(c.ToArgb()==P[4].ToArgb())b.SetPixel(x,y,P[5]);}
  // Shallow metal conduit eight pixels below the four-pixel cap.
  R(b,0,12,60,1,2);R(b,0,13,60,1,5);R(b,0,14,60,1,2);
  foreach(int x in new[]{10,40}){R(b,x,11,2,5,2);R(b,x,12,1,3,6);}
  R(b,0,44,60,1,13);R(b,0,45,60,1,1);for(int y=0;y<46;y++)b.SetPixel(59,y,b.GetPixel(0,y));return b;}
 static Bitmap Door(string n,int state){var b=Load(n);
  // All edits remain within the accepted alpha mask and outside the opening.
  R(b,4,2,37,6,3);R(b,4,2,37,1,6);R(b,4,7,37,1,1);R(b,18,1,9,7,1);R(b,19,2,7,5,7);
  R(b,7,5,8,1,17);R(b,7,6,8,1,15);R(b,29,3,6,4,1);R(b,31,4,2,2,state==2?25:20);
  for(int y=9;y<42;y++){Pixel(b,2,y,6);Pixel(b,3,y,5);Pixel(b,4,y,3);Pixel(b,40,y,5);Pixel(b,41,y,6);Pixel(b,42,y,3);}
  foreach(int yy in new[]{15,32}){R(b,1,yy,4,2,4);R(b,2,yy,2,1,7);R(b,40,yy,4,2,4);R(b,41,yy,2,1,6);}
  R(b,2,21,2,3,13);R(b,41,21,2,3,13);
  // Bevel follows existing 3,2,1 stepped alpha cut at every outer corner.
  for(int step=0;step<3;step++)for(int depth=0;depth<2;depth++){
   int xx=3-step+depth,yy=step;Pixel(b,xx,yy,depth==0?7:5);Pixel(b,44-xx,yy,depth==0?6:4);Pixel(b,xx,45-yy,depth==0?5:3);Pixel(b,44-xx,45-yy,depth==0?5:3);
  }
  if(state>0){R(b,8,12,11,1,5);R(b,26,12,9,1,5);R(b,8,41,11,1,3);R(b,26,41,9,1,3);}
  return b;}
 static Dictionary<char,string> font=new Dictionary<char,string>{{'D',"111101101101111"},{'O',"111101101101111"},{'R',"110101110101101"},{'S',"111100111001111"},{'I',"111010010010111"},{'E',"111100110100111"},{'W',"101101111111101"},{'A',"010101111101101"},{'L',"100100100100111"},{'C',"111100100100111"},{'N',"101111111111101"},{' ',"000000000000000"}};
 static void Text(Bitmap b,string s,int x,int y){foreach(char c in s){string bits=font[c];for(int j=0;j<5;j++)for(int i=0;i<3;i++)if(bits[j*3+i]=='1')b.SetPixel(x+i,y+j,P[8]);x+=4;}}
 public static void Run(string dir){root=dir;prev=Path.GetFullPath(Path.Combine(root,"../batch1_v4"));project=Path.GetFullPath(Path.Combine(root,"../../.."));string[] h={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f"};P=Array.ConvertAll(h,ColorTranslator.FromHtml);
  var wall=Wall();var rib=Load("wall_rib_6x46");var strip=Load("wall_top_6_plus2");var sd=Load("door_side_gap38");var ci=Load("corner_right_L");var co=Load("corner_left_L");
  // Recolor only E-W face pixels of corners; cap turns and side strips stay pixel-identical.
  for(int y=4;y<46;y++)for(int x=0;x<24;x++){ci.SetPixel(x,y,wall.GetPixel(x,y));co.SetPixel(8+x,y,wall.GetPixel(x,y));}
  var modules=new Dictionary<string,Bitmap>{{"wall_straight_60x46",wall},{"wall_rib_6x46",rib},{"wall_top_6_plus2",strip},{"door_side_gap38",sd},{"corner_right_L",ci},{"corner_left_L",co},{"door_open_45x46",Door("door_open_45x46",0)},{"door_closed_45x46",Door("door_closed_45x46",1)},{"door_sealed_45x46",Door("door_sealed_45x46",2)}};
  foreach(var kv in modules){using(var old=Load(kv.Key))AlphaSame(old,kv.Value,kv.Key);Save(kv.Value,kv.Key);}
  using(var old=Load("corner_right_L")){for(int y=0;y<60;y++)for(int x=0;x<32;x++)if(y<4||x>=24)Check(old.GetPixel(x,y).ToArgb()==ci.GetPixel(x,y).ToArgb(),"Right corner cap/strip changed");}
  using(var old=Load("corner_left_L")){for(int y=0;y<60;y++)for(int x=0;x<32;x++)if(y<4||x<8)Check(old.GetPixel(x,y).ToArgb()==co.GetPixel(x,y).ToArgb(),"Left corner cap/strip changed");}
  var door=modules["door_open_45x46"];for(int y=9;y<45;y++)for(int x=6;x<38;x++)Check(door.GetPixel(x,y).A==0,"32x36 clearance");
  foreach(string n in new[]{"door_open_45x46","door_closed_45x46","door_sealed_45x46"}){var b=modules[n];for(int step=0;step<3;step++)for(int x=0;x<3-step;x++){Check(b.GetPixel(x,step).A==0&&b.GetPixel(44-x,step).A==0&&b.GetPixel(x,45-step).A==0&&b.GetPixel(44-x,45-step).A==0,"3px chamfer");}}
  var atlas=New(256,192);Put(atlas,wall,2,10);Put(atlas,rib,93,10);Put(atlas,ci,144,2);Put(atlas,co,208,2);Put(atlas,door,9,74);Put(atlas,modules["door_closed_45x46"],73,74);Put(atlas,modules["door_sealed_45x46"],137,74);Put(atlas,strip,28,130);Put(atlas,sd,92,130);Save(atlas,"rhodes_walls_doors");
  var shadow=New(60,2);R(shadow,0,0,60,2,1);Save(shadow,"wall_floor_contact_shadow_60x2");
  // Accepted console is copied byte-for-byte, retaining v4 names.
  foreach(string name in new[]{"console_on_v4.png","console_off_v4.png","rhodes_console_v4.png","rhodes_console_v4_8x.png"})File.Copy(Path.Combine(prev,name),Path.Combine(root,name),true);
  using(var sheet=new Bitmap(Path.Combine(project,"godot_assets/lappland_combat_64.png")))using(var console=Load("console_on"))using(var floorsrc=new Bitmap(Path.Combine(root,"../source_batch1_v2/rhodes_floor_source_v2.png"))){
   var character=sheet.Clone(new Rectangle(0,0,64,64),PixelFormat.Format32bppArgb);var cb=Bounds(character);character.Save(Path.Combine(root,"lappland_frame0_64.png"),ImageFormat.Png);
   // The accepted high-resolution floor is sampled only for this review background;
   // its source is not modified. Uniform /10, centered1200x1200 crop ->120x120.
   var floor=New(120,120);int[] hist=new int[26];int ox=(floorsrc.Width-1200)/2,oy=(floorsrc.Height-1200)/2;
   for(int y=0;y<120;y++)for(int x=0;x<120;x++){int q=Nearest(floorsrc.GetPixel(ox+x*10+5,oy+y*10+5));floor.SetPixel(x,y,P[q]);hist[q]++;}int dom=0;for(int i=1;i<hist.Length;i++)if(hist[i]>hist[dom])dom=i;
   var comp=New(540,120);for(int y=0;y<120;y++)for(int x=0;x<540;x++)comp.SetPixel(x,y,y<16?P[1]:floor.GetPixel(x%120,y%120));R(comp,179,0,1,120,0);R(comp,359,0,1,120,0);Text(comp,"DOOR",8,5);Text(comp,"SIDE WALL",188,5);Text(comp,"CONSOLE",368,5);
   // E-W wall joins doorway directly: no rib beside the frame.
   Put(comp,wall,8,38);Put(comp,wall,113,38);Put(comp,shadow,8,84);Put(comp,shadow,113,84);Put(comp,door,68,38);
   int cx=68+6+16-(cb.Left+cb.Width/2),cy=83-(cb.Bottom-1);Put(comp,character,cx,cy);
   Put(comp,strip,209,24);Put(comp,character,230-cb.Left,83-(cb.Bottom-1));
   Put(comp,console,370,41);Put(comp,character,481-cb.Left,83-(cb.Bottom-1));
   comp.Save(Path.Combine(root,"lappland_scale_composite_1x.png"),ImageFormat.Png);ScaleSave(comp,"lappland_scale_composite_4x",4);
   for(int p=0;p<3;p++){using(var panel=comp.Clone(new Rectangle(p*180,0,180,120),PixelFormat.Format32bppArgb)){string n=new[]{"doorway","side_wall","console"}[p];panel.Save(Path.Combine(root,"comparison_"+n+"_1x.png"),ImageFormat.Png);ScaleSave(panel,"comparison_"+n+"_4x",4);}}
   notes.Add("Frame0 source rect=(0,0,64,64), unscaled. Alpha>=128 bounds="+cb+". No character pixel edits.");notes.Add("Composite foreground actor is composited OVER door jambs. Sword tips may overlap frame; this is not collision validation.");notes.Add("Preview floor only: centered1200x1200 source crop /10; nearest-palette dominant="+h[dom]+". Accepted floor source unchanged.");notes.Add("Wall face dominant=#3d4448; supporting steel=#2c3236. Contact shadow is separate60x2 overlay, wall remains60x46.");
  }
  foreach(var kv in modules){using(var n=new Bitmap(Path.Combine(root,kv.Key+"_v5.png")))using(var up=new Bitmap(Path.Combine(root,kv.Key+"_v5_8x.png"))){for(int y=0;y<n.Height;y++)for(int x=0;x<n.Width;x++){Color c=n.GetPixel(x,y);Check(c.A==0||c.A==255,"Alpha");if(c.A==255)Check(P[Nearest(c)].ToArgb()==c.ToArgb(),"Palette");for(int j=0;j<8;j++)for(int k=0;k<8;k++)Check(up.GetPixel(8*x+k,8*y+j).ToArgb()==c.ToArgb(),"8x pixels");}}}
  using(var small=new Bitmap(Path.Combine(root,"lappland_scale_composite_1x.png")))using(var big=new Bitmap(Path.Combine(root,"lappland_scale_composite_4x.png"))){for(int y=0;y<big.Height;y++)for(int x=0;x<big.Width;x++)Check(big.GetPixel(x,y).ToArgb()==small.GetPixel(x/4,y/4).ToArgb(),"4x composite pixels");}
  for(int y=0;y<46;y++)Check(wall.GetPixel(0,y)==wall.GetPixel(59,y),"Horizontal tiling seam");
  File.WriteAllText(Path.Combine(root,"validation.txt"),"PASS: all9 existing module dimensions and alpha masks identical to v4.\nPASS:32x36 clear opening unchanged;45deg3px outer chamfers all4 corners.\nPASS: side strip and side-door pixels unchanged; corner L caps and side strips unchanged.\nPASS: horizontal wall tiling edges, palette, binary alpha, exact8x exports.\nPASS: exact4x composite replica; character frame0 at native scale.\nNOTE: floor contact shadow is separate60x2 overlay.\nNOT RUN: engine validation.\n"+string.Join("\n",notes)+"\n");
 }
}
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies System.Drawing
[RhodesStyleV5]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')
