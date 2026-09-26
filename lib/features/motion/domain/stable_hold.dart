/// Counts only observed valid time. Brief loss pauses; sustained loss resets.
class StableHold {
  Duration? _last, _lastGood, _candidate;
  bool _previousGood = false;
  bool active = false, completed = false;
  double seconds = 0;
  void reset() {
    if (completed) return;
    _last = _lastGood = _candidate = null;
    _previousGood = active = false;
    seconds = 0;
  }

  void update(bool good, Duration now) {
    if (completed) return;
    final gap = _last == null ? Duration.zero : now - _last!;
    if (gap.isNegative || (_lastGood != null &&
        now - _lastGood! > const Duration(milliseconds: 800))) {
      reset();
    }
    if (good) {
      _candidate ??= now;
      if (!active && now - _candidate! >= const Duration(milliseconds: 300)) {
        active = true;
      } else if (active && _previousGood && gap <= const Duration(milliseconds: 400)) {
        seconds = (seconds + gap.inMicroseconds / 1e6).clamp(0, 3);
        completed = seconds >= 3;
      }
      _lastGood = now;
    } else if (!active) {
      _candidate = null;
    }
    _previousGood = good;
    _last = now;
  }
}
