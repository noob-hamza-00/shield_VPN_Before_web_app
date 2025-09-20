import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../Models/vpn_server.dart' as models;
import 'server_datasource.dart';

class TechnosoftsDataSource extends ServerDataSource {
  static const String apiUrl = 'https://technosofts.org/api/vpnservers'; // Updated to actual endpoint

  Future<List<models.VpnServer>> fetchServers() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
  return data.map((json) => models.VpnServer.fromJson(json)).toList();
      }
    } catch (e) {
      // Handle error or log
    }
    return [];
  }
}
