import 'package:flutter/foundation.dart';

/// Configuration for the optional attachment (paperclip) button.
///
/// Pass `null` to [VoiceChatInput.attachment] to hide the button entirely.
@immutable
class AttachmentConfig {
  /// Called when the attach button is tapped.
  final VoidCallback onTap;

  /// Number rendered as a badge on the button. `0` hides the badge.
  final int badgeCount;

  /// Optional cap. When [badgeCount] reaches this value the button becomes
  /// non-interactive. Pass `null` to allow unlimited attachments.
  final int? maxCount;

  const AttachmentConfig({
    required this.onTap,
    this.badgeCount = 0,
    this.maxCount,
  });

  bool get _atCapacity => maxCount != null && badgeCount >= maxCount!;

  /// Whether the button should respond to taps.
  bool get enabled => !_atCapacity;
}
