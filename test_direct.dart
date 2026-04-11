import 'dart:convert';
import 'dart:io';

void main() async {
  String _normalizePlate(String plate) {
    String p = plate.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    print('Cleaned: $p');
    final match = RegExp(r'^(\d+)TU(\d+)$').firstMatch(p);
    if (match != null) {
      final p1 = int.parse(match.group(1)!);
      final p2 = int.parse(match.group(2)!);
      final nums = [p1, p2]..sort();
      return '${nums[0]}TU${nums[1]}';
    }
    return p;
  }

  print(_normalizePlate('462 TU 141'));
  print(_normalizePlate('141 TU 462'));
  print(_normalizePlate(' 141   TU   462 '));
  print(_normalizePlate('462TU141'));

  final url = Uri.parse(
      "http://www.alpha-technology.com.tn/WS_ATSPRO/LoadTempsReelVehiculesService/29010/atspro_hamzacommerce/0/2275/1/Tunisie");

  print('=== TEST 1: GET ===');
  await _test(url, 'GET');

  print('\n=== TEST 2: POST ===');
  await _test(url, 'POST');
}

Future<void> _test(Uri url, String method) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final request = method == 'POST'
        ? await client.postUrl(url)
        : await client.getUrl(url);
    request.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    request.headers.set('Accept', 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();

    print('Status: ${response.statusCode}');
    print('Length: ${body.length} chars');
    if (body.length > 300) {
      print('Body: ${body.substring(0, 300)}...');
    } else {
      print('Body: $body');
    }
  } catch (e) {
    print('ERREUR: $e');
  } finally {
    client.close();
  }
}
