import 'package:flutter/material.dart';
import '../../Controller/Api/apis.dart';
import '../../Models/vpn_server.dart';


class ServersProvider with ChangeNotifier {
  int selectedIndex = 0;
  VpnServer? _selectedServer;
  String selectedTab = "free";
  List<VpnServer> _freeServers = [];
  List<VpnServer> _proServers = [];
  bool _isInitialized = false;
  bool _hasPreferenceServer = false;



  // Getters
  VpnServer? get selectedServer => _selectedServer;
  List<VpnServer> get freeServers => _freeServers;
  List<VpnServer> get proServers => _proServers;
  bool get isInitialized => _isInitialized;
  bool get hasPreferenceServer => _hasPreferenceServer;

  int getSelectedIndex() => selectedIndex;
  String getSelectedTab() => selectedTab;

  // Initialize provider and load saved data
  Future<void> initialize() async {
    if (_isInitialized) return;
  // No persistent storage: nothing to load
    _isInitialized = true;
    notifyListeners();
  }

  // Fetch and set free servers from API
  Future<void> fetchAndSetFreeServers(BuildContext context) async {
    try {
      final servers = await ApiService.fetchTechnosoftsServers(context, type: "free");
      setFreeServers(servers);
    } catch (e) {
      debugPrint('Error fetching free servers: $e');
      setFreeServers([]);
    }
  }

  // Fetch and set pro servers from API
  Future<void> fetchAndSetProServers(BuildContext context) async {
    try {
      final servers = await ApiService.fetchTechnosoftsServers(context, type: "pro");
      setProServers(servers);
    } catch (e) {
      debugPrint('Error fetching pro servers: $e');
      setProServers([]);
    }
  }


  // No persistent preferences logic included. If you want to persist server selection, implement it here.
  // Example usage with VpnConnectionProvider:
  // final server = getSelectedServerForConnection();
  // vpnConnectionProvider.initPlatformState(server.ovpn, server.country, disallowList, server.username ?? '', server.password ?? '');

  // Set selected server and save to storage
  void setSelectedServer(VpnServer server) {
    _selectedServer = server;
    _hasPreferenceServer = true;
  // No persistent storage: nothing to save
    notifyListeners();
  }

  // Set selected index and save to storage
  void setSelectedIndex(int index) {
    selectedIndex = index;
    if (selectedTab == "free" && index >= 0 && index < _freeServers.length) {
      _selectedServer = _freeServers[index];
      _hasPreferenceServer = true;
  // No persistent storage: nothing to save
    } else if (selectedTab == "pro" && index >= 0 && index < _proServers.length) {
      _selectedServer = _proServers[index];
      _hasPreferenceServer = true;
  // No persistent storage: nothing to save
    }
    notifyListeners();
  }

  // Set selected tab and save to storage
  void setSelectedTab(String tab) {
    selectedTab = tab;
    if (_selectedServer != null) {
  // No persistent storage: nothing to save
    }
    notifyListeners();
  }

  void setFreeServers(List<VpnServer> servers) {
    _freeServers = servers;

    if (servers.isEmpty) {
      notifyListeners();
      return;
    }

    // Always try to find saved server in new list
    if (_hasPreferenceServer && _selectedServer != null) {
      bool found = false;
      for (int i = 0; i < servers.length; i++) {
        if (servers[i].id == _selectedServer!.id) {
          selectedIndex = i;
          _selectedServer = servers[i];
          found = true;
          break;
        }
      }

      if (!found) {
        _selectedServer = servers.first;
        selectedIndex = 0;
      }
  // No persistent storage: nothing to save
    }
    else if (!_hasPreferenceServer) {
      _selectedServer = servers.first;
      selectedIndex = 0;
      selectedTab = "free";
  // No persistent storage: nothing to save
    }

    notifyListeners();
  }

  void setProServers(List<VpnServer> servers) {
    _proServers = servers;

    if (servers.isEmpty) {
      notifyListeners();
      return;
    }

    // Only update if preference server exists and is in pro tab
    if (_hasPreferenceServer && _selectedServer != null && selectedTab == "pro") {
      for (int i = 0; i < servers.length; i++) {
        if (servers[i].id == _selectedServer!.id) {
          selectedIndex = i;
          _selectedServer = servers[i]; // Update with current object
          // No persistent storage: nothing to save
          break;
        }
      }
    }
    notifyListeners();
  }

  // Clear selected server data and reset to free servers
  Future<void> clearSelectedServer() async {
    // TODO: Implement your preferences logic here or use a working preferences utility
    _hasPreferenceServer = false;

    if (_freeServers.isNotEmpty) {
      _selectedServer = _freeServers.first;
      selectedIndex = 0;
      selectedTab = "free";
  // No persistent storage: nothing to save
    } else {
      _selectedServer = null;
      selectedIndex = 0;
      selectedTab = "free";
    }

    notifyListeners();
  }

  // Get selected server for VPN connection
  VpnServer? getSelectedServerForConnection() {
    // Return preference server if exists
    if (_hasPreferenceServer && _selectedServer != null) {
      return _selectedServer;
    }

    // Fallback to first free server if no preference server
    if (_freeServers.isNotEmpty) {
      return _freeServers.first;
    }

    return null;
  }

  // Check if a server is currently selected
  bool isServerSelected(VpnServer server, int index, String tab) {
    return index == selectedIndex &&
        tab == selectedTab &&
        _selectedServer != null &&
        _selectedServer!.id == server.id;
  }

  // Reset to default server (first free server)
  void resetToDefault() {
    if (_freeServers.isNotEmpty) {
      selectedIndex = 0;
      selectedTab = "free";
      _selectedServer = _freeServers.first;
      _hasPreferenceServer = true;
  // No persistent storage: nothing to save
      notifyListeners();
    }
  }

  // Force set free servers (ignores preference check)
  void forceSetFreeServers(List<VpnServer> servers) {
    _freeServers = servers;
    if (servers.isNotEmpty && _selectedServer == null) {
      _selectedServer = servers.first;
      selectedIndex = 0;
      selectedTab = "free";
  // No persistent storage: nothing to save
    }
    notifyListeners();
  }

  // Check if should show servers based on preference
  bool shouldShowServers() {
    return _hasPreferenceServer || _freeServers.isNotEmpty;
  }

  // Get display servers based on preference
  List<VpnServer> getDisplayServers() {
    if (_hasPreferenceServer && _selectedServer != null) {
      return [_selectedServer!];
    }
    return _freeServers;
  }
}
