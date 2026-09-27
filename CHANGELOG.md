## 0.2.0

* **Breaking:** the action button keys are now public constants,
  `VoiceChatInputKeys.send` / `.mic` / `.transcribing`, with the values
  `send_action`, `voice_action` and `transcribing_action` (were `vci_send`,
  `vci_mic`, `vci_transcribing`).
* New `textInputEnabled` to disable only the text field while the attach and
  action buttons keep working.
* The action button stays on the mic for the whole recording, shown as a
  brand-filled circle, even if the field gets text mid-recording. Before, it
  could swap to send and end the long-press gesture.
* Releasing the mic calls `VoiceConfig.onStop` immediately instead of first
  waiting for the amplitude stream to finish cancelling, which could delay or
  block `onStop`.

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
