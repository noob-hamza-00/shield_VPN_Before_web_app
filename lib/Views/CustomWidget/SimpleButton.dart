import 'package:flutter/material.dart';
import 'package:vpn_app/Views/Constant.dart';

class SimpleButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  
  const SimpleButton({super.key, required this.text, this.onTap});
 

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 60,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(

          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            blue,
            gradientblue
          ]
        )
      ),

      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
      child: Center(
        child: Text(
          text,
          style: btnStyle,
        ),
      ),
    ),
    );
  }
}