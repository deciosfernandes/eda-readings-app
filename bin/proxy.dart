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
    // SENTINEL: Require an explicit browser Origin header; requests with no
    // Origin (curl, native clients) are not allowed through — this is a
    // browser-only CORS proxy, not a general-purpose proxy.
    final origin = request.headers.value('origin');
    bool isAuthorized = false;
    if (origin != null) {
      try {
        final uri = Uri.parse(origin);
        isAuthorized = uri.host == 'localhost' || uri.host == '127.0.0.1';
      } catch (_) {
        isAuthorized = false;
      }
    }

    if (!isAuthorized) {
      stderr.writeln('Blocked request from unauthorized origin: ${origin ?? "(no origin)"}');
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      continue;
    }

    // Add CORS headers, echoing only the validated origin (never raw input).
    request.response.headers
        .set('Access-Control-Allow-Origin', origin!);
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

      // Sentinel: Validate the resolved path to prevent path traversal via '..' segments.
      if (!url.path.startsWith('/api/leitura')) {
        stderr.writeln(
            'Blocked request to unauthorized resolved path: ${url.path}');
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }

      var proxyRequest = await client.openUrl(request.method, url);

      // SENTINEL: Forward only safe headers; strip host-specific, origin, referer,
      // and credential-bearing headers (Authorization, Cookie) so browser-session
      // credentials are never forwarded to the upstream EDA server.
      const stripHeaders = {
        'host', 'origin', 'referer', 'authorization', 'cookie',
      };
      request.headers.forEach((name, values) {
        if (!stripHeaders.contains(name.toLowerCase())) {
          for (var value in values) {
            proxyRequest.headers.add(name, value);
          }
        }
      });

      // Forward request body
      await proxyRequest.addStream(request);
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

      // Forward response body; guard against client disconnect mid-stream.
      try {
        await request.response.addStream(proxyResponse);
        await request.response.close();
      } catch (_) {
        // Client disconnected mid-response; response headers are already sent
        // so we cannot set an error status. Just close silently.
        try {
          await request.response.close();
        } catch (_) {
          // Already closed; ignore.
        }
      }
    } catch (e) {
      stderr.writeln('Error proxying request: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        // Sentinel: Use a generic error message to avoid leaking internal details.
        request.response.write('Internal Server Error');
        await request.response.close();
      } catch (_) {
        // Response may already be partially committed; ignore.
      }
    }
  }
}
