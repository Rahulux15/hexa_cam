import 'dart:ui';

import 'package:demo_app/data/models/annotation.dart';
import 'package:demo_app/data/models/point.dart';
import 'package:demo_app/ui/viewer/draw_action.dart';
import 'package:flutter_test/flutter_test.dart';

Annotation _ann(String id) => Annotation(
      id: id,
      type: AnnotationType.draw,
      points: const [HexaPoint(x: 0, y: 0)],
      color: const Color(0xFFFF00FF),
      timestamp: 't',
    );

void main() {
  test('DrawHistory caps undo stack at maxUndoDepth', () {
    final h = DrawHistory();
    for (var i = 0; i < 55; i++) {
      h.record(DAAdd(_ann('a$i')));
    }
    expect(h.undoStackLength, DrawHistory.maxUndoDepth);
  });

  test('undo/redo still work after cap (oldest history dropped)', () {
    final list = <Annotation>[];
    final h = DrawHistory();
    for (var i = 0; i < 3; i++) {
      final a = _ann('x$i');
      list.add(a);
      h.record(DAAdd(a));
    }
    expect(h.undoStackLength, 3);
    h.undo(list);
    expect(list.length, 2);
    h.redo(list);
    expect(list.length, 3);
  });
}
