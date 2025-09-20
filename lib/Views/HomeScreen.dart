// ...existing code...
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:vpn_app/utils/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math; // for custom connecting animation
import 'package:provider/provider.dart';
import 'dart:async'; // for unawaited
import 'dart:ui' as ui; // for BackdropFilter blur
import 'package:vpn_app/Views/Constant.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vpn_app/Views/widgets/CustomAppDrawer.dart';
import 'package:vpn_app/Views/SpeedTestScreen.dart';
import 'package:vpn_app/Views/LocationsScreen.dart' as locations;
import 'package:vpn_app/Views/CustomWidget/report.dart';
import 'package:vpn_app/Views/SettingsScreen.dart';
import 'package:vpn_app/Providers/homeProvider.dart';
import 'package:vpn_app/Models/vpn_server.dart';

import 'package:vpn_app/Controller/services/notification_permission.dart';
import 'package:vpn_app/Models/vpn_status.dart';
import 'package:vpn_app/Controller/services/vpn_engine.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // ...existing code...


  bool isConnected = false; // mirrors provider.vpnState == connected
  bool _isPressing = false; // for press feedback
  late AnimationController _connectButtonController;
  late AnimationController _pulseController;
  String currentServer = "Auto Select";
  String? currentServerCode; // ISO country code
  String downloadSpeed = "0.00";
  String uploadSpeed = "0.00";
  DateTime? _sessionStart;
  DateTime? _sessionEnd;
  final List<double> _downloadSamples = [];
  final List<double> _uploadSamples = [];
  int _mockPingMs = 0;
  int? _lastByteIn;
  int? _lastByteOut;
  DateTime? _lastStatusTime;
  final Set<String> _connectingStates = {
    VpnEngine.vpnConnecting,
    VpnEngine.vpnAuthenticating,
    VpnEngine.vpnWaitConnection,
    VpnEngine.vpnReconnect,
    VpnEngine.vpnPrepare,
  };
  bool _manualDisconnectInProgress = false; // distinguishes user tap disconnect
  bool _reportShownForSession = false; // prevents duplicate report popup
  StreamSubscription<bool>? _connectivitySub;
  bool _noInternetDialogShown = false;
  InterstitialAd? _testInterstitialAd;
  BannerAd? _topBannerAd;
  bool _bannerLoaded = false;
  int _interstitialRetry = 0;
  int _bannerRetry = 0;
  bool _initializedFirstStage = false; // to avoid showing ads on first restore event
  Timer? _bannerKeepaliveTimer;
  // Track native stream subscriptions to cancel on dispose
  StreamSubscription<String>? _stageSub;
  StreamSubscription<VpnStatus>? _statusSub;
  DateTime? _lastRestart;
  // Guard window to ignore transient 'disconnected' stage right after cold start restore
  bool _restoreGuardActive = false;
  DateTime? _restoreGuardUntil;

  void _startRestoreGuard(Duration d) {
    _restoreGuardActive = true;
    _restoreGuardUntil = DateTime.now().add(d);
  }

  // Loads Google's official TEST interstitial (not tied to any real AdMob account)
  void _loadTestInterstitial() {
    InterstitialAd.load(
      // Google Test Interstitial ID
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialRetry = 0;
          _testInterstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _testInterstitialAd = null;
          if (_interstitialRetry < 3) {
            _interstitialRetry++;
            Future.delayed(Duration(seconds: 1 << _interstitialRetry), _loadTestInterstitial);
          }
        },
      ),
    );
  }

  // Loads Google's official TEST banner (not tied to any real AdMob account)
  void _loadTopBanner() {
    final banner = BannerAd(
      size: AdSize.banner,
      // Google Test Banner ID
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerRetry = 0;
          setState(() { _bannerLoaded = true; });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() { _bannerLoaded = false; });
          if (_bannerRetry < 5) {
            _bannerRetry++;
            Future.delayed(Duration(milliseconds: 400 * _bannerRetry), _loadTopBanner);
          }
        },
      ),
      request: const AdRequest(),
    );
    banner.load();
    _topBannerAd = banner;
  }

  void _ensureBannerLoaded() {
    if (_topBannerAd == null || !_bannerLoaded) {
      _loadTopBanner();
    }
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    // Listen for internet connectivity changes (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
  _loadTestInterstitial();
  _loadTopBanner();
      // Sync currentServer UI from provider immediately (in case a server was auto-selected during app init)
      final hp0 = Provider.of<HomeProvider>(context, listen: false);
      if (hp0.server != null) {
        setState(() {
          currentServer = hp0.server!.country;
          currentServerCode = hp0.server!.countryCode;
        });
      }
      final connectivityService = ConnectivityService();
      connectivityService.initialize();
      _connectivitySub = connectivityService.onConnectionChanged.listen((hasConnection) {
        if (!hasConnection && !_noInternetDialogShown) {
          _noInternetDialogShown = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Stack(
              children: [
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withOpacity(0.7)),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No Internet Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 12),
                        const Text('Please check your connection. VPN will not work until internet is restored.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          onPressed: () {
                            _noInternetDialogShown = false;
                            Navigator.of(ctx).pop();
                            Future.delayed(const Duration(milliseconds: 200), () {
                              final now = DateTime.now();
                              if (_lastRestart == null || now.difference(_lastRestart!) > const Duration(seconds: 15)) {
                                _lastRestart = now;
                                Restart.restartApp();
                              }
                            });
                          },
                          child: const Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (hasConnection && _noInternetDialogShown) {
          // Dismiss dialog if internet is restored
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      });
    });

    // Start pulse animation when connected
    if (isConnected) {
      _pulseController.repeat();
    }

    // Intercept connect button and connection attempts
    // Wrap connect logic to check internet before connecting
    // Example: in _buildConnectButton or connect logic, add:
    // if (!Provider.of<ConnectivityService>(context, listen: false).hasConnection) {
    //   _showNoInternetPopup();
    //   return;
    // }

    // Precache background so it appears immediately when toggled & attach VPN stage listener once
    WidgetsBinding.instance.addPostFrameCallback((_) {
    precacheImage(const AssetImage('assets/images/world_map_bg.jpg'), context);
  final hp = Provider.of<HomeProvider>(context, listen: false);
      // Query initial stage to restore UI state if VPN is already connected in background
      () async {
        try {
          await VpnEngine.refreshStage();
          final s = await VpnEngine.stage();
          if (s != null && mounted) {
            final sLower = s.toLowerCase();
            hp.changeVpnState(sLower);
            setState(() {
              isConnected = sLower == VpnEngine.vpnConnected;
            });
          }
          // Sync UI with any auto-selected server from provider
          if (mounted && hp.server != null) {
            setState(() {
              currentServer = hp.server!.country;
              currentServerCode = hp.server!.countryCode;
            });
          }
          // If still connected, try to restore last-known server name/flag so UI matches background connection
          if (mounted && isConnected && (hp.server == null)) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final lastName = prefs.getString('last_server_country');
              final lastCode = prefs.getString('last_server_code');
              if (lastName != null && lastName.isNotEmpty) {
                setState(() {
                  currentServer = lastName;
                  currentServerCode = lastCode;
                });
              }
            } catch (_) {}
          }
        } catch (_) {}
      }();
      _stageSub = VpnEngine.vpnStageSnapshot().listen((stage) {
        final stageLower = stage.toLowerCase();
        hp.changeVpnState(stageLower);
        if (!mounted) return;
        // During restore guard window, ignore transient 'disconnected' flips right after cold start
        if (_restoreGuardActive) {
          final now = DateTime.now();
          if (_restoreGuardUntil != null && now.isAfter(_restoreGuardUntil!)) {
            _restoreGuardActive = false;
          } else if (stageLower == VpnEngine.vpnDisconnected) {
            return; // ignore this transient update
          }
        }
        setState(() {
          final prev = isConnected;
          isConnected = stageLower == VpnEngine.vpnConnected;
          final bool isConnectingStage = _connectingStates.contains(stageLower);
          if (isConnectingStage && !isConnected && !_pulseController.isAnimating) {
            _pulseController.repeat();
          }
          if (isConnected && !prev) {
            Fluttertoast.showToast(msg: 'VPN Connected', gravity: ToastGravity.BOTTOM, backgroundColor: Colors.green.shade600, textColor: Colors.white, fontSize: 14);
            // start session stats
            _sessionStart = DateTime.now();
            _downloadSamples.clear();
            _uploadSamples.clear();
            _mockPingMs = 40 + DateTime.now().millisecond % 60;
            _pulseController.repeat();
            _reportShownForSession = false;
            _manualDisconnectInProgress = false;
            // Persist last connected flag
            () async { try { final p = await SharedPreferences.getInstance(); await p.setBool('last_connected', true);} catch (_) {} }();
            // Do not show report on connect; only after disconnect
          } else if (!isConnected && prev) {
            Fluttertoast.showToast(msg: 'VPN Disconnected', gravity: ToastGravity.BOTTOM, backgroundColor: Colors.red.shade600, textColor: Colors.white, fontSize: 14);
            // disconnected: finalize session & maybe open report
            _sessionEnd = DateTime.now();
            _pulseController.stop();
            _pulseController.reset();
            // Persist last connected flag
            () async { try { final p = await SharedPreferences.getInstance(); await p.setBool('last_connected', false);} catch (_) {} }();
            // If disconnect not manually initiated OR manual path hasn't already shown report
            // Also suppress the very first auto-disconnect report after app restore
            if (_initializedFirstStage && !_manualDisconnectInProgress && !_reportShownForSession) {
              _handleManualDisconnectAndReport();
              _reportShownForSession = true;
            }
            _manualDisconnectInProgress = false; // reset flag after any disconnect
          } else if (!isConnectingStage && !isConnected) {
            // Fully idle
            _pulseController.stop();
            _pulseController.reset();
          }
        });
        // Mark that we've processed the first stage event
        if (!_initializedFirstStage) _initializedFirstStage = true;
      });
      // Listen for live traffic stats to compute speeds
      _statusSub = VpnEngine.vpnStatusSnapshot().listen((status) {
        if (!mounted) return;
        if (!isConnected) return; // only measure while connected
        final now = DateTime.now();
        int parseBytes(String? s) {
          if (s == null) return 0;
          final cleaned = s.replaceAll(RegExp(r'[^0-9]'), '');
          return int.tryParse(cleaned) ?? 0;
        }
        final bIn = parseBytes(status.byteIn);
        final bOut = parseBytes(status.byteOut);
        if (_lastStatusTime != null && _lastByteIn != null && _lastByteOut != null) {
          final dtSeconds = now.difference(_lastStatusTime!).inMilliseconds / 1000.0;
          if (dtSeconds > 0) {
            final dIn = bIn - _lastByteIn!; // bytes
            final dOut = bOut - _lastByteOut!;
            // Convert to Mbps
            final downMbps = dIn <= 0 ? 0 : (dIn * 8) / (dtSeconds * 1000 * 1000);
            final upMbps = dOut <= 0 ? 0 : (dOut * 8) / (dtSeconds * 1000 * 1000);
            setState(() {
              downloadSpeed = downMbps.toStringAsFixed(2);
              uploadSpeed = upMbps.toStringAsFixed(2);
              // Store samples (cap length)
              _downloadSamples.add(downMbps.toDouble());
              _uploadSamples.add(upMbps.toDouble());
              if (_downloadSamples.length > 120) _downloadSamples.removeAt(0);
              if (_uploadSamples.length > 120) _uploadSamples.removeAt(0);
            });
          }
        }
        _lastByteIn = bIn;
        _lastByteOut = bOut;
        _lastStatusTime = now;
      });
    });
    // Pre-load last known connected UI quickly on cold start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadLastKnownUI();
    });
    // After initial post frame work, attempt to restore state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreConnectedState();
    });
    // Periodically ensure banner stays loaded
    _bannerKeepaliveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _ensureBannerLoaded());
  // ...existing code...
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectButtonController.dispose();
    _pulseController.dispose();
    _connectivitySub?.cancel();
    _stageSub?.cancel();
    _statusSub?.cancel();
    _topBannerAd?.dispose();
    _testInterstitialAd?.dispose();
    _bannerKeepaliveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _ensureBannerLoaded();
      // Re-sync VPN state when returning to foreground
      () async {
        try {
          await VpnEngine.refreshStage();
        } catch (_) {}
        _tryRestoreConnectedState();
      }();
    }
  }



  void _handleManualDisconnectAndReport() {
    _sessionEnd = DateTime.now();
    final lastDown = double.tryParse(downloadSpeed) ?? 0;
    final lastUp = double.tryParse(uploadSpeed) ?? 0;
    final avgDown = _downloadSamples.isEmpty ? 0 : _downloadSamples.reduce((a,b)=>a+b)/_downloadSamples.length;
    final avgUp = _uploadSamples.isEmpty ? 0 : _uploadSamples.reduce((a,b)=>a+b)/_uploadSamples.length;
    final start = _sessionStart ?? DateTime.now();
    final end = _sessionEnd ?? start;
    final duration = end.difference(start);
  // Removed unused variable 'hp'
  final serverPing = _mockPingMs;
    SessionReport.show(
      context,
      serverName: currentServer,
      duration: duration,
      avgDownloadMbps: avgDown.toDouble(),
      avgUploadMbps: avgUp.toDouble(),
      lastDownloadMbps: lastDown,
      lastUploadMbps: lastUp,
      pingMs: serverPing,
      startedAt: start,
      endedAt: end,
      downloadSamples: List<double>.from(_downloadSamples),
      uploadSamples: List<double>.from(_uploadSamples),
      serverFlagAsset: _serverFlagFor(currentServer),
    );
  }

  Future<void> _tryRestoreConnectedState() async {
    final hp = Provider.of<HomeProvider>(context, listen: false);
    // Poll more times (with refresh) in case native side needs time to reply after process death
    const attempts = 10;
    for (int i = 0; i < attempts; i++) {
      try {
        try { await VpnEngine.refreshStage(); } catch (_) {}
        final s = await VpnEngine.stage();
        if (!mounted) return;
        if (s != null) {
          final sLower = s.toLowerCase();
          hp.changeVpnState(sLower);
          final connectedNow = sLower == VpnEngine.vpnConnected;
          if (connectedNow != isConnected) {
            setState(() { isConnected = connectedNow; });
          }
          if (connectedNow) {
            // Ensure server name/flag are shown
            if (hp.server != null) {
              setState(() { currentServer = hp.server!.country; currentServerCode = hp.server!.countryCode; });
            } else {
              try {
                final prefs = await SharedPreferences.getInstance();
                final lastName = prefs.getString('last_server_country');
                final lastCode = prefs.getString('last_server_code');
                if (lastName != null && lastName.isNotEmpty) {
                  setState(() { currentServer = lastName; currentServerCode = lastCode; });
                }
              } catch (_) {}
            }
            return; // already restored
          }
        }
      } catch (_) {}
      // small backoff between polls
      await Future.delayed(const Duration(milliseconds: 250));
    }
    // If we reach here and still not connected, optionally auto-reconnect if enabled and user was previously connected
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool('last_connected') ?? false;
      final autoReconnect = prefs.getBool('auto_reconnect_on_reopen') ?? true;
      if (wasConnected && autoReconnect && hp.servers.isNotEmpty) {
        // Ensure provider has the last server selected
        final lastId = prefs.getInt('last_server_id') ?? 0;
        final lastIp = prefs.getString('last_server_ip') ?? '';
        final lastCode = prefs.getString('last_server_code') ?? '';
        final lastCountry = prefs.getString('last_server_country') ?? '';
        VpnServer? match;
        try {
          match = hp.servers.firstWhere(
            (s) => (lastId != 0 && s.id == lastId) ||
                   (lastIp.isNotEmpty && s.ipAddress == lastIp) ||
                   (lastCode.isNotEmpty && lastCountry.isNotEmpty && s.countryCode == lastCode && s.country == lastCountry),
            orElse: () => hp.servers.first,
          );
        } catch (_) {}
        if (match != null) {
          hp.setServer(match);
          // Silent reconnect (no interstitial, no report) – use provider logic
          hp.connectToVpn(context);
        }
      }
    } catch (_) {}
  }

  Future<void> _preloadLastKnownUI() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastConnected = prefs.getBool('last_connected') ?? false;
      if (!mounted || !lastConnected) return;
      // Start a short guard window to ignore transient 'disconnected' stage updates during restore
      _startRestoreGuard(const Duration(seconds: 2));
      final hp = Provider.of<HomeProvider>(context, listen: false);
      hp.changeVpnState(VpnEngine.vpnConnected);
      setState(() {
        isConnected = true;
      });
      // Apply last server UI immediately
      final lastName = prefs.getString('last_server_country');
      final lastCode = prefs.getString('last_server_code');
      if (lastName != null && lastName.isNotEmpty) {
        setState(() {
          currentServer = lastName;
          currentServerCode = lastCode;
        });
      } else if (hp.server != null) {
        setState(() {
          currentServer = hp.server!.country;
          currentServerCode = hp.server!.countryCode;
        });
      }
      // Start the pulse to reflect connected state visually
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hp = Provider.of<HomeProvider>(context);

    // Listen for result from LocationsScreen
    Future<void> _handleServerSelection() async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const locations.LocationsScreen()),
      );
      if (result is Map && result['name'] != null && result['code'] != null) {
        setState(() {
          currentServer = result['name'];
          currentServerCode = result['code'];
        });
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: primarycolor,
      drawer: CustomAppDrawer(
        onSpeedTest: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SpeedTestScreen()),
          );
        },
        onLocations: () {
          Navigator.pop(context);
          _handleServerSelection();
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: isConnected
                  ? const WorldMapBackground(key: ValueKey('bg'))
                  : const PreConnectBackground(key: ValueKey('pre-bg')),
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: isConnected
                  ? Container(
                      key: const ValueKey('dim'),
                      color: Colors.black.withOpacity(0.25),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-dim')),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double h = constraints.maxHeight;
                final double w = constraints.maxWidth;
                final bool veryCompact = h < 720;
                final bool compact = h < 800;
                final double pad = veryCompact ? 12 : (compact ? 16 : 20);
                final double gapS = veryCompact ? 8 : (compact ? 10 : 14);
                final double gapM = veryCompact ? 10 : (compact ? 14 : 22);
                final double buttonSize = _computeButtonSize(w, h);

                return Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      SizedBox(height: gapS),
                      _buildConnectionStatus(),
                      SizedBox(height: gapS),
                      if (_bannerLoaded && _topBannerAd != null)
                        SizedBox(
                          height: _topBannerAd!.size.height.toDouble(),
                          width: _topBannerAd!.size.width.toDouble(),
                          child: AdWidget(ad: _topBannerAd!),
                        ),
                      SizedBox(height: gapM),
                      // Use the middle space for the connect button so layout never overflows
                      Expanded(
                        child: Center(child: _buildConnectButton(context: context, size: buttonSize, provider: hp)),
                      ),
                      SizedBox(height: gapM),
                      _buildSpeedSection(compact: compact || veryCompact),
                      SizedBox(height: gapS),
                      _buildServerSection(compact: compact || veryCompact),
                      // Bottom actions removed; available via left navigation drawer.
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Left navigation (hamburger) icon
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardcolor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 22,
                ),
              )
              .animate()
              .scale(delay: 300.ms, duration: 400.ms)
              .fade(delay: 300.ms, duration: 400.ms),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shield VPN',
                  style: boldStyle.copyWith(fontSize: 24),
                )
                .animate()
                .fade(duration: 600.ms)
                .slideX(begin: -0.3, end: 0, duration: 600.ms),
                const SizedBox(height: 5),
                Text(
                  isConnected ? 'Protected' : 'Not Protected',
                  style: mediumStyle.copyWith(
                    color: isConnected ? Colors.green : Colors.red,
                    fontSize: 14,
                  ),
                )
                .animate()
                .fade(delay: 200.ms, duration: 600.ms),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          onLongPress: () {
            NotificationPermissionHelper.requestNotificationPermission();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Requesting notification permission...')),
            );
          },
          child: Tooltip(
            message: 'Settings (long press: notifications permission)',
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardcolor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        )
        .animate()
        .scale(delay: 400.ms, duration: 400.ms)
        .fade(delay: 400.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardcolor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isConnected ? Icons.shield : Icons.shield_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Connection Secured' : 'Connection Unsecured',
                  style: boldStyle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  isConnected 
                    ? 'Your internet traffic is encrypted'
                    : 'Your internet traffic is not protected',
                  style: mediumStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          SvgPicture.asset(
            'assets/images/safe.svg',
            height: 30,
            colorFilter: ColorFilter.mode(
              isConnected ? Colors.green : Colors.grey,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    )
    .animate()
    .fade(delay: 600.ms, duration: 600.ms)
    .slideY(begin: 0.3, end: 0, delay: 600.ms, duration: 600.ms);
  }

  double _computeButtonSize(double w, double h) {
  // Size the button based on available space to avoid overflow on short screens
  // Make it even smaller across devices
  // Slightly increased so the button content has a bit more breathing room
  final double byWidth = w * 0.35;   // was 0.33
  final double byHeight = h * 0.19;  // was 0.18
  // modestly larger min/max bounds
  return byWidth.clamp(105.0, 160.0).clamp(105.0, byHeight);
  }

  Widget _buildConnectButton({required BuildContext context, double size = 200, required HomeProvider provider}) {
    final bool isConnectingState = _connectingStates.contains(provider.vpnState) && !isConnected;
    final double ringThickness = size * 0.06; // thinner, more refined ring
    final double innerSize = size - (ringThickness * 2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressing = true),
      onTapCancel: () => setState(() => _isPressing = false),
      onTapUp: (_) => setState(() => _isPressing = false),
      // onTap: () async {
      //   if (provider.vpnState == VpnEngine.vpnConnected) {
      //     // Mark manual disconnect and show report instantly (avoid duplicate later)
      //     _manualDisconnectInProgress = true;
      //     if (!_reportShownForSession) {
      //       _handleManualDisconnectAndReport();
      //       _reportShownForSession = true;
      //     }
      //     // Kick off native stop without waiting
      //     unawaited(VpnEngine.stopVpn());
      //     provider.changeVpnState(VpnEngine.vpnDisconnected);
      //     setState(() { isConnected = false; });
      //     _pulseController.stop();
      //     _pulseController.reset();
      //   } else if (provider.vpnState == VpnEngine.vpnDisconnected) {
      //     provider.connectToVpn(context);
      //     _connectButtonController.forward();
      //   } else {
      //     // If in connecting/reconnecting state allow cancel
      //     await VpnEngine.stopVpn();
      //     provider.changeVpnState(VpnEngine.vpnDisconnected);
      //     setState(() { isConnected = false; });
      //     _pulseController.stop();
      //     _pulseController.reset();
      //   }
      // },

//        onTap: () async {
//   void handleVpnAction() async {
//     if (provider.vpnState == VpnEngine.vpnConnected) {
//       // Mark manual disconnect and show report instantly (avoid duplicate later)
//       _manualDisconnectInProgress = true;
//       if (!_reportShownForSession) {
//         _handleManualDisconnectAndReport();
//         _reportShownForSession = true;
//       }
//       // Kick off native stop without waiting
//       unawaited(VpnEngine.stopVpn());
//       provider.changeVpnState(VpnEngine.vpnDisconnected);
//       setState(() { isConnected = false; });
//       _pulseController.stop();
//       _pulseController.reset();
//     } else if (provider.vpnState == VpnEngine.vpnDisconnected) {
//       provider.connectToVpn(context);
//       _connectButtonController.forward();
//     } else {
//       // If in connecting/reconnecting state allow cancel
//       await VpnEngine.stopVpn();
//       provider.changeVpnState(VpnEngine.vpnDisconnected);
//       setState(() { isConnected = false; });
//       _pulseController.stop();
//       _pulseController.reset();
//     }
//   }
//   _showInterstitialAd(handleVpnAction);
// },


    onTap: () async {
      if (provider.vpnState == VpnEngine.vpnDisconnected) {
        // Show interstitial (test) only when initiating connection
        if (_testInterstitialAd != null) {
          final ad = _testInterstitialAd!;
          _testInterstitialAd = null;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              ad.dispose();
              _loadTestInterstitial();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              ad.dispose();
              _loadTestInterstitial();
            },
          );
          ad.show();
        } else {
          _loadTestInterstitial();
        }
        provider.connectToVpn(context);
        _connectButtonController.forward();
      } else if (provider.vpnState == VpnEngine.vpnConnected) {
        // Show interstitial when disconnecting too
        Future<void> performDisconnect() async {
          _manualDisconnectInProgress = true;
          if (!_reportShownForSession) {
            _handleManualDisconnectAndReport();
            _reportShownForSession = true;
          }
          await VpnEngine.stopVpn();
          provider.changeVpnState(VpnEngine.vpnDisconnected);
          setState(() { isConnected = false; });
          _pulseController.stop();
          _pulseController.reset();
        }
        if (_testInterstitialAd != null) {
          final ad = _testInterstitialAd!;
          _testInterstitialAd = null;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (_) {
                ad.dispose();
                _loadTestInterstitial();
              },
              onAdFailedToShowFullScreenContent: (_, __) {
                ad.dispose();
                _loadTestInterstitial();
              },
            );
          await performDisconnect();
          ad.show();
        } else {
          await performDisconnect();
          _loadTestInterstitial();
        }
      } else {
        // Cancel if in intermediate state
        await VpnEngine.stopVpn();
        provider.changeVpnState(VpnEngine.vpnDisconnected);
        setState(() { isConnected = false; });
        _pulseController.stop();
        _pulseController.reset();
      }
    },



      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _connectButtonController]),
        builder: (context, _) {
          final Color start = isConnected ? Colors.green : (isConnectingState ? gradientblue : blue);
          final Color end = isConnected ? Colors.greenAccent : (isConnectingState ? blue : gradientblue);

          return AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            scale: _isPressing ? 0.97 : 1.0,
            child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating gradient ring
                Transform.rotate(
                  angle: (isConnected || isConnectingState) ? (_pulseController.value * 6.283185) : 0,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          start.withOpacity(0.08),
                          start.withOpacity(0.30),
                          end.withOpacity(0.40),
                          start.withOpacity(0.30),
                          start.withOpacity(0.08),
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        center: Alignment.center,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isConnectingState ? gradientblue : start).withOpacity(0.22 + (_pulseController.value * 0.10)),
                          blurRadius: 20,
                          spreadRadius: 2 + (_pulseController.value * 4),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mask the ring center so it looks like a stroke
                Container(
                  width: size - ringThickness,
                  height: size - ringThickness,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                ),

                // Main circular button with glossy look
                Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
            colors: isConnected
              ? [Colors.green.shade700, Colors.green.shade400]
              : (isConnectingState
                ? [gradientblue.withOpacity(0.7), blue.withOpacity(0.9)]
                : [blue, gradientblue]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? Colors.green : blue).withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 2 + (_pulseController.value * (isConnected ? 4 : 2)),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // subtle outer glossy edge
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
                          ),
                        ),
                      ),
                      // subtle inner shadow to add depth
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.black.withOpacity(0.10),
                                Colors.transparent,
                              ],
                              radius: 1.0,
                              center: const Alignment(0.2, 0.2),
                            ),
                          ),
                        ),
                      ),
                      // subtle glossy highlight
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          width: innerSize * 0.9,
                          height: innerSize * 0.9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.20),
                                Colors.white.withOpacity(0.02),
                                Colors.transparent,
                              ],
                              radius: 0.85,
                              center: const Alignment(-0.5, -0.5),
                            ),
                          ),
                        ),
                      ),

                      // Content
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: child),
                            ),
                            child: isConnectingState
                                ? _SimpleConnectLoader(
                                    key: const ValueKey('simple_loader'),
                                    size: innerSize * 0.60,
                                    progress: _pulseController.value,
                                  )
                                : Column(
                                    key: ValueKey<String>(isConnected ? 'on_content' : 'off_content'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isConnected ? Icons.power_settings_new : Icons.power,
                                        size: innerSize * 0.30,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        isConnected ? 'DISCONNECT' : 'CONNECT',
                                        style: boldStyle.copyWith(fontSize: 15, letterSpacing: 1.0),
                                      ),
                                    ],
                                  ),
                          ),
                          // No connecting text or extra dots per request
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    )
    .animate()
    .scale(delay: 800.ms, duration: 800.ms, curve: Curves.elasticOut);
  }

  // Connecting loader removed per request; keeping button visuals polished

  Widget _buildSpeedSection({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: cardcolor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _buildMergedSpeedCard(compact: compact),
    )
    .animate()
    .fade(delay: 1000.ms, duration: 600.ms)
    .slideX(begin: 0.3, end: 0, delay: 1000.ms, duration: 600.ms);
  }

  Widget _buildMergedSpeedCard({bool compact = false}) {
    final BorderRadius br = BorderRadius.circular(18);
    final double pad = compact ? 12 : 14;
    final double iconSize = compact ? 22 : 24;
    final double valueSize = compact ? 18 : 20;
    final double unitSize = compact ? 11 : 12;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: br,
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            // very subtle border sheen
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: br,
          ),
          padding: const EdgeInsets.all(1.3),
          child: ClipRRect(
            borderRadius: br,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.14),
                  borderRadius: br,
                  border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Download side
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(compact ? 8 : 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
                            ),
                            child: Icon(Icons.download, color: Colors.green, size: iconSize),
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          Text('Download', style: mediumStyle.copyWith(fontSize: unitSize)),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: ScaleTransition(scale: anim, child: child),
                                ),
                                child: Text(
                                  downloadSpeed,
                                  key: ValueKey<String>(downloadSpeed),
                                  style: boldStyle.copyWith(fontSize: valueSize, color: Colors.green),
                                ),
                              ),
                              SizedBox(width: 5),
                              Text('Mbps', style: mediumStyle.copyWith(fontSize: unitSize, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: compact ? 58 : 64,
                      margin: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    // Upload side
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(compact ? 8 : 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
                            ),
                            child: Icon(Icons.upload, color: Colors.orange, size: iconSize),
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          Text('Upload', style: mediumStyle.copyWith(fontSize: unitSize)),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: ScaleTransition(scale: anim, child: child),
                                ),
                                child: Text(
                                  uploadSpeed,
                                  key: ValueKey<String>(uploadSpeed),
                                  style: boldStyle.copyWith(fontSize: valueSize, color: Colors.orange),
                                ),
                              ),
                              SizedBox(width: 5),
                              Text('Mbps', style: mediumStyle.copyWith(fontSize: unitSize, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // legacy single speed card removed; using merged card now

  Widget _buildServerSection({bool compact = false}) {
    final hp = Provider.of<HomeProvider>(context);
    final String? displayCode = hp.server?.countryCode ?? currentServerCode;
    final String displayName = hp.server?.country ?? currentServer;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: cardcolor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Server',
                style: boldStyle.copyWith(fontSize: compact ? 14 : 16),
              ),
              Icon(Icons.location_on, color: blue, size: compact ? 18 : 20),
            ],
          ),
          SizedBox(height: compact ? 10 : 15),
          // Attractive server selector with gradient border and ripple
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                // Optional: allow manual change, but not required since we auto-select at launch
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => locations.LocationsScreen(selected: displayName == 'Auto Select' ? null : displayName),
                  ),
                );
                if (result is Map && result['name'] != null) {
                  setState(() {
                    currentServer = result['name'];
                    currentServerCode = result['code'];
                  });
                  final hp = Provider.of<HomeProvider>(context, listen: false);
                  bool wasConnected = hp.vpnState == VpnEngine.vpnConnected;
                  if (wasConnected) {
                    // Show strong, smooth loading popup
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                    strokeWidth: 5,
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Switching server...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    // Prevent report popup during server switch
                    bool prevManualDisconnect = _manualDisconnectInProgress;
                    bool prevReportShown = _reportShownForSession;
                    _manualDisconnectInProgress = true;
                    _reportShownForSession = true;
                    unawaited(VpnEngine.stopVpn());
                    hp.changeVpnState(VpnEngine.vpnDisconnected);
                    setState(() { isConnected = false; });
                    _pulseController.stop();
                    _pulseController.reset();
                    await Future.delayed(const Duration(milliseconds: 500));
                    hp.connectToVpn(context);
                    _connectButtonController.forward();
                    // Restore report flags after switch
                    _manualDisconnectInProgress = prevManualDisconnect;
                    _reportShownForSession = prevReportShown;
                    // Dismiss loading popup when VPN is connected
                    void dismissLoading() {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    }
                    Future.doWhile(() async {
                      await Future.delayed(const Duration(milliseconds: 300));
                      return hp.vpnState != VpnEngine.vpnConnected;
                    }).then((_) => dismissLoading());
                  }
                  // If disconnected, do NOT auto-connect. Only update server selection.
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [blue.withOpacity(0.6), gradientblue.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(1.4),
                child: Container(
                  padding: EdgeInsets.all(compact ? 10 : 14),
                  decoration: BoxDecoration(
                    color: primarycolor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      // Flag or globe placeholder
                      Container(
                        width: compact ? 42 : 48,
                        height: compact ? 28 : 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                          image: currentServerCode != null
                                  ? DecorationImage(
                                      image: AssetImage('assets/flags/${(displayCode ?? currentServerCode)!.toLowerCase()}.png'),
                                      fit: BoxFit.cover,
                                      onError: (e, st) {},
                                    )
                                  : null,
                              color: (displayCode ?? currentServerCode) == null ? cardcolor : null,
                        ),
                            child: (displayCode ?? currentServerCode) == null
                            ? const Icon(Icons.public, color: Colors.white70, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                        displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: boldStyle.copyWith(fontSize: compact ? 13 : 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cardcolor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Recommended',
                                    style: mediumStyle.copyWith(fontSize: 10, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Fastest Available Server',
                              style: mediumStyle.copyWith(fontSize: compact ? 11 : 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardcolor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: compact ? 12 : 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .animate()
          .fade(duration: 400.ms)
          .slideX(begin: -0.1, end: 0, duration: 400.ms),
        ],
      ),
    )
    .animate()
    .fade(delay: 1200.ms, duration: 600.ms)
    .slideY(begin: 0.3, end: 0, delay: 1200.ms, duration: 600.ms);
  }

  String? _serverFlagFor(String name) {
    final map = {
      'United States': 'assets/flags/us.png',
      'United Kingdom': 'assets/flags/gb.png',
      'Germany': 'assets/flags/de.png',
      'France': 'assets/flags/fr.png',
      'Canada': 'assets/flags/ca.png',
      'Australia': 'assets/flags/au.png',
      'India': 'assets/flags/in.png',
      'Japan': 'assets/flags/jp.png',
      'Singapore': 'assets/flags/sg.png',
      'Netherlands': 'assets/flags/nl.png',
    };
    return map[name];
  }

  // Bottom actions removed; navigation is now in the drawer.
}

// Material-inspired smooth connecting indicator: pulsing center + orbiting dots + subtle arcs.
// New minimal smooth loader: two counter-rotating gradient rings + fading center pulse.
class _SimpleConnectLoader extends StatelessWidget {
  final double size;
  final double progress; // 0..1
  const _SimpleConnectLoader({super.key, required this.size, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SimpleLoaderPainter(progress: progress),
        child: Center(
          child: Opacity(
            opacity: 0.55 + 0.45 * math.sin(progress * 2 * math.pi),
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.90),
                    Colors.white.withOpacity(0.15),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleLoaderPainter extends CustomPainter {
  final double progress;
  _SimpleLoaderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    void ring({required double radiusFactor, required double strokeFactor, required double speed, required List<Color> colors}) {
      final radius = r * radiusFactor;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final start = progress * 2 * math.pi * speed;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * strokeFactor
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: colors,
          stops: const [0, 0.5, 1],
          transform: GradientRotation(start),
        ).createShader(rect);
      canvas.drawArc(rect, start, math.pi * 1.2, false, paint);
    }

    ring(
      radiusFactor: 0.95,
      strokeFactor: 0.085,
      speed: 1.0,
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.35),
        Colors.white.withOpacity(0.0),
      ],
    );
    ring(
      radiusFactor: 0.70,
      strokeFactor: 0.070,
      speed: -1.6,
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.28),
        Colors.white.withOpacity(0.0),
      ],
    );

    // Subtle thin ring for polish
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.015
      ..color = Colors.white.withOpacity(0.15);
    canvas.drawCircle(center, r * 0.50, thin);
  }

  @override
  bool shouldRepaint(covariant _SimpleLoaderPainter oldDelegate) => oldDelegate.progress != progress;
}

class WorldMapBackground extends StatelessWidget {
  const WorldMapBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/world_map_bg.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    );
  }
}

class PreConnectBackground extends StatelessWidget {
  const PreConnectBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/background.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    );
  }
}

// Top-level painter for the professional connecting loader
// (Connecting loader painter removed)