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
      final resized = img.copyResize(image, width: 128, height: 128);
      await File(path).writeAsBytes(img.encodePng(resized));
      print('Resized $file to 128x128');
    }
  }
}
