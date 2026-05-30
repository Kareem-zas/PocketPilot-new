import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Load the splash logo
  final logoFile = File('assets/images/splashScreenLogo.png');
  
  if (!logoFile.existsSync()) {
    stdout.writeln('ERROR: splashScreenLogo.png not found!');
    return;
  }

  // Load logo
  final logoBytes = logoFile.readAsBytesSync();
  final logo = img.decodePng(logoBytes)!;

  // Create a large background canvas (1080x1920 portrait, standard Android)
  const int canvasW = 1080;
  const int canvasH = 1920;
  
  // Background color #00367F -> R=0, G=54, B=127
  final canvas = img.Image(width: canvasW, height: canvasH);
  img.fill(canvas, color: img.ColorRgba8(0, 54, 127, 255));

  // Scale logo to 400x400 (prominent but not too large)
  const int logoSize = 400;
  final resizedLogo = img.copyResize(logo, width: logoSize, height: logoSize, interpolation: img.Interpolation.cubic);

  // Center the logo on the canvas
  final int offsetX = (canvasW - logoSize) ~/ 2;
  final int offsetY = (canvasH - logoSize) ~/ 2;

  // Composite logo onto background (respects alpha)
  img.compositeImage(canvas, resizedLogo, dstX: offsetX, dstY: offsetY);

  // Save
  final pngBytes = img.encodePng(canvas);
  File('assets/images/splash_composite.png').writeAsBytesSync(pngBytes);
  stdout.writeln('Generated splash_composite.png ($canvasW x $canvasH)');
}
