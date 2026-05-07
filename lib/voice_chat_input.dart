/// A polished voice-first chat input composer for Flutter.
///
/// Drop-in replacement for a standard chat `TextField`. Supports
/// hold-to-record voice with live amplitude waveform, slide-to-cancel,
/// animated mic↔send transition, attachments, and a fully overridable theme.
///
/// The audio engine is intentionally not bundled — provide your own
/// recording pipeline (e.g. `package:record`) and wire it via [VoiceConfig].
library;

export 'src/attachment_config.dart';
export 'src/voice_chat_input_theme.dart';
export 'src/voice_chat_input_widget.dart';
export 'src/voice_config.dart';
