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
      // Create a transparent version
      final transparentImage = img.Image.from(image);
      
      for (int y = 0; y < transparentImage.height; y++) {
        for (int x = 0; x < transparentImage.width; x++) {
          final pixel = transparentImage.getPixel(x, y);
          
          // If the pixel is white or very close to white, make it transparent
          // In 'image' package, getPixel returns a color object.
          // We check R, G, B > 240
          if (pixel.r > 245 && pixel.g > 245 && pixel.b > 245) {
            transparentImage.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }
      
      await File(path).writeAsBytes(img.encodePng(transparentImage));
      print('Fixed background for $file');
    }
  }
}
