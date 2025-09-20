
import '../../Models/vpn_server.dart' as models;

abstract class ServerDataSource {
  Future<List<models.VpnServer>> fetchServers();
}