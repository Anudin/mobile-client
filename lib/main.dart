import 'dart:async';
import 'dart:io';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile/util.dart';
import 'package:wakelock/wakelock.dart';

import 'alias.dart';

List<CameraDescription> cameras;

// FIXME Handle camera lifecycle, see https://pub.dev/packages/camera#handling-lifecycle-states
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  if (!kReleaseMode) {
    Wakelock.enable();
  }
  runApp(
    MaterialApp(
      home: MainScreen(),
    ),
  );
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [CameraView(), AliasMasterView()][_selected],
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          setState(() {
            _selected = index;
          });
        },
        currentIndex: _selected,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.photo_camera), label: "Erfassen"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: "Aliasse")
        ],
      ),
    );
  }
}

class AliasMasterView extends StatelessWidget {
  final aliasses = [
    Alias('google', 'https://www.google.com'),
    Alias('reddit', 'https://www.reddit.com'),
    Alias('rickroll', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', '420s')
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListView(
          children: aliasses
              .map(
                (alias) => ListTile(
                  title: Text(alias.alias),
                  subtitle: Text(alias.URL),
                  trailing: Text(alias.position ?? ''),
                  onTap: () async {
                    final result = await Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) => AliasDetailView(alias)));
                    print(result);
                  },
                ),
              )
              .toList()),
    );
  }
}

class AliasDetailView extends StatelessWidget {
  final Alias alias;

  AliasDetailView(this.alias);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Ensure that the edited instance is returned, even is the back button is used
      onWillPop: () async {
        Navigator.of(context).pop(alias);
        return false;
      },
      child: SizedBox.shrink(),
    );
  }
}

class CameraView extends StatefulWidget {
  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController cameraController;

  @override
  void initState() {
    super.initState();
    cameraController = CameraController(cameras[0], ResolutionPreset.veryHigh);
    cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!cameraController.value.isInitialized) {
      return Container();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: cameraController.value.aspectRatio,
          child: CameraPreview(cameraController),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: TakePictureFAB(
              onPressed: () {
                cameraController.takePicture().then((xfile) async {
                  final visionImage = FirebaseVisionImage.fromFilePath(xfile.path);
                  // Both cloudTextRecognizer and cloudDocumentTextRecognizer could be used
                  // Requires testing to see which provides more reliable results
                  final cloudTextRecognizer = FirebaseVision.instance
                      .cloudDocumentTextRecognizer(CloudDocumentRecognizerOptions(hintedLanguages: ['en', 'de']));
                  final visionText = await cloudTextRecognizer.processImage(visionImage);
                  String text = visionText.text;
                  try {
                    File(xfile.path).deleteSync();
                  } catch (exception) {
                    print(exception);
                  }

                  cloudTextRecognizer.close();
                  showDevToast(text);
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

class TakePictureFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const TakePictureFAB({
    Key key,
    @required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(
          width: 4,
          color: Theme.of(context).accentColor,
        ),
      ),
      elevation: 0,
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).accentColor),
      ),
      onPressed: onPressed,
    );
  }
}
