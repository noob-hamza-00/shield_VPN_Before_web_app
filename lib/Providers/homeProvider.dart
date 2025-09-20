import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vpn_app/Controller/services/vpn_engine.dart';
import 'package:vpn_app/Models/vpn_Configuration.dart';
import 'package:vpn_app/Models/vpn_server.dart';

import 'package:vpn_app/config/api_config.dart';



class HomeProvider with ChangeNotifier {
  String vpnState = VpnEngine.vpnDisconnected;
  VpnServer? server; // selected server from API
  List<VpnServer> servers = const []; // cached list from API (optional)

  void changeVpnState(String state) {
    vpnState = state.toLowerCase();
    notifyListeners();
  }

  void setServer(VpnServer s) {
    server = s;
    notifyListeners();
  }

  void setServers(List<VpnServer> list) {
    servers = list;
    notifyListeners();
  }

  bool get hasServer => server != null;

  Future<void> connectToVpn(BuildContext context) async {
    // Require a selected server with config
    if (server == null) {
      debugPrint('connectToVpn: No server selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a server first')),
      );
      return;
    }
    if (server!.ovpn.isEmpty) {
      debugPrint('connectToVpn: Selected server has empty OpenVPN config');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server configuration not available. Try another server.')),
      );
      return; // nothing to connect
    }

    // Always try to connect: if already connected, disconnect and reconnect to new server
    if (vpnState == VpnEngine.vpnConnected || vpnState == VpnEngine.vpnConnecting) {
      await VpnEngine.stopVpn();
      // Wait for VPN to be fully disconnected (timeout after 10s)
      int waited = 0;
      while (vpnState != VpnEngine.vpnDisconnected && waited < 10000) {
        await Future.delayed(const Duration(milliseconds: 200));
        waited += 200;
      }
      changeVpnState(VpnEngine.vpnDisconnected);
    }
    try {
      // Normalize Base64 (remove whitespace/newlines) and decode
      final configText = server!.ovpn;
      debugPrint('Starting VPN with server ${server!.ipAddress} (${server!.countryCode}) configLength=${configText.length}');
      // Persist last connected server metadata for restore-on-reopen UX
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_server_id', server!.id);
        await prefs.setString('last_server_country', server!.country);
        await prefs.setString('last_server_code', server!.countryCode);
        await prefs.setString('last_server_ip', server!.ipAddress);
      } catch (e) {
        debugPrint('Persist last server failed: $e');
      }
      // First try with API creds (for Technosofts). If it fails synchronously, retry with legacy creds.
      Future<void> _startWith(String user, String pass) async {
        final cfg = VpnConfig(
          country: server!.country,
          username: user.isNotEmpty ? user : (server!.username ?? ''),
          password: pass.isNotEmpty ? pass : (server!.password ?? ''),
          config: configText,
        );
        await VpnEngine.startVpn(cfg);
      }
      try {
        await _startWith(ApiConfig.username, ApiConfig.password);
      } catch (e) {
        debugPrint('Start with API creds failed, retrying with legacy creds: $e');
        await _startWith('vpn', 'vpn');
      }
      // state will be updated by stage listener, but set provisional state
      changeVpnState(VpnEngine.vpnConnecting);
    } catch (e) {
      debugPrint('Failed to start VPN: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Start failed: $e')),
      );
    }
  }
}


// String get getButtonText{
//   switch (HomeProvider().vpnState) {
//     case VpnEngine.vpnConnecting:
//       return 'Connecting...';
//     case VpnEngine.vpnConnected:
//       return 'Disconnect';
//     case VpnEngine.vpnDisconnected:
//       return 'Connect';
//     default:
//       return 'Unknown State';
//   }
// }


