import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Find Your Moment',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Take a pause and reset your mind'),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: () => context.go('/auth'),
              child: const Text('Begin Journey'),
            ),
          ],
        ),
      ),
    );
  }
}
