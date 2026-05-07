import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'attachment_config.dart';
import 'recording_waveform_painter.dart';
import 'voice_chat_input_theme.dart';
import 'voice_config.dart';

/// A polished chat input composer with hold-to-record voice support.
///
/// Layout (left → right):
///
/// ```
/// [Attach]  [  Rounded text field  ]  [Mic / Send]
/// ```
///
/// While recording, the entire row is replaced with a recording surface that
/// shows a pulsing red dot, an `mm:ss` timer, a live amplitude waveform, and a
/// "slide to cancel" hint. Drag the mic left past
/// [VoiceConfig.cancelThreshold] to cancel.
///
/// All audio I/O is delegated to your app via [VoiceConfig]. Pass `null` to
/// [voice] to ship a text-only composer.
class VoiceChatInput extends StatefulWidget {
  /// The text controller for the input.
  final TextEditingController controller;

  /// Optional focus node. Created internally if omitted.
  final FocusNode? focusNode;

  /// Called when the user taps the send button. Awaited so callers can disable
  /// the input during async submission.
  final Future<void> Function() onSubmit;

  /// Voice-recording configuration. Pass `null` for a text-only composer.
  final VoiceConfig? voice;

  /// Attachment button configuration. Pass `null` to hide the attach button.
  final AttachmentConfig? attachment;

  /// Visual tokens. Defaults to [VoiceChatInputTheme.dark].
  final VoiceChatInputTheme? theme;

  /// Placeholder text shown when the input is empty.
  final String hintText;

  /// Label rendered next to the back-arrow during recording.
  final String slideToCancelLabel;

  /// Disables every action button (text submit, mic press, attach).
  ///
  /// Use while a previous request is in-flight.
  final bool isBusy;

  /// Renders a small spinner in place of the action button — useful when the
  /// app is transcribing the recording before sending.
  final bool isTranscribing;

  /// Extra padding applied below the row. Pass
  /// `MediaQuery.of(context).padding.bottom` to respect the iOS home indicator.
  final double bottomPadding;

  /// Custom send-button glyph. Defaults to a rounded paper-plane (filled
  /// arrow). Sized internally — the glyph should respect its parent constraints.
  final Widget? sendIcon;

  /// Custom mic glyph. Defaults to [Icons.mic_none_rounded].
  final Widget? micIcon;

  /// Custom attach glyph. Defaults to [Icons.attach_file_rounded].
  final Widget? attachIcon;

  const VoiceChatInput({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.focusNode,
    this.voice,
    this.attachment,
    this.theme,
    this.hintText = 'Message',
    this.slideToCancelLabel = 'Slide to cancel',
    this.isBusy = false,
    this.isTranscribing = false,
    this.bottomPadding = 0,
    this.sendIcon,
    this.micIcon,
    this.attachIcon,
  });

  @override
  State<VoiceChatInput> createState() => _VoiceChatInputState();
}

class _VoiceChatInputState extends State<VoiceChatInput>
    with TickerProviderStateMixin {
  // ─── Recording state ──────────────────────────────────────────
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Timer? _waveformTimer;
  Offset? _dragStart;
  double _dragDistance = 0.0;
  bool _isSubmitting = false;

  // ─── Amplitude buffer ─────────────────────────────────────────
  final List<double> _amplitudes = [];
  StreamSubscription<double>? _amplitudeSub;
  double _targetAmplitude = 0.0;
  double _displayAmplitude = 0.0;

  // ─── Animations ───────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  FocusNode? _ownedFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  // Layout constants
  static const _actionButtonSize = 50.0;
  static const _iconSize = 26.0;
  static const _waveformFrameInterval = Duration(milliseconds: 32);
  static const _maxWaveformSamples = 72;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    _amplitudeSub?.cancel();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  VoiceChatInputTheme get _theme => widget.theme ?? VoiceChatInputTheme.dark();

  bool get _isActionBusy => widget.isBusy || _isSubmitting;

  // ─── Recording lifecycle ──────────────────────────────────────

  void _startRecording() {
    final voice = widget.voice;
    if (voice == null || _isRecording) return;

    _focusNode.unfocus();

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _amplitudes.clear();
      _targetAmplitude = 0.0;
      _displayAmplitude = 0.0;
    });

    HapticFeedback.mediumImpact();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= voice.maxDuration.inSeconds) {
        _stopRecording(canceled: false);
      }
    });

    _waveformTimer = Timer.periodic(_waveformFrameInterval, (_) {
      if (!mounted || !_isRecording) return;
      final next = _advanceWaveform();
      setState(() {
        if (_amplitudes.length >= _maxWaveformSamples) {
          _amplitudes.removeAt(0);
        }
        _amplitudes.add(next);
      });
    });

    _amplitudeSub = voice.amplitudeStream.listen((value) {
      if (!mounted) return;
      _targetAmplitude = _prepareAmplitude(value);
    });

    voice.onStart();
  }

  Future<void> _stopRecording({required bool canceled}) async {
    final voice = widget.voice;
    if (voice == null || !_isRecording) return;

    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    setState(() {
      _isRecording = false;
      _dragDistance = 0.0;
      _dragStart = null;
      _targetAmplitude = 0.0;
      _displayAmplitude = 0.0;
    });

    _scaleController.reverse();
    HapticFeedback.lightImpact();

    if (canceled) {
      voice.onCancel();
    } else {
      await voice.onStop();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────

  double _prepareAmplitude(double raw) {
    final clamped = raw.clamp(0.0, 1.0);
    return (clamped * 0.5) + (clamped * clamped * 0.5);
  }

  double _advanceWaveform() {
    final delta = _targetAmplitude - _displayAmplitude;
    final blend = delta > 0 ? 0.42 : 0.18;
    _displayAmplitude += delta * blend;
    return _displayAmplitude.clamp(0.0, 1.0);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSubmitTap() async {
    if (_isActionBusy || widget.isTranscribing) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: widget.bottomPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _isRecording ? _buildRecordingMode() : _buildNormalMode(),
          ),
          const SizedBox(width: 8),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildNormalMode() {
    final theme = _theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.attachment != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: GestureDetector(
              onTap: (_isActionBusy || !widget.attachment!.enabled)
                  ? null
                  : widget.attachment!.onTap,
              child: Badge(
                isLabelVisible: widget.attachment!.badgeCount > 0,
                label: Text(
                  widget.attachment!.badgeCount.toString(),
                  style: const TextStyle(fontSize: 10),
                ),
                child: SizedBox(
                  width: _actionButtonSize,
                  height: _actionButtonSize,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(
                        color: (_isActionBusy || !widget.attachment!.enabled)
                            ? theme.textTertiary
                            : theme.textSecondary,
                        size: 26,
                      ),
                      child: widget.attachIcon ??
                          const Icon(Icons.attach_file_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.attachment != null) const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.borderRadius),
              border: Border.all(color: theme.border),
            ),
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 10,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              scrollPadding: const EdgeInsets.only(bottom: 100),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: theme.textTertiary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    final theme = _theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          final hasAttachments = (widget.attachment?.badgeCount ?? 0) > 0;
          final canSend = hasText || hasAttachments;
          final hasVoice = widget.voice != null;

          Widget child;
          if (widget.isTranscribing) {
            child = _buildTranscribingButton(theme);
          } else if (canSend || !hasVoice) {
            child = _buildSendButton(theme);
          } else {
            child = _buildMicButton(theme);
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (c, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
                child: c,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildTranscribingButton(VoiceChatInputTheme theme) {
    return Container(
      key: const ValueKey('vci_transcribing'),
      width: _actionButtonSize,
      height: _actionButtonSize,
      decoration: BoxDecoration(
        color: theme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: theme.border),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.brand),
        ),
      ),
    );
  }

  Widget _buildSendButton(VoiceChatInputTheme theme) {
    return GestureDetector(
      key: const ValueKey('vci_send'),
      onTap: _handleSubmitTap,
      child: Container(
        width: _actionButtonSize,
        height: _actionButtonSize,
        decoration: BoxDecoration(
          color: theme.brand,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: IconTheme(
            data: IconThemeData(color: theme.onBrand, size: _iconSize),
            child: widget.sendIcon ?? const Icon(Icons.arrow_upward_rounded),
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton(VoiceChatInputTheme theme) {
    return GestureDetector(
      key: const ValueKey('vci_mic'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (_isActionBusy || widget.isTranscribing) return;
        _scaleController.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        if (!_isRecording) _scaleController.reverse();
      },
      onTapCancel: () {
        if (!_isRecording) _scaleController.reverse();
      },
      onLongPressStart: (details) {
        if (_isRecording || _isActionBusy || widget.isTranscribing) return;
        _dragStart = details.globalPosition;
        _startRecording();
      },
      onLongPressEnd: (_) => _stopRecording(canceled: false),
      onLongPressCancel: () => _stopRecording(canceled: false),
      onLongPressMoveUpdate: (details) {
        if (_dragStart == null) return;
        final distance = (_dragStart!.dx - details.globalPosition.dx).abs();
        setState(() => _dragDistance = distance);
        if (distance > widget.voice!.cancelThreshold) {
          _stopRecording(canceled: true);
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: _actionButtonSize,
              height: _actionButtonSize,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: theme.textSecondary,
                    size: 28,
                  ),
                  child: widget.micIcon ?? const Icon(Icons.mic_none_rounded),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Recording surface ────────────────────────────────────────

  Widget _buildRecordingMode() {
    final theme = _theme;
    final cancelProgress =
        (_dragDistance / widget.voice!.cancelThreshold).clamp(0.0, 1.0);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) => Opacity(
              opacity: _pulseAnimation.value,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: theme.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_recordingSeconds),
            style: TextStyle(
              color: theme.danger,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: CustomPaint(
              painter: RecordingWaveformPainter(
                amplitudes: List<double>.unmodifiable(_amplitudes),
                barColor: theme.danger.withValues(alpha: 0.55),
              ),
              size: const Size(double.infinity, 34),
            ),
          ),
          const SizedBox(width: 10),
          Opacity(
            opacity: 1 - cancelProgress,
            child: Transform.translate(
              offset: Offset(-24 * cancelProgress, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.textTertiary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.slideToCancelLabel,
                    style: TextStyle(
                      color: theme.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
