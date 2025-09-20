class ApiConfig {
  // Base URL for Technosofts API (no trailing slash)
  static const String baseUrl = String.fromEnvironment(
    'VPN_API_BASE_URL',
    defaultValue: 'https://vpn.technosofts.net',
  );

  // Server list endpoint path (leading slash). Example: '/api/servers' or '/api/v1/servers'
  static const String serversPath = String.fromEnvironment(
    'VPN_API_SERVERS_PATH',
    defaultValue: '/api/servers',
  );

  // Auth mode: 'basic' or 'bearer'
  static const String authMode = String.fromEnvironment(
    'VPN_API_AUTH',
    defaultValue: 'basic',
  );

  // For Basic auth
  static const String username = String.fromEnvironment('VPN_API_USER', defaultValue: 'freeopenvpn');
  static const String password = String.fromEnvironment('VPN_API_PASS', defaultValue: '605196725');

  // For Bearer auth
  static const String token = String.fromEnvironment('VPN_API_TOKEN', defaultValue: '');

  // If true, do NOT fall back to legacy VPNGate. Show empty list instead.
  static const bool onlyTechnosofts = bool.fromEnvironment(
    'VPN_ONLY_TECH',
    defaultValue: false,  // Changed to false to allow fallback while debugging
  );
}
