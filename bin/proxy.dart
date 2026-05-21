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
    // Sentinel: Enforce a 1MB request body limit to prevent local DoS.
    const int maxRequestBodySize = 1024 * 1024;
    if (request.contentLength > maxRequestBodySize) {
      stderr.writeln('Blocked request: Content-Length exceeds limit');
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      await request.response.close();
      continue;
    }

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
    if (!request.uri.path.startsWith('/api/leitura')) {
      stderr
          .writeln('Blocked request to unauthorized path: ${request.uri.path}');
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    try {
      // Sentinel: Use Uri.https for safer URI construction, mitigating injection risks.
      final url = Uri.https(
        'smile.eda.pt',
        request.uri.path,
        request.uri.queryParametersAll,
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

      // Sentinel: Forward request body with size-limiting transformer to handle chunked encoding.
      int bytesReceived = 0;
      final sizeLimiter = request.map((List<int> chunk) {
        bytesReceived += chunk.length;
        if (bytesReceived > maxRequestBodySize) {
          throw HttpException('Payload Too Large');
        }
        return chunk;
      });

      try {
        await proxyRequest.addStream(sizeLimiter);
      } catch (e) {
        if (e is HttpException && e.message == 'Payload Too Large') {
          stderr.writeln('Blocked request: Stream exceeds body limit');
          request.response.statusCode = HttpStatus.requestEntityTooLarge;
          await request.response.close();
          continue;
        }
        rethrow;
      }

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
      request.response.write('Proxy error: $e');
      await request.response.close();
    }
  }
}
