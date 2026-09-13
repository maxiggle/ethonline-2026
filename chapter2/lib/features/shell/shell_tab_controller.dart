import 'package:flutter/foundation.dart';

/// Lets a screen pushed on top of [MainShellScreen] (e.g. the purchase
/// detail screen's "Open Approvals" link) select a shell tab before popping
/// back to it. The shell's selected tab is private [State], so this is the
/// only way to reach it from outside without threading a callback through
/// every intermediate route.
class ShellTabController extends ValueNotifier<int> {
  ShellTabController() : super(0);
}
