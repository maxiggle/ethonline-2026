import 'dart:io';

import 'package:flutter/services.dart';

/// Loads real Roboto and MaterialIcons glyphs from the Flutter SDK's cached
/// material fonts into the test font registry, so screenshot goldens render
/// legible text and icons instead of the default "Ahem" tofu boxes.
///
/// Call once from a `setUpAll` before pumping any screenshot golden.
Future<void> loadRealFontsForGoldens() async {
  final flutterRoot = _resolveFlutterRoot();
  final materialFontsDir = _resolveMaterialFontsDir(flutterRoot);

  final roboto = FontLoader('Roboto')
    ..addFont(_readFont(materialFontsDir, 'Roboto-Regular.ttf'))
    ..addFont(_readFont(materialFontsDir, 'Roboto-Bold.ttf'))
    ..addFont(_readFont(materialFontsDir, 'Roboto-Medium.ttf'));
  await roboto.load();

  final icons = FontLoader('MaterialIcons')..addFont(_readFont(materialFontsDir, 'MaterialIcons-Regular.otf'));
  await icons.load();

  // AppTextStyles.mono() renders EVM addresses and tx hashes with
  // `fontFamily: 'Courier'`. Register a real monospace font under that exact
  // family name so those goldens show legible characters instead of tofu.
  final monoFontsDir = Directory('$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto_Mono');
  if (monoFontsDir.existsSync()) {
    final courier = FontLoader('Courier')
      ..addFont(_readFont(monoFontsDir, 'RobotoMono-Regular.ttf'))
      ..addFont(_readFont(monoFontsDir, 'RobotoMono-Bold.ttf'));
    await courier.load();
  }
}

Directory _resolveMaterialFontsDir(String flutterRoot) {
  final dir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) {
    throw StateError(
      'Could not find the Flutter SDK material fonts cache at ${dir.path}. '
      'Run `flutter precache` or set FLUTTER_ROOT.',
    );
  }
  return dir;
}

String _resolveFlutterRoot() {
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) return envRoot;

  const marker = '/bin/cache/dart-sdk/';
  final resolved = Platform.resolvedExecutable;
  final index = resolved.indexOf(marker);
  if (index == -1) {
    throw StateError('Could not derive the Flutter SDK root from $resolved; set FLUTTER_ROOT.');
  }
  return resolved.substring(0, index);
}

Future<ByteData> _readFont(Directory dir, String fileName) async {
  final bytes = await File('${dir.path}/$fileName').readAsBytes();
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}
