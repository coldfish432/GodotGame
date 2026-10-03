$ErrorActionPreference='Stop'
$code=@'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;
public static class RhodesL0Redo {
static string d; static Color field=ColorTranslator.FromHtml("#c3cacc"), dark=ColorTranslator.FromHtml("#15181a"), yellow=ColorTranslator.FromHtml("#f4d73c"), cyan=ColorTranslator.FromHtml("#5fd0d8"), teal=ColorTranslator.FromHtml("#0f3a40"), glow=ColorTranslator.FromHtml("#b8f4f6"), tarp=ColorTranslator.FromHtml("#385878"), fold=ColorTranslator.FromHtml("#5888a8");
static Bitmap Load(string n){return new Bitmap(Path.Combine(d,n));} static void Put(Bitmap dst,Bitmap src,int ox,int oy){for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++){Color c=src.GetPixel(x,y);if(c.A>0&&x+ox>=0&&y+oy>=0&&x+ox<dst.Width&&y+oy<dst.Height)dst.SetPixel(x+ox,y+oy,c);}}
static Bitmap ScaleL(Bitmap src,int n){var b=new Bitmap(n,n,PixelFormat.Format32bppArgb);for(int y=0;y<n;y++)for(int x=0;x<n;x++){Color c=src.GetPixel(x*src.Width/n,y*src.Height/n);if(c.A>0)b.SetPixel(x,y,c.ToArgb()==field.ToArgb()?field:dark);}return b;}
static Bitmap Grid(string name){using(var a=Load(name)){var b=new Bitmap(a.Width,a.Height,PixelFormat.Format32bppArgb);for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++){Color c=a.GetPixel(x,y);if(c.A>0)b.SetPixel(x,y,c.ToArgb()==field.ToArgb()?field:dark);}return b;}}
static void Save(Bitmap b,string n){b.Save(Path.Combine(d,n+".png"),ImageFormat.Png);var u=new Bitmap(b.Width*8,b.Height*8,PixelFormat.Format32bppArgb);for(int y=0;y<u.Height;y++)for(int x=0;x<u.Width;x++)u.SetPixel(x,y,b.GetPixel(x/8,y/8));u.Save(Path.Combine(d,n+"_8x.png"),ImageFormat.Png);u.Dispose();}
static bool In(Bitmap b,int x,int y){return x>=0&&y>=0&&x<b.Width&&y<b.Height;}
static void Px(Bitmap b,int x,int y,Color c){if(In(b,x,y))b.SetPixel(x,y,c);} static void Rect(Bitmap b,int x,int y,int w,int h,Color c){for(int j=y;j<y+h;j++)for(int i=x;i<x+w;i++)Px(b,i,j,c);}
static void Serif(Bitmap b,char c,int x,int y,Color k){ // 5x12 cap; paired stems, fine bars and terminal serifs
 switch(c){
 case 'R':Rect(b,x,y,2,12,k);Rect(b,x+1,y,4,1,k);Rect(b,x+3,y+1,2,4,k);Rect(b,x+1,y+5,4,1,k);Px(b,x-1,y,k);Px(b,x-1,y+11,k);for(int i=0;i<6;i++){int xx=x+2+(i*2/5);Rect(b,xx,y+6+i,2,1,k);}break;
 case 'H':Rect(b,x,y,2,12,k);Rect(b,x+3,y,2,12,k);Rect(b,x+1,y+5,3,1,k);Px(b,x-1,y,k);Px(b,x+5,y,k);Px(b,x-1,y+11,k);Px(b,x+5,y+11,k);break;
 case 'O':Rect(b,x,y,2,12,k);Rect(b,x+3,y,2,12,k);Rect(b,x+1,y,3,1,k);Rect(b,x+1,y+11,3,1,k);break;
 case 'D':Rect(b,x,y,2,12,k);Rect(b,x+1,y,3,1,k);Rect(b,x+3,y+1,2,10,k);Rect(b,x+1,y+11,3,1,k);break;
 case 'E':Rect(b,x,y,2,12,k);Rect(b,x+1,y,4,1,k);Rect(b,x+1,y+5,3,1,k);Rect(b,x+1,y+11,4,1,k);Px(b,x-1,y,k);Px(b,x-1,y+11,k);break;
 case 'S':Rect(b,x+1,y,4,1,k);Rect(b,x,y+1,2,4,k);Rect(b,x+1,y+5,4,1,k);Rect(b,x+3,y+6,2,5,k);Rect(b,x+1,y+11,4,1,k);Px(b,x,y+5,k);Px(b,x+4,y+6,k);break;
 case 'I':Rect(b,x+1,y,3,1,k);Rect(b,x+2,y+1,2,10,k);Rect(b,x+1,y+11,3,1,k);Rect(b,x,y,5,1,k);Rect(b,x,y+11,5,1,k);break;
 case 'L':Rect(b,x,y,2,12,k);Rect(b,x+1,y+11,4,1,k);Px(b,x-1,y,k);Px(b,x-1,y+11,k);break;
 case 'A':Rect(b,x,y+3,2,9,k);Rect(b,x+3,y+2,2,10,k);Px(b,x+2,y,k);Rect(b,x+1,y+1,3,1,k);Px(b,x+1,y+2,k);Px(b,x+2,y+2,k);Rect(b,x+1,y+6,3,1,k);Px(b,x-1,y+11,k);Px(b,x+5,y+11,k);break;
 case 'N':Rect(b,x,y,2,12,k);Rect(b,x+4,y,2,12,k);for(int i=0;i<10;i++)Px(b,x+1+i*3/9,y+1+i,k);Px(b,x-1,y,k);Px(b,x+6,y,k);Px(b,x-1,y+11,k);Px(b,x+6,y+11,k);break;
 }
 }
static void Word(Bitmap b){string s="RHODES ISLAND";int x=47;foreach(char c in s){if(c==' '){x+=4;continue;}if(c=='D'&&x==128)x++;Serif(b,c,x,16,dark);x+=7;}}
static Bitmap Screen(Bitmap src){var b=new Bitmap(src.Width,src.Height,PixelFormat.Format32bppArgb);for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++){Color c=src.GetPixel(x,y);if(c.A>0)Px(b,x,y,c.ToArgb()==field.ToArgb()?cyan:teal);} // ring goes only on vacant perimeter cells; underlying M/S stays unchanged
 for(int x=0;x<b.Width;x++){if(b.GetPixel(x,0).A==0)Px(b,x,0,glow);if(b.GetPixel(x,b.Height-1).A==0)Px(b,x,b.Height-1,glow);}for(int y=0;y<b.Height;y++){if(b.GetPixel(0,y).A==0)Px(b,0,y,glow);if(b.GetPixel(b.Width-1,y).A==0)Px(b,b.Width-1,y,glow);}return b;}
static Bitmap Emit(Bitmap src){var b=new Bitmap(src.Width,src.Height,PixelFormat.Format32bppArgb);for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++){Color c=src.GetPixel(x,y);if(c.ToArgb()==glow.ToArgb()||c.ToArgb()==cyan.ToArgb()||c.ToArgb()==teal.ToArgb())Px(b,x,y,glow);}return b;}
static Bitmap RecolorGrid(Bitmap src,bool screen){var b=new Bitmap(src.Width,src.Height,PixelFormat.Format32bppArgb);for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++){Color c=src.GetPixel(x,y);if(c.A>0)Px(b,x,y,c.ToArgb()==field.ToArgb()?(screen?cyan:field):(screen?teal:dark));}return b;}
static Bitmap LightEmit(Bitmap src){var b=new Bitmap(src.Width,src.Height,PixelFormat.Format32bppArgb);for(int y=1;y<31;y++)for(int x=1;x<31;x++)if((x==1||x==30||y==1||y==30)&&src.GetPixel(x,y).A>0)Px(b,x,y,glow);return b;}
public static void Run(string dir){d=dir;using(var accepted=Load("../batch2_v2/rhodes_logo_L_gray_v2.png"))using(var l=Load("../reference_grids/logo_M_24_from_L.png"))using(var s=Load("../reference_grids/logo_S_9_from_L.png")){
 var xl=new Bitmap(140,44,PixelFormat.Format32bppArgb);using(var mark=ScaleL(accepted,44))Put(xl,mark,0,0);Rect(xl,0,0,140,44,yellow); // safety-yellow wordmark backplate
 using(var mark=ScaleL(accepted,44))Put(xl,mark,0,0);Word(xl);Save(xl,"rhodes_logo_XL_lockup_v1");
 var oldbox=Load("rhodes_logo_lightbox_v1.png");var box=new Bitmap(oldbox.Width,oldbox.Height,PixelFormat.Format32bppArgb);for(int y=0;y<box.Height;y++)for(int x=0;x<box.Width;x++)box.SetPixel(x,y,oldbox.GetPixel(x,y));oldbox.Dispose();Rect(box,1,1,29,29,ColorTranslator.FromHtml("#2c3236"));using(var mark=ScaleL(accepted,29))Put(box,mark,1,1);Save(box,"rhodes_logo_lightbox_v1");using(var em=LightEmit(box))Save(em,"rhodes_logo_lightbox_emit_v1");
 var m=RecolorGrid(l,false);Save(m,"rhodes_logo_M_gray_v1");var sm=RecolorGrid(s,false);Save(sm,"rhodes_logo_S_gray_v1");
 var sc24=Screen(l);Save(sc24,"rhodes_logo_screen_24_v1");using(var em=Emit(sc24))Save(em,"rhodes_logo_screen_24_emit_v1");var sc9=Screen(s);Save(sc9,"rhodes_logo_screen_9_v1");using(var em=Emit(sc9))Save(em,"rhodes_logo_screen_9_emit_v1");
 var tb=new Bitmap(40,40,PixelFormat.Format32bppArgb);Rect(tb,0,0,40,40,tarp);Rect(tb,1,1,38,38,fold);Rect(tb,2,2,36,36,tarp);using(var mark=ScaleL(accepted,36))Put(tb,mark,2,2); // folded fabric crosses and partly occludes print, preserving the logo pixels underneath
 for(int i=0;i<12;i++){Px(tb,3+i,10-i/4,fold);Px(tb,4+i,11-i/4,tarp);}for(int i=0;i<11;i++){Px(tb,25+i,29-i/3,fold);Px(tb,25+i,30-i/3,tarp);}Rect(tb,8,16,1,8,fold);Save(tb,"rhodes_logo_tarp_print_v1");
 // FIELD OPS header intentionally remains byte-for-byte unchanged.
 using(var floor=Load("../batch3_equipment_v3/rhodes_floor_equipment_v1.png"))using(var wall=Load("../batch3_equipment_v3/wall_straight_60x46_light_v2.png"))using(var side=Load("../batch3_equipment_v3/wall_top_6_plus2_light_v2.png"))using(var sheet=Load("../../../godot_assets/lappland_combat_64.png"))using(var ch=sheet.Clone(new Rectangle(0,0,64,64),PixelFormat.Format32bppArgb)){
 var comp=new Bitmap(320,150,PixelFormat.Format32bppArgb);for(int y=0;y<150;y++)for(int x=0;x<320;x++)comp.SetPixel(x,y,y<46?ColorTranslator.FromHtml("#1f2427"):floor.GetPixel(x%120,(y-46)%120));for(int x=0;x<320;x+=60)Put(comp,wall,x,0);for(int y=46;y<150;y+=60){Put(comp,side,0,y);Put(comp,side,312,y);}using(var a=Load("rhodes_logo_XL_lockup_v1.png"))Put(comp,a,2,1);Put(comp,box,146,1);using(var a=Load("rhodes_logo_FIELD_OPS_header_v1.png"))Put(comp,a,180,1);Put(comp,tb,246,3);Put(comp,m,146,53);Put(comp,sm,180,60);Put(comp,sc24,198,51);Put(comp,sc9,228,58);var alpha=Bounds(ch);Put(comp,ch,275-alpha.Left,137-(alpha.Bottom-1));Save(comp,"L0_logo_kit_lappland_1x");var c4=new Bitmap(1280,600,PixelFormat.Format32bppArgb);for(int y=0;y<600;y++)for(int x=0;x<1280;x++)c4.SetPixel(x,y,comp.GetPixel(x/4,y/4));c4.Save(Path.Combine(d,"L0_logo_kit_lappland_4x.png"),ImageFormat.Png);c4.Dispose();comp.Dispose();}
 xl.Dispose();box.Dispose();m.Dispose();sm.Dispose();sc24.Dispose();sc9.Dispose();tb.Dispose(); }
}
static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,bot=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>0){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);bot=Math.Max(bot,y);}return Rectangle.FromLTRB(l,t,r+1,bot+1);}
}
'@
$gdi=[System.Drawing.Bitmap].Assembly.Location -replace 'System.Drawing.Common.dll','System.Private.Windows.GdiPlus.dll'
$core=$gdi -replace 'System.Private.Windows.GdiPlus.dll','System.Private.Windows.Core.dll'
Add-Type -TypeDefinition $code -ReferencedAssemblies @(([System.Drawing.Bitmap].Assembly.Location),([System.Drawing.Color].Assembly.Location),$gdi,$core)
[RhodesL0Redo]::Run($PSScriptRoot)
