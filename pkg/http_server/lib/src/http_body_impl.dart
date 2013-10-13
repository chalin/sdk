// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of http_server;

class _HttpBodyHandlerTransformer
    implements StreamTransformer<HttpRequest, HttpRequestBody> {
  final Encoding _defaultEncoding;

  const _HttpBodyHandlerTransformer(this._defaultEncoding);

  Stream<HttpRequestBody> bind(Stream<HttpRequest> stream) {
    return new Stream<HttpRequestBody>.eventTransformed(
        stream,
        (EventSink<HttpRequestBody> sink) =>
            new _HttpBodyHandlerTransformerSink(_defaultEncoding, sink));
  }
}

class _HttpBodyHandlerTransformerSink implements EventSink<HttpRequest> {
  final Encoding _defaultEncoding;
  final EventSink<HttpRequestBody> _outSink;

  _HttpBodyHandlerTransformerSink(this._defaultEncoding, this._outSink);

  void add(HttpRequest request) {
    _HttpBodyHandler.processRequest(request, _defaultEncoding)
        .then(_outSink.add, onError: _outSink.addError);
  }
  void addError(Object error, [StackTrace stackTrace]) {
    _outSink.addError(error, stackTrace);
  }
  void close() => _outSink.close();
}

class _HttpBodyHandler {
  static Future<HttpRequestBody> processRequest(
      HttpRequest request,
      Encoding defaultEncoding) {
    return process(request, request.headers, defaultEncoding)
        .then((body) => new _HttpRequestBody(request, body),
              onError: (error) {
                // Try to send BAD_REQUEST response.
                request.response.statusCode = HttpStatus.BAD_REQUEST;
                request.response.close();
                request.response.done.catchError((_) {});
                throw error;
              });
  }

  static Future<HttpClientResponseBody> processResponse(
      HttpClientResponse response,
      Encoding defaultEncoding) {
    return process(response, response.headers, defaultEncoding)
        .then((body) => new _HttpClientResponseBody(response, body));
  }

  static Future<HttpBody> process(Stream<List<int>> stream,
                                  HttpHeaders headers,
                                  Encoding defaultEncoding) {
    ContentType contentType = headers.contentType;

    Future<HttpBody> asBinary() {
      return stream
          .fold(new BytesBuilder(), (builder, data) => builder..add(data))
          .then((builder) => new _HttpBody(contentType,
                                           "binary",
                                           builder.takeBytes()));
    }

    Future<HttpBody> asText(Encoding defaultEncoding) {
      var encoding;
      var charset = contentType.charset;
      if (charset != null) encoding = Encoding.getByName(charset);
      if (encoding == null) encoding = defaultEncoding;
      return stream
          .transform(encoding.decoder)
          .fold(new StringBuffer(), (buffer, data) => buffer..write(data))
          .then((buffer) => new _HttpBody(contentType,
                                          "text",
                                          buffer.toString()));
    }

    Future<HttpBody> asFormData() {
      return stream
          .transform(new MimeMultipartTransformer(
                contentType.parameters['boundary']))
          .map((part) => HttpMultipartFormData.parse(
                part, defaultEncoding: defaultEncoding))
          .map((multipart) {
            var future;
            if (multipart.isText) {
              future = multipart
                  .fold(new StringBuffer(), (b, s) => b..write(s))
                  .then((b) => b.toString());
            } else {
              future = multipart
                  .fold(new BytesBuilder(), (b, d) => b..add(d))
                  .then((b) => b.takeBytes());
            }
            return future.then((data) {
              var filename =
                  multipart.contentDisposition.parameters['filename'];
              if (filename != null) {
                data = new _HttpBodyFileUpload(multipart.contentType,
                                               filename,
                                               data);
              }
              return [multipart.contentDisposition.parameters['name'], data];
            });
          })
          .fold([], (l, f) => l..add(f))
          .then(Future.wait)
          .then((parts) {
            Map<String, dynamic> map = new Map<String, dynamic>();
            for (var part in parts) {
              map[part[0]] = part[1];  // Override existing entries.
            }
            return new _HttpBody(contentType, 'form', map);
          });
    }

    if (contentType == null) {
      return asBinary();
    }

    switch (contentType.primaryType) {
      case "text":
        return asText(defaultEncoding);

      case "application":
        switch (contentType.subType) {
          case "json":
            return asText(UTF8)
                .then((body) => new _HttpBody(contentType,
                                              "json",
                                              JSON.decode(body.body)));

          case "x-www-form-urlencoded":
            return asText(ASCII)
                .then((body) {
                  var map = Uri.splitQueryString(body.body,
                      encoding: defaultEncoding);
                  var result = {};
                  for (var key in map.keys) {
                    result[key] = map[key];
                  }
                  return new _HttpBody(contentType, "form", result);
                });

          default:
            break;
        }
        break;

      case "multipart":
        switch (contentType.subType) {
          case "form-data":
            return asFormData();

          default:
            break;
        }
        break;

      default:
        break;
    }

    return asBinary();
  }
}

class _HttpBodyFileUpload implements HttpBodyFileUpload {
  final ContentType contentType;
  final String filename;
  final dynamic content;
  _HttpBodyFileUpload(this.contentType, this.filename, this.content);
}

class _HttpBody implements HttpBody {
  final ContentType contentType;
  final String type;
  final dynamic body;

  _HttpBody(ContentType this.contentType,
            String this.type,
            dynamic this.body);
}

class _HttpRequestBody extends _HttpBody implements HttpRequestBody {
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final HttpResponse response;

  _HttpRequestBody(HttpRequest request, HttpBody body)
      : super(body.contentType, body.type, body.body),
        method = request.method,
        uri = request.uri,
        headers = request.headers,
        response = request.response;
}

class _HttpClientResponseBody
    extends _HttpBody implements HttpClientResponseBody {
  final HttpClientResponse response;

  _HttpClientResponseBody(HttpClientResponse response, HttpBody body)
      : super(body.contentType, body.type, body.body),
        this.response = response;

  int get statusCode => response.statusCode;

  String get reasonPhrase => response.reasonPhrase;

  HttpHeaders get headers => response.headers;
}
