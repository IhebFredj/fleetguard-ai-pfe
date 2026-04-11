import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final dir = Directory('assets/images/markers');
  for (var file in dir.listSync()) {
    if (file is File && file.path.endsWith('.png') && !file.path.contains('_fixed.png')) {
      print('Processing ${file.path}');
      final raw = file.readAsBytesSync();
      final image = img.decodePng(raw);
      if (image == null) {
        print('Failed to decode ${file.path}');
        continue;
      }
      
      // Resize to 256
      final resized = img.copyResize(image, width: 256);
      
      // Remove White/Gray checkerboard
      for (final pixel in resized) {
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        if ((r > 190 && r < 215 && g > 190 && g < 215 && b > 190 && b < 215) ||
            (r > 240 && g > 240 && b > 240)) {
           pixel.a = 0;
        }
      }
      
      final outPath = file.path.replaceAll('.png', '_fixed.png');
      File(outPath).writeAsBytesSync(img.encodePng(resized));
      print('Saved $outPath');
    }
  }
}
