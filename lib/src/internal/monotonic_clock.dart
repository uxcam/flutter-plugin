/// One monotonic millisecond clock for the occlusion pipeline.
///
/// Every consumer takes differences — a 100 ms sliding window, a 500 ms grace,
/// a velocity from two samples — so the epoch is irrelevant, and a `Stopwatch`
/// read allocates nothing where `DateTime.now()` allocates a `DateTime` per
/// call, several times per field per frame. It is also immune to wall-clock
/// jumps, which used to perturb the window and the grace at once.
final Stopwatch _stopwatch = Stopwatch()..start();

int monotonicNowMs() => _stopwatch.elapsedMilliseconds;
