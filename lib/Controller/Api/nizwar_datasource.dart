import 'dart:convert';
import 'package:http/http.dart' as http;
import 'server_datasource.dart';
import 'package:vpn_app/Models/vpn_server.dart';

/// Data source for Nizwar VPN public servers
class NizwarDataSource extends ServerDataSource {
  static const String nizwarUrl = 'https://www.nizwar.com/freevpn/vpnservers.csv';

  @override
  Future<List<VpnServer>> fetchServers() async {
    try {
      final response = await http.get(Uri.parse(nizwarUrl));
      if (response.statusCode == 200) {
        return _parseCsv(response.body);
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  List<VpnServer> _parseCsv(String csv) {
    final lines = LineSplitter.split(csv).toList();
    if (lines.isEmpty) return [];
    final header = lines.first.split(',');
    final servers = <VpnServer>[];
    for (var i = 1; i < lines.length; i++) {
      final row = lines[i].split(',');
      if (row.length < header.length) continue;
      // Nizwar CSV columns (example): HostName,IP,CountryLong,CountryShort,Score,Ping,Speed,NumVpnSessions,Uptime,TotalUsers,TotalTraffic,OpenVPN_ConfigData_Base64
      final server = VpnServer(
        id: i, // Use row index as id
        ipAddress: row.length > 1 ? row[1] : '',
        country: row.length > 2 ? row[2] : '',
        countryCode: row.length > 3 ? row[3] : '',
        ovpn: row.length > 11 ? row[11] : '',
        ispro: '0',
        state: '',
      );
      // Optionally set username/password if needed
      // server.username = '';
      // server.password = '';
      servers.add(server);
    }
    return servers;
  }
}
