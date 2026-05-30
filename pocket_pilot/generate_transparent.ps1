Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap(1, 1)
$bmp.SetPixel(0, 0, [System.Drawing.Color]::Transparent)
$bmp.Save("d:\PocketPilot-new-monorepo\pocket_pilot\assets\images\transparent.png", [System.Drawing.Imaging.ImageFormat]::Png)
