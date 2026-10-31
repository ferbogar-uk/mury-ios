param([Parameter(Mandatory=$true)][string]$Reference)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, PresentationCore, WindowsBase
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Text;
public static class FlowTrace {
    static long Key(int x, int y) { return ((long)x << 32) | (uint)y; }
    static void Edge(Dictionary<long,List<long>> edges, int x, int y, int a, int b) {
        long key = Key(x,y);
        if (!edges.ContainsKey(key)) edges[key] = new List<long>();
        edges[key].Add(Key(a,b));
    }
    static List<Point> Simplify(List<Point> points, double tolerance) {
        if (points.Count<3) return points;
        Point a=points[0], b=points[points.Count-1];
        double length=Math.Sqrt((b.X-a.X)*(b.X-a.X)+(b.Y-a.Y)*(b.Y-a.Y));
        double largest=0; int split=0;
        for(int i=1;i<points.Count-1;i++) {
            Point p=points[i];
            double distance=length==0 ? Math.Sqrt((p.X-a.X)*(p.X-a.X)+(p.Y-a.Y)*(p.Y-a.Y)) : Math.Abs((b.Y-a.Y)*p.X-(b.X-a.X)*p.Y+b.X*a.Y-b.Y*a.X)/length;
            if(distance>largest) {largest=distance;split=i;}
        }
        if(largest<=tolerance) return new List<Point>{a,b};
        var first=Simplify(points.GetRange(0,split+1),tolerance);
        var second=Simplify(points.GetRange(split,points.Count-split),tolerance);
        first.RemoveAt(first.Count-1); first.AddRange(second); return first;
    }
    static string Number(double value) { return value.ToString("0.###",System.Globalization.CultureInfo.InvariantCulture); }
    public static string Outline(bool[,] mask) {
        int width = mask.GetLength(0), height = mask.GetLength(1);
        var edges = new Dictionary<long,List<long>>();
        for (int x=0; x<width; x++) for (int y=0; y<height; y++) {
            if (!mask[x,y]) continue;
            if (y==0 || !mask[x,y-1]) Edge(edges,x,y,x+1,y);
            if (x==width-1 || !mask[x+1,y]) Edge(edges,x+1,y,x+1,y+1);
            if (y==height-1 || !mask[x,y+1]) Edge(edges,x+1,y+1,x,y+1);
            if (x==0 || !mask[x-1,y]) Edge(edges,x,y+1,x,y);
        }
        var result = new StringBuilder();
        while (edges.Count>0) {
            long start=0; foreach (long key in edges.Keys) { start=key; break; }
            long current=start;
            var points = new List<Point>();
            do {
                points.Add(new Point((int)(current>>32),(int)current));
                if (!edges.ContainsKey(current)) throw new InvalidOperationException("Open contour");
                var next=edges[current]; long target=next[0]; next.RemoveAt(0);
                if (next.Count==0) edges.Remove(current);
                current=target;
            } while (current!=start);
            double area=0;
            for(int i=0;i<points.Count;i++) { var a=points[i]; var b=points[(i+1)%points.Count]; area+=(double)a.X*b.Y-(double)b.X*a.Y; }
            if (Math.Abs(area)<8) continue;
            int middle=points.Count/2;
            var firstHalf=Simplify(points.GetRange(0,middle+1),0.65);
            var secondHalf=points.GetRange(middle,points.Count-middle); secondHalf.Add(points[0]);
            secondHalf=Simplify(secondHalf,0.65);
            firstHalf.RemoveAt(firstHalf.Count-1); secondHalf.RemoveAt(secondHalf.Count-1);
            firstHalf.AddRange(secondHalf); points=firstHalf;
            var last=points[points.Count-1];
            result.Append("M "+Number((last.X+points[0].X)/2.0)+" "+Number((last.Y+points[0].Y)/2.0)+" ");
            for(int i=0;i<points.Count;i++) {
                var a=points[i]; var b=points[(i+1)%points.Count];
                result.Append("Q "+a.X+" "+a.Y+" "+Number((a.X+b.X)/2.0)+" "+Number((a.Y+b.Y)/2.0)+" ");
            }
            result.Append("Z ");
        }
        return result.ToString();
    }
    public static string Trace(Bitmap image, Rectangle bounds, bool lightMark) {
        var mask = new bool[bounds.Width,bounds.Height];
        for(int x=0;x<bounds.Width;x++) for(int y=0;y<bounds.Height;y++) {
            int absoluteX=x+bounds.X, absoluteY=y+bounds.Y;
            Color c=image.GetPixel(absoluteX,absoluteY);
            bool ink=lightMark ? c.R>220 && c.G>145 && c.B>175 : c.R>170 && c.R-c.G>30 && c.R-c.B>5;
            // The tagline is separate from the wordmark, including the y descender.
            if (!lightMark && absoluteY>=158 && absoluteX>=150 && absoluteX<=505) ink=false;
            mask[x,y]=ink;
        }
        return Outline(mask);
    }
    public static void SelfCheck() {
        var square = new bool[8,8];
        for(int x=0;x<8;x++) for(int y=0;y<8;y++) square[x,y]=true;
        if (Outline(square).Split('M').Length-1!=1) throw new Exception("Square contour check failed");
        for(int x=2;x<6;x++) for(int y=2;y<6;y++) square[x,y]=false;
        if (Outline(square).Split('M').Length-1!=2) throw new Exception("Hole contour check failed");
    }
}
'@
[FlowTrace]::SelfCheck()
$projectRoot = Split-Path -Parent $PSScriptRoot
$designRoot = Join-Path $projectRoot 'design/branding'
New-Item -ItemType Directory -Path $designRoot -Force | Out-Null
$bitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $Reference).Path)
try {
    if ($bitmap.Width -ne 1774 -or $bitmap.Height -ne 887) { throw 'Expected the supplied 1774x887 branding board' }
    $wordmark = [FlowTrace]::Trace($bitmap,[System.Drawing.Rectangle]::new(40,15,565,170),$false)
    $mark = [FlowTrace]::Trace($bitmap,[System.Drawing.Rectangle]::new(675,70,140,70),$true)
} finally { $bitmap.Dispose() }
if ($wordmark.Length -lt 100 -or $mark.Length -lt 100) { throw 'Missing traced artwork' }
function Save-Vector([string]$Name,[string]$Geometry,[int]$Width,[int]$Height) {
    $svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 '+$Width+' '+$Height+'"><path fill="black" fill-rule="evenodd" d="'+$Geometry+'"/></svg>'
    [IO.File]::WriteAllText((Join-Path $designRoot $Name),$svg)
}
Save-Vector 'flow-wordmark.svg' $wordmark 565 170
Save-Vector 'flow-mark.svg' $mark 140 70
function Save-Png([string]$Destination,[string]$Geometry,[int]$Width,[int]$Height,[double]$ScaleX,[double]$ScaleY,[double]$OffsetX,[double]$OffsetY,[string]$Background,[string]$Foreground) {
    $visual = [System.Windows.Media.DrawingVisual]::new()
    $context = $visual.RenderOpen()
    $brushes = [System.Windows.Media.BrushConverter]::new()
    if ($Background) { $context.DrawRectangle($brushes.ConvertFromString($Background),$null,[System.Windows.Rect]::new(0,0,$Width,$Height)) }
    $context.PushTransform([System.Windows.Media.TranslateTransform]::new($OffsetX,$OffsetY))
    $context.PushTransform([System.Windows.Media.ScaleTransform]::new($ScaleX,$ScaleY))
    $context.DrawGeometry($brushes.ConvertFromString($Foreground),$null,[System.Windows.Media.Geometry]::Parse($Geometry))
    $context.Pop()
    $context.Pop()
    $context.Close()
    $render = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($Width,$Height,96,96,[System.Windows.Media.PixelFormats]::Pbgra32)
    $render.Render($visual)
    $encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
    $frame = $render
    if ($Background) {
        $frame = [System.Windows.Media.Imaging.FormatConvertedBitmap]::new($render,[System.Windows.Media.PixelFormats]::Rgb24,$null,0)
    }
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($frame))
    $stream = [IO.File]::Create($Destination)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}
Save-Png (Join-Path $projectRoot 'larping/Assets.xcassets/LogoHorizontal.imageset/logo-horizontal.png') $wordmark 1695 510 3 3 0 0 '' '#FFFFFF'
Save-Png (Join-Path $projectRoot 'larping/Assets.xcassets/AppIcon.appiconset/icon-light.png') $mark 1024 1024 5 5 162 337 '#FF4F98' '#FFF2F8'
Save-Png (Join-Path $projectRoot 'larping/Assets.xcassets/AppIcon.appiconset/icon-dark.png') $mark 1024 1024 5 5 162 337 '#20131B' '#FF7EB9'
Save-Png (Join-Path $projectRoot 'larping/Assets.xcassets/AppIcon.appiconset/icon-tinted.png') $mark 1024 1024 5 5 162 337 '#171717' '#FFFFFF'
Save-Png (Join-Path $designRoot 'tiffany-icon.png') $mark 1024 1024 5 5 162 337 '#00C2CC' '#0B3D4A'
Write-Output 'Flow vector and PNG assets prepared; square/hole contour self-checks passed.'
