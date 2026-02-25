

import 'package:flutter/material.dart';
import 'screens/payment_screen.dart';

void main() {
  runApp(const EsewaPaymentApp());
}

class EsewaPaymentApp extends StatelessWidget {
  const EsewaPaymentApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSewa Payment Integration',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const PaymentScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
