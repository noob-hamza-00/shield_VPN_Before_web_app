import 'package:flutter/material.dart';
import 'package:vpn_app/Views/Constant.dart';
import 'package:flutter/services.dart';
import 'package:vpn_app/Views/onBoardingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn_app/Views/HomeScreen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    try {
      // Set the preferred orientations to portrait only
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Wait for splash duration
      await Future.delayed(const Duration(milliseconds: 3000));

      // Check first launch flag
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarding_seen') ?? false;

      if (!mounted) return;
      if (!seen) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnBoardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      // If something goes wrong, still navigate after delay
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarding_seen') ?? false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => seen ? const HomeScreen() : const OnBoardingScreen()),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primarycolor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with safe loading
              _buildSafeLogo(),
              const SizedBox(height: 30),
              // App title
              _buildAppTitle(),
              const SizedBox(height: 20),
              // Loading indicator
              _buildLoadingIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeLogo() {
    // Use PNG logo to avoid crashes if SVG is missing; fall back to icon on error
    return Container(
      height: 120,
      width: 120,
      child: Image.asset(
        'assets/images/shield_logo.png',
        height: 100,
        width: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _buildLogoFallback(),
      ),
    )
    .animate()
    .scale(delay: 200.ms, duration: 800.ms, curve: Curves.elasticOut)
    .fade(duration: 600.ms);
  }

  Widget _buildLogoFallback() {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [blue, gradientblue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.vpn_lock_rounded,
        size: 50,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAppTitle() {
    return Text(
      'Shield VPN',
      style: boldStyle.copyWith(fontSize: 28),
    )
    .animate()
    .fade(delay: 800.ms, duration: 600.ms)
    .slideY(begin: 0.3, end: 0, delay: 800.ms, duration: 600.ms);
  }

  Widget _buildLoadingIndicator() {
    return const CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      strokeWidth: 2,
    )
    .animate()
    .fade(delay: 1000.ms, duration: 400.ms);
  }
}