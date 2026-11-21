// Records a short tour of the app for the website: real widgets, scripted
// touches, and one PNG per 60 fps frame of fake time, so motion is exactly
// smooth. Run through tool/website_media.sh, not the test suite.
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';

import 'sample_library.dart';

const _frameKey = ValueKey<String>('tour-frame');

void main() {
  setUpAll(loadFonts);

  testWidgets('record tour', (tester) async {
    prepareView(tester);
    final touch = ValueNotifier<_Touch?>(null);
    addTearDown(touch.dispose);
    await tester.pumpWidget(
      _TourFrame(touch: touch, child: sampleApp(const DiscoverySnapshot())),
    );
    await settleWithImages(tester);
    await _warmPosters(tester);

    final tour = _Recorder(tester, touch);
    final candidate = WidgetKeys.discoveryCandidate;

    // Browse: scroll the poster grid, then switch to the list.
    await tour.wait(1.2);
    await tour.drag(const Offset(200, 560), const Offset(200, 260), 0.55);
    await tour.wait(1.0);
    await tour.drag(const Offset(200, 260), const Offset(200, 620), 0.5);
    await tour.wait(0.6);
    await tour.tap(find.byKey(WidgetKeys.discoveryBrowseLayoutToggle));
    await tour.wait(1.4);

    // Select two movies, then let go of the selection.
    await tour.longPress(find.byKey(candidate('phantom')));
    await tour.wait(0.5);
    await tour.tap(find.byKey(candidate('safetylast')));
    await tour.wait(1.3);
    await tour.tap(find.byKey(WidgetKeys.discoverySelectionCancel));
    await tour.wait(0.6);
    await tour.tap(find.byKey(WidgetKeys.discoveryBrowseLayoutToggle));
    await tour.wait(0.8);

    // Swipe: like one movie, pass on the next.
    await tour.tap(find.byKey(WidgetKeys.discoverySwipeMode));
    await tour.wait(1.0);
    final deck = tester.getCenter(find.byKey(WidgetKeys.discoverySwipeDeck));
    await tour.drag(deck, deck + const Offset(250, 40), 0.45);
    await tour.wait(1.0);
    await tour.drag(deck, deck + const Offset(-250, 30), 0.45);
    await tour.wait(1.0);

    // Shuffle: spin the reel and let it land.
    await tour.tap(find.byKey(WidgetKeys.discoveryShuffleMode));
    await tour.wait(0.9);
    await tour.tap(find.byKey(WidgetKeys.discoveryRevealButton));
    await tour.wait(
      (CandyMotion.reelSpin + CandyMotion.reelSettle).inMilliseconds / 1000 +
          1.6,
    );

    // Back to Browse, where the tour began, so the video loops.
    await tour.tap(find.byKey(WidgetKeys.discoveryGridMode));
    await tour.wait(1.0);
  });
}

/// Loads every poster size the tour shows, because fake time never lets a
/// real download or decode finish mid-recording.
Future<void> _warmPosters(WidgetTester tester) async {
  final page = tester.widget<DiscoveryPage>(find.byType(DiscoveryPage));
  final context = tester.element(find.byType(DiscoveryPage));
  const variants = <({int width, int quality, int? blur})>[
    (
      width: CandyImages.posterDisplayNetworkWidth,
      quality: CandyImages.posterDisplayQuality,
      blur: null,
    ),
    (
      width: CandyReel.posterNetworkWidth,
      quality: CandyReel.posterQuality,
      blur: null,
    ),
    (
      width: CandyImages.posterThumbnailNetworkWidth,
      quality: CandyImages.posterThumbnailQuality,
      blur: null,
    ),
    (
      width: CandyImages.posterPreviewNetworkWidth,
      quality: CandyImages.posterPreviewQuality,
      blur: CandyImages.posterPreviewBlur,
    ),
  ];
  await tester.runAsync(() async {
    for (final movie in page.cubit.state.candidates) {
      for (final variant in variants) {
        final uri = movie.poster.variantUri(
          maxWidth: variant.width,
          quality: variant.quality,
          blur: variant.blur,
        );
        if (uri == null) {
          continue;
        }
        await precacheImage(
          ResizeImage.resizeIfNeeded(
            variant.width == CandyImages.posterDisplayNetworkWidth
                ? CandyImages.posterCacheWidth
                : variant.width,
            null,
            NetworkImage(uri.toString(), headers: page.imageHeaders),
          ),
          context,
        );
      }
    }
  });
}

/// Where a finger is touching, drawn over the app like a screen recording.
typedef _Touch = ({Offset position, double strength});

final class _TourFrame extends StatelessWidget {
  const _TourFrame({required this.touch, required this.child});

  final ValueNotifier<_Touch?> touch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _frameKey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child,
            IgnorePointer(
              child: ValueListenableBuilder<_Touch?>(
                valueListenable: touch,
                builder: (context, value, _) => value == null
                    ? const SizedBox.shrink()
                    : CustomPaint(painter: _TouchPainter(value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TouchPainter extends CustomPainter {
  const _TouchPainter(this.touch);

  final _Touch touch;

  @override
  void paint(Canvas canvas, Size size) {
    final strength = touch.strength.clamp(0.0, 1.0);
    final radius = lerpDouble(16, 24, strength)!;
    canvas
      ..drawCircle(
        touch.position,
        radius,
        Paint()..color = Colors.white.withValues(alpha: 0.32 * strength),
      )
      ..drawCircle(
        touch.position,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.75 * strength),
      );
  }

  @override
  bool shouldRepaint(_TouchPainter oldDelegate) => oldDelegate.touch != touch;
}

/// Advances fake time one 60 fps frame at a time and saves each frame.
final class _Recorder {
  _Recorder(this.tester, this.touch);

  static const _frame = Duration(microseconds: 16667);
  static const _fps = 60;

  final WidgetTester tester;
  final ValueNotifier<_Touch?> touch;
  Duration _clock = Duration.zero;
  int _index = 0;

  Future<void> _step() async {
    _clock += _frame;
    await tester.pump(_frame);
    final bytes = await capturePng(tester, find.byKey(_frameKey));
    File('$outDir/tour/${_index.toString().padLeft(5, '0')}.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    _index++;
  }

  int _frames(double seconds) => (seconds * _fps).round();

  Future<void> wait(double seconds) async {
    for (var frame = 0; frame < _frames(seconds); frame++) {
      await _step();
    }
  }

  /// Fades the touch mark in or out over a few frames.
  Future<void> _fade(Offset at, {required bool show}) async {
    const frames = 6;
    for (var frame = 1; frame <= frames; frame++) {
      final t = Curves.easeOut.transform(frame / frames);
      touch.value = (position: at, strength: show ? t : 1 - t);
      await _step();
    }
    if (!show) {
      touch.value = null;
    }
  }

  Future<TestGesture> _down(Offset at) async {
    final gesture = await tester.createGesture();
    await gesture.down(at, timeStamp: _clock);
    return gesture;
  }

  Future<void> tap(Finder finder) async {
    final at = tester.getCenter(finder);
    touch.value = (position: at, strength: 0);
    await _fade(at, show: true);
    final gesture = await _down(at);
    await wait(0.08);
    await gesture.up(timeStamp: _clock);
    await _fade(at, show: false);
  }

  Future<void> longPress(Finder finder) async {
    final at = tester.getCenter(finder);
    await _fade(at, show: true);
    final gesture = await _down(at);
    await wait(0.7);
    await gesture.up(timeStamp: _clock);
    await _fade(at, show: false);
  }

  /// Drags with an ease-in so a released card or list keeps its momentum.
  Future<void> drag(Offset from, Offset to, double seconds) async {
    await _fade(from, show: true);
    final gesture = await _down(from);
    final frames = _frames(seconds);
    var at = from;
    for (var frame = 1; frame <= frames; frame++) {
      at = Offset.lerp(from, to, Curves.easeInCubic.transform(frame / frames))!;
      await gesture.moveTo(at, timeStamp: _clock + _frame);
      touch.value = (position: at, strength: 1);
      await _step();
    }
    await gesture.up(timeStamp: _clock);
    await _fade(at, show: false);
  }
}
