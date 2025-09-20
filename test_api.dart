import 'dart:convert';
import 'dart:io';

// Quick test script to debug Technosofts API authentication
Future<void> main() async {
  final client = HttpClient();
  
  print('=== Testing Technosofts API Authentication ===');
  
  // Test 1: Basic auth with provided credentials
  print('\n1. Testing Basic auth with freeopenvpn:605196725');
  await testEndpoint(client, 'https://vpn.technosofts.net/api/servers', {
    'Authorization': 'Basic ${base64Encode(utf8.encode('freeopenvpn:605196725'))}',
    'Accept': 'application/json',
    'User-Agent': 'ShieldVPN/1.0',
  });
  
  // Test 2: No auth
  print('\n2. Testing without auth');
  await testEndpoint(client, 'https://vpn.technosofts.net/api/servers', {
    'Accept': 'application/json',
    'User-Agent': 'ShieldVPN/1.0',
  });
  
  // Test 3: Different endpoints
  print('\n3. Testing different endpoints');
  for (final path in ['/servers', '/api', '/api/v1', '/api/vpn/servers']) {
    await testEndpoint(client, 'https://vpn.technosofts.net$path', {
      'Accept': 'application/json',
    });
  }
  
  client.close();
}

Future<void> testEndpoint(HttpClient client, String url, Map<String, String> headers) async {
  try {
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri).timeout(Duration(seconds: 10));
    
    headers.forEach((k, v) => request.headers.set(k, v));
    
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    print('URL: $url');
    print('Status: ${response.statusCode}');
    print('Response: ${body.length > 200 ? body.substring(0, 200) + '...' : body}');
    
  } catch (e) {
    print('URL: $url');
    print('Error: $e');
  }
}
