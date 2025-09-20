
import 'vpn_server_http.dart';
import '../../Models/vpn_server.dart' as models;
import 'package:flutter/material.dart';

class ApiService {
  /// Fetch servers from Technosofts API using VpnServerHttp
  static Future<List<models.VpnServer>> fetchTechnosoftsServers(BuildContext context, {String type = 'free'}) async {
    final httpFetcher = VpnServerHttp(context);
    return await httpFetcher.getServers(type);
  }
}