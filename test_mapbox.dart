import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  var layer = ModelLayer(id: "test", sourceId: "test-source");
  print(layer.id);
}
