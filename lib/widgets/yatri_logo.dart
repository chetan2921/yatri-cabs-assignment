import 'package:flutter/material.dart';

class YatriCabsLogo extends StatelessWidget {
  final double height;

  const YatriCabsLogo({super.key, this.height = 60});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/c9d266ea557200d314d2233d110293781b55198b.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
