import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final dir = Directory('assets/images/markers');
  final files = ['truck_green_v3.png', 'truck_orange_v3.png', 'truck_purple_v3.png', 'truck_red_v3.png'];

  for (final file in files) {
    final path = '${dir.path}/$file';
    final bytes = await File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image != null) {
      // 1. Resize to a slightly smaller size for better density
      final resized = img.copyResize(image, width: 96, height: 96);
      
      // 2. Aggressive alpha check: make sure light-gray or whites are really transparent
      // (Wait, only if they are on the edges? AI background removal sometimes isn't perfect)
      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          // If R, G, B are all > 230, it's likely a leftover background
          if (pixel.r > 230 && pixel.g > 230 && pixel.b > 230) {
            resized.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }

      await File(path).writeAsBytes(img.encodePng(resized));
      print('Resized and cleaned $file');
    }
  }
}
