import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_input/voice_chat_input.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
        body: SafeArea(
            child: Align(
      alignment: Alignment.bottomCenter,
      child: child,
    ))),
  );
}

void main() {
  group('VoiceChatInput', () {
    testWidgets(
        'renders the hint and a mic when text is empty and voice is set',
        (tester) async {
      final controller = TextEditingController();
      final amp = StreamController<double>.broadcast();
      addTearDown(() {
        controller.dispose();
        amp.close();
      });

      await tester.pumpWidget(_wrap(
        VoiceChatInput(
          controller: controller,
          hintText: 'Say something',
          voice: VoiceConfig(
            amplitudeStream: amp.stream,
            onStart: () {},
            onStop: () async {},
            onCancel: () {},
          ),
          onSubmit: () async {},
        ),
      ));
      await tester.pump();

      expect(find.text('Say something'), findsOneWidget);
      expect(find.byKey(VoiceChatInputKeys.mic), findsOneWidget);
      expect(find.byKey(VoiceChatInputKeys.send), findsNothing);
    });

    testWidgets('swaps to send when text is entered', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(
        VoiceChatInput(
          controller: controller,
          onSubmit: () async {},
        ),
      ));
      await tester.pump();

      // No voice config => send button is the default.
      expect(find.byKey(VoiceChatInputKeys.send), findsOneWidget);

      controller.text = 'hello';
      await tester.pump();
      expect(find.byKey(VoiceChatInputKeys.send), findsOneWidget);
    });

    testWidgets('tap on send invokes onSubmit', (tester) async {
      final controller = TextEditingController(text: 'hi');
      addTearDown(controller.dispose);
      var submitted = 0;

      await tester.pumpWidget(_wrap(
        VoiceChatInput(
          controller: controller,
          onSubmit: () async => submitted++,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byKey(VoiceChatInputKeys.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(submitted, 1);
    });

    testWidgets('isBusy disables send', (tester) async {
      final controller = TextEditingController(text: 'hi');
      addTearDown(controller.dispose);
      var submitted = 0;

      await tester.pumpWidget(_wrap(
        VoiceChatInput(
          controller: controller,
          isBusy: true,
          onSubmit: () async => submitted++,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byKey(VoiceChatInputKeys.send));
      await tester.pump();
      expect(submitted, 0);
    });

    testWidgets('attachment hidden when config is null', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(
        VoiceChatInput(controller: controller, onSubmit: () async {}),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
    });

    testWidgets('attachment renders with badge', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(
        VoiceChatInput(
          controller: controller,
          onSubmit: () async {},
          attachment: AttachmentConfig(
            onTap: () {},
            badgeCount: 2,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('VoiceChatInput 0.2.0', () {
    testWidgets('textInputEnabled false disables only the text field',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var attachTaps = 0;

      await tester.pumpWidget(_wrap(
        VoiceChatInput(
          controller: controller,
          textInputEnabled: false,
          onSubmit: () async {},
          attachment: AttachmentConfig(onTap: () => attachTaps++),
        ),
      ));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.enabled, isFalse);

      await tester.tap(find.byIcon(Icons.attach_file_rounded));
      expect(attachTaps, 1);
    });

    testWidgets('keeps the mic while recording even if text appears',
        (tester) async {
      final controller = TextEditingController();
      final amp = StreamController<double>.broadcast();
      addTearDown(() {
        controller.dispose();
        amp.close();
      });
      var starts = 0;
      var stops = 0;

      await tester.pumpWidget(_wrap(
        VoiceChatInput(
          controller: controller,
          onSubmit: () async {},
          voice: VoiceConfig(
            amplitudeStream: amp.stream,
            onStart: () => starts++,
            onStop: () async => stops++,
            onCancel: () {},
          ),
        ),
      ));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(VoiceChatInputKeys.mic)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(starts, 1);

      // Text set by the host mid-recording must not swap the button to send.
      controller.text = 'hello';
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(VoiceChatInputKeys.mic), findsOneWidget);
      expect(find.byKey(VoiceChatInputKeys.send), findsNothing);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(stops, 1);
      expect(find.byKey(VoiceChatInputKeys.send), findsOneWidget);
    });
  });

  group('VoiceChatInputTheme', () {
    test('dark and light produce distinct surfaces', () {
      final dark = VoiceChatInputTheme.dark();
      final light = VoiceChatInputTheme.light();
      expect(dark.surface, isNot(light.surface));
      expect(dark.brand, light.brand); // same default brand
    });

    test('copyWith overrides only the requested field', () {
      final base = VoiceChatInputTheme.dark();
      final copy = base.copyWith(brand: const Color(0xFF00FF00));
      expect(copy.brand, const Color(0xFF00FF00));
      expect(copy.surface, base.surface);
    });
  });
}
