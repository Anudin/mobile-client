import 'dart:async';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:wakelock/wakelock.dart';

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
      home: CameraScreen(),
    ),
  );
}

class CameraScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: CameraApp(),
    );
  }
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController controller;

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.veryHigh);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: FloatingActionButton(
              child: Icon(Icons.photo_camera),
              onPressed: () {
                controller.takePicture().then((xfile) async {
                  final visionImage = FirebaseVisionImage.fromFilePath(xfile.path);
                  final cloudTextRecognizer = FirebaseVision.instance.cloudTextRecognizer();
                  final visionText = await cloudTextRecognizer.processImage(visionImage);

                  String text = visionText.text;
                  // for (TextBlock block in visionText.blocks) {
                  //   final Rect boundingBox = block.boundingBox;
                  //   final List<Offset> cornerPoints = block.cornerPoints;
                  //   final String text = block.text;
                  //   final List<RecognizedLanguage> languages = block.recognizedLanguages;
                  //
                  //   for (TextLine line in block.lines) {
                  //     // Same getters as TextBlock
                  //     for (TextElement element in line.elements) {
                  //       // Same getters as TextBlock
                  //     }
                  //   }
                  // }

                  cloudTextRecognizer.close();
                  Fluttertoast.showToast(
                      msg: text,
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0
                  );
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
