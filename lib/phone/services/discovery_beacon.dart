import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/protocol.dart';

/// Announces the phone on the LAN so the desktop can list it without typing an IP.
/// Broadcasts a small JSON beacon every 2 s and answers desktop probes directly.
class DiscoveryBeacon {
  DiscoveryBeacon(this.payload);

  final Map<String, dynamic> Function() payload;
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start() async {
    if (_socket != null) return;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        FcamPorts.discoveryPort,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket.receive();
        if (d == null) return;
        if (utf8.decode(d.data, allowMalformed: true) == FcamDiscovery.probe) {
          try {
            socket.send(_message(), d.address, d.port);
          } on SocketException {
            // Network blocked (e.g. phone asleep); the next probe gets an answer.
          }
        }
      });
      _socket = socket;
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _broadcast());
      _broadcast();
    } on SocketException {
      // Discovery is a convenience; manual IP entry still works.
    }
  }

  void _broadcast() {
    try {
      _socket?.send(
          _message(), InternetAddress('255.255.255.255'), FcamPorts.discoveryPort);
    } on SocketException {
      // Network down / no Wi-Fi; try again on the next tick.
    }
  }

  List<int> _message() => utf8.encode(jsonEncode({
        'app': FcamDiscovery.app,
        'v': FcamDiscovery.version,
        ...payload(),
      }));

  void stop() {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}
