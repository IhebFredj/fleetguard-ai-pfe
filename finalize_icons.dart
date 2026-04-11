import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final dir = Directory('assets/images/markers');
  final files = ['truck_green.png', 'truck_orange.png', 'truck_purple.png', 'truck_red.png'];

  for (final file in files) {
    final path = '${dir.path}/$file';
    final bytes = await File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image != null) {
      // 1. Remove black background
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          // Pure black or very dark colors near black. 
          // Threshold of 30 allows for some anti-aliasing artifacts
          if (pixel.r < 30 && pixel.g < 30 && pixel.b < 30) {
             image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }
      
      // 2. Resize to 128x128 for memory optimization
      final resized = img.copyResize(image, width: 128, height: 128);
      
      await File(path).writeAsBytes(img.encodePng(resized));
      print('Processed and transparentified $file');
    }
  }
}
