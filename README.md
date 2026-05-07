# voice_chat_input

A polished, voice-first chat input composer for Flutter — hold-to-record with
live waveform, slide-to-cancel, animated mic↔send. Drop-in for any chat shell.

<p align="center">
  <img src="doc/demo.gif" alt="voice_chat_input demo" width="320" />
</p>

## Why

Chat shells like [`flutter_chat_ui`](https://pub.dev/packages/flutter_chat_ui)
and [`dash_chat_2`](https://pub.dev/packages/dash_chat_2) ship great message
lists but leave the input as plain `TextField`. Building a Telegram-grade
voice composer is a weekend of fiddly gesture work most people skip — so most
chatbots stay text-only.

`voice_chat_input` is the missing piece. It is **only** the composer (the bar
at the bottom of the screen). Pair it with any chat list.

## Features

- Hold-to-record with haptics and a 100ms press-scale animation
- Pulsing red dot, `mm:ss` timer with tabular figures
- Right-to-left scrolling amplitude waveform driven by your own `Stream<double>`
- Slide-to-cancel with progressive fade
- Animated mic↔send transition based on text content
- Optional attach button with badge counter and capacity cap
- Audio engine fully delegated — works with `package:record`, `flutter_sound`,
  or anything you already use
- Pure Flutter — no native deps, no asset deps, ~22 KB compiled

## Install

```yaml
dependencies:
  voice_chat_input: ^0.1.0
```

## Usage

Minimal text-only:

```dart
import 'package:voice_chat_input/voice_chat_input.dart';

VoiceChatInput(
  controller: _controller,
  onSubmit: () async => _send(_controller.text),
)
```

Full voice composer (using `package:record` for the audio engine):

```dart
VoiceChatInput(
  controller: _controller,
  hintText: 'Message',
  theme: VoiceChatInputTheme.dark(brand: const Color(0xFFF97316)),
  voice: VoiceConfig(
    amplitudeStream: _recorder.amplitudeStream(), // your engine
    onStart: _recorder.start,
    onStop: _recorder.stopAndUpload,
    onCancel: _recorder.discard,
    maxDuration: const Duration(minutes: 2),
  ),
  attachment: AttachmentConfig(
    onTap: _pickImage,
    badgeCount: _images.length,
    maxCount: 3,
  ),
  bottomPadding: MediaQuery.of(context).padding.bottom,
  onSubmit: () async => _send(_controller.text, _images),
)
```

See [`example/`](./example) for a runnable demo.

## API

### `VoiceChatInput`

| Property | Description |
|---|---|
| `controller` | The `TextEditingController` for the input. |
| `focusNode` | Optional. One is created internally if omitted. |
| `onSubmit` | Awaited when the user taps send. Disable inputs in your handler if needed. |
| `voice` | `VoiceConfig` for hold-to-record. Pass `null` for a text-only composer. |
| `attachment` | `AttachmentConfig` for the paperclip button. Pass `null` to hide it. |
| `theme` | `VoiceChatInputTheme`. Defaults to `VoiceChatInputTheme.dark()`. |
| `hintText` | Placeholder text. |
| `slideToCancelLabel` | Label shown next to the back-arrow during recording. |
| `isBusy` | Disable all actions while a previous request is in flight. |
| `isTranscribing` | Show a spinner in place of the action button. |
| `bottomPadding` | Extra padding below the row (use for the iOS home indicator). |
| `sendIcon` / `micIcon` / `attachIcon` | Override the default glyphs with any `Widget`. |

### `VoiceConfig`

| Property | Description |
|---|---|
| `amplitudeStream` | `Stream<double>` of normalised samples (0.0–1.0). |
| `onStart` | Begin recording. |
| `onStop` | Awaited when the user releases — finalise/upload here. |
| `onCancel` | User slid past the cancel threshold. Discard the file. |
| `maxDuration` | Hard cap. Default 2 minutes. |
| `cancelThreshold` | Drag distance in logical pixels. Default 100. |

### `VoiceChatInputTheme`

Build with `.dark()`, `.light()`, or `.fromColorScheme(scheme)`. Override
individual tokens with `.copyWith(...)`.

## Design philosophy

- **Engine-agnostic.** No recording or transcription dependencies. You bring
  the audio pipeline; the package owns the gestures and visuals.
- **One widget, no providers, no controllers to wire.** State lives inside
  the widget. The host app is involved only at the input/output boundary.
- **No asset bundling.** Glyphs are `Widget` slots — pass `Icon`,
  `SvgPicture.asset`, or anything else.

## Contributing

Issues and PRs welcome. The package is intentionally small in scope; new
features should fit the "composer" remit (anything you'd see between the
keyboard and the message list).

## License

MIT — see [LICENSE](./LICENSE).
