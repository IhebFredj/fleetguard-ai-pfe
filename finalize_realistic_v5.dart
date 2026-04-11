import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final dir = Directory('assets/images/markers');
  
  final sourceFiles = [
    'truck_green_v4_ultra_real_1775267378431.png',
    'truck_orange_v4_ultra_real_1775267392864.png',
    'truck_purple_v4_ultra_real_1775267418863.png',
    'truck_red_v4_ultra_real_1775267404989.png',
  ];
  
  final mapping = {
    'truck_green_v4_ultra_real_1775267378431.png': 'truck_green.png',
    'truck_orange_v4_ultra_real_1775267392864.png': 'truck_orange.png',
    'truck_purple_v4_ultra_real_1775267418863.png': 'truck_purple.png',
    'truck_red_v4_ultra_real_1775267404989.png': 'truck_red.png',
  };

  for (final srcName in sourceFiles) {
    final srcPath = '${dir.path}/$srcName';
    final destName = mapping[srcName]!;
    final destPath = '${dir.path}/$destName';
    
    if (await File(srcPath).exists()) {
      final bytes = await File(srcPath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        // 1. Convert to RGBA for transparency
        final rgbaImage = image.convert(format: img.Format.uint8, numChannels: 4);

        // 2. Aggressive Background Removal (Checkerboard + Noise)
        // We clean pure white, very light gray, and slightly textured gray
        for (int y = 0; y < rgbaImage.height; y++) {
          for (int x = 0; x < rgbaImage.width; x++) {
            final pixel = rgbaImage.getPixel(x, y);
            
            // Check if pixel is part of the checkerboard (usually shades of white/gray)
            bool isBackground = (pixel.r > 200 && pixel.g > 200 && pixel.b > 200) ||
                                (pixel.r > 190 && pixel.g > 190 && pixel.b > 190 && 
                                 (pixel.r - pixel.g).abs() < 5 && 
                                 (pixel.g - pixel.b).abs() < 5);
            
            if (isBackground) {
              rgbaImage.setPixelRgba(x, y, 0, 0, 0, 0);
            }
          }
        }

        // 3. Resize to a smaller standard for Mapbox performance (64x64 is better for markers)
        final resized = img.copyResize(rgbaImage, width: 64, height: 64, interpolation: img.Interpolation.average);
        
        await File(destPath).writeAsBytes(img.encodePng(resized));
        print('✨ Finalized: $destName (Aggressive cleaning)');
      }
    }
  }
}
