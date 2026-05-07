import 'package:flutter/material.dart';

/// Visual tokens used by [VoiceChatInput].
///
/// Build one from your app's theme with [VoiceChatInputTheme.fromColorScheme],
/// or use the [VoiceChatInputTheme.dark] / [VoiceChatInputTheme.light] presets.
@immutable
class VoiceChatInputTheme {
  /// Fill color of the rounded input container.
  final Color surface;

  /// 1px border around the input container and circular accent buttons.
  final Color border;

  /// Body text color (typed input).
  final Color textPrimary;

  /// Icon color for idle action buttons (mic, attach).
  final Color textSecondary;

  /// Hint and slide-to-cancel label color.
  final Color textTertiary;

  /// Brand accent — fills the send button and the active mic when recording.
  final Color brand;

  /// Foreground color rendered on top of [brand] (send arrow, active mic icon).
  final Color onBrand;

  /// Recording-state accent — pulsing dot, timer, waveform bars.
  final Color danger;

  /// Border radius applied to the input container. Default `24`.
  final double borderRadius;

  const VoiceChatInputTheme({
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brand,
    required this.onBrand,
    required this.danger,
    this.borderRadius = 24,
  });

  /// Dark theme preset. Override [brand] to match your app's accent.
  factory VoiceChatInputTheme.dark({Color brand = const Color(0xFFF97316)}) {
    return VoiceChatInputTheme(
      surface: const Color(0xFF1A1A1A),
      border: const Color(0xFF2A2A2A),
      textPrimary: const Color(0xFFF5F5F5),
      textSecondary: const Color(0xFFA0A0A0),
      textTertiary: const Color(0xFF6B6B6B),
      brand: brand,
      onBrand: Colors.white,
      danger: const Color(0xFFEF4444),
    );
  }

  /// Light theme preset. Override [brand] to match your app's accent.
  factory VoiceChatInputTheme.light({Color brand = const Color(0xFFF97316)}) {
    return VoiceChatInputTheme(
      surface: const Color(0xFFF3F4F6),
      border: const Color(0xFFE5E7EB),
      textPrimary: const Color(0xFF111827),
      textSecondary: const Color(0xFF6B7280),
      textTertiary: const Color(0xFF9CA3AF),
      brand: brand,
      onBrand: Colors.white,
      danger: const Color(0xFFEF4444),
    );
  }

  /// Derive theme tokens from a Material [ColorScheme].
  factory VoiceChatInputTheme.fromColorScheme(ColorScheme scheme) {
    return VoiceChatInputTheme(
      surface: scheme.surfaceContainerHighest,
      border: scheme.outlineVariant,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textTertiary: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      brand: scheme.primary,
      onBrand: scheme.onPrimary,
      danger: scheme.error,
    );
  }

  VoiceChatInputTheme copyWith({
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? brand,
    Color? onBrand,
    Color? danger,
    double? borderRadius,
  }) {
    return VoiceChatInputTheme(
      surface: surface ?? this.surface,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      danger: danger ?? this.danger,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
