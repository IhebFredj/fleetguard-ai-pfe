import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/markers/truck_green.png');
  if(!file.existsSync()) { print('not found'); return; }
  final raw = file.readAsBytesSync();
  final image = img.decodePng(raw);
  if (image == null) return;
  final resized = img.copyResize(image, width: 256);
  for (final pixel in resized) {
    if ((pixel.r > 195 && pixel.r < 210 && pixel.g > 195 && pixel.g < 210 && pixel.b > 195 && pixel.b < 210) ||
        (pixel.r > 250 && pixel.g > 250 && pixel.b > 250)) {
       pixel.a = 0;
    }
  }
  File('assets/images/markers/truck_green_fixed.png').writeAsBytesSync(img.encodePng(resized));
  print('done');
}
