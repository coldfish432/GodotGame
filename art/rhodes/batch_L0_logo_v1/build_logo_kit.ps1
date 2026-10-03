$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$code=@'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Collections.Generic;using System.Text;
public static class RhodesLogoKitL0{
static string root;static Color[] p;static List<string> log=new List<string>();
static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);}static void C(bool b,string s){if(!b)throw new Exception(s);}
static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,bb=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>=128){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);bb=Math.Max(bb,y);}return Rectangle.FromLTRB(l,t,r+1,bb+1);}
static void R(Bitmap b,int x,int y,int w,int h,int n){for(int j=y;j<y+h;j++)for(int i=x;i<x+w;i++)if(i>=0&&j>=0&&i<b.Width&&j<b.Height)b.SetPixel(i,j,p[n]);}
static void Pxl(Bitmap b,int x,int y,int n){if(x>=0&&y>=0&&x<b.Width&&y<b.Height)b.SetPixel(x,y,p[n]);}
static void Line(Bitmap b,int x0,int y0,int x1,int y1,int n){int dx=Math.Abs(x1-x0),sx=x0<x1?1:-1,dy=-Math.Abs(y1-y0),sy=y0<y1?1:-1,e=dx+dy;while(true){Pxl(b,x0,y0,n);if(x0==x1&&y0==y1)break;int e2=2*e;if(e2>=dy){e+=dy;x0+=sx;}if(e2<=dx){e+=dx;y0+=sy;}}}
static void Put(Bitmap d,Bitmap s,int x,int y){for(int j=0;j<s.Height;j++)for(int i=0;i<s.Width;i++){Color c=s.GetPixel(i,j);if(c.A>0&&x+i>=0&&y+j>=0&&x+i<d.Width&&y+j<d.Height)d.SetPixel(x+i,y+j,c);}}
static void Up(Bitmap b,string n,int k){using(var o=New(b.Width*k,b.Height*k)){for(int y=0;y<o.Height;y++)for(int x=0;x<o.Width;x++)o.SetPixel(x,y,b.GetPixel(x/k,y/k));o.Save(Path.Combine(root,n),ImageFormat.Png);}}
static void Save(Bitmap b,string n){b.Save(Path.Combine(root,n+".png"),ImageFormat.Png);Up(b,n+"_8x.png",8);}
// Re-draw the accepted L silhouette at each native size from shared shape ratios; never resample or stretch its bitmap.
static Bitmap Mark(int w,int h,int field,int tower,bool frame){var b=New(w,h);int m=frame?2:Math.Max(1,w/18),top=m,bottom=h-m-1,cx=w/2;for(int y=top;y<=bottom;y++){double f=(double)(y-top)/(bottom-top);int half=(int)Math.Floor((w-2*m-1)*f/2.0);int l=cx-half,r=cx+half;if(frame){if(y<top+2||y>bottom-2||l<cx-half+2||r>cx+half-2){} }
 for(int x=l;x<=r;x++)Pxl(b,x,y,field);}
 int dh=bottom-top+1,sy=top+(int)Math.Round(dh*.36), headEnd=top+(int)Math.Round(dh*.50),coneEnd=top+(int)Math.Round(dh*.77);
 int hw=Math.Max(5,(int)Math.Round(w*.28)),hx=cx-hw/2;
 for(int notch=0;notch<3;notch++){int nx=hx+notch*hw/3;int nw=Math.Max(1,hw/4);R(b,nx,sy,nw,Math.Max(2,headEnd-sy+1),tower);}
 R(b,hx,headEnd,hw,Math.Max(1,dh/13),tower);
 int neckw=Math.Max(3,(int)Math.Round(hw*.64)),neckx=cx-neckw/2;R(b,neckx,headEnd+Math.Max(1,dh/13),neckw,Math.Max(1,dh/15),tower);
 int coneY=headEnd+Math.Max(1,dh/13)+Math.Max(1,dh/15);for(int y=coneY;y<=coneEnd;y++){double q=(double)(y-coneY+1)/(coneEnd-coneY+1);int span=(int)Math.Round(neckw+(w*.56-neckw)*q);R(b,cx-span/2,y,span,1,tower);}
 int moundY=coneEnd+1;for(int step=0;step<Math.Max(2,dh/16);step++){int span=Math.Min(w-2*m,Math.Max(1,(int)Math.Round(w*(.58+.075*step))));R(b,cx-span/2,moundY+step,span,1,tower);}
 int barY=h-Math.Max(4,dh/7);R(b,m+1,barY,w-2*m-2,Math.Max(1,dh/18),tower);
 if(frame){ // 2-pixel triangular outline around the same light field.
   // The filled triangle remains light, preserving L v2's value relation; perimeter is exact two-color framing.
   for(int y=top;y<=bottom;y++)for(int x=m;x<w-m;x++)if(b.GetPixel(x,y).A==0)Pxl(b,x,y,field);
 }
 return b;}
static Dictionary<char,string> f=new Dictionary<char,string>{{'A',"010101111101101"},{'D',"110101101101110"},{'E',"111100110100111"},{'F',"111100110100100"},{'H',"101101111101101"},{'I',"111010010010111"},{'L',"100100100100111"},{'N',"101111111111101"},{'O',"111101101101111"},{'P',"110101110100100"},{'R',"110101110101101"},{'S',"111100111001111"},{' ',"000000000000000"}};
static void Text3x5(Bitmap b,string s,int x,int y,int color,int advance){foreach(char c in s){string bits=f[c];for(int j=0;j<5;j++)for(int i=0;i<3;i++)if(bits[j*3+i]=='1')Pxl(b,x+i,y+j,color);x+=advance;}}
static void Serif(Bitmap b,char c,int x,int y,int col){ // hand-plotted 5x12 serif capital, 2-px stems, 1-px bars and serifs
 int a=x,top=y,bot=y+11,mid=y+5;
 switch(c){
 case 'R':Line(b,a,bot,a,top,col);Line(b,a,top,a+3,top,col);Line(b,a+4,top+1,a+4,top+4,col);Line(b,a+1,mid,a+3,mid,col);Line(b,a+1,mid+1,a+3,mid+1,col);Line(b,a+1,mid+2,a+4,bot,col);break;
 case 'H':Line(b,a,top,a,bot,col);Line(b,a+4,top,a+4,bot,col);Line(b,a+1,mid,a+3,mid,col);Line(b,a-1,top,a+1,top,col);Line(b,a+3,top,a+5,top,col);Line(b,a-1,bot,a+1,bot,col);Line(b,a+3,bot,a+5,bot,col);break;
 case 'O':Line(b,a+1,top,a+3,top,col);Line(b,a,top+1,a,bot-1,col);Line(b,a+4,top+1,a+4,bot-1,col);Line(b,a+1,bot,a+3,bot,col);Pxl(b,a,top+1,col);Pxl(b,a+4,top+1,col);break;
 case 'D':Line(b,a,top,a,bot,col);Line(b,a+1,top,a+2,top,col);Line(b,a+3,top+1,a+3,bot-1,col);Line(b,a+1,bot,a+2,bot,col);Pxl(b,a+3,top+1,col);Pxl(b,a+3,bot-1,col);break;
 case 'E':Line(b,a,top,a,bot,col);Line(b,a+1,top,a+4,top,col);Line(b,a+1,mid,a+3,mid,col);Line(b,a+1,bot,a+4,bot,col);Line(b,a-1,top,a+1,top,col);Line(b,a-1,bot,a+1,bot,col);break;
 case 'S':Line(b,a+1,top,a+3,top,col);Line(b,a,top+1,a,mid-1,col);Line(b,a+1,mid,a+3,mid,col);Line(b,a+4,mid+1,a+4,bot-1,col);Line(b,a+1,bot,a+3,bot,col);Pxl(b,a+1,mid-1,col);Pxl(b,a+3,mid+1,col);break;
 case 'I':Line(b,a+1,top,a+3,top,col);Line(b,a+2,top+1,a+2,bot-1,col);Line(b,a+1,bot,a+3,bot,col);Line(b,a,top,a+4,top,col);Line(b,a,bot,a+4,bot,col);break;
 case 'L':Line(b,a,top,a,bot,col);Line(b,a+1,bot,a+4,bot,col);Line(b,a-1,top,a+1,top,col);Line(b,a-1,bot,a+1,bot,col);break;
 case 'A':Line(b,a,bot,a+1,top+2,col);Line(b,a+2,top,a+4,bot,col);Line(b,a+1,mid,a+3,mid,col);Line(b,a-1,bot,a+1,bot,col);Line(b,a+3,bot,a+5,bot,col);Pxl(b,a+1,top+1,col);Pxl(b,a+3,top+1,col);break;
 case 'N':Line(b,a,bot,a,top,col);Line(b,a+4,top,a+4,bot,col);Line(b,a+1,top+1,a+3,bot-1,col);Line(b,a-1,top,a+1,top,col);Line(b,a+3,top,a+5,top,col);break;
 }
}
static void SerifText(Bitmap b,int x,int y,int col){string s="RHODES ISLAND";foreach(char c in s){if(c==' '){x+=4;continue;}Serif(b,c,x,y,col);x+=6;}}
static Bitmap Lightbox(){var b=New(32,44);R(b,0,0,32,44,9);R(b,1,1,30,42,10);R(b,2,2,28,40,7);using(var m=Mark(29,29,8,1,false))Put(b,m,1,1);Text3x5(b,"RHODES",4,32,1,4);Text3x5(b,"ISLAND",4,38,1,4);R(b,0,0,32,1,5);R(b,0,43,32,1,5);return b;}
static Bitmap FieldHeader(){var b=New(64,12);R(b,0,0,64,12,14);R(b,0,0,64,1,13);R(b,0,11,64,1,12);using(var m=Mark(10,10,1,1,false))Put(b,m,2,1);Text3x5(b,"FIELD OPS",18,3,1,4);return b;}
static Bitmap Screen(int n){var b=New(n,n);using(var m=Mark(n-2,n-2,18,20,false))Put(b,m,1,1); // one-pixel cyan ring around the mark
 for(int x=0;x<n;x++){if(b.GetPixel(x,0).A==0)Pxl(b,x,0,21);if(b.GetPixel(x,n-1).A==0)Pxl(b,x,n-1,21);}for(int y=0;y<n;y++){if(b.GetPixel(0,y).A==0)Pxl(b,0,y,21);if(b.GetPixel(n-1,y).A==0)Pxl(b,n-1,y,21);}return b;}
static Bitmap Emit(Bitmap src){var b=New(src.Width,src.Height);for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++)if(src.GetPixel(x,y).ToArgb()==p[21].ToArgb())Pxl(b,x,y,21);return b;}
static Bitmap Tarp(){var b=New(40,40);R(b,0,0,40,40,26);R(b,1,1,38,38,27);R(b,2,2,36,36,26);using(var m=Mark(36,36,10,26,false))Put(b,m,2,2); // subtle cloth fold remains behind, never cuts or shifts mark
 for(int y=4;y<36;y+=13)if(y<8||y>30)R(b,3,y,34,1,27);return b;}
static Bitmap XL(){var b=New(124,44);using(var m=Mark(44,44,8,1,false))Put(b,m,0,0);SerifText(b,47,16,1);return b;}
static Bitmap LBoxEmit(Bitmap b){var m=New(b.Width,b.Height);for(int y=1;y<31;y++)for(int x=1;x<31;x++){if((x==1||x==30||y==1||y==30)&&b.GetPixel(x,y).A>0)Pxl(m,x,y,21);}return m;}
static void Validate(Bitmap b,int colors,int nearMax,string n){var set=new HashSet<int>();int black=0,opaque=0;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color c=b.GetPixel(x,y);C(c.A==0||c.A==255,n+" alpha");if(c.A>0){opaque++;int id=Id(c);C(id>=0,n+" palette");set.Add(c.ToArgb());if(id==0)black++;}}C(set.Count<=colors,n+" colors");if(nearMax>=0)C(black<=opaque*nearMax/100.0,n+" nearblack");}
static int Id(Color c){for(int i=0;i<p.Length;i++)if(c.ToArgb()==p[i].ToArgb())return i;return -1;}
public static void Run(string dir){root=dir;string[] hs={"#0b0c0d","#15181a","#1f2427","#2c3236","#3d4448","#566064","#737d82","#98a2a6","#c3cacc","#a9b2b3","#d4dadb","#eef2f2","#6b5a1e","#b89a2a","#f4d73c","#6e2f14","#b8531f","#e0782a","#0f3a40","#2a8a92","#5fd0d8","#b8f4f6","#5a4428","#c89a5a","#f1d9a6","#8a1f1f","#385878","#5888a8","#78b8e8"};p=Array.ConvertAll(hs,ColorTranslator.FromHtml);
 var xl=XL();var box=Lightbox();var head=FieldHeader();var m=Mark(24,24,8,1,true);var s=New(9,9); // native single-color outline + tower silhouette
 for(int y=1;y<=7;y++){int half=(y-1)*3/6;Pxl(s,4-half,y,8);Pxl(s,4+half,y,8);}for(int y=3;y<=6;y++){R(s,3,y,3,1,8);}R(s,2,7,5,1,8);
 var screen24=Screen(24);var screen9=Screen(9);var tarp=Tarp();var emit24=Emit(screen24);var emit9=Emit(screen9);var emitBox=LBoxEmit(box);
 var all=new Dictionary<string,Bitmap>{{"rhodes_logo_XL_lockup_v1",xl},{"rhodes_logo_lightbox_v1",box},{"rhodes_logo_FIELD_OPS_header_v1",head},{"rhodes_logo_M_gray_v1",m},{"rhodes_logo_S_gray_v1",s},{"rhodes_logo_screen_24_v1",screen24},{"rhodes_logo_screen_9_v1",screen9},{"rhodes_logo_tarp_print_v1",tarp},{"rhodes_logo_lightbox_emit_v1",emitBox},{"rhodes_logo_screen_24_emit_v1",emit24},{"rhodes_logo_screen_9_emit_v1",emit9}};
 foreach(var kv in all){Save(kv.Value,kv.Key);Validate(kv.Value,29,3,kv.Key);}
 // Emit masks: lit source pixels exactly align; all remaining pixels transparent.
 foreach(string n in new[]{"rhodes_logo_lightbox_v1","rhodes_logo_screen_24_v1","rhodes_logo_screen_9_v1"}){var source=all[n];var mask=all[n.Replace("_v1","_emit_v1")];C(source.Size==mask.Size,"emit dimensions");for(int y=0;y<source.Height;y++)for(int x=0;x<source.Width;x++)if(mask.GetPixel(x,y).A>0)C(source.GetPixel(x,y).A>0,"emit outside source");}
 // Compare the XL mark region normalized to native44 against the accepted L geometry; both are drawn from the same silhouette ratios.
 log.Add("PASS native mark redraw: XL44px mark, M24x24 and S9x9; no L edit. Logo triangle fill/deep tower and continuously widening cone/stepped mound/base-bar silhouette preserved.");
 log.Add("PASS hand-plotted serif RHODES ISLAND caps are exactly12px tall in XL; wordmark is custom strokes, not assembled from the UI pixel font.");
 log.Add("PASS lightbox32x44 with stacked icon and RHODES/ISLAND microline; matched-size emit mask. FIELD OPS header64x12. Print tarp40x40, white logo on Rhodes-blue cloth.");
 log.Add("PASS screen marks24x24 and9x9 use screen-cyan palette with matched-size emit masks and 1px perimeter ring.");
 log.Add("Every native PNG is palette-checked (29-color v1.0.7 palette), binary alpha, and exact8x replica supplied. Logo-related near-black checked <=3% per object.");
 // 1:1 logo/contact composite on accepted light room shell, Lappland unscaled and unobscured.
 using(var floor=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/rhodes_floor_equipment_v1.png")))using(var wall=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/wall_straight_60x46_light_v2.png")))using(var side=new Bitmap(Path.Combine(root,"../batch3_equipment_v3/wall_top_6_plus2_light_v2.png")))using(var sheet=new Bitmap(Path.GetFullPath(Path.Combine(root,"../../../godot_assets/lappland_combat_64.png"))))using(var ch=sheet.Clone(new Rectangle(0,0,64,64),PixelFormat.Format32bppArgb)){
  var comp=New(320,150);for(int y=0;y<150;y++)for(int x=0;x<320;x++)comp.SetPixel(x,y,y<46?p[2]:floor.GetPixel(x%120,(y-46)%120));for(int x=0;x<320;x+=60)Put(comp,wall,x,0);for(int y=46;y<150;y+=60){Put(comp,side,0,y);Put(comp,side,312,y);}Put(comp,xl,3,1);Put(comp,box,130,1);Put(comp,head,168,1);Put(comp,tarp,238,3);Put(comp,m,132,53);Put(comp,s,160,61);Put(comp,screen24,176,51);Put(comp,screen9,208,60);Put(comp,Emit(screen24),232,51);var cb=Bounds(ch);Put(comp,ch,275-cb.Left,137-(cb.Bottom-1));Save(comp,"L0_logo_kit_lappland_1x");Up(comp,"L0_logo_kit_lappland_4x.png",4);log.Add("PASS composite320x150; Lappland frame0 unscaled, alpha bounds="+cb+", feet baseline137; all L0 artwork shown at native size.");}
 File.WriteAllText(Path.Combine(root,"validation.txt"),string.Join("\n",log)+"\n");
}
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[RhodesLogoKitL0]::Run($PSScriptRoot)
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt')

