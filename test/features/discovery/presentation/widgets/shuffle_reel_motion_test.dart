import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/shuffle_reel_motion.dart';

void main() {
  const samples = 2000;
  const durations = <Duration>[
    Duration(milliseconds: 500),
    CandyMotion.reelSpin,
    Duration(seconds: 6),
  ];

  List<double> sigmas(ShuffleReelMotion motion) => <double>[
    for (var step = 0; step <= samples; step++)
      motion.blurSigma(step / samples),
  ];

  group('ShuffleReelMotion', () {
    test('should start on the first poster and land exactly on the pick', () {
      final motion = ShuffleReelMotion(end: 24, duration: CandyMotion.reelSpin);

      expect(motion.position.transform(0), ShuffleReelMotion.start);
      expect(motion.position.transform(1), 24);
    });

    for (final duration in durations) {
      test(
        'should be sharp at rest for a ${duration.inMilliseconds} ms spin',
        () {
          final motion = ShuffleReelMotion(end: 24, duration: duration);

          expect(motion.blurSigma(0), 0);
          expect(motion.blurSigma(ShuffleReelMotion.settleStart), 0);
          expect(motion.blurSigma(1), 0);
          for (var t = ShuffleReelMotion.settleStart; t <= 1; t += 0.005) {
            expect(motion.blurSigma(t), 0, reason: 'settling at $t');
          }
        },
      );

      test('should blur once and fade it out evenly for a '
          '${duration.inMilliseconds} ms spin', () {
        final values = sigmas(ShuffleReelMotion(end: 24, duration: duration));
        final peak = values.indexOf(values.reduce((a, b) => a > b ? a : b));

        expect(values[peak], greaterThan(CandyReel.maxBlurSigma / 2));
        expect(values[peak], lessThanOrEqualTo(CandyReel.maxBlurSigma));
        for (var index = 1; index <= peak; index++) {
          expect(values[index], greaterThanOrEqualTo(values[index - 1]));
        }
        for (var index = peak + 1; index < values.length; index++) {
          expect(
            values[index],
            lessThanOrEqualTo(values[index - 1]),
            reason: 'blur rose again at ${index / samples}',
          );
        }
      });
    }

    test('should not blur when the spin has no length', () {
      final motion = ShuffleReelMotion(end: 24, duration: Duration.zero);

      expect(sigmas(motion).every((sigma) => sigma == 0), isTrue);
    });
  });
}
