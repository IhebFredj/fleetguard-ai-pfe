import 'package:fleetguard/core/models/truck.dart';

class TruckRepository {
  const TruckRepository();

  List<Truck> initialTrucks() {
    // Matricules fournis par l'utilisateur
    const raw = [
      '144 tun 147',
      '205 tun 186',
      '205 tun 221',
      '151 tun 2345',
      '180 tun 4266',
      '219 tun 4350',
      '222 tun 4356',
      '222 tun 4359',
      '189 tun 4469',
      '141 tun 462',
      '205 tun 6078',
      '205 tun 6079',
      '205 tun 6081',
      '184 tun 6361',
      '194 tun 6869',
      '238 tun 6884',
      '160 tun 6958',
      '210 tun 7421',
      '210 tun 7422',
      '112 tun 7774',
      '240 tun 8208',
      '218 tun 9045',
    ];

    String normalize(String s) => s.trim().replaceAll(RegExp(r"\s+"), ' ');

    return List<Truck>.generate(
      raw.length,
      (i) {
        final plate = normalize(raw[i]);
        final id = plate.toLowerCase().replaceAll(' ', '_');
        return Truck(id: id, plate: plate);
      },
    );
  }
}
