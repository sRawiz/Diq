# Export the same primitive geometry used by ui/blocks/BrandMark.lua.
Add-Type -AssemblyName System.Drawing
$brandRoot = Split-Path -Parent $PSScriptRoot
function New-RoundedPath([single]$x, [single]$y, [single]$width, [single]$height, [single]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = 2 * $radius
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc(($x + $width - $diameter), $y, $diameter, $diameter, 270, 90)
    $path.AddArc(($x + $width - $diameter), ($y + $height - $diameter), $diameter, $diameter, 0, 90)
    $path.AddArc($x, ($y + $height - $diameter), $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return ,$path
}
function Draw-Mark($graphics) {
    $ink = [System.Drawing.ColorTranslator]::FromHtml('#f0ebe0')
    $pen = [System.Drawing.Pen]::new($ink, 2.5)
    $brush = [System.Drawing.SolidBrush]::new($ink)
    $accent = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#c1ad8b'))
    $loop = New-RoundedPath 6 4 20 24 10
    $spine = New-RoundedPath 4.75 2.75 2.5 26.5 1.25
    $tail = New-RoundedPath -5 -1.25 10 2.5 1.25
    $clipState = $graphics.Save()
    $graphics.SetClip([System.Drawing.RectangleF]::new(16, 2, 12, 28))
    $graphics.DrawPath($pen, $loop)
    $graphics.Restore($clipState)
    $graphics.FillPath($brush, $spine)
    $graphics.FillRectangle($brush, [single]6, [single]2.75, [single]10, [single]2.5)
    $graphics.FillRectangle($brush, [single]6, [single]26.75, [single]10, [single]2.5)
    $state = $graphics.Save()
    $graphics.TranslateTransform(24, 26)
    $graphics.RotateTransform(45)
    $graphics.FillPath($accent, $tail)
    $graphics.Restore($state)
    foreach ($item in @($pen, $brush, $accent, $loop, $spine, $tail)) { $item.Dispose() }
}
foreach ($badge in @($false, $true)) {
    $bitmap = [System.Drawing.Bitmap]::new(1024, 1024)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)
    if ($badge) {
        $graphics.ScaleTransform(16, 16)
        $background = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#181818'))
        $outline = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#3e3e3e'), 1)
        $path = New-RoundedPath 4 4 56 56 18
        $graphics.FillPath($background, $path)
        $graphics.DrawPath($outline, $path)
        $graphics.TranslateTransform(16, 16)
        Draw-Mark $graphics
        $background.Dispose(); $outline.Dispose(); $path.Dispose()
    } else {
        $graphics.ScaleTransform(32, 32)
        Draw-Mark $graphics
    }
    $graphics.Dispose()
    $output = [System.Drawing.Bitmap]::new(256, 256)
    $downsample = [System.Drawing.Graphics]::FromImage($output)
    $downsample.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $downsample.DrawImage($bitmap, 0, 0, 256, 256)
    $name = if ($badge) { 'diq-badge-preview.png' } else { 'diq-mark.png' }
    $output.Save((Join-Path $brandRoot "assets/$name"), [System.Drawing.Imaging.ImageFormat]::Png)
    $downsample.Dispose(); $output.Dispose(); $bitmap.Dispose()
}
