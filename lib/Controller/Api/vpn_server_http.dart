import 'dart:convert';
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter/material.dart';

import '../../Models/vpn_server.dart';
// import '../providers/vpn_provider.dart'; // Uncomment and adjust if needed
import '../../Views/api_constants.dart';
import 'package:http/http.dart' as http;

class VpnServerHttp {
  final BuildContext context;
  VpnServerHttp(this.context);

  Future<List<VpnServer>> getServers(String type) async {
    List<VpnServer> servers = [];
    Map<String, String> header = {'auth_token': 'wQLAYr4pe4Bl'};
    http.Response res;
    try {
      res = await http
          .get(Uri.parse("${api}servers/$type"), headers: header)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      dev.log('Server fetch timed out');
      return [];
    } catch (e) {
      dev.log('Server fetch error: ' + e.toString());
      return [];
    }

    try {
      if (res.statusCode == 200) {
        var json = jsonDecode(res.body.toString());
        json = json['data'];

        for (final js in json) {
          final server = VpnServer.fromJson(js);
          servers.add(server);
        }

        // Shuffle the servers list before returning
        servers.shuffle(Random());
      } else {
        servers = [];
      }
      dev.log("_____________________________DATA_____________________________");
      dev.log(type);
    } catch (e) {
      servers = [];
  dev.log('Parse error: ' + e.toString());
    }
    return servers;
  }

  // You can implement getBestServer if needed, similar to your provided code
}
