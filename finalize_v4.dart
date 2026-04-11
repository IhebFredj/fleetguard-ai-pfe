import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final dir = Directory('assets/images/markers_v4');
  final files = ['truck_green_v4.png', 'truck_orange_v4.png', 'truck_purple_v4.png', 'truck_red_v4.png'];

  for (final file in files) {
    final path = '${dir.path}/$file';
    final bytes = await File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image != null) {
      // 1. Resize to 128x128
      final resized = img.copyResize(image, width: 128, height: 128);
      
      // 2. High-quality background cleaning (just in case)
      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          // If it's pure white or very light gray, make it transparent
          if (pixel.r > 245 && pixel.g > 245 && pixel.b > 245) {
            resized.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }

      await File(path).writeAsBytes(img.encodePng(resized));
      print('Finalized ultra-realistic icon: $file');
    }
  }
}
