// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/file_state.dart';
import 'package:analyzer/src/dart/analysis/performance_logger.dart';
import 'package:analyzer/src/file_system/file_system.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/engine.dart' as engine;
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/testing/element_search.dart';
import 'package:analyzer/src/source/package_map_resolver.dart';
import 'package:analyzer/src/test_utilities/mock_sdk.dart';
import 'package:analyzer/src/test_utilities/resource_provider_mixin.dart';

/**
 * Finds an [Element] with the given [name].
 */
Element findChildElement(Element root, String name, [ElementKind kind]) {
  Element result = null;
  root.accept(new _ElementVisitorFunctionWrapper((Element element) {
    if (element.name != name) {
      return;
    }
    if (kind != null && element.kind != kind) {
      return;
    }
    result = element;
  }));
  return result;
}

/**
 * A function to be called for every [Element].
 */
typedef void _ElementVisitorFunction(Element element);

class AbstractContextTest with ResourceProviderMixin {
  DartSdk sdk;
  Map<String, List<Folder>> packageMap;
  UriResolver resourceResolver;

  StringBuffer _logBuffer = new StringBuffer();
  FileContentOverlay _fileContentOverlay = new FileContentOverlay();
  AnalysisDriver _driver;

  AnalysisDriver get driver => _driver;

  /**
   * Return the analysis session associated with the driver.
   */
  AnalysisSession get session => driver.currentSession;

  void addMetaPackage() {
    addPackageFile('meta', 'meta.dart', r'''
library meta;

const Required required = const Required();

class Required {
  final String reason;
  const Required([this.reason]);
}
''');
  }

  File addPackageFile(String packageName, String pathInLib, String content) {
    var packageLibPath = '/.pub-cache/$packageName/lib';
    packageMap[packageName] = [newFolder(packageLibPath)];
    return newFile('$packageLibPath/$pathInLib', content: content);
  }

  Source addSource(String path, String content, [Uri uri]) {
    path = convertPath(path);
    driver.addFile(path);
    driver.changeFile(path);
    _fileContentOverlay[path] = content;
    return getFile(path).createSource();
  }

  Element findElementInUnit(CompilationUnit unit, String name,
      [ElementKind kind]) {
    return findElementsByName(unit, name)
        .where((e) => kind == null || e.kind == kind)
        .single;
  }

  Future<CompilationUnit> resolveLibraryUnit(Source source) async {
    return (await driver.getResult(source.fullName))?.unit;
  }

  void setUp() {
    sdk = new MockSdk(resourceProvider: resourceProvider);
    resourceResolver = new ResourceUriResolver(resourceProvider);
    packageMap = new Map<String, List<Folder>>();
    PackageMapUriResolver packageResolver =
        new PackageMapUriResolver(resourceProvider, packageMap);
    SourceFactory sourceFactory = new SourceFactory(
        [new DartUriResolver(sdk), packageResolver, resourceResolver]);
    PerformanceLog log = new PerformanceLog(_logBuffer);
    AnalysisDriverScheduler scheduler = new AnalysisDriverScheduler(log);
    AnalysisOptionsImpl options = new AnalysisOptionsImpl();
    _driver = new AnalysisDriver(
        scheduler,
        log,
        resourceProvider,
        new MemoryByteStore(),
        _fileContentOverlay,
        null,
        sourceFactory,
        options);
    scheduler.start();
    AnalysisEngine.instance.logger = PrintLogger.instance;
  }

  void tearDown() {
    AnalysisEngine.instance.clearCaches();
    AnalysisEngine.instance.logger = null;
  }
}

/**
 * Instances of the class [PrintLogger] print all of the errors.
 */
class PrintLogger implements Logger {
  static final Logger instance = new PrintLogger();

  @override
  void logError(String message, [CaughtException exception]) {
    print(message);
    if (exception != null) {
      print(exception);
    }
  }

  @override
  void logInformation(String message, [CaughtException exception]) {
    print(message);
    if (exception != null) {
      print(exception);
    }
  }
}

/**
 * Wraps the given [_ElementVisitorFunction] into an instance of
 * [engine.GeneralizingElementVisitor].
 */
class _ElementVisitorFunctionWrapper extends GeneralizingElementVisitor {
  final _ElementVisitorFunction function;

  _ElementVisitorFunctionWrapper(this.function);

  @override
  visitElement(Element element) {
    function(element);
    super.visitElement(element);
  }
}
