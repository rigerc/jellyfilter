// Renders the website screenshots from the real app widgets with a sample
// library. Run through tool/website_media.sh, not the test suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/discovery/domain/entities/browse_layout.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';

import 'sample_library.dart';

typedef _Scene = ({String name, DiscoverySnapshot snapshot});

const _scenes = <_Scene>[
  (name: 'browse', snapshot: DiscoverySnapshot()),
  (
    name: 'browse-list',
    snapshot: DiscoverySnapshot(browseLayout: BrowseLayout.list),
  ),
  (name: 'swipe', snapshot: DiscoverySnapshot(mode: DiscoveryMode.swipe)),
  (
    name: 'shuffle',
    snapshot: DiscoverySnapshot(
      mode: DiscoveryMode.shuffle,
      currentRevealId: 'phantom',
    ),
  ),
];

void main() {
  setUpAll(loadFonts);

  for (final scene in _scenes) {
    testWidgets('capture ${scene.name}', (tester) async {
      prepareView(tester);
      await tester.pumpWidget(sampleApp(scene.snapshot));
      await settleWithImages(tester);

      final bytes = await capturePng(tester, find.byType(MaterialApp));
      File('$outDir/${scene.name}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    });
  }
}
