import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final dir = Directory('assets/images/markers');
  
  // Mapping paths to original names correctly
  final mapping = {
    'truck_green_v4_ultra_real_1775267378431.png': 'truck_green.png',
    'truck_orange_v4_ultra_real_1775267392864.png': 'truck_orange.png',
    'truck_purple_v4_ultra_real_1775267418863.png': 'truck_purple.png',
    'truck_red_v4_ultra_real_1775267404989.png': 'truck_red.png',
  };

  for (final entry in mapping.entries) {
    final srcPath = '${dir.path}/${entry.key}';
    final destPath = '${dir.path}/${entry.value}';
    
    if (await File(srcPath).exists()) {
      final bytes = await File(srcPath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        // High quality resize to 128px
        final resized = img.copyResize(image, width: 128, height: 128);
        
        // Ensure absolutely transparent background for Windows/Mapbox
        for (int y = 0; y < resized.height; y++) {
          for (int x = 0; x < resized.width; x++) {
            final pixel = resized.getPixel(x, y);
            if (pixel.r > 245 && pixel.g > 245 && pixel.b > 245) {
              resized.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
            }
          }
        }
        
        await File(destPath).writeAsBytes(img.encodePng(resized));
        print('✅ Overwritten: ${entry.value}');
      }
    } else {
      print('✘ Not found: ${entry.key}');
    }
  }
}
