// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/lsp_protocol/protocol_special.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analysis_server/src/lsp/channel/lsp_channel.dart';
import 'package:analysis_server/src/lsp/lsp_analysis_server.dart';
import 'package:analysis_server/src/socket_server.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/instrumentation/instrumentation.dart';
import 'package:analyzer/src/generated/sdk.dart';

/**
 * Instances of the class [SocketServer] implement the common parts of
 * http-based and stdio-based analysis servers.  The primary responsibility of
 * the SocketServer is to manage the lifetime of the AnalysisServer and to
 * encode and decode the JSON messages exchanged with the client.
 */
class LspSocketServer {
  final AnalysisServerOptions analysisServerOptions;
  /**
   * The analysis server that was created when a client established a
   * connection, or `null` if no such connection has yet been established.
   */
  LspAnalysisServer analysisServer;

  /**
   * The function used to create a new SDK using the default SDK.
   */
  final DartSdkManager sdkManager;

  final InstrumentationService instrumentationService;

  LspSocketServer(
    this.analysisServerOptions,
    this.sdkManager,
    this.instrumentationService,
  );

  /**
   * Create an analysis server which will communicate with the client using the
   * given serverChannel.
   */
  void createAnalysisServer(LspServerCommunicationChannel serverChannel) {
    if (analysisServer != null) {
      ResponseError error = new ResponseError<void>(
          ServerErrorCodes.ServerAlreadyStarted,
          'Server already started',
          null);
      serverChannel.sendNotification(new NotificationMessage(
        Method.window_showMessage,
        new ShowMessageParams(MessageType.Error, error.message),
        jsonRpcVersion,
      ));
      serverChannel.listen((Message message) {
        if (message is RequestMessage) {
          serverChannel.sendResponse(
              new ResponseMessage(message.id, null, error, jsonRpcVersion));
        }
      });
      return;
    }

    PhysicalResourceProvider resourceProvider;
    if (analysisServerOptions.fileReadMode == 'as-is') {
      resourceProvider = new PhysicalResourceProvider(null,
          stateLocation: analysisServerOptions.cacheFolder);
    } else if (analysisServerOptions.fileReadMode == 'normalize-eol-always') {
      resourceProvider = new PhysicalResourceProvider(
          PhysicalResourceProvider.NORMALIZE_EOL_ALWAYS,
          stateLocation: analysisServerOptions.cacheFolder);
    } else {
      throw new Exception(
          'File read mode was set to the unknown mode: $analysisServerOptions.fileReadMode');
    }

    analysisServer = new LspAnalysisServer(serverChannel, resourceProvider,
        analysisServerOptions, sdkManager, instrumentationService);
  }
}
