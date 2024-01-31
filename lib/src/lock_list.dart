class LockList<T> {
  static const _waitDuration = Duration(milliseconds: 1);
  final List<T> _readLocks = <T>[];
  final List<T> _writeLocks = <T>[];

  Future<void> lockRead(T object) async {
    while (_writeLocks.contains(object)) {
      await Future.delayed(_waitDuration);
    }
    _readLocks.add(object);
  }

  void releaseRead(T object) {
    if (!_readLocks.remove(object)) {
      throw Exception("Trying to release not owned read-lock on $object");
    }
  }

  Future<void> lockWrite(T object) async {
    while (_writeLocks.contains(object)) {
      await Future.delayed(_waitDuration);
    }
    _writeLocks.add(object);
    while (_readLocks.contains(object)) {
      await Future.delayed(_waitDuration);
    }
  }

  void releaseWrite(T object) {
    if (!_writeLocks.remove(object)) {
      throw Exception("Trying to release not owned write-lock on $object");
    }
  }

  Future<void> waitForAllReleased() async {
    while (_writeLocks.isNotEmpty || _readLocks.isNotEmpty) {
      await Future.delayed(_waitDuration);
    }
  }
}
