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
      final cleaned = img.Image.from(image);
      
      for (int y = 0; y < cleaned.height; y++) {
        for (int x = 0; x < cleaned.width; x++) {
          final pixel = cleaned.getPixel(x, y);
          
          // AI noise detection: pixels that are very light or gray-ish
          bool isBackground = false;
          
          // 1. Light colors (shades of white/gray)
          if (pixel.r > 200 && pixel.g > 200 && pixel.b > 200) {
            isBackground = true;
          }
          
          // 2. Grays where R, G, B are almost equal and relatively bright
          final diffMax = [ (pixel.r - pixel.g).abs(), (pixel.r - pixel.b).abs(), (pixel.g - pixel.b).abs() ].reduce((a, b) => a > b ? a : b);
          if (diffMax < 25 && pixel.r > 180) {
            isBackground = true;
          }

          if (isBackground) {
            cleaned.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }
      
      await File(path).writeAsBytes(img.encodePng(cleaned));
      print('Cleaned $file aggressively');
    }
  }
}
