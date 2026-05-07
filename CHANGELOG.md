## 0.1.0

* Initial release.
* `VoiceChatInput` widget — rounded text composer with attach button on the
  left and an animated mic↔send action button on the right.
* Hold-to-record voice mode with pulsing dot, `mm:ss` timer, live amplitude
  waveform, and slide-to-cancel.
* `VoiceConfig` delegates audio I/O to the host app — no recording dependency
  shipped.
* `AttachmentConfig` for the optional attach button with badge count and
  capacity cap.
* `VoiceChatInputTheme` with `dark()`, `light()`, and `fromColorScheme()`
  factories.
* Icon slots (`micIcon`, `sendIcon`, `attachIcon`) accept any `Widget`.
