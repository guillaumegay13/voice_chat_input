// Demo for the `voice_chat_input` package.
//
// To keep this example dependency-free and runnable on every platform out of
// the box, the recording engine is **simulated**: a periodic timer pushes a
// fake amplitude into the stream so you can see the waveform react. To wire a
// real recorder, replace `_FakeAmplitude` with a `Stream<double>` from
// `package:record`, `flutter_sound`, or your engine of choice.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:voice_chat_input/voice_chat_input.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'voice_chat_input demo',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF97316),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFF97316),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _controller = TextEditingController();
  final _amplitude = _FakeAmplitude();
  final _messages = <String>[
    'Hold the mic to record. Slide left to cancel.',
  ];
  int _attachments = 0;

  @override
  void dispose() {
    _controller.dispose();
    _amplitude.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments == 0) return;
    setState(() {
      if (_attachments > 0) {
        _messages.add('🖼 Sent $_attachments attachment(s)');
        _attachments = 0;
      }
      if (text.isNotEmpty) _messages.add(text);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme =
        isDark ? VoiceChatInputTheme.dark() : VoiceChatInputTheme.light();

    return Scaffold(
      appBar: AppBar(title: const Text('voice_chat_input')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[_messages.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: Text(m, style: TextStyle(color: theme.textPrimary)),
                  ),
                );
              },
            ),
          ),
          VoiceChatInput(
            controller: _controller,
            onSubmit: _send,
            theme: theme,
            voice: VoiceConfig(
              amplitudeStream: _amplitude.stream,
              onStart: _amplitude.start,
              onStop: () async {
                _amplitude.stop();
                setState(() => _messages.add('🎙 Sent a voice message'));
              },
              onCancel: _amplitude.stop,
            ),
            attachment: AttachmentConfig(
              onTap: () => setState(() => _attachments++),
              badgeCount: _attachments,
              maxCount: 3,
            ),
            bottomPadding: MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }
}

/// Drives the waveform with a fake-but-believable amplitude curve so the demo
/// works without any audio engine wired in.
class _FakeAmplitude {
  final _controller = StreamController<double>.broadcast();
  Timer? _timer;
  final _rng = Random();
  double _phase = 0;

  Stream<double> get stream => _controller.stream;

  void start() {
    _phase = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _phase += 0.18;
      final base = 0.5 + 0.45 * sin(_phase);
      final jitter = _rng.nextDouble() * 0.15;
      _controller.add((base + jitter).clamp(0.0, 1.0));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
