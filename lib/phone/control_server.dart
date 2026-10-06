import 'dart:convert';
import 'dart:io';

import '../shared/protocol.dart';

/// JSON control API served by the phone on [FcamPorts.controlPort].
///
///   GET  /                 status page with a live MJPEG preview (MJPEG codec)
///   GET  /api/info         device name, ports, streaming flag
///   GET  /api/status       live stats (fps, bitrate, clients)
///   GET  /api/settings     current settings + features
///   POST /api/settings     partial update (JSON body), returns settings + features
///   POST /api/focus        {"x":0..1,"y":0..1} tap-to-focus in sensor coordinates
///   GET  /video            redirect to the MJPEG stream
class ControlServer {
  ControlServer({
    required this.info,
    required this.status,
    required this.state,
    required this.update,
    required this.focus,
  });

  final Map<String, dynamic> Function() info;
  final Future<Map<String, dynamic>> Function() status;
  final Map<String, dynamic> Function() state;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) update;
  final Future<void> Function(double x, double y) focus;

  HttpServer? _server;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      FcamPorts.controlPort,
      shared: true,
    );
    _server!.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', 'Content-Type')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Cache-Control', 'no-store');
    try {
      final path = req.uri.path;
      switch ((req.method, path)) {
        case ('OPTIONS', _):
          res.statusCode = HttpStatus.noContent;
        case ('GET', '/api/info'):
          _json(res, info());
        case ('GET', '/api/status'):
          _json(res, await status());
        case ('GET', '/api/settings'):
          _json(res, state());
        case ('POST', '/api/settings'):
          final body = await utf8.decoder.bind(req).join();
          final changes = jsonDecode(body) as Map<String, dynamic>;
          _json(res, await update(changes));
        case ('POST', '/api/focus'):
          final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
          await focus((body['x'] as num).toDouble(), (body['y'] as num).toDouble());
          _json(res, {'ok': true});
        case ('GET', '/video'):
          final host = req.requestedUri.host;
          res.redirect(Uri.parse('http://$host:${FcamPorts.mjpegPort}/video'));
          return;
        case ('GET', '/'):
          res.headers.contentType = ContentType.html;
          res.write(_page(req.requestedUri.host));
        default:
          res.statusCode = HttpStatus.notFound;
          _json(res, {'error': 'not found'});
      }
    } catch (e) {
      res.statusCode = HttpStatus.badRequest;
      _json(res, {'error': e.toString()});
    }
    await res.close();
  }

  void _json(HttpResponse res, Object data) {
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(data));
  }

  String _page(String host) {
    final i = info();
    return '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mini Webcam</title>
<style>body{font-family:system-ui;background:#0e1116;color:#e6edf3;margin:0;padding:24px}
img{max-width:100%;border-radius:12px;background:#000}code{background:#161b22;padding:2px 6px;border-radius:6px}
a{color:#58a6ff}</style></head><body>
<h2>Mini Webcam &mdash; ${const HtmlEscape().convert('${i['device']}')}</h2>
<p>Desktop client: connect to <code>$host</code>. FCAM stream port <code>${FcamPorts.streamPort}</code>.</p>
<p>MJPEG (when the phone codec is set to MJPEG): <a href="http://$host:${FcamPorts.mjpegPort}/video">http://$host:${FcamPorts.mjpegPort}/video</a>
 &middot; snapshot: <a href="http://$host:${FcamPorts.mjpegPort}/snapshot.jpg">/snapshot.jpg</a></p>
<img src="http://$host:${FcamPorts.mjpegPort}/video" alt="Switch the phone codec to MJPEG to preview here">
</body></html>''';
  }
}
