import 'dart:async';
import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/util.dart';
import 'package:wakelock/wakelock.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'alias.dart';

List<CameraDescription> cameras;

// FIXME Alias persistence - UIDs, data order vs sorting order
// FIXME Handle camera lifecycle, see https://pub.dev/packages/camera#handling-lifecycle-states
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final aliasCubit = AliasCubit();
  aliasCubit.create(Alias('google', 'https://www.google.com'));
  aliasCubit.create(Alias('reddit', 'https://www.reddit.com'));
  aliasCubit.create(Alias('rickroll', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', '420s'));
  cameras = await availableCameras();
  if (!kReleaseMode) {
    Wakelock.enable();
  }
  runApp(
    BlocProvider.value(
      value: aliasCubit,
      child: MaterialApp(
        home: MainScreen(),
      ),
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
    final aliasCubit = BlocProvider.of<AliasCubit>(context);
    return Scaffold(
      body: SafeArea(
        child: [CameraView(), AliasMasterView()][_selected],
      ),
      floatingActionButton: _selected == 1
          ? FloatingActionButton(
              onPressed: () async {
                final alias = await Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) => AliasDetailView(alias: Alias('', ''))));
                if (alias != null) aliasCubit.create(alias);
              },
              child: Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

// TODO Undo dismiss, insert in same position?
class AliasMasterView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final aliasCubit = BlocProvider.of<AliasCubit>(context);
    return BlocBuilder<AliasCubit, BuiltMap<String, Alias>>(
      builder: (context, state) => ListView(
        children: [
          for (var uuid in state.keys)
            Dismissible(
              key: Key(uuid),
              background: Container(
                color: Colors.black12,
                padding: EdgeInsets.only(left: 16),
                alignment: Alignment.centerLeft,
                child: Icon(Icons.delete_outline),
              ),
              direction: DismissDirection.startToEnd,
              onDismissed: (direction) {
                aliasCubit.delete(uuid);
              },
              child: ListTile(
                title: Text(state[uuid].alias),
                // TODO Shorten URL: remove http[s]://www. and limit length, if necessary add ...
                subtitle: Text(state[uuid].URL),
                trailing: Text(state[uuid].position ?? ''),
                onTap: () async {
                  // TODO Give feedback
                  final update = await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) => AliasDetailView(alias: state[uuid])));
                  if (update != null) aliasCubit.update(uuid, update);
                },
              ),
            )
        ],
      ),
    );
  }
}

class AliasDetailView extends StatefulWidget {
  final Alias alias;

  AliasDetailView({@required this.alias});

  @override
  _AliasDetailViewState createState() => _AliasDetailViewState();
}

class _AliasDetailViewState extends State<AliasDetailView> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _aliasEditingController;
  TextEditingController _URLEditingController;
  TextEditingController _positionEditingController;

  @override
  void initState() {
    super.initState();
    _aliasEditingController = TextEditingController(text: widget.alias.alias);
    _URLEditingController = TextEditingController(text: widget.alias.URL);
    _positionEditingController = TextEditingController(text: widget.alias.position);
  }

  @override
  void dispose() {
    _aliasEditingController.dispose();
    _URLEditingController.dispose();
    _positionEditingController.dispose();
    super.dispose();
  }

  bool valid = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onWillPop: () async {
              if (_hasChanges()) {
                final shouldDiscardChanges = await showDiscardChangesDialog(context);
                return shouldDiscardChanges;
              } else {
                return true;
              }
            },
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'Alias'),
                  controller: _aliasEditingController,
                  validator: (text) => null,
                ),
                TextFormField(
                  controller: _URLEditingController,
                  decoration: InputDecoration(labelText: 'URL'),
                  maxLines: null,
                  validator: (text) => null,
                ),
                TextFormField(
                  controller: _positionEditingController,
                  decoration: InputDecoration(labelText: 'Position'),
                  validator: (text) => null,
                ),
                Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FlatButton(
                      child: Text('Verwerfen'),
                      // TODO Show discard changes dialog?
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    RaisedButton(
                      color: Colors.lightGreen,
                      child: Text('Bestätigen'),
                      onPressed: _onConfirmChanges,
                    ),
                  ],
                )
              ],
            ),
          ),
          padding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  bool _hasChanges() =>
      widget.alias.alias != _aliasEditingController.text ||
      widget.alias.URL != _URLEditingController.text ||
      (widget.alias.position ?? '') != _positionEditingController.text;

  void _onConfirmChanges() {
    if (_hasChanges()) {
      // FIXME Implement validators
      final hasValidChanges = _formKey.currentState.validate();
      if (hasValidChanges) {
        Navigator.of(context).pop(Alias(
          _aliasEditingController.text,
          _URLEditingController.text,
          _positionEditingController.text != '' ? _positionEditingController.text : null,
        ));
      } else {
        Fluttertoast.showToast(
          msg: 'Die Eingaben enthalten Fehler.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          fontSize: 16.0,
        );
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool> showDiscardChangesDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Änderungen verwerfen?'),
        actions: [
          FlatButton(
            child: Text('Nein'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FlatButton(
            child: Text('Ja'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
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
            padding: EdgeInsets.all(16),
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
