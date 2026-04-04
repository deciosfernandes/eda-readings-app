import 'dart:io';

void main() async {
  var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  stdout.writeln('CORS Proxy Server running on http://${server.address.host}:${server.port}');

  var client = HttpClient();

  await for (HttpRequest request in server) {
    // Add CORS headers to allow browser requests
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    try {
      // Forward request to the actual EDA API
      var url = Uri.parse('https://smile.eda.pt${request.uri.path}');
      if (request.uri.hasQuery) {
        url = Uri.parse('$url?${request.uri.query}');
      }

      var proxyRequest = await client.openUrl(request.method, url);

      // Forward headers, omitting host-specific ones
      request.headers.forEach((name, values) {
        if (name != 'host' && name != 'origin' && name != 'referer') {
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
