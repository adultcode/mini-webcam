import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/lan.dart';
import '../../core/protocol.dart';

class DiscoveredPhone {
  DiscoveredPhone(this.address, this.name, this.streaming, this.lastSeen);
  final String address;
  final String name;
  final bool streaming;
  final DateTime lastSeen;
}

/// Listens for phone beacons on the LAN and periodically probes for phones.
class DiscoveryListener {
  final _phones = <String, DiscoveredPhone>{};
  final _controller = StreamController<List<DiscoveredPhone>>.broadcast();
  RawDatagramSocket? _socket;
  Timer? _probeTimer;

  Stream<List<DiscoveredPhone>> get phones => _controller.stream;
  List<DiscoveredPhone> get current => _phones.values.toList();

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
        if (d != null) _onDatagram(d);
      });
      _socket = socket;
      _probeTimer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
      _tick();
    } on SocketException {
      // Port busy (another instance) — manual IP entry still works.
    }
  }

  void _onDatagram(Datagram d) {
    final text = utf8.decode(d.data, allowMalformed: true);
    if (!text.startsWith('{')) return;
    try {
      final m = jsonDecode(text) as Map<String, dynamic>;
      if (m['app'] != FcamDiscovery.app) return;
      final ip = d.address.address;
      _phones[ip] = DiscoveredPhone(
        ip,
        m['name'] as String? ?? ip,
        m['streaming'] as bool? ?? false,
        DateTime.now(),
      );
      _emit();
    } catch (_) {}
  }

  void _tick() {
    // Per-interface so a VPN default route cannot swallow the probe.
    if (_socket != null) {
      broadcastOnAllInterfaces(utf8.encode(FcamDiscovery.probe), FcamPorts.discoveryPort);
    }
    final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
    final before = _phones.length;
    _phones.removeWhere((_, p) => p.lastSeen.isBefore(cutoff));
    if (_phones.length != before) _emit();
  }

  void _emit() => _controller.add(current);

  void stop() {
    _probeTimer?.cancel();
    _socket?.close();
    _socket = null;
  }
}
