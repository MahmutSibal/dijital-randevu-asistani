param([string]$OutDir)
# Draws the app mark (white calendar with a check on a blue→indigo gradient) as PNGs:
#   icon.png             1024px full icon (rounded square), for the legacy launcher icon
#   icon_foreground.png  1024px transparent, mark only inside the adaptive-icon safe zone
#   splash.png           512px transparent mark for the splash screen
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null

function New-Canvas($size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear([System.Drawing.Color]::Transparent)
    return $bmp, $g
}
function RoundRect($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, 2*$r, 2*$r, 180, 90); $p.AddArc($x+$w-2*$r, $y, 2*$r, 2*$r, 270, 90)
    $p.AddArc($x+$w-2*$r, $y+$h-2*$r, 2*$r, 2*$r, 0, 90); $p.AddArc($x, $y+$h-2*$r, 2*$r, 2*$r, 90, 90)
    $p.CloseFigure(); return $p
}
function Gradient($size) {
    New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point $size, $size), ([System.Drawing.Color]::FromArgb(255, 59, 130, 246)), ([System.Drawing.Color]::FromArgb(255, 99, 102, 241))
}
# Calendar with a check mark, centred at (cx, cy), width w.
function Draw-Mark($g, $cx, $cy, $w) {
    $white = [System.Drawing.Color]::White
    $stroke = $w * 0.085
    $pen = New-Object System.Drawing.Pen $white, $stroke
    $pen.LineJoin = 'Round'; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $h = $w * 0.9; $x = $cx - $w/2; $y = $cy - $h/2 + $w*0.06
    $body = RoundRect $x $y $w $h ($w*0.16)
    $g.DrawPath($pen, $body)
    # Header band, clipped to the calendar's rounded outline (plus the stroke).
    $brush = New-Object System.Drawing.SolidBrush $white
    $outer = RoundRect ($x - $stroke/2) ($y - $stroke/2) ($w + $stroke) ($h + $stroke) ($w*0.16 + $stroke/2)
    $g.SetClip($outer)
    $g.FillRectangle($brush, ($x - $stroke), ($y - $stroke), ($w + 2*$stroke), ($h*0.26 + $stroke))
    $g.ResetClip()
    foreach ($rx in @(($x + $w*0.27), ($x + $w*0.73))) {                # binder rings
        $g.DrawLine($pen, $rx, $y - $w*0.1, $rx, $y + $w*0.06)
    }
    $check = New-Object System.Drawing.Pen $white, ($stroke * 1.15)
    $check.StartCap = 'Round'; $check.EndCap = 'Round'; $check.LineJoin = 'Round'
    $pts = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF ($x + $w*0.28), ($y + $h*0.62)),
        (New-Object System.Drawing.PointF ($x + $w*0.44), ($y + $h*0.77)),
        (New-Object System.Drawing.PointF ($x + $w*0.74), ($y + $h*0.46)))
    $g.DrawLines($check, $pts)
}

# Full icon
$bmp, $g = New-Canvas 1024
$g.FillPath((Gradient 1024), (RoundRect 0 0 1024 1024 230))
Draw-Mark $g 512 512 500
$bmp.Save((Join-Path $OutDir 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# Adaptive foreground: the OS masks the outer third, keep the mark within the centre 66%.
$bmp, $g = New-Canvas 1024
Draw-Mark $g 512 512 360
$bmp.Save((Join-Path $OutDir 'icon_foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# Adaptive background: the gradient, full bleed (the launcher applies its own mask).
$bmp, $g = New-Canvas 1024
$g.FillRectangle((Gradient 1024), 0, 0, 1024, 1024)
$bmp.Save((Join-Path $OutDir 'icon_background.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# Splash: gradient rounded badge with the mark.
$bmp, $g = New-Canvas 512
$g.FillPath((Gradient 512), (RoundRect 96 96 320 320 90))
Draw-Mark $g 256 256 170
$bmp.Save((Join-Path $OutDir 'splash.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
"ok"
