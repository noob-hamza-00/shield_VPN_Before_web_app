import 'dart:convert';
import 'dart:io';

// Test login to Technosofts API
Future<void> main() async {
  final client = HttpClient();
  
  print('=== Testing Technosofts Login ===');
  
  try {
    // Test login with credentials
    final uri = Uri.parse('https://vpn.technosofts.net/login');
    final request = await client.postUrl(uri);
    
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.headers.set('User-Agent', 'ShieldVPN/1.0');
    
    final body = jsonEncode({
      'email': 'freeopenvpn',
      'password': '605196725',
    });
    
    request.add(utf8.encode(body));
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('Login Status: ${response.statusCode}');
    print('Login Response: $responseBody');
    
    // Also try with 'username' field instead of 'email'
    print('\n=== Testing with username field ===');
    final request2 = await client.postUrl(uri);
    request2.headers.set('Content-Type', 'application/json');
    request2.headers.set('Accept', 'application/json');
    
    final body2 = jsonEncode({
      'username': 'freeopenvpn',
      'password': '605196725',
    });
    
    request2.add(utf8.encode(body2));
    final response2 = await request2.close();
    final responseBody2 = await response2.transform(utf8.decoder).join();
    
    print('Login Status (username): ${response2.statusCode}');
    print('Login Response (username): $responseBody2');
    
  } catch (e) {
    print('Login Error: $e');
  }
  
  client.close();
}
