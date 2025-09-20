import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:vpn_app/Views/SplashScreen.dart';
import 'package:vpn_app/Views/Constant.dart';
import 'package:flutter/services.dart';
import 'package:vpn_app/Controller/Api/apis.dart';
import 'package:provider/provider.dart';
import 'package:vpn_app/Providers/homeProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Mobile Ads SDK
  MobileAds.instance.initialize();

  // Forward Flutter framework errors to zone
  FlutterError.onError = (FlutterErrorDetails details) {
    // Still print to console
    FlutterError.presentError(details);
    // Send to zone handler
    Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.empty);
  };

  // Platform (engine) level errors (Flutter 3.3+)
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error\n$stack');
    return true; // mark handled
  };

  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
  ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VPN App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'UMedium', // Set a default font
        ),
        home: const SafeWrapper(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: child ?? const ErrorScreen(),
          );
        },
      ),
    );
  }
}

// NOTE: Test-only code commented out to avoid duplicate banners.
// The app already shows a banner from HomeScreen using Google's official test unit ID.
// To re-enable this example widget, remove the comment block below.
/*
// Example widget to show a test banner ad
class TestBannerAdWidget extends StatefulWidget {
  const TestBannerAdWidget({Key? key}) : super(key: key);

  @override
  State<TestBannerAdWidget> createState() => _TestBannerAdWidgetState();
}

class _TestBannerAdWidgetState extends State<TestBannerAdWidget> {
  late BannerAd _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _bannerAd = BannerAd(
      // Google official TEST banner unit ID (not tied to any real account)
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: _bannerAd.size.width.toDouble(),
      height: _bannerAd.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd),
    );
  }
}
*/

// Safe wrapper to catch initialization errors
class SafeWrapper extends StatelessWidget {
  const SafeWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(context),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorScreen(error: snapshot.error.toString());
        }
        
        if (snapshot.connectionState == ConnectionState.done) {
          return const Splashscreen();
        }
        
        // Show loading while initializing
        return Scaffold(
          backgroundColor: primarycolor,
          body: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }

  Future<void> _initializeApp(BuildContext context) async {
    try {
      // Initialize system settings
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Small delay to ensure everything is loaded
      await Future.delayed(const Duration(milliseconds: 100));

      // Preload VPN server list and select server for this launch
      try {
        final servers = await ApiService.fetchTechnosoftsServers(context);
        debugPrint('Initial VPN servers loaded: \\${servers.length}');
        final hp = Provider.of<HomeProvider>(context, listen: false);
        hp.setServers(servers);
        if (servers.isNotEmpty) {
          // If user was connected previously, restore that exact server; else pick random
          bool restored = false;
          try {
            final prefs = await SharedPreferences.getInstance();
            final lastConnected = prefs.getBool('last_connected') ?? false;
            if (lastConnected) {
              final lastId = prefs.getInt('last_server_id') ?? 0;
              final lastIp = prefs.getString('last_server_ip') ?? '';
              final lastCode = prefs.getString('last_server_code') ?? '';
              final lastCountry = prefs.getString('last_server_country') ?? '';
              final match = servers.firstWhere(
                (s) => (lastId != 0 && s.id == lastId) ||
                       (lastIp.isNotEmpty && s.ipAddress == lastIp) ||
                       (lastCode.isNotEmpty && lastCountry.isNotEmpty && s.countryCode == lastCode && s.country == lastCountry),
                orElse: () => servers.first,
              );
              hp.setServer(match);
              restored = true;
              debugPrint('Restored last server: \\${match.country} (\\${match.countryCode})');
            }
          } catch (e) {
            debugPrint('Restore last server failed: $e');
          }
          if (!restored) {
            final rnd = math.Random();
            final pick = servers[rnd.nextInt(servers.length)];
            hp.setServer(pick);
            debugPrint('Auto-selected server: \\${pick.country} (\\${pick.countryCode})');
          }
        }
      } catch (e) {
        debugPrint('Initial VPN server fetch failed: $e');
      }
    } catch (e) {
      // Log error but continue
      print('Initialization error: $e');
    }
  }
}

// Enhanced error screen with optional error message
class ErrorScreen extends StatelessWidget {
  final String? error;
  
  const ErrorScreen({Key? key, this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primarycolor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Restart the app
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SafeWrapper()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restart App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
