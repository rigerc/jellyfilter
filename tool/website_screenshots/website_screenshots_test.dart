// Renders the website screenshots from the real app widgets with a sample
// library. Run through tool/website_media.sh, not the test suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/discovery/domain/entities/browse_layout.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';

import 'sample_library.dart';

typedef _Scene = ({
  String name,
  DiscoverySnapshot snapshot,
  CatalogMediaType mediaType,
  Future<void> Function(WidgetTester tester)? act,
});

const _scenes = <_Scene>[
  (
    name: 'browse',
    snapshot: DiscoverySnapshot(),
    mediaType: CatalogMediaType.movie,
    act: null,
  ),
  (
    name: 'browse-list',
    snapshot: DiscoverySnapshot(browseLayout: BrowseLayout.list),
    mediaType: CatalogMediaType.movie,
    act: null,
  ),
  (
    name: 'swipe',
    snapshot: DiscoverySnapshot(mode: DiscoveryMode.swipe),
    mediaType: CatalogMediaType.movie,
    act: null,
  ),
  (
    name: 'shuffle',
    snapshot: DiscoverySnapshot(
      mode: DiscoveryMode.shuffle,
      currentRevealId: 'phantom',
    ),
    mediaType: CatalogMediaType.movie,
    act: null,
  ),
  (
    name: 'shows',
    snapshot: DiscoverySnapshot(),
    mediaType: CatalogMediaType.series,
    act: null,
  ),
  (
    name: 'show-episodes',
    snapshot: DiscoverySnapshot(),
    mediaType: CatalogMediaType.series,
    act: _openEpisodes,
  ),
];

/// Opens Star Trek's details on the Episodes tab.
Future<void> _openEpisodes(WidgetTester tester) async {
  await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('startrek')));
  await settleWithImages(tester);
  await tester.tap(find.byKey(WidgetKeys.discoveryDetailsTab(1)));
  await settleWithImages(tester);
}

void main() {
  setUpAll(loadFonts);

  for (final scene in _scenes) {
    testWidgets('capture ${scene.name}', (tester) async {
      prepareView(tester);
      await tester.pumpWidget(
        sampleApp(scene.snapshot, mediaType: scene.mediaType),
      );
      await settleWithImages(tester);
      await scene.act?.call(tester);

      final bytes = await capturePng(tester, find.byType(MaterialApp));
      File('$outDir/${scene.name}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    });
  }
}
