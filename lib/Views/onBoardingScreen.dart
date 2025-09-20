import 'package:flutter/material.dart';
import 'package:vpn_app/Views/Constant.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vpn_app/Models/splashScreenContent.dart';
import 'package:vpn_app/Views/CustomWidget/SimpleButton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn_app/Views/HomeScreen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key}); 
  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  int currentIndex = 0;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
   _pageController = PageController(initialPage: 0);
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: primarycolor,
        body: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: contents.length,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(30.0), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(    //image
                        flex: 4,
                        child: _buildSafeImage(contents[index].image)
                            .animate()
                            .fade(duration: 600.ms)
                            .slideY(
                              begin: 0.3,
                              end: 0,
                              duration: 500.ms,
                              curve: Curves.easeInOut,
                            ),
                      ),
             //title
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 25.0),
                          child: Text(
                            contents[index].title,
                            style: boldStyle,
                            textAlign: TextAlign.center,
                          )
                          .animate()
                          .fade(delay: 200.ms, duration: 600.ms)
                          .slideX(
                            begin: 0.3,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          ),
                        ),
                      ),

                      Expanded(
                        flex: 2,
                        child: Text(
                          contents[index].description,
                          style: mediumStyle,
                          textAlign: TextAlign.center,
                        )
                        .animate()
                        .fade(delay: 400.ms, duration: 600.ms)
                        .slideX(
                          begin: -0.3,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          // Page indicator dots
          Container(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                contents.length,
                (index) => buildDot(index, context),
              ),
            ),
          ),


         // Next button
          Padding(
           // padding: const EdgeInsets.all(18.0),
           padding: EdgeInsets.only(bottom: 17, top: 12),
            child: SimpleButton(
              text: currentIndex == contents.length - 1 ? 'Get Started' : 'Next',
              onTap: () async {
                try {
                  if (currentIndex == contents.length - 1) {
                    // Last page - navigate to home screen
                    var sharedpreferences = await SharedPreferences.getInstance();
                    // Mark onboarding as seen (keep old key for backward compatibility)
                    await sharedpreferences.setBool('onboarding_seen', true);
                    await sharedpreferences.setBool('newUser', true);

                    // Navigate to the HomeScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  } else {
                    // Go to next page
                    _pageController?.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                } catch (e) {
                  // Handle button tap errors
                  print('Button tap error: $e');
                }
              },
            ),
          ),


          // Skip button
          Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 5),
            child: InkWell(
              onTap: () async {
                try {
                  // Skip to home screen
                  var sharedpreferences = await SharedPreferences.getInstance();
                  await sharedpreferences.setBool('onboarding_seen', true);
                  await sharedpreferences.setBool('newUser', true);
                  
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                } catch (e) {
                  print('Skip button error: $e');
                }
              },
              child: Text(
                'Skip', 
                style: boldStyle.copyWith(fontSize: 16),
              ),
            ),
          ),
        ]),
      );
    } catch (e) {
      // Return error screen if something goes wrong
      return Scaffold(
        backgroundColor: primarycolor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 20),
              Text(
                'Error loading onboarding screen',
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '$e',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSafeImage(String imagePath) {
    try {
      return SvgPicture.asset(
        imagePath,
        fit: BoxFit.contain,
        height: 250,
        placeholderBuilder: (BuildContext context) => Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.image,
              size: 50,
              color: Colors.grey,
            ),
          ),
        ),
      );
    } catch (e) {
      // Return fallback container if SVG fails to load
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.grey,
              ),
              SizedBox(height: 10),
              Text(
                'Image not found',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }

  Container buildDot(int index, BuildContext context) {
    return Container(
      height: 8,
      width: 8,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: FractionalOffset.topRight,
          end: FractionalOffset.bottomLeft,
          colors: currentIndex == index
              ? [blue, gradientblue] : [Colors.white, Colors.white],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController!.dispose();
    super.dispose();
  }
}




