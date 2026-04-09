import '../../data/models/annotation.dart';
import '../../data/models/point.dart';

/// Reversible edit for [List<Annotation>] undo/redo stacks.
abstract class DrawAction {
  const DrawAction();

  void undo(List<Annotation> annotations);
  void redo(List<Annotation> annotations);
}

/// User added a new annotation (already present in the list when recorded).
class DAAdd extends DrawAction {
  final Annotation added;
  const DAAdd(this.added);

  @override
  void undo(List<Annotation> annotations) {
    annotations.removeWhere((a) => a.id == added.id);
  }

  @override
  void redo(List<Annotation> annotations) {
    annotations.add(added);
  }
}

/// Single annotation removed (by id).
class DARemove extends DrawAction {
  final Annotation removed;
  final int index;
  const DARemove(this.removed, this.index);

  @override
  void undo(List<Annotation> annotations) {
    if (index >= 0 && index <= annotations.length) {
      annotations.insert(index, removed);
    } else {
      annotations.add(removed);
    }
  }

  @override
  void redo(List<Annotation> annotations) {
    annotations.removeWhere((a) => a.id == removed.id);
  }
}

/// Replace all annotations (clear).
class DAClear extends DrawAction {
  final List<Annotation> before;
  const DAClear(this.before);

  @override
  void undo(List<Annotation> annotations) {
    annotations
      ..clear()
      ..addAll(before);
  }

  @override
  void redo(List<Annotation> annotations) {
    annotations.clear();
  }
}

/// Eraser removed several annotations in one stroke.
class DARemoveBatch extends DrawAction {
  final List<DARemoveEntry> removed;
  const DARemoveBatch(this.removed);

  @override
  void undo(List<Annotation> annotations) {
    final sorted = List<DARemoveEntry>.from(removed)
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final entry in sorted) {
      final idx = entry.index.clamp(0, annotations.length);
      annotations.insert(idx, entry.annotation);
    }
  }

  @override
  void redo(List<Annotation> annotations) {
    for (final r in removed) {
      annotations.removeWhere((a) => a.id == r.annotation.id);
    }
  }
}

class DARemoveEntry {
  final Annotation annotation;
  final int index;
  const DARemoveEntry({
    required this.annotation,
    required this.index,
  });
}

/// Move finished: restore [before] / apply [after] points for one id.
class DAMove extends DrawAction {
  final String id;
  final List<HexaPoint> before;
  final List<HexaPoint> after;
  const DAMove({
    required this.id,
    required this.before,
    required this.after,
  });

  @override
  void undo(List<Annotation> annotations) {
    final i = annotations.indexWhere((a) => a.id == id);
    if (i < 0) return;
    annotations[i] = annotations[i].copyWith(points: List.from(before));
  }

  @override
  void redo(List<Annotation> annotations) {
    final i = annotations.indexWhere((a) => a.id == id);
    if (i < 0) return;
    annotations[i] = annotations[i].copyWith(points: List.from(after));
  }
}

/// Manages undo/redo for annotation lists.
class DrawHistory {
  /// Keeps memory stable during long drawing sessions (drops oldest history).
  static const int maxUndoDepth = 50;

  final List<DrawAction> _undo = [];
  final List<DrawAction> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Current undo stack size (capped at [maxUndoDepth]).
  int get undoStackLength => _undo.length;

  void clear() {
    _undo.clear();
    _redo.clear();
  }

  void record(DrawAction action) {
    _undo.add(action);
    while (_undo.length > maxUndoDepth) {
      _undo.removeAt(0);
    }
    _redo.clear();
  }

  void undo(List<Annotation> annotations) {
    if (_undo.isEmpty) return;
    final action = _undo.removeLast();
    action.undo(annotations);
    _redo.add(action);
  }

  void redo(List<Annotation> annotations) {
    if (_redo.isEmpty) return;
    final action = _redo.removeLast();
    action.redo(annotations);
    _undo.add(action);
  }
}
