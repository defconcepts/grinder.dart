// Copyright 2013 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

library grinder_test;

import 'dart:async';

import 'package:grinder/grinder.dart' hide fail;
import 'package:test/test.dart';
import 'package:unscripted/unscripted.dart';

main() {
  group('grinder', () {
    test('tasks must have a task function or dependencies', () {
      expect(() {
        new GrinderTask('foo', taskFunction: null, depends: []);
      }, throwsA(new isInstanceOf<GrinderException>()));
    });

    test('badTaskName', () {
      // test that a bad task name throws
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('foo', taskFunction: () {}));
      expect(() => grinder.start(['bar'], dontRun: true),
          throwsA(new isInstanceOf<GrinderException>()));
    });

    test('duplicate task name', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('foo', taskFunction: () {}));
      grinder.addTask(new GrinderTask('foo', taskFunction: () {}));
      expect(() => grinder.start(['foo'], dontRun: true),
          throwsA(new isInstanceOf<GrinderException>()));
    });

    test('badDependencyName', () {
      // test that a bad task name throws
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('foo', depends: ['baz']));
      expect(() => grinder.start(['foo'], dontRun: true),
          throwsA(new isInstanceOf<GrinderException>()));
    });

    test('default task is run by default', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('foo', taskFunction: () {}));
      grinder.defaultTask = new GrinderTask('bar', depends: ['foo']);
      grinder.start([], dontRun: true);
      expect(
          grinder.getBuildOrder(),
          orderedEquals(
              [new TaskInvocation('foo'), new TaskInvocation('bar')]));
    });

    test('throws when overwriting default task', () {
      Grinder grinder = new Grinder();
      grinder.defaultTask = new GrinderTask('foo', taskFunction: () {});
      expect(() {
        grinder.defaultTask = new GrinderTask('bar', taskFunction: () {});
      }, throwsA(new isInstanceOf<GrinderException>()));
    });

    test('test that dependency cycles are caught', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('foo', depends: ['bar']));
      grinder.addTask(new GrinderTask('bar', depends: ['foo']));
      expect(() => grinder.start(['foo'], dontRun: true),
          throwsA(new isInstanceOf<GrinderException>()));
    });

    test('can invoke a task with arguments', () {
      Grinder grinder = new Grinder();
      var received;
      grinder.addTask(new GrinderTask('foo', taskFunction: () {
        received = context.invocation;
      },
          positionals: [new Positional()],
          rest: new Rest(),
          options: [new Option(name: 'option')]));
      var sent = new TaskInvocation('foo',
          positionals: ['positional value', 1, 2, 3],
          options: {'option': 'option value'});
      return grinder.start([sent]).then((_) {
        expect(received, sent);
      });
    });

    test('can invoke a dependency task with arguments', () {
      Grinder grinder = new Grinder();
      var invocation;
      grinder.addTask(new GrinderTask('foo', taskFunction: () {
        invocation = context.invocation;
      },
          positionals: [new Positional()],
          rest: new Rest(),
          options: [new Option(name: 'option')]));
      var dep = new TaskInvocation('foo',
          positionals: ['positional value', 1, 2, 3],
          options: {'option': 'option value'});
      grinder.addTask(new GrinderTask('bar', depends: [dep]));
      return grinder.start(['bar']).then((_) {
        expect(invocation, dep);
      });
    });

    test('throws when task invoked twice with different arguments', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('foo',
          taskFunction: () {}, options: [new Option(name: 'option')]));
      var dep = new TaskInvocation('foo', options: {'option': 'option value'});
      grinder.addTask(new GrinderTask('bar', depends: [dep]));

      expect(() => grinder.start(['bar', 'foo']),
          throwsA(new isInstanceOf<GrinderException>()));
    });

    test('stringEscape', () {
      // test that we execute tasks in the correct order
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('b', taskFunction: () {}));
      grinder.addTask(new GrinderTask('d', taskFunction: () {}));
      grinder.addTask(new GrinderTask('a', depends: ['b']));
      grinder.addTask(new GrinderTask('c', depends: ['d']));
      grinder.addTask(new GrinderTask('e', depends: ['a', 'c']));
      grinder.start(['e'], dontRun: true);
      expect(
          grinder.getBuildOrder(),
          orderedEquals(['b', 'a', 'd', 'c', 'e']
              .map((taskName) => new TaskInvocation(taskName))));
    });

    test('task execution order 1', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('setup', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-notest', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-test', taskFunction: () {}));
      grinder.addTask(new GrinderTask('compile', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('deploy', depends: ['setup', 'mode-notest']));
      grinder.addTask(
          new GrinderTask('deploy-test', depends: ['setup', 'mode-test']));
      grinder.addTask(new GrinderTask('docs', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('archive', depends: ['mode-notest', 'compile']));
      grinder.addTask(
          new GrinderTask('release', depends: ['mode-notest', 'compile']));

      grinder.start(['archive'], dontRun: true);
      expect(
          grinder.getBuildOrder(),
          orderedEquals(['mode-notest', 'setup', 'compile', 'archive']
              .map((taskName) => new TaskInvocation(taskName))));
    });

    test('task execution order 2', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('setup', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-notest', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-test', taskFunction: () {}));
      grinder.addTask(new GrinderTask('compile', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('deploy', depends: ['setup', 'mode-notest']));
      grinder.addTask(
          new GrinderTask('deploy-test', depends: ['setup', 'mode-test']));
      grinder.addTask(new GrinderTask('docs', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('archive', depends: ['mode-notest', 'compile']));
      grinder.addTask(
          new GrinderTask('release', depends: ['mode-notest', 'compile']));

      grinder.start(['docs'], dontRun: true);
      expect(
          grinder.getBuildOrder(),
          orderedEquals(['setup', 'docs']
              .map((taskName) => new TaskInvocation(taskName))));
    });

    test('task execution order 3', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('setup', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-notest', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-test', taskFunction: () {}));
      grinder.addTask(new GrinderTask('compile', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('deploy', depends: ['setup', 'mode-notest']));
      grinder.addTask(
          new GrinderTask('deploy-test', depends: ['setup', 'mode-test']));
      grinder.addTask(new GrinderTask('docs', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('archive', depends: ['mode-notest', 'compile']));
      grinder.addTask(
          new GrinderTask('release', depends: ['mode-notest', 'compile']));

      grinder.start(['docs', 'archive'], dontRun: true);
      expect(
          grinder.getBuildOrder(),
          orderedEquals(['setup', 'docs', 'mode-notest', 'compile', 'archive']
              .map((taskName) => new TaskInvocation(taskName))));
    });

    test('task execution order 4', () {
      Grinder grinder = new Grinder();
      grinder.addTask(new GrinderTask('setup', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-notest', taskFunction: () {}));
      grinder.addTask(new GrinderTask('mode-test', taskFunction: () {}));
      grinder.addTask(new GrinderTask('compile', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('deploy', depends: ['setup', 'mode-notest']));
      grinder.addTask(
          new GrinderTask('deploy-test', depends: ['setup', 'mode-test']));
      grinder.addTask(new GrinderTask('docs', depends: ['setup']));
      grinder.addTask(
          new GrinderTask('archive', depends: ['mode-notest', 'compile']));
      grinder.addTask(
          new GrinderTask('release', depends: ['mode-notest', 'compile']));

      grinder.addTask(new GrinderTask('clean', taskFunction: () {}));

      grinder.start(['clean'], dontRun: true);
      expect(grinder.getBuildOrder(),
          orderedEquals([new TaskInvocation('clean')]));
    });

    test('returns future', () {
      StringBuffer buf = new StringBuffer();
      Grinder grinder = new Grinder();

      grinder.addTask(new GrinderTask('a1', taskFunction: (c) {
        Completer completer = new Completer();
        new Timer(new Duration(milliseconds: 100), () {
          buf.write('a');
          completer.complete();
        });
        return completer.future;
      }));
      grinder.addTask(new GrinderTask('a2', depends: ['a1'], taskFunction: (c) {
        buf.write('b');
      }));

      return grinder.start(['a2']).then((_) {
        expect(buf.toString(), 'ab');
      });
    });

    test('throw on fail', () {
      Grinder grinder = new Grinder();
      grinder.addTask(
          new GrinderTask('i_throw', taskFunction: (GrinderContext context) {
        context.fail('boo');
      }));

      expect(grinder.start(['i_throw']),
          throwsA(new isInstanceOf<GrinderException>()));
    });
  });
}
