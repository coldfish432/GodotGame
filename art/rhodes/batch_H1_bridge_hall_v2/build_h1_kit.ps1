$ErrorActionPreference='Stop'
$code=@'
using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;
public static class RhodesH1Kit {
static string root,art; static Color C(string s){return ColorTranslator.FromHtml(s);} static readonly Color K=C("#0b0c0d"),D=C("#15181a"),S0=C("#1f2427"),S1=C("#2c3236"),S2=C("#3d4448"),S3=C("#566064"),G0=C("#737d82"),G1=C("#98a2a6"),G2=C("#c3cacc"),W0=C("#a9b2b3"),W1=C("#d4dadb"),W2=C("#eef2f2"),Y0=C("#6b5a1e"),Y1=C("#b89a2a"),Y2=C("#f4d73c"),O0=C("#6e2f14"),O1=C("#b8531f"),O2=C("#e0782a"),T0=C("#0f3a40"),T1=C("#2a8a92"),T2=C("#5fd0d8"),T3=C("#b8f4f6"),B0=C("#385878"),B1=C("#5888a8"),B2=C("#78b8e8"),L0=C("#5a4428"),L1=C("#c89a5a"),L2=C("#f1d9a6"),R0=C("#8a1f1f"),E0=C("#487808"),E1=C("#68d848");
static Bitmap New(int w,int h){return new Bitmap(w,h,PixelFormat.Format32bppArgb);} static void P(Bitmap b,int x,int y,Color c){if(x>=0&&y>=0&&x<b.Width&&y<b.Height)b.SetPixel(x,y,c);} static void Rect(Bitmap b,int x,int y,int w,int h,Color c){for(int j=y;j<y+h;j++)for(int i=x;i<x+w;i++)P(b,i,j,c);} static void Line(Bitmap b,int x0,int y0,int x1,int y1,Color c){int dx=Math.Abs(x1-x0),sx=x0<x1?1:-1,dy=-Math.Abs(y1-y0),sy=y0<y1?1:-1,e=dx+dy;while(true){P(b,x0,y0,c);if(x0==x1&&y0==y1)break;int e2=2*e;if(e2>=dy){e+=dy;x0+=sx;}if(e2<=dx){e+=dx;y0+=sy;}}}
static void Poly(Bitmap b,int[] xy,Color c){int n=xy.Length/2,minY=b.Height,maxY=0;for(int i=0;i<n;i++){minY=Math.Min(minY,xy[i*2+1]);maxY=Math.Max(maxY,xy[i*2+1]);}for(int y=minY;y<=maxY;y++){double[] xs=new double[n];int xn=0;for(int i=0,j=n-1;i<n;j=i++){int xi=xy[2*i],yi=xy[2*i+1],xj=xy[2*j],yj=xy[2*j+1];if((yi<y+.5&&yj>=y+.5)||(yj<y+.5&&yi>=y+.5))xs[xn++]=xi+(y+.5-yi)*(xj-xi)/(double)(yj-yi);}Array.Sort(xs,0,xn);for(int k=0;k+1<xn;k+=2)for(int x=(int)Math.Ceiling(xs[k]);x<=Math.Floor(xs[k+1]);x++)P(b,x,y,c);}}
static void Blit(Bitmap d,Bitmap s,int ox,int oy){for(int y=0;y<s.Height;y++)for(int x=0;x<s.Width;x++){Color q=s.GetPixel(x,y);if(q.A>0)P(d,ox+x,oy+y,q);}} static void BlitAdd(Bitmap d,Bitmap s,int ox,int oy){for(int y=0;y<s.Height;y++)for(int x=0;x<s.Width;x++){int tx=ox+x,ty=oy+y;if(tx<0||ty<0||tx>=d.Width||ty>=d.Height)continue;Color q=s.GetPixel(x,y);if(q.A==0)continue;Color v=d.GetPixel(tx,ty);P(d,tx,ty,Color.FromArgb(255,Math.Min(255,v.R+q.R),Math.Min(255,v.G+q.G),Math.Min(255,v.B+q.B)));}} static Bitmap Load(string rel){return new Bitmap(Path.Combine(art,rel));}
static void Save(Bitmap b,string file){string f=Path.Combine(root,file);b.Save(f,ImageFormat.Png);using(Bitmap u=New(b.Width*8,b.Height*8)){for(int y=0;y<u.Height;y++)for(int x=0;x<u.Width;x++)u.SetPixel(x,y,b.GetPixel(x/8,y/8));u.Save(Path.Combine(root,Path.GetFileNameWithoutExtension(file)+"_8x.png"),ImageFormat.Png);}}
static Bitmap Emit(Bitmap b,params Color[] cs){Bitmap e=New(b.Width,b.Height);for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){Color q=b.GetPixel(x,y);foreach(Color c in cs)if(q.ToArgb()==c.ToArgb()){e.SetPixel(x,y,q);break;}}return e;}
static void SavePair(Bitmap b,string name,params Color[] emit){Save(b,name+".png");if(emit.Length>0){using(Bitmap e=Emit(b,emit))Save(e,name+"_emit.png");}}
static void Screen(Bitmap b,int x,int y,int w,int h,int seed){Poly(b,new[]{x,y+3,x+3,y,x+w-3,y,x+w,y+3,x+w,y+h-2,x+2,y+h},S0);Poly(b,new[]{x+2,y+4,x+4,y+2,x+w-4,y+2,x+w-2,y+4,x+w-2,y+h-4,x+3,y+h-2},B0);Rect(b,x+4,y+4,w-10,1,T3);Rect(b,x+4,y+6,w-9,1,T2);for(int i=0;i<3;i++){int bx=x+5+i*4, bh=4+((i+seed)%5);Rect(b,bx,y+h-4-bh,2,bh,(i%2==0?T1:B1));}Line(b,x+4,y+h-3,x+w-4,y+h-3,T3);}
static string Pattern(char c){switch(c){case 'A':return "010101111101101";case 'B':return "110101110101110";case 'C':return "011100100100011";case 'D':return "110101101101110";case 'E':return "111100110100111";case 'F':return "111100110100100";case 'G':return "011100101101011";case 'H':return "101101111101101";case 'I':return "111010010010111";case 'K':return "101101110101101";case 'L':return "100100100100111";case 'M':return "101111111101101";case 'N':return "101111111111101";case 'O':return "010101101101010";case 'P':return "110101110100100";case 'R':return "110101110101101";case 'S':return "011100010001110";case 'T':return "111010010010010";case 'U':return "101101101101111";case 'V':return "101101101101010";case 'W':return "101101111111101";case 'X':return "101101010101101";case 'Y':return "101101010010010";case '0':return "111101101101111";case '1':return "010110010010111";case '2':return "110001010100111";case '3':return "110001010001110";case '4':return "101101111001001";case '7':return "111001010010010";case '-':return "000000111000000";case ' ':return "000000000000000";}return null;}
static void Text3(Bitmap b,string s,int x,int y,Color c){foreach(char ch in s){string m=Pattern(ch);if(m!=null)for(int yy=0;yy<5;yy++)for(int xx=0;xx<3;xx++)if(m[yy*3+xx]=='1')P(b,x+xx,y+yy,c);x+=4;}}
static void TiltScreen(Bitmap b,int x,int y,int w,int h,int variant){
 Poly(b,new[]{x+3,y,x+w-1,y+2,x+w-4,y+h-1,x,y+h-3},S2);
 Poly(b,new[]{x+4,y+2,x+w-4,y+3,x+w-6,y+h-3,x+3,y+h-4},T0);
 Line(b,x+5,y+5,x+w-8,y+6,B1);
 Line(b,x+5,y+h-6,x+9,y+h-9,T2);Line(b,x+9,y+h-9,x+13,y+h-7,T2);Line(b,x+13,y+h-7,x+w-8,y+h-11,T3);
 if(variant%2==0){P(b,x+7,y+7,T3);P(b,x+w-9,y+8,T2);}else{Line(b,x+7,y+8,x+w-11,y+8,B2);P(b,x+w-10,y+7,T3);}
}
static Bitmap Window(bool flip,Bitmap logoS){Bitmap b=New(98,46);
 Poly(b,new[]{0,0,97,0,97,39,91,46,6,46,0,39},S1);Rect(b,5,1,88,2,G0);
 Poly(b,new[]{5,5,91,5,95,35,88,39,9,39,3,35},S0);
 Poly(b,new[]{12,7,81,7,90,33,7,33},G0);
 Poly(b,new[]{14,9,79,9,82,15,12,15},L2);
 Poly(b,new[]{12,16,83,16,85,20,10,20},W1);
 Poly(b,new[]{10,21,86,21,89,31,7,31},B0);
 Line(b,9,24,86,24,B1);Line(b,8,30,88,30,S3);
 Line(b,26,7,38,33,S0);Line(b,27,7,39,33,S2);Line(b,60,7,72,33,S0);Line(b,61,7,73,33,S2);
 Line(b,1,2,13,36,G1);Line(b,2,2,14,36,S2);Line(b,95,2,83,36,G1);Line(b,94,2,82,36,S2);
 Rect(b,4,34,90,4,S2);Rect(b,5,38,88,2,Y1);Rect(b,4,41,90,3,S0);
 Line(b,7,33,7,38,G0);Line(b,90,33,90,38,G0);
 TiltScreen(b,5,27,18,11,0);TiltScreen(b,75,27,18,11,1);
 Blit(b,logoS,44,35);
 if(flip){using(Bitmap f=New(b.Width,b.Height)){for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)f.SetPixel(b.Width-1-x,y,b.GetPixel(x,y));return f.Clone(new Rectangle(0,0,f.Width,f.Height),PixelFormat.Format32bppArgb);}}
 return b;}

static Bitmap Slot(int w,bool lightbox){Bitmap b=New(w,46);Rect(b,0,0,w,46,S1);Rect(b,1,1,w-2,44,S2);Rect(b,2,2,w-4,42,S0);int hole=lightbox?32:140, x=(w-hole)/2;Rect(b,x-1,0,hole+2,1,G0);Rect(b,x-1,45,hole+2,1,D);Rect(b,x-1,1,1,44,G1);Rect(b,x+hole,1,1,44,S0);if(lightbox){Rect(b,0,0,2,46,S3);Rect(b,w-2,0,2,46,D);}for(int y=1;y<45;y++)for(int xx=x;xx<x+hole;xx++)b.SetPixel(xx,y,Color.Transparent);return b;}
static void Chevron(Bitmap b,int x,int y,bool right,Color c){if(right){Line(b,x,y,x+4,y+4,c);Line(b,x+4,y+4,x,y+8,c);}else{Line(b,x+4,y,x,y+4,c);Line(b,x,y+4,x+4,y+8,c);}}
static Bitmap Lift(int state,Bitmap logoS){Bitmap b=New(96,62);Poly(b,new[]{0,6,6,0,90,0,96,6,96,56,90,62,6,62,0,56},S0);Poly(b,new[]{2,7,7,2,89,2,94,7,94,55,89,60,7,60,2,55},S1);Poly(b,new[]{7,10,11,6,85,6,89,10,89,55,85,59,11,59,7,55},S2);Rect(b,11,13,74,45,S0);Rect(b,13,16,70,41,S1);Rect(b,8,14,1,42,Y2);Rect(b,9,14,1,42,Y1);Rect(b,86,14,1,42,Y1);Rect(b,87,14,1,42,Y2);Rect(b,12,11,72,3,G0);Chevron(b,34,2,true,Y2);Chevron(b,56,2,false,Y2);if(state<2){Rect(b,16,18,31,37,S2);Rect(b,49,18,31,37,S1);Rect(b,18,20,27,2,G0);Rect(b,51,20,27,2,G0);Rect(b,46,18,2,37,D);for(int y=23;y<52;y+=7){Rect(b,20,y,23,1,S3);Rect(b,53,y,23,1,S3);}Rect(b,39,35,2,8,Y1);Rect(b,55,35,2,8,Y1);}else{Rect(b,15,17,17,39,S2);Rect(b,64,17,17,39,S2);Rect(b,17,19,13,2,G0);Rect(b,66,19,13,2,G0);Rect(b,33,18,29,36,L0);Rect(b,35,20,25,32,L1);Rect(b,37,21,21,30,L2);Rect(b,42,22,12,1,W2);Rect(b,39,26,17,1,L2);}Rect(b,45,8,6,3,state==1?T2:(state==2?L2:S3));if(state==1)Rect(b,44,7,8,1,T3);if(state==2){Rect(b,40,5,16,1,L2);Rect(b,42,4,12,1,L1);}Blit(b,logoS,18,47);return b;}
static Bitmap LiftModule(int state,Bitmap logoS,Bitmap header){Bitmap b=New(96,74);Blit(b,header,16,0);using(Bitmap lift=Lift(state,logoS))Blit(b,lift,0,12);return b;}
static Bitmap Monitors(int count,Bitmap logoS){int w=count==2?56:88,h=count==2?42:50;Bitmap b=New(w,h);
 Rect(b,2,0,w-4,3,S2);Rect(b,4,1,w-8,1,G0);Rect(b,0,0,3,5,S0);Rect(b,w-3,0,3,5,S0);
 int[] xs=count==2?new[]{3,29}:new[]{2,23,44,65};
 for(int i=0;i<count;i++){int x=xs[i],yy=13+(i%2==0?0:3),sw=count==2?23:21;
  Rect(b,x+9,3,2,6,S2);Line(b,x+10,8,x+13,yy-1,G0);Line(b,x+13,yy-1,x+15,yy+1,S2);
  TiltScreen(b,x,yy,sw,18,i);Rect(b,x+7,yy+18,sw-12,2,S1);
 }
 Blit(b,logoS,w/2-4,2);
 return b;}

static Bitmap Cable(int variant){int w=variant==0?28:44,h=variant==0?36:18;Bitmap b=New(w,h);if(variant==0){Line(b,5,0,5,15,O1);Line(b,6,0,6,15,O2);Line(b,5,15,9,21,O1);Line(b,9,21,16,24,O2);Line(b,16,24,16,31,O1);Line(b,17,24,17,31,O2);Rect(b,13,31,8,3,S1);Rect(b,14,30,5,1,G0);}else{Line(b,0,4,22,4,O1);Line(b,0,5,22,5,O2);Line(b,22,4,29,10,O1);Line(b,23,5,30,10,O2);Line(b,29,10,43,10,O1);Line(b,30,11,43,11,O2);Rect(b,39,8,5,6,S1);}return b;}
static Bitmap Platform(){Bitmap b=New(164,44);
 Rect(b,3,26,158,5,G0);Rect(b,4,27,156,2,G1);Rect(b,3,31,158,2,Y2);
 for(int x=5;x<160;x+=12){Line(b,x,31,x+3,32,D);}
 Rect(b,3,33,158,6,S2);Rect(b,4,34,156,4,S3);Rect(b,3,39,158,3,S0);Rect(b,3,42,158,2,D);
 Rect(b,4,5,156,2,Y1);Rect(b,5,4,154,2,Y2);Rect(b,6,7,152,2,G0);
 for(int x=8;x<158;x+=22){Rect(b,x,8,2,18,S2);Rect(b,x,9,1,16,G1);Rect(b,x-1,24,4,2,S0);}
 return b;}
static Bitmap PlatformModule(int variant){int w=variant<2?32:20;Bitmap b=New(w,44);bool right=variant==1||variant==3;
 Rect(b,0,26,w,5,G0);Rect(b,1,27,w-2,2,G1);Rect(b,0,31,w,2,Y2);for(int x=2;x<w-2;x+=8)Line(b,x,31,x+2,32,D);
 Rect(b,0,33,w,6,S2);Rect(b,1,34,w-2,4,S3);Rect(b,0,39,w,3,S0);Rect(b,0,42,w,2,D);
 Rect(b,0,5,w,2,Y1);Rect(b,0,4,w,2,Y2);Rect(b,0,7,w,2,G0);
 int edge=right?w-4:2;Rect(b,edge,7,2,19,S2);Rect(b,edge,8,1,17,G1);Rect(b,edge-1,24,4,2,S0);
 if(variant<2){int x0=right?w-16:15,x1=right?w-3:2;Line(b,x0,7,x1,19,Y2);Line(b,x0,8,x1,20,Y1);Line(b,x1,20,x1,25,S2);}else{Rect(b,edge-1,3,4,3,Y2);Rect(b,edge,7,2,18,S2);}
 return b;}

static Bitmap Station(bool on,Bitmap logoS){Bitmap b=New(48,50);
 Rect(b,2,20,44,4,G0);Rect(b,4,21,40,2,G1);Rect(b,3,24,42,10,S1);Rect(b,4,25,40,7,S2);Rect(b,5,34,3,6,S0);Rect(b,40,34,3,6,S0);
 Rect(b,15,3,22,16,S0);Rect(b,17,5,18,12,on?B0:S1);Rect(b,18,6,16,9,on?T0:S0);
 if(on){Line(b,19,12,23,10,T2);Line(b,23,10,27,11,T2);Line(b,27,11,32,8,T3);P(b,31,8,W2);Rect(b,18,6,9,1,B2);}else{Rect(b,20,10,11,1,S3);Rect(b,20,12,7,1,S2);}
 Rect(b,24,19,3,2,S2);Blit(b,logoS,6,25);
 Rect(b,11,36,26,3,S2);Rect(b,13,39,22,7,S0);Rect(b,15,40,18,5,S3);Rect(b,12,46,3,3,D);Rect(b,33,46,3,3,D);
 Rect(b,2,39,3,2,S0);Rect(b,43,39,3,2,S0);return b;}

static Bitmap Barrier(Bitmap tarp,Bitmap logoS){Bitmap b=New(128,56);
 // Uncleared, dim debris is visible behind the striped fence.
 Rect(b,7,27,25,12,S1);Rect(b,10,24,20,3,S2);Rect(b,9,28,21,8,S3);Line(b,9,28,29,36,S1);
 Rect(b,88,23,25,15,S1);Rect(b,91,21,19,2,S2);Rect(b,90,25,20,10,S3);Line(b,90,25,110,35,S1);
 Poly(b,new[]{35,24,43,22,52,28,51,33,34,34},S2);Line(b,36,27,49,30,G0);
 Poly(b,new[]{73,23,91,27,86,34,70,32},S2);Line(b,74,25,88,29,G0);
 Line(b,13,20,26,27,O0);Line(b,26,27,31,31,O1);Line(b,103,15,101,27,O0);Line(b,101,27,113,30,O1);
 Rect(b,4,34,120,5,Y1);Rect(b,4,44,120,5,Y1);
 for(int x=5;x<124;x+=8){Line(b,x,34,x+4,38,S0);Line(b,x,44,x+4,48,S0);}
 for(int x=7;x<124;x+=22){Rect(b,x,31,3,21,S0);Rect(b,x+1,32,1,19,G0);}
 Rect(b,3,51,122,3,D);Rect(b,5,54,118,2,S1);
 Poly(b,new[]{14,7,24,24,4,24},Y2);Poly(b,new[]{14,10,21,22,7,22},Y1);Rect(b,13,13,2,5,D);Rect(b,13,20,2,2,D);
 Poly(b,new[]{39,7,47,5,54,8,64,6,74,9,86,6,90,13,89,48,82,53,74,50,65,55,55,51,46,54,39,49},B0);Line(b,41,12,40,48,B1);Line(b,86,12,88,48,B1);Line(b,42,50,48,52,S2);Line(b,78,52,85,49,S2);Blit(b,tarp,44,9);Blit(b,logoS,105,6);return b;}

static Bitmap Elevator(bool open,Bitmap logoS){Bitmap b=New(64,58);Poly(b,new[]{0,6,6,0,58,0,64,6,64,52,58,58,6,58,0,52},S0);Poly(b,new[]{2,7,7,2,57,2,62,7,62,51,57,56,7,56,2,51},S1);Rect(b,7,8,2,43,Y2);Rect(b,55,8,2,43,Y2);Rect(b,10,8,44,43,S0);if(open){Rect(b,11,12,42,36,L0);Rect(b,13,14,38,32,L1);Rect(b,15,16,34,28,L2);Rect(b,19,18,26,2,W2);Rect(b,19,24,26,1,L2);Rect(b,19,29,26,1,L2);}else{Rect(b,11,10,20,41,S2);Rect(b,33,10,21,41,S1);Rect(b,13,12,16,3,G0);Rect(b,35,12,17,3,G0);Rect(b,31,11,2,40,D);for(int y=20;y<46;y+=8){Rect(b,15,y,12,1,S3);Rect(b,37,y,12,1,S3);}}Blit(b,logoS,14,43);return b;}
static Bitmap Arrow(int idx){Bitmap b=New(40,28);
 Poly(b,new[]{20,0,39,14,29,14,29,27,11,27,11,14,1,14},D);
 Poly(b,new[]{20,3,35,13,27,13,27,25,13,25,13,13,5,13},Y2);
 Line(b,14,24,26,24,Y1);Line(b,9,12,19,5,W1);
 if(idx==0){Rect(b,16,17,8,7,D);Rect(b,17,18,6,5,Y2);Rect(b,18,14,1,4,D);Rect(b,21,14,1,4,D);Rect(b,18,14,4,1,D);}
 if(idx==1){Line(b,17,22,23,16,D);Line(b,18,22,24,16,D);Rect(b,21,15,4,2,D);Line(b,15,21,19,25,D);}
 if(idx==2){Rect(b,16,17,9,7,D);Rect(b,17,18,7,5,Y2);Line(b,17,18,23,22,D);Line(b,23,18,17,22,D);}
 if(idx==3){Rect(b,18,16,4,8,D);Rect(b,16,18,8,4,D);}
 return b;}

static Bitmap SideSign(int i){string[] ids={"B1-01","B1-02","B1-03","B1-04"};string[] rooms={"STORE","ARMORY","WAREHOUSE","MEDICAL"};Bitmap b=New(58,20);Rect(b,0,0,58,20,S0);Rect(b,1,1,56,18,S2);Rect(b,2,2,54,2,i==0?Y2:B1);Rect(b,3,5,52,13,S1);Text3(b,ids[i],5,6,G2);Text3(b,rooms[i],5,13,W1);Rect(b,51,6,4,8,(i==3?E1:Y1));return b;}

static Bitmap ExitSign(){Bitmap b=New(48,18);Rect(b,0,0,48,18,E0);Rect(b,1,1,46,16,E1);Rect(b,2,2,44,14,E0);Text3(b,"EXIT",18,6,W2);Line(b,4,9,13,9,W2);Line(b,4,9,8,5,W2);Line(b,4,9,8,13,W2);return b;}
static Bitmap Marker(bool yellow){Bitmap b=New(12,12);Color f=yellow?Y2:T2,lo=yellow?Y0:T0;Poly(b,new[]{6,0,11,6,6,11,0,6},lo);Poly(b,new[]{6,2,9,6,6,9,2,6},f);P(b,5,4,W2);P(b,6,4,W2);P(b,5,5,W2);return b;}
static void EllipseBand(Bitmap b,int rx,int ry,Color c){int cx=b.Width/2,cy=b.Height/2;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){long dx=x-cx,dy=y-cy;if(dx*dx*ry*ry+dy*dy*rx*rx<=(long)rx*rx*ry*ry)P(b,x,y,c);}}
static Bitmap Pool(int w,int h,int kind,bool warm){Bitmap b=New(w,h);Rect(b,0,0,w,h,Color.FromArgb(255,0,0,0));
 Color outer=warm?O0:T0,mid=warm?L0:B0,inner=warm?L1:T1;
 if(kind==0){EllipseBand(b,w/2-2,h/2-2,outer);EllipseBand(b,w/2-7,h/2-6,mid);EllipseBand(b,w/2-13,h/2-10,inner);}
 else if(kind==1){Rect(b,3,3,w-6,h-6,outer);Rect(b,4,2,w-8,1,outer);Rect(b,4,h-3,w-8,1,outer);Rect(b,9,8,w-18,h-16,mid);Rect(b,10,7,w-20,1,mid);Rect(b,14,13,w-28,h-26,inner);}
 else{Poly(b,new[]{w/2,2,w-3,h-3,3,h-3},outer);Poly(b,new[]{w/2,10,w-13,h-9,13,h-9},mid);Poly(b,new[]{w/2,20,w-25,h-17,25,h-17},inner);}
 return b;}

static Bitmap Extinguisher(){Bitmap b=New(14,28);Rect(b,4,5,7,19,R0);Rect(b,5,6,5,16,O1);Rect(b,6,4,3,2,S2);Line(b,6,4,3,1,S2);Line(b,3,1,7,1,S2);Rect(b,3,22,9,2,S1);Rect(b,2,3,2,4,Y1);Rect(b,11,4,2,3,G1);return b;}
static Bitmap StopPlate(){Bitmap b=New(16,20);Rect(b,1,1,14,18,S0);Rect(b,2,2,12,16,R0);Rect(b,4,4,8,8,O1);Rect(b,5,5,6,6,O2);Rect(b,6,6,4,4,R0);Rect(b,3,14,10,2,G1);Rect(b,4,17,8,1,D);return b;}
static Bitmap Memo(){Bitmap b=New(16,14);Poly(b,new[]{2,1,12,1,14,3,14,13,2,13},W1);Rect(b,4,4,7,1,B0);Rect(b,4,6,8,1,G1);Rect(b,4,8,5,1,G1);Rect(b,4,11,6,1,O2);return b;}
static Bitmap Mug(){Bitmap b=New(12,10);Rect(b,2,2,7,6,W1);Rect(b,3,3,5,3,B1);Rect(b,9,3,2,3,W1);Rect(b,3,8,6,1,S2);return b;}
static Bitmap IdBadge(Bitmap logoS){Bitmap b=New(38,14);Rect(b,0,0,38,14,S1);Rect(b,1,1,36,12,S3);Blit(b,logoS,2,3);Text3(b,"RI-07",15,4,W1);return b;}

static Bitmap SafetyPanel(Bitmap logoS){Bitmap b=New(68,50);Rect(b,0,1,68,47,S1);Rect(b,1,2,66,44,S2);Rect(b,2,3,64,42,S1);
 Rect(b,4,6,25,10,Y0);Rect(b,5,7,23,8,Y2);Text3(b,"RI-01",6,9,D);
 using(Bitmap e=Extinguisher())Blit(b,e,4,20);using(Bitmap s=StopPlate())Blit(b,s,31,5);using(Bitmap m=Memo())Blit(b,m,49,5);
 using(Bitmap id=IdBadge(logoS))Blit(b,id,26,32);
 Rect(b,59,22,5,7,O1);Rect(b,60,23,3,5,O2);Rect(b,3,3,2,2,G2);Rect(b,63,3,2,2,G2);
 for(int x=4;x<68;x+=8)P(b,x,45,G0);return b;}

static Bitmap Boarding(){Bitmap b=New(96,48);Rect(b,2,2,92,2,Y2);Rect(b,2,44,92,2,Y2);Rect(b,2,2,2,44,Y2);Rect(b,92,2,2,44,Y2);for(int x=7;x<92;x+=12){Line(b,x,4,x+5,10,Y1);Line(b,x,40,x+5,46,Y1);}Rect(b,8,9,80,1,S1);Rect(b,8,38,80,1,S1);return b;}
static Rectangle Bounds(Bitmap b){int l=b.Width,t=b.Height,r=-1,bb=-1;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(b.GetPixel(x,y).A>0){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);bb=Math.Max(bb,y);}return Rectangle.FromLTRB(l,t,r+1,bb+1);}
static Bitmap Crop(Bitmap b,int x,int y,int w,int h){return b.Clone(new Rectangle(x,y,w,h),PixelFormat.Format32bppArgb);}
public static void Run(string outDir,string artRoot){root=outDir;art=artRoot;using(Bitmap logoS=Load("batch_L0_logo_v1/rhodes_logo_S_gray_v1.png"))using(Bitmap tarp=Load("batch_L0_logo_v1/rhodes_logo_tarp_print_v1.png"))using(Bitmap xl=Load("batch_L0_logo_v1/rhodes_logo_XL_lockup_v1.png"))using(Bitmap lb=Load("batch_L0_logo_v1/rhodes_logo_lightbox_v1.png"))using(Bitmap header=Load("batch_L0_logo_v1/rhodes_logo_FIELD_OPS_header_v1.png"))using(Bitmap consoleOff=Load("batch1_v5/console_off_v4.png"))using(Bitmap consoleOn=Load("batch1_v5/console_on_v4.png"))using(Bitmap atlas=Load("batch2_v1/rhodes_logistics_atlas_v1.png"))using(Bitmap floor=Load("batch2_v2/rhodes_floor_v1.png"))using(Bitmap wall=Load("batch1_v5/wall_straight_60x46_v5.png"))using(Bitmap lapSheet=Load("batch1_v5/lappland_frame0_64.png")){
  using(Bitmap wL=Window(false,logoS))SavePair(wL,"north_wall_window_left_98x46",T2,T3,L2,W1);using(Bitmap wR=Window(true,logoS))SavePair(wR,"north_wall_window_right_98x46",T2,T3,L2,W1);using(Bitmap sl=Slot(146,false))Save(sl,"north_wall_XL_backplate_slot_146x46.png");using(Bitmap sb=Slot(36,true))Save(sb,"north_wall_lightbox_slot_36x46.png");
 Bitmap cLift=LiftModule(0,logoS,header),sLift=LiftModule(1,logoS,header),oLift=LiftModule(2,logoS,header);SavePair(cLift,"exit_lift_closed_module");SavePair(sLift,"exit_lift_standby_module",T2,T3);SavePair(oLift,"exit_lift_open_module",L1,L2,W2);
 using(Bitmap mon2=Monitors(2,logoS))SavePair(mon2,"hanging_monitor_cluster_2",T1,T2,T3,B2);using(Bitmap mon4=Monitors(4,logoS))SavePair(mon4,"hanging_monitor_cluster_4",T1,T2,T3,B2);
 using(Bitmap cable=Cable(0))Save(cable,"orange_cable_drop_28x36.png");using(Bitmap cable=Cable(1))Save(cable,"orange_cable_run_44x18.png");using(Bitmap plat=Platform())Save(plat,"dispatch_platform_railing_164x44.png");for(int i=0;i<4;i++){using(Bitmap pm=PlatformModule(i))Save(pm,i==0?"dispatch_platform_corner_left_32x44.png":i==1?"dispatch_platform_corner_right_32x44.png":i==2?"dispatch_platform_end_left_20x44.png":"dispatch_platform_end_right_20x44.png");}
  using(Bitmap station=Station(false,logoS))Save(station,"duty_station_empty_off.png");using(Bitmap station=Station(true,logoS))SavePair(station,"duty_station_empty_on",T2,T3);
  Save(consoleOff,"accepted_dispatch_console_off_95x43.png");SavePair(consoleOn,"accepted_dispatch_console_on_95x43",T1,T2,T3);
  using(Bitmap counterOff=Crop(atlas,156,74,71,40))Save(counterOff,"accepted_logistics_counter_off_71x40.png");using(Bitmap counterOn=Crop(atlas,28,74,71,40))SavePair(counterOn,"accepted_logistics_counter_on_71x40",T1,T2,T3);using(Bitmap genericDoor=Load("batch1_v5/door_open_45x46_v5.png"))SavePair(genericDoor,"accepted_generic_door_open_45x46",T1,T2,T3);
 using(Bitmap barri=Barrier(tarp,logoS))Save(barri,"wing_construction_barrier_uncleared_128x56.png");using(Bitmap ev=Elevator(false,logoS))Save(ev,"hall_elevator_closed_64x58.png");using(Bitmap ev=Elevator(true,logoS))SavePair(ev,"hall_elevator_open",L1,L2);
 for(int i=0;i<4;i++){using(Bitmap a=Arrow(i))Save(a,"floor_arrow_icon_0"+(i+1)+".png");using(Bitmap s=SideSign(i))Save(s,"side_wall_top_sign_0"+(i+1)+".png");}
  using(Bitmap exit=ExitSign())SavePair(exit,"exit_wayfinding_sign",E0,E1,W2);using(Bitmap m=Marker(false))SavePair(m,"interaction_marker_cyan",T2,T3);using(Bitmap m=Marker(true))SavePair(m,"interaction_marker_yellow",Y2);
 string[] names={"light_pool_circle_warm_60x40","light_pool_rectangle_warm_90x60","light_pool_fan_warm_120x80","light_pool_circle_cool_60x40","light_pool_rectangle_cool_90x60","light_pool_fan_cool_120x80"};int[] ws={60,90,120,60,90,120},hs={40,60,80,40,60,80};for(int i=0;i<6;i++){using(Bitmap pool=Pool(ws[i],hs[i],i%3,i<3))SavePair(pool,names[i],i<3?new[]{O0,L0,L1}:new[]{T0,B0,T1});}
  using(Bitmap d=Extinguisher())Save(d,"wall_mounted_extinguisher_14x28.png");using(Bitmap d=StopPlate())Save(d,"emergency_stop_plate_16x20.png");using(Bitmap d=Memo())Save(d,"desk_memo_sticker_16x14.png");using(Bitmap d=Mug())Save(d,"duty_mug_clip_12x10.png");using(Bitmap d=IdBadge(logoS))Save(d,"equipment_id_badge_RI-07_38x14.png");using(Bitmap d=SafetyPanel(logoS))Save(d,"wall_safety_detail_panel_68x50.png");using(Bitmap d=Boarding())Save(d,"lift_boarding_zone_decal_96x48.png");
 // Contact sheet is a scale reference only. It reuses locked floor/wall/door/counter/console/logo pixels without resampling.
 using(Bitmap comp=New(960,480)){for(int y=0;y<comp.Height;y++)for(int x=0;x<comp.Width;x++){Color q=y<46?S1:floor.GetPixel(x%floor.Width,(y-46)%floor.Height);comp.SetPixel(x,y,q);}for(int x=0;x<comp.Width;x+=60)Blit(comp,wall,x,0);using(Bitmap t=Window(false,logoS))Blit(comp,t,12,0);using(Bitmap t=Slot(146,false))Blit(comp,t,110,0);Blit(comp,xl,113,1);using(Bitmap t=Slot(36,true))Blit(comp,t,256,0);Blit(comp,lb,258,1);using(Bitmap t=Window(true,logoS))Blit(comp,t,292,0);
  Blit(comp,cLift,11,49);Blit(comp,sLift,117,49);Blit(comp,oLift,223,49);using(Bitmap mon2=Monitors(2,logoS))Blit(comp,mon2,331,58);using(Bitmap mon4=Monitors(4,logoS))Blit(comp,mon4,391,55);using(Bitmap p=Platform())Blit(comp,p,517,66);using(Bitmap m=PlatformModule(0))Blit(comp,m,485,66);using(Bitmap m=PlatformModule(1))Blit(comp,m,681,66);using(Bitmap m=PlatformModule(2))Blit(comp,m,720,66);using(Bitmap m=PlatformModule(3))Blit(comp,m,744,66);using(Bitmap cable=Cable(0))Blit(comp,cable,790,55);using(Bitmap cable=Cable(1))Blit(comp,cable,825,67);
  using(Bitmap a=Station(false,logoS))Blit(comp,a,12,132);using(Bitmap a=Station(true,logoS))Blit(comp,a,75,132);using(Bitmap a=Station(false,logoS))Blit(comp,a,138,132);Blit(comp,consoleOn,216,139);using(Bitmap barri=Barrier(tarp,logoS))Blit(comp,barri,330,136);using(Bitmap ed=Elevator(false,logoS))Blit(comp,ed,480,138);using(Bitmap ed=Elevator(true,logoS))Blit(comp,ed,552,138);using(Bitmap depDoor=Load("batch1_v5/door_open_45x46_v5.png"))Blit(comp,depDoor,628,145);using(Bitmap counter=Crop(atlas,28,74,71,40))Blit(comp,counter,690,149);
  for(int i=0;i<4;i++){using(Bitmap s=SideSign(i))Blit(comp,s,12,220+i*22);using(Bitmap a=Arrow(i))Blit(comp,a,270,221+i*25);}using(Bitmap ex=ExitSign())Blit(comp,ex,355,223);using(Bitmap m=Marker(false))Blit(comp,m,420,224);using(Bitmap m=Marker(true))Blit(comp,m,441,224);using(Bitmap panel=SafetyPanel(logoS))Blit(comp,panel,478,218);using(Bitmap d=Boarding())Blit(comp,d,580,218);
 using(Bitmap a=Pool(60,40,0,true))BlitAdd(comp,a,12,340);using(Bitmap a=Pool(90,60,1,true))BlitAdd(comp,a,82,330);using(Bitmap a=Pool(120,80,2,true))BlitAdd(comp,a,182,320);using(Bitmap a=Pool(60,40,0,false))BlitAdd(comp,a,320,340);using(Bitmap a=Pool(90,60,1,false))BlitAdd(comp,a,390,330);using(Bitmap a=Pool(120,80,2,false))BlitAdd(comp,a,490,320);
  var cb=Bounds(lapSheet);using(Bitmap ch=lapSheet.Clone(new Rectangle(0,0,64,64),PixelFormat.Format32bppArgb))Blit(comp,ch,870,440-(cb.Bottom-1));comp.Save(Path.Combine(root,"H1_asset_kit_lappland_1x.png"),ImageFormat.Png);}
 cLift.Dispose();sLift.Dispose();oLift.Dispose(); }
}
}
'@
$gdi=[System.Drawing.Bitmap].Assembly.Location -replace 'System.Drawing.Common.dll','System.Private.Windows.GdiPlus.dll'
$core=$gdi -replace 'System.Private.Windows.GdiPlus.dll','System.Private.Windows.Core.dll'
Add-Type -TypeDefinition $code -ReferencedAssemblies @(([System.Drawing.Bitmap].Assembly.Location),([System.Drawing.Color].Assembly.Location),$gdi,$core)
$out=$PSScriptRoot
$art=Split-Path -Parent $out
[RhodesH1Kit]::Run($out,$art)
