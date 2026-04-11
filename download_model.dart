import 'dart:io';

void main() async {
  final url = 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb';
  final file = File('assets/models/truck.glb');
  
  await Directory('assets/models').create(recursive: true);
  
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();
  
  await response.pipe(file.openWrite());
  print('Download complete!');
}
