import 'dart:io';

/// INK: CORS Proxy Utility for Web Development
///
/// This utility is essential for bypassing Cross-Origin Resource Sharing (CORS)
/// restrictions when running the application on a Web browser.
///
/// 🎯 Why: The EDA API does not include CORS headers, which causes browsers
/// to block direct requests from `http://localhost`. This proxy acts as a
/// bridge, adding the necessary headers.
///
/// 🛡️ SENTINEL: Security Note: This proxy is intended for LOCAL DEVELOPMENT ONLY.
/// It binds to `loopbackIPv4` (127.0.0.1) and should never be exposed to the
/// public internet or used in production environments.
void main() async {
  var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  stdout.writeln('CORS Proxy Server running on http://${server.address.host}:${server.port}');

  var client = HttpClient();
  // Sentinel: Enforce a connection timeout to prevent the proxy from hanging indefinitely
  // on unresponsive upstream requests, mitigating a potential local DoS risk.
  client.connectionTimeout = const Duration(seconds: 15);

  await for (HttpRequest request in server) {
    // Sentinel: Implement Origin validation to prevent unauthorized cross-origin access.
    // This proxy is for local development; only allow localhost/127.0.0.1.
    final origin = request.headers.value('origin');
    bool isAuthorized = true;
    if (origin != null) {
      try {
        final uri = Uri.parse(origin);
        isAuthorized = uri.host == 'localhost' || uri.host == '127.0.0.1';
      } catch (_) {
        isAuthorized = false;
      }
    }

    if (!isAuthorized) {
      stderr.writeln('Blocked request from unauthorized origin: $origin');
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      continue;
    }

    // Add CORS headers, mirroring the origin if valid or defaulting to localhost for non-browser requests
    request.response.headers
        .set('Access-Control-Allow-Origin', origin ?? 'http://localhost');
    request.response.headers.set(
        'Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers
        .set('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept');
    request.response.headers.set('X-Content-Type-Options', 'nosniff');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    // Sentinel: Restrict proxying to the expected API path to minimize attack surface.
    // Use normalizePath and check pathSegments to prevent path traversal bypasses.
    final normalizedUri = request.uri.normalizePath();
    final isAuthorizedPath = normalizedUri.path.startsWith('/api/leitura') &&
        !normalizedUri.pathSegments.any((s) => s == '..' || s == '.');

    if (!isAuthorizedPath) {
      stderr.writeln(
          'Blocked request to unauthorized path: ${request.uri.path}');
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    // Sentinel: Enforce a 1MB request body limit to mitigate local DoS risks.
    const int maxPayloadSize = 1024 * 1024;
    if (request.contentLength > maxPayloadSize) {
      stderr.writeln('Blocked request with oversized payload: ${request.contentLength} bytes');
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      await request.response.close();
      continue;
    }

    try {
      // Sentinel: Use Uri.https for safer URI construction, mitigating injection risks.
      final url = Uri.https(
        'smile.eda.pt',
        normalizedUri.path,
        normalizedUri.queryParametersAll,
      );

      var proxyRequest = await client.openUrl(request.method, url);

      // Forward headers, omitting host-specific ones
      request.headers.forEach((name, values) {
        if (name != 'host' && name != 'origin' && name != 'referer') {
          for (var value in values) {
            proxyRequest.headers.add(name, value);
          }
        }
      });

      // Sentinel: Use a transformer to count bytes for chunked transfers where
      // contentLength might be unknown (-1) or to catch malicious streams.
      int bytesRead = 0;
      final limitedStream = request.map((data) {
        bytesRead += data.length;
        if (bytesRead > maxPayloadSize) {
          throw HttpException('Request body exceeds 1MB limit');
        }
        return data;
      });

      // Forward request body
      await proxyRequest.addStream(limitedStream);
      var proxyResponse = await proxyRequest.close();

      // Forward response headers
      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        // Avoid sending duplicate or restrictive CORS headers from the upstream
        if (name.toLowerCase() != 'access-control-allow-origin' &&
            name.toLowerCase() != 'content-security-policy') {
          for (var value in values) {
            request.response.headers.add(name, value);
          }
        }
      });

      // Forward response body
      await request.response.addStream(proxyResponse);
      await request.response.close();
    } catch (e) {
      stderr.writeln('Error proxying request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      // Sentinel: Mask internal exception details to prevent information leakage.
      request.response.write('Internal Server Error');
      await request.response.close();
    }
  }
}
