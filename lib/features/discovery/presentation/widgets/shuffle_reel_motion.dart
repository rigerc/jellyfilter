import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';

/// Where the Shuffle reel sits, and how blurred it looks, over one spin.
///
/// Speed comes from the travel curve's exact slope rather than from frame
/// timings, so the motion blur fades out evenly as the reel slows instead of
/// flickering with uneven frames.
final class ShuffleReelMotion {
  ShuffleReelMotion({required this.end, required Duration duration})
    : _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond,
      position = TweenSequence<double>(<TweenSequenceItem<double>>[
        // Wind-up: the reel pulls back a touch, like a lever being drawn.
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: start,
            end: _travelStart,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: _windUpWeight,
        ),
        // Rapid acceleration, then a long deceleration that overshoots.
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: _travelStart,
            end: end + _overshoot,
          ).chain(CurveTween(curve: _travelCurve)),
          weight: _travelWeight,
        ),
        // Settle the poster back into the center.
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: end + _overshoot,
            end: end,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: _settleWeight,
        ),
      ]);

  /// Reel index shown when the spin starts.
  static const start = 1.0;

  /// Controller value at which the reel stops travelling and settles back
  /// onto the pick. Speed is zero here, and so is the blur from then on.
  static const settleStart = (_windUpWeight + _travelWeight) / _totalWeight;

  static const _windUp = 0.16;
  static const _overshoot = 0.12;
  static const _travelStart = start - _windUp;
  static const _windUpWeight = 7.0;
  static const _travelWeight = 80.0;
  static const _settleWeight = 13.0;
  static const _totalWeight = _windUpWeight + _travelWeight + _settleWeight;
  static const _travelBegin = _windUpWeight / _totalWeight;
  static const _travelCurve = _ExactCubic(0.33, 0, 0.1, 1);

  /// Speed, in posters per second, below which the reel looks sharp.
  static const _blurDeadZone = 1.0;

  /// Blur sigma added per poster per second above the dead zone.
  static const _blurGain = 0.55;

  /// Reel index of the pick the spin lands on.
  final double end;

  /// Reel index over the spin, driven by a controller running from 0 to 1.
  final Animatable<double> position;

  final double _seconds;

  /// Reel speed in posters per second at controller value [t]. Only the
  /// travel phase counts: the wind-up and settle are too small to blur.
  double velocity(double t) {
    if (_seconds <= 0 || t <= _travelBegin || t >= settleStart) {
      return 0;
    }
    const span = settleStart - _travelBegin;
    final local = (t - _travelBegin) / span;
    final distance = end + _overshoot - _travelStart;
    return distance * _travelCurve.slope(local) / span / _seconds;
  }

  /// Vertical motion blur sigma at controller value [t].
  double blurSigma(double t) {
    final excess = velocity(t) - _blurDeadZone;
    if (excess <= 0) {
      return 0;
    }
    return math.min(CandyReel.maxBlurSigma, excess * _blurGain);
  }
}

/// A cubic Bezier easing solved precisely, with an exact slope.
///
/// Flutter's [Cubic] stops solving at an error of 0.001, which is too coarse
/// to take a speed from without visible jitter.
final class _ExactCubic extends Curve {
  const _ExactCubic(this.a, this.b, this.c, this.d);

  final double a;
  final double b;
  final double c;
  final double d;

  static const _iterations = 40;

  @override
  double transformInternal(double t) => _bezier(b, d, _parameterFor(t));

  /// Rate of change of the eased value with respect to [t].
  double slope(double t) {
    final s = _parameterFor(t.clamp(0.0, 1.0));
    final dx = _bezierSlope(a, c, s);
    if (dx <= 0) {
      return 0;
    }
    return _bezierSlope(b, d, s) / dx;
  }

  double _parameterFor(double x) {
    var low = 0.0;
    var high = 1.0;
    for (var step = 0; step < _iterations; step++) {
      final mid = (low + high) / 2;
      if (_bezier(a, c, mid) < x) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  static double _bezier(double p1, double p2, double s) {
    final inverse = 1 - s;
    return 3 * p1 * inverse * inverse * s +
        3 * p2 * inverse * s * s +
        s * s * s;
  }

  static double _bezierSlope(double p1, double p2, double s) {
    final inverse = 1 - s;
    return 3 * p1 * inverse * inverse +
        6 * (p2 - p1) * inverse * s +
        3 * (1 - p2) * s * s;
  }
}
