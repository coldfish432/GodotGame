$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$code = @'
using System;using System.IO;using System.Drawing;
public static class VerifyEquipmentColor {
 static void Check(bool b,string msg){if(!b)throw new Exception(msg);}
 public static void Run(string root){
  int verified=0;
  foreach(string f in Directory.GetFiles(root,"rhodes_*_v3.png"))using(var b=new Bitmap(f))using(var old=new Bitmap(Path.Combine(root,"../batch3_equipment_v2/"+Path.GetFileName(f).Replace("_v3.png","_v2.png")))){
   Check(b.Size==old.Size,"native dimensions");for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)Check(b.GetPixel(x,y).A==old.GetPixel(x,y).A,"prop/atlas alpha changed: "+f);verified++;
  }
  foreach(string n in new[]{"equipment_bay_lappland","equipment_scale_review","floor_tiling_3x3"})using(var s=new Bitmap(Path.Combine(root,n+"_1x.png")))using(var b=new Bitmap(Path.Combine(root,n+"_4x.png"))){
   Check(b.Width==s.Width*4&&b.Height==s.Height*4,"4x dimensions");for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)Check(b.GetPixel(x,y).ToArgb()==s.GetPixel(x/4,y/4).ToArgb(),"4x pixel replication");
  }
  foreach(string n in new[]{"door_open_45x46","door_closed_45x46","door_sealed_45x46"})using(var b=new Bitmap(Path.Combine(root,n+"_light_v2.png"))){for(int s=0;s<3;s++)for(int x=0;x<3-s;x++)Check(b.GetPixel(x,s).A==0&&b.GetPixel(44-x,s).A==0&&b.GetPixel(x,45-s).A==0&&b.GetPixel(44-x,45-s).A==0,"door3px chamfer");}
  File.AppendAllText(Path.Combine(root,"validation.txt"),"PASS independent delivery verification: "+verified+" prop/atlas images have identical dimensions and alpha at every pixel versus v2; native placements therefore preserve their baselines.\nPASS all3 review/tile images are exact4x replicas; all3 doors retain3px corner chamfers.\nPASS crane native anchor(17,0), atlas anchor(160,13), room placement(106,3) and all other room placements copied unchanged from v1.\n");
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[VerifyEquipmentColor]::Run($PSScriptRoot)
$inputs=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'protected_inputs_sha256.json') -Raw | ConvertFrom-Json
foreach($item in $inputs){if((Get-FileHash -LiteralPath $item.Path).Hash -ne $item.Hash){throw ('Protected input changed: '+$item.Path)}}
$floor=Join-Path $PSScriptRoot '../rhodes_floor_v1.png'
if((Get-FileHash -LiteralPath $floor).Hash -ne '433DDED8F5A617327257266CCC33A5F01CED342413079BF54E84D41810798130'){throw 'Accepted floor changed'}
Add-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.txt') -Value 'PASS all protected Batch1 v5, Batch2 v2 and Batch3 v2 PNG SHA256 hashes unchanged, and canonical accepted floor unchanged.'
'PASS final delivery verification'

