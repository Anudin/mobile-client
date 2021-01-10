import 'dart:async';
import 'dart:convert';
import 'dart:io' hide Link;
import 'package:bonsoir/bonsoir.dart';
import 'package:built_collection/built_collection.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mobile/discovery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

import 'alias.dart';
import 'link.dart';

SharedPreferences _preferences;
List<CameraDescription> _cameras;
ServiceDiscoveryCubit _serviceDiscovery;

class BlocLogging extends BlocObserver {
  @override
  void onChange(Cubit cubit, Change change) {
    print('${cubit.runtimeType} $change');
    super.onChange(cubit, change);
  }

  @override
  void onError(Cubit cubit, Object error, StackTrace stackTrace) {
    print('${cubit.runtimeType} $error');
    super.onError(cubit, error, stackTrace);
  }
}

// TODO Consistent handling of string sanitization from OCR artifacts
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = BlocLogging();
  _cameras = await availableCameras();
  _preferences = await SharedPreferences.getInstance();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationSupportDirectory(),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (!kReleaseMode) {
    Wakelock.enable();
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => _ExternalViewerStaticConfig(_preferences.getString('externalViewerIP') ?? ''),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => _serviceDiscovery = ServiceDiscoveryCubit(type: '_http._tcp.')),
          BlocProvider(create: (context) => AliasCubit())
        ],
        child: MaterialApp(
          home: MainScreen(),
        ),
      ),
    ),
  );
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceDiscovery.stop();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await _serviceDiscovery.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        await _serviceDiscovery.stop();
        break;
    }
  }

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

class AliasMasterView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final aliasCubit = BlocProvider.of<AliasCubit>(context);
    return BlocBuilder<AliasCubit, BuiltMap<String, Alias>>(
      builder: (context, state) => ListView(
        children: [
          for (var alias in state.keys)
            Dismissible(
              key: Key(alias),
              background: Container(
                color: Colors.black12,
                padding: EdgeInsets.only(left: 16),
                alignment: Alignment.centerLeft,
                child: Icon(Icons.delete_outline),
              ),
              direction: DismissDirection.startToEnd,
              onDismissed: (direction) {
                aliasCubit.delete(state[alias]);
              },
              child: ListTile(
                title: Text(state[alias].name),
                // TODO Shorten URL: remove http[s]://www. and limit length, if necessary add ...
                subtitle: Text(state[alias].URL),
                trailing: Text(state[alias].position ?? ''),
                onTap: () async {
                  // TODO Give feedback
                  final update = await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) => AliasDetailView(alias: state[alias])));
                  if (update != null) aliasCubit.update(state[alias], update);
                },
              ),
            )
        ],
      ),
    );
  }
}

// FIXME Disable keyboard correction
class AliasDetailView extends StatefulWidget {
  final Alias alias;

  AliasDetailView({@required this.alias});

  @override
  _AliasDetailViewState createState() => _AliasDetailViewState();
}

class _AliasDetailViewState extends State<AliasDetailView> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _nameEditingController;
  TextEditingController _URLEditingController;
  TextEditingController _positionEditingController;

  @override
  void initState() {
    super.initState();
    _nameEditingController = TextEditingController(text: widget.alias.name);
    _URLEditingController = TextEditingController(text: widget.alias.URL);
    _positionEditingController = TextEditingController(text: widget.alias.position);
  }

  @override
  void dispose() {
    _nameEditingController.dispose();
    _URLEditingController.dispose();
    _positionEditingController.dispose();
    super.dispose();
  }

  bool valid = false;

  @override
  Widget build(BuildContext context) {
    final aliasCubit = BlocProvider.of<AliasCubit>(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
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
                  decoration: InputDecoration(labelText: 'Name'),
                  controller: _nameEditingController,
                  validator: (text) => !Alias.isValidName(text)
                      ? 'Name has invalid format.'
                      : text != widget.alias.name && !aliasCubit.isAvailable(text)
                          ? 'An alias with the given name already exists.'
                          : null,
                ),
                TextFormField(
                  controller: _URLEditingController,
                  decoration: InputDecoration(labelText: 'URL'),
                  maxLines: null,
                  validator: (text) => !Alias.isValidURL(text) ? 'URL has invalid format.' : null,
                ),
                TextFormField(
                  controller: _positionEditingController,
                  decoration: InputDecoration(
                    labelText: 'Position',
                    prefixText: '# ',
                    prefixStyle: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  validator: (text) =>
                      text.isNotEmpty && !Alias.isValidPosition(text) ? 'Position has invalid format.' : null,
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
        ),
      ),
    );
  }

  bool _hasChanges() =>
      widget.alias.name != _nameEditingController.text ||
      widget.alias.URL != _URLEditingController.text ||
      (widget.alias.position ?? '') != _positionEditingController.text;

  void _onConfirmChanges() {
    if (_hasChanges()) {
      final hasValidChanges = _formKey.currentState.validate();
      if (hasValidChanges) {
        Navigator.of(context).pop(Alias(
          _nameEditingController.text.trim(),
          _URLEditingController.text.trim(),
          _positionEditingController.text != '' ? _positionEditingController.text.trim() : null,
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

// TODO Add UI control for flash
class CameraView extends StatefulWidget {
  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController _cameraController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraController();
  }

  Future<void> _initializeCameraController() {
    _cameraController = CameraController(_cameras[0], ResolutionPreset.veryHigh);
    return _cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_cameraController == null || !_cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController.debugCheckIsDisposed();
      _initializeCameraController();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Container();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: _cameraController.value.aspectRatio,
          child: CameraPreview(_cameraController),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Builder(
              builder: (context) {
                final discoveredService = context.watch<ServiceDiscoveryCubit>().state;
                final staticService = context.watch<_ExternalViewerStaticConfig>();
                return TakePictureFAB(
                  onPressed: discoveredService != null || staticService.ip.isNotEmpty
                      ? () => _onTakePicture(context, discoveredService, staticService)
                      : null,
                );
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: Icon(Icons.settings),
            color: Theme.of(context).accentColor,
            padding: EdgeInsets.all(16),
            onPressed: () => _onSettings(context),
          ),
        )
      ],
    );
  }

  Future<void> _onTakePicture(
    BuildContext context,
    ResolvedBonsoirService discoveredService,
    _ExternalViewerStaticConfig staticService,
  ) async {
    final imageXFile = await _cameraController.takePicture();
    File croppedImage = await ImageCropper.cropImage(
        sourcePath: imageXFile.path,
        compressFormat: ImageCompressFormat.png,
        aspectRatioPresets: [CropAspectRatioPreset.ratio16x9],
        androidUiSettings: AndroidUiSettings(hideBottomControls: true));
    if (croppedImage != null) {
      var ocrText = '';
      DocumentTextRecognizer textRecognizer;
      try {
        final textRecognizer =
            FirebaseVision.instance.cloudTextRecognizer(CloudTextRecognizerOptions(hintedLanguages: ['en', 'de']));
        final visionImage = FirebaseVisionImage.fromFilePath(croppedImage.path);
        final visionResult = await textRecognizer.processImage(visionImage);
        // Remove leading or trailing white space - artifacts from OCR
        ocrText = visionResult.blocks[0].text.trim();
      } catch (e) {
        print('An error occurred during text recognition $e');
      } finally {
        textRecognizer?.close();
      }
      print('OCR recognized string: $ocrText');
      final link = ocrText.isNotEmpty ? Link.tryParse(ocrText) : null;
      if (link == null) {
        Fluttertoast.showToast(
          msg: 'Der Link enthält Fehler.\nGelesen wurde: $ocrText',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          fontSize: 16.0,
        );
      } else {
        final target = BlocProvider.of<AliasCubit>(context).resolve(link);
        if (target == null) {
          Fluttertoast.showToast(
            msg: 'Kein passender Alias.\nGelesen wurde: $ocrText',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            fontSize: 16.0,
          );
        } else {
          // FIXME Static configuration should have priority so it can act as an overwrite
          assert(discoveredService != null || staticService.ip.isNotEmpty);
          final ip = discoveredService?.ip ?? staticService.ip;
          final port = discoveredService?.port ?? staticService.port;
          print('Sending target (${jsonEncode(target)}) to viewer ($ip:$port).');
          final response = http.post(
            'http://$ip:$port/open',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(target),
          );
          response.catchError((e) {
            Fluttertoast.showToast(
              msg: 'Die Verbindung mit dem Viewer ist gescheitert (${e.toString()}).',
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              fontSize: 16.0,
            );
          }).then((response) {
            final status = response?.statusCode ?? -1;
            if (status >= 400) {
              Fluttertoast.showToast(
                msg: 'Bei der Kommunikation mit dem Viewer ist ein Fehler aufgetreten, Statuscode $status.',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.BOTTOM,
                fontSize: 16.0,
              );
            }
          });
        }
      }
    }
    try {
      File(imageXFile.path).deleteSync();
      croppedImage.deleteSync();
    } catch (exception) {
      print('Couldn\'t delete temporary file: $exception');
    }
  }

  Future<void> _onSettings(BuildContext context) async {
    final staticService = Provider.of<_ExternalViewerStaticConfig>(context, listen: false);
    final ip = await showDialog(
          context: context,
          builder: (context) {
            var ip = staticService.ip;
            return AlertDialog(
              content: Container(
                child: Wrap(
                  children: [
                    TextFormField(
                      initialValue: ip,
                      onChanged: (text) => ip = text,
                      decoration: InputDecoration(
                        labelText: 'IP Adresse Computer',
                        hintText: 'Beispiel: 192.168.0.1',
                        suffix: IconButton(
                          icon: Icon(
                            Icons.check,
                            color: Colors.lightGreen,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(ip),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        '';
    await _preferences.setString('externalViewerIP', ip);
    staticService.ip = ip;
  }
}

class _ExternalViewerStaticConfig extends ValueNotifier<String> {
  final port = '34501';

  set ip(String text) {
    print('Static IP ' + (text.isEmpty ? 'removed.' : 'set to $text'));
    value = text;
  }

  String get ip => value;

  _ExternalViewerStaticConfig(value) : super(value);
}

class TakePictureFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const TakePictureFAB({
    Key key,
    @required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = onPressed != null ? Theme.of(context).accentColor : Colors.grey;
    return FloatingActionButton(
      backgroundColor: Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(
          width: 4,
          color: color,
        ),
      ),
      elevation: 0,
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
      onPressed: onPressed,
    );
  }
}
