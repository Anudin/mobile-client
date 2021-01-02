import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';

void showDevToast(String message) {
  if (!kReleaseMode) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      fontSize: 16.0,
    );
  }
}
