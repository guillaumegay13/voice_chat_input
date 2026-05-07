import 'package:flutter/foundation.dart';

/// Wires the voice-recording UI to your audio engine.
///
/// `voice_chat_input` is intentionally engine-agnostic — it does not depend on
/// any recording package. Implement these callbacks against `package:record`,
/// `flutter_sound`, or any other recorder.
///
/// Lifecycle:
///   1. User long-presses the mic → [onStart] is called.
///   2. While recording, push normalised samples (0.0–1.0) to [amplitudeStream]
///      to drive the live waveform.
///   3. User releases → [onStop] is awaited; the `Future` lets you finalise the
///      file and (for example) start transcription.
///   4. User slides to cancel (or the widget hits [maxDuration]) →
///      [onCancel] is called and the recording should be discarded.
@immutable
class VoiceConfig {
  /// Stream of normalised amplitude samples (0.0–1.0). Drive this from your
  /// recorder's amplitude API. Sample rate is up to you — the widget smooths
  /// internally and renders ~30 fps.
  final Stream<double> amplitudeStream;

  /// Called when the user starts recording (long-press begins).
  final VoidCallback onStart;

  /// Called when the user releases the mic to send the recording. The
  /// returned `Future` is awaited before the input transitions back to text
  /// mode, so this is the right place to upload, transcribe, etc.
  final Future<void> Function() onStop;

  /// Called when the user slides far enough to cancel, or aborts otherwise.
  final VoidCallback onCancel;

  /// Hard cap on recording duration. Default 2 minutes.
  final Duration maxDuration;

  /// Horizontal drag distance (logical pixels) at which the recording is
  /// cancelled. Default `100`.
  final double cancelThreshold;

  const VoiceConfig({
    required this.amplitudeStream,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.maxDuration = const Duration(minutes: 2),
    this.cancelThreshold = 100.0,
  });
}
