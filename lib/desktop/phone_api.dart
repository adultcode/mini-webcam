import 'dart:convert';
import 'dart:io';

import '../shared/models.dart';

/// HTTP client for the phone's control API (see lib/phone/control_server.dart).
class PhoneApi {
  PhoneApi(this.host, this.port);

  final String host;
  final int port;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 3);

  Uri _uri(String path) => Uri(scheme: 'http', host: host, port: port, path: path);

  Future<PhoneState> state() async => PhoneState.fromJson(await _get('/api/settings'));

  Future<PhoneState> update(Map<String, dynamic> changes) async =>
      PhoneState.fromJson(await _post('/api/settings', changes));

  Future<Map<String, dynamic>> _get(String path) async {
    final req = await _client.getUrl(_uri(path));
    return _read(await req.close());
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final req = await _client.postUrl(_uri(path));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    return _read(await req.close());
  }

  Future<Map<String, dynamic>> _read(HttpClientResponse res) async {
    final text = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 5));
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw HttpException(json['error']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    return json;
  }

  void close() => _client.close(force: true);
}

class PhoneState {
  const PhoneState(this.settings, this.features, this.streaming);
  final CameraSettings settings;
  final CameraFeatures features;
  final bool streaming;

  factory PhoneState.fromJson(Map<String, dynamic> j) => PhoneState(
        CameraSettings.fromMap(j['settings'] as Map),
        CameraFeatures.fromMap(j['features'] as Map),
        j['streaming'] as bool? ?? false,
      );
}
