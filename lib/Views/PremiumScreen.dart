import 'package:flutter/material.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // These prices should be fetched from backend API in real app
  double monthlyPrice = 330;
  double yearlyPrice = 3200;
  double lifetimePrice = 10500;

  // Simulate fetching prices from backend
  Future<void> fetchPrices() async {
    // TODO: Replace with real API call
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      // Example: update prices from backend response
      monthlyPrice = 330; // Replace with backend value
      yearlyPrice = 3200; // Replace with backend value
      lifetimePrice = 10500; // Replace with backend value
    });
  }

  @override
  void initState() {
    super.initState();
    fetchPrices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent, Colors.amber],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: const Text('Shield VPN Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildPlanCard('Monthly Plan', monthlyPrice, '1 Month', accentColor, Icons.calendar_today),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildPlanCard('Yearly Plan', yearlyPrice, '12 Months', accentColor, Icons.star, highlight: true, showBanner: true),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildPlanCard('Lifetime Access', lifetimePrice, 'Lifetime', accentColor, Icons.lock),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueGrey.shade900, Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Note: Subscription can be cancelled any time.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const accentColor = Color(0xFF4F8AFE);

  Widget _buildPlanCard(String title, double price, String duration, Color color, IconData icon, {bool highlight = false, bool showBanner = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.grey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: highlight ? Border.all(color: Colors.amber, width: 2.2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(title, style: TextStyle(color: accentColor, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 5),
                Text('Rs ${price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 1),
                Text(duration, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                      elevation: 2,
                      shadowColor: accentColor.withOpacity(0.15),
                    ),
                    onPressed: () {
                      // TODO: Handle buy logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Buy $title selected!')),
                      );
                    },
                    child: const Text('BUY NOW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          if (showBanner)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: const Text(
                  'Most Popular',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
