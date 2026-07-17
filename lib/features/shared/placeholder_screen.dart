import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, this.message, super.key});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message ?? title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      floatingActionButton: title == 'Home'
          ? FloatingActionButton(
              onPressed: () => context.push('/capture'),
              child: const Icon(Icons.document_scanner_outlined),
            )
          : null,
    );
  }
}
