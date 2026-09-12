import 'dart:async';
import 'dart:convert';
import 'package:chapter2/core/config/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Chapter2SocketService {
  Chapter2SocketService({String? gatewayUrl})
      : _gatewayUrl = gatewayUrl ?? AppConfig.websocketUrl;

  final String _gatewayUrl;
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_gatewayUrl));
      _channel?.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            _eventStreamController.add(parsed);
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _eventStreamController.close();
  }
}
