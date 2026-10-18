import 'package:flutter/material.dart';

/// Colours for [TideSlide]. Any field left null is taken from the ambient
/// [ThemeData], so the control follows light and dark themes on its own.
@immutable
class TideSlideColors {
  /// Creates a colour set. All fields are optional.
  const TideSlideColors({
    this.track,
    this.border,
    this.tide,
    this.onTide,
    this.thumb,
    this.thumbIcon,
    this.label,
    this.success,
    this.onSuccess,
  });

  /// Track background.
  final Color? track;

  /// Track outline.
  final Color? border;

  /// The rising tide behind the thumb, or the closed teeth in the zipper style.
  final Color? tide;

  /// Label colour where the tide covers it.
  final Color? onTide;

  /// Thumb background.
  final Color? thumb;

  /// Arrows and spinner on the thumb.
  final Color? thumbIcon;

  /// Label colour on the bare track.
  final Color? label;

  /// Tide and tick colour once confirmed.
  final Color? success;

  /// Label colour on the success tide.
  final Color? onSuccess;

  /// Returns a copy with the given fields replaced.
  TideSlideColors copyWith({
    Color? track,
    Color? border,
    Color? tide,
    Color? onTide,
    Color? thumb,
    Color? thumbIcon,
    Color? label,
    Color? success,
    Color? onSuccess,
  }) {
    return TideSlideColors(
      track: track ?? this.track,
      border: border ?? this.border,
      tide: tide ?? this.tide,
      onTide: onTide ?? this.onTide,
      thumb: thumb ?? this.thumb,
      thumbIcon: thumbIcon ?? this.thumbIcon,
      label: label ?? this.label,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
    );
  }

  /// Fills every null field from [theme].
  ResolvedTideColors resolve(ThemeData theme) {
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return ResolvedTideColors(
      track: track ?? scheme.surfaceContainerHighest,
      border: border ?? scheme.outlineVariant,
      tide: tide ?? scheme.primary,
      onTide: onTide ?? scheme.onPrimary,
      thumb: thumb ?? scheme.surface,
      thumbIcon: thumbIcon ?? scheme.primary,
      label: label ?? scheme.onSurfaceVariant,
      success:
          success ?? (dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32)),
      onSuccess: onSuccess ?? (dark ? const Color(0xFF0B1F0D) : Colors.white),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TideSlideColors &&
      other.track == track &&
      other.border == border &&
      other.tide == tide &&
      other.onTide == onTide &&
      other.thumb == thumb &&
      other.thumbIcon == thumbIcon &&
      other.label == label &&
      other.success == success &&
      other.onSuccess == onSuccess;

  @override
  int get hashCode => Object.hash(
    track,
    border,
    tide,
    onTide,
    thumb,
    thumbIcon,
    label,
    success,
    onSuccess,
  );
}

/// [TideSlideColors] with every colour filled in.
@immutable
class ResolvedTideColors {
  /// Creates a fully resolved colour set.
  const ResolvedTideColors({
    required this.track,
    required this.border,
    required this.tide,
    required this.onTide,
    required this.thumb,
    required this.thumbIcon,
    required this.label,
    required this.success,
    required this.onSuccess,
  });

  /// See [TideSlideColors.track].
  final Color track;

  /// See [TideSlideColors.border].
  final Color border;

  /// See [TideSlideColors.tide].
  final Color tide;

  /// See [TideSlideColors.onTide].
  final Color onTide;

  /// See [TideSlideColors.thumb].
  final Color thumb;

  /// See [TideSlideColors.thumbIcon].
  final Color thumbIcon;

  /// See [TideSlideColors.label].
  final Color label;

  /// See [TideSlideColors.success].
  final Color success;

  /// See [TideSlideColors.onSuccess].
  final Color onSuccess;
}
