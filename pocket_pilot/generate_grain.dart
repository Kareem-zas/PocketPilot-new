import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  // Base color: #0A3E84 -> R=10, G=62, B=132
  const int baseR = 10;
  const int baseG = 62;
  const int baseB = 132;
  
  // Create a 512x512 image
  final image = img.Image(width: 512, height: 512);
  final random = Random();

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // Generate noise between -12 and +12
      int noise = random.nextInt(25) - 12;
      
      int r = (baseR + noise).clamp(0, 255);
      int g = (baseG + noise).clamp(0, 255);
      int b = (baseB + noise).clamp(0, 255);
      
      // Set pixel (format depends on image package version, usually setPixelRgba)
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Encode as PNG
  final pngBytes = img.encodePng(image);
  
  // Save to file
  final file = File('assets/images/splash_background.png');
  file.writeAsBytesSync(pngBytes);
  
  stdout.writeln('Generated splash_background.png successfully!');
}
