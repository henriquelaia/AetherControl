Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

$cx = $size / 2.0
$cy = $size / 2.0
$r = ($size / 2.0) - ($size * 0.05)

# Outer dark obsidian circle
$bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 12, 14, 20))
$g.FillEllipse($bgBrush, [float]($cx - $r), [float]($cy - $r), [float]($r * 2), [float]($r * 2))

# Cyan neon outer rim
$rimPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 6, 182, 212)), ($size * 0.04)
$g.DrawEllipse($rimPen, [float]($cx - $r), [float]($cy - $r), [float]($r * 2), [float]($r * 2))

# Violet inner accent arc
$arcPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220, 139, 92, 246)), ($size * 0.02)
$rInner = $r * 0.82
$g.DrawEllipse($arcPen, [float]($cx - $rInner), [float]($cy - $rInner), [float]($rInner * 2), [float]($rInner * 2))

# 3 Aerodynamic curved fan blades
$bladeBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.PointF 0, 0),
    (New-Object System.Drawing.PointF $size, $size),
    ([System.Drawing.Color]::FromArgb(255, 6, 182, 212)),
    ([System.Drawing.Color]::FromArgb(255, 139, 92, 246))
)

for ($i = 0; $i -lt 3; $i++) {
    $angle = $i * 120.0
    $state = $g.Save()
    $g.TranslateTransform($cx, $cy)
    $g.RotateTransform($angle)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bLen = $size * 0.38
    $bWidth = $size * 0.16
    $path.AddBezier(
        [float]0, [float]0,
        [float]($bWidth * 0.8), [float](-$bLen * 0.35),
        [float]($bWidth * 1.2), [float](-$bLen * 0.8),
        [float]0, [float](-$bLen)
    )
    $path.AddBezier(
        [float]0, [float](-$bLen),
        [float](-$bWidth * 0.5), [float](-$bLen * 0.6),
        [float](-$bWidth * 0.2), [float](-$bLen * 0.2),
        [float]0, [float]0
    )
    $path.CloseFigure()
    $g.FillPath($bladeBrush, $path)
    $g.Restore($state)
}

# Center metallic rotor hub
$hubR = $size * 0.14
$hubBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 24, 28, 38))
$g.FillEllipse($hubBrush, [float]($cx - $hubR), [float]($cy - $hubR), [float]($hubR * 2), [float]($hubR * 2))

$hubRing = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 56, 189, 248)), ($size * 0.03)
$g.DrawEllipse($hubRing, [float]($cx - $hubR), [float]($cy - $hubR), [float]($hubR * 2), [float]($hubR * 2))

# Core thermal LED center dot
$dotR = $size * 0.05
$dotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 244, 63, 94))
$g.FillEllipse($dotBrush, [float]($cx - $dotR), [float]($cy - $dotR), [float]($dotR * 2), [float]($dotR * 2))

$g.Dispose()

$assetsDir = "C:\Users\Admin\Desktop\controller-fan\assets"
if (-not (Test-Path $assetsDir)) { New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null }
$outPng = Join-Path $assetsDir "aether-256.png"
$bmp.Save($outPng, [System.Drawing.Imaging.ImageFormat]::Png)

# Convert to multi-size Windows .ICO
# Simple valid ICO header writing with embedded PNG
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $ms.ToArray()
$ms.Dispose()

$icoPath = Join-Path $assetsDir "aethercontrol.ico"
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fs)

# ICONDIR header (6 bytes)
$bw.Write([uint16]0) # Reserved
$bw.Write([uint16]1) # Type 1 = ICO
$bw.Write([uint16]1) # 1 image

# ICONDIRENTRY (16 bytes)
$bw.Write([byte]0)   # Width 0 = 256
$bw.Write([byte]0)   # Height 0 = 256
$bw.Write([byte]0)   # Color count
$bw.Write([byte]0)   # Reserved
$bw.Write([uint16]1) # Color planes
$bw.Write([uint16]32)# Bits per pixel
$bw.Write([uint32]$pngBytes.Length) # Image size in bytes
$bw.Write([uint32]22)# Image offset (6 + 16 = 22)

# Write PNG bytes
$bw.Write($pngBytes)
$bw.Flush()
$fs.Close()
$bmp.Dispose()

# Also copy to wwwroot favicon.ico
Copy-Item $icoPath "C:\Users\Admin\Desktop\controller-fan\src\AetherControl.Daemon\wwwroot\favicon.ico" -Force
Write-Host "SUCCESS: Created $icoPath and updated favicon.ico"
