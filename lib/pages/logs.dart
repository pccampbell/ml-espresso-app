import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class LogsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.all(15),
          child: Text('Diddle'),
        ),
      ],
    );
  }
}