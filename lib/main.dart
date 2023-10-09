import 'package:flutter/material.dart';
import 'package:ml_espresso_app/pages/camera.dart';
import 'package:ml_espresso_app/pages/logs.dart';
import 'package:ml_espresso_app/pages/settings.dart';
import 'package:camera/camera.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EspressoFlowML',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedPageIndex = 0;
  var titleText = 'Logs';

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedPageIndex) {
      case 0:
        page = LogsPage();
        titleText = 'Logs';
        break;
      case 1:
        page = CameraPage();
        titleText = 'Graph ML';
        break;
      case 2:
        page = SettingsPage();
        titleText = 'Settings';
        break;
      default:
        throw UnimplementedError('no widget for $selectedPageIndex');
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(titleText),
      ),
      body: Center(
        child: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: page,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Spacer(),
            IconButton(
                icon: Icon(Icons.list_alt, size: 35),
                onPressed: () {
                  setState(() {
                    selectedPageIndex = 0;
                  });
                }),
            FloatingActionButton(
                child: Icon(Icons.photo_camera, size: 35),
                onPressed: () {
                  setState(() {
                    selectedPageIndex = 1;
                  });
                }),
            IconButton(
                icon: Icon(Icons.settings, size: 35),
                onPressed: () {
                  setState(() {
                    selectedPageIndex = 2;
                  });
                }),
            // Spacer(),
          ],
        ),
      ),
    );
  }
}
