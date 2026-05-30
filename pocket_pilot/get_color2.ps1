Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap("d:\PocketPilot-new-monorepo\pocket_pilot\assets\images\splashScreenLogo.png")
$color = $bmp.GetPixel(0, 0)
Write-Host "R=$($color.R) G=$($color.G) B=$($color.B)"
Write-Host "#$($color.R.ToString('X2'))$($color.G.ToString('X2'))$($color.B.ToString('X2'))"
