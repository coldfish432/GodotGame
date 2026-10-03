Add-Type -AssemblyName System.Drawing
$s = @'
using System;using System.Drawing;using System.IO;
public static class InspectRhodes {
public static void Run(string dir){foreach(string f in Directory.GetFiles(dir,"*.png")){using(var b=new Bitmap(f)){int n=f.Contains("doors_redraw")?3:f.Contains("corners_redraw")?2:1;for(int i=0;i<n;i++){int l=b.Width*(i+1)/n,t=b.Height,r=-1,d=-1;for(int y=0;y<b.Height;y++)for(int x=b.Width*i/n;x<b.Width*(i+1)/n;x++)if(b.GetPixel(x,y).A>=128){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);d=Math.Max(d,y);}Console.WriteLine(Path.GetFileName(f)+" cell="+i+" canvas="+b.Width+"x"+b.Height+" bbox="+l+","+t+","+(r-l+1)+","+(d-t+1));}}}}
}
'@
Add-Type -TypeDefinition $s -ReferencedAssemblies System.Drawing
[InspectRhodes]::Run((Join-Path $PSScriptRoot 'sources'))
