Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap("d:\PocketPilot-new-monorepo\pocket_pilot\assets\images\PocketPilotLogoApp.png")
$color = $bmp.GetPixel(0, 0)
Write-Host "#$($color.R.ToString('X2'))$($color.G.ToString('X2'))$($color.B.ToString('X2'))"
