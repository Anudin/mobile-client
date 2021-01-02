import 'dart:async';
import 'dart:io';
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
