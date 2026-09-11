import 'package:chapter2/app/app.dart';
import 'package:chapter2/core/di/locator.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  runApp(const Chapter2App());
}
