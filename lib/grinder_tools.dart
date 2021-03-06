// Copyright 2013 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

/// Commonly used tools for build scripts.
library grinder.tools;

import 'dart:async';
import 'dart:io';

import 'grinder.dart';
import 'src/run.dart' as run_lib;
import 'src/run_utils.dart';
import 'src/utils.dart';

export 'src/run.dart';

final Directory binDir = new Directory('bin');
final Directory buildDir = new Directory('build');
final Directory libDir = new Directory('lib');
final Directory webDir = new Directory('web');

/// Run a dart [script] using [run_lib.run]. Returns the stdout.
///
/// Prefer `Dart.run` instead.
String runDartScript(String script,
    {List<String> arguments: const [],
    bool quiet: false,
    String packageRoot,
    RunOptions runOptions,
    String workingDirectory}) {
  runOptions = mergeWorkingDirectory(workingDirectory, runOptions);
  return Dart.run(script,
      arguments: arguments,
      quiet: quiet,
      packageRoot: packageRoot,
      runOptions: runOptions);
}

/// A default implementation of a `clean` task. This task deletes all generated
/// artifacts in the `build/`.
void defaultClean([GrinderContext context]) => delete(buildDir);

/// A wrapper around the `test` package. This class is used to run your unit
/// tests.
class TestRunner {
  final PubApp _test = new PubApp.local('test');

  TestRunner();

  /// Run the tests in the current package. See the
  /// [test package](https://pub.dartlang.org/packages/test).
  ///
  /// [files] - the files or directories to test. This can a path ([String]),
  /// [File], or list of paths or files.
  ///
  /// [name] is substring of the name of the test to run. Regular expression
  /// syntax is supported. [plainName] is a plain-text substring of the name of
  /// the test to run. [platformSelector] is the platform(s) on which to run the
  /// tests. This parameter can be a String or a List.
  /// [Available values](https://github.com/dart-lang/test#platform-selector-syntax)
  /// are `vm` (default), `dartium`, `content-shell`, `chrome`, `phantomjs`,
  /// `firefox`, `safari`. [concurrency] controls the number of concurrent test
  /// suites run (defaults to 4). [pubServe] is the port of a pub serve instance
  /// serving `test/`.
  void test(
      {dynamic files,
      String name,
      String plainName,
      dynamic platformSelector,
      int concurrency,
      int pubServe,
      RunOptions runOptions}) {
    _test.run(
        _buildArgs(
            files: files,
            name: name,
            plainName: plainName,
            selector: platformSelector,
            concurrency: concurrency,
            pubServe: pubServe),
        script: 'test',
        runOptions: runOptions);
  }

  /// Run the tests in the current package. See the
  /// [test package](https://pub.dartlang.org/packages/test).
  ///
  /// [files] - the files or directories to test. This can a path ([String]),
  /// [File], or list of paths or files.
  ///
  /// [name] is substring of the name of the test to run. Regular expression
  /// syntax is supported. [plainName] is a plain-text substring of the name of
  /// the test to run. [platformSelector] is the platform(s) on which to run the
  /// tests. This parameter can be a String or a List.
  /// [Available values](https://github.com/dart-lang/test#platform-selector-syntax)
  /// are `vm` (default), `dartium`, `content-shell`, `chrome`, `phantomjs`,
  /// `firefox`, `safari`. [concurrency] controls the number of concurrent test
  /// suites run (defaults to 4). [pubServe] is the port of a pub serve instance
  /// serving `test/`.
  Future testAsync(
      {dynamic files,
      String name,
      String plainName,
      dynamic platformSelector,
      int concurrency,
      int pubServe,
      RunOptions runOptions}) {
    return _test.runAsync(
        _buildArgs(
            files: files,
            name: name,
            plainName: plainName,
            selector: platformSelector,
            concurrency: concurrency,
            pubServe: pubServe),
        script: 'test',
        runOptions: runOptions);
  }

  List<String> _buildArgs(
      {dynamic files,
      String name,
      String plainName,
      dynamic selector,
      int concurrency,
      int pubServe}) {
    List<String> args = ['--reporter=expanded'];
    if (name != null) args.add('--name=${name}');
    if (plainName != null) args.add('--plain-name=${plainName}');
    if (selector != null) {
      if (selector is List) selector = selector.join(',');
      args.add('--platform=${selector}');
    }
    if (concurrency != null) args.add('--concurrency=${concurrency}');
    if (pubServe != null) args.add('--pub-serve=${pubServe}');
    if (files != null) args.addAll(coerceToPathList(files));
    // TODO: Pass in --color based on a global property: #243.
    return args;
  }
}

/// An interface into the DDC (`dev_compiler`).
class DevCompiler {
  final PubApp _ddc = new PubApp.global('dev_compiler');

  DevCompiler();

  void analyze(dynamic files) {
    _ddc.run(coerceToPathList(files));
  }

  Future analyzeAsync(dynamic files) {
    return _ddc.runAsync(coerceToPathList(files));
  }

  void compile(dynamic files, Directory outDir) {
    List args = coerceToPathList(files);
    args.add('-o${outDir.path}');
    _ddc.run(args);
  }

  Future compileAsync(dynamic files, Directory outDir) {
    List args = coerceToPathList(files);
    args.add('-o${outDir.path}');
    return _ddc.runAsync(args);
  }
}
