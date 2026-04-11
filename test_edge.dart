import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse("https://obwbtsgibyvbmslzrbwu.supabase.co/functions/v1/rapid-task");
  final anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2J0c2dpYnl2Ym1zbHpyYnd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMzM4MzUsImV4cCI6MjA4ODkwOTgzNX0.3rDQcB_ZGa0SJs-qSJ2AjmyxjZj3r2e4caiGZhzSoLE";
  
  print('--- TEST SUPABASE EDGE FUNCTION ---');
  final client = HttpClient();
  
  try {
    final request = await client.postUrl(url);
    request.headers.set('Authorization', 'Bearer $anonKey');
    request.headers.set('Content-Type', 'application/json');
    
    print('Calling Edge Function...');
    final response = await request.close().timeout(Duration(seconds: 40));
    
    print('Status: ${response.statusCode}');
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (responseBody.length > 500) {
      print('Body (tronqué): ${responseBody.substring(0, 500)}...');
    } else {
      print('Body: $responseBody');
    }
  } catch (e) {
    print('ERREUR: $e');
  } finally {
    client.close();
  }
}
