import 'dart:io';

/// One IPv4 address of this machine.
class LanAddress {
  const LanAddress(this.interfaceName, this.address, this.isVpn);
  final String interfaceName;
  final String address;
  final bool isVpn;

  /// /24 broadcast guess; Dart exposes no netmask.
  InternetAddress get broadcast {
    final p = address.split('.');
    return InternetAddress('${p[0]}.${p[1]}.${p[2]}.255');
  }
}

final _vpnName = RegExp(r'tun|tap|ppp|wg|ipsec|vpn|wintun|wireguard|utun|zerotier|tailscale|hamachi|proton|nord',
    caseSensitive: false);

/// Non-loopback IPv4 addresses, real LAN interfaces first and VPN tunnels last.
Future<List<LanAddress>> lanAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final all = [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal) LanAddress(i.name, a.address, _vpnName.hasMatch(i.name)),
    ];
    return [...all.where((a) => !a.isVpn), ...all.where((a) => a.isVpn)];
  } catch (_) {
    return const [];
  }
}

/// Sends [data] as a broadcast from each LAN interface address, so the packet
/// leaves through the real network and not through a VPN tunnel.
Future<void> broadcastOnAllInterfaces(List<int> data, int port) async {
  for (final a in await lanAddresses()) {
    if (a.isVpn) continue;
    RawDatagramSocket? s;
    try {
      s = await RawDatagramSocket.bind(InternetAddress(a.address), 0);
      s.broadcastEnabled = true;
      s.send(data, a.broadcast, port);
      s.send(data, InternetAddress('255.255.255.255'), port);
    } on SocketException {
      // Interface went away; next tick retries.
    } finally {
      s?.close();
    }
  }
}
