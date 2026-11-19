import 'package:flutter/material.dart';
import 'package:jellyfin_picker/core/media/entities/catalog_filter.dart';
import 'package:jellyfin_picker/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_filter_sections.dart';

typedef DiscoveryQueryFilterData = ({
  TextEditingController searchController,
  List<CatalogLibrary> libraries,
  String? libraryId,
  CatalogSort sort,
  bool sortReversed,
  CatalogAddedWindow? addedWithin,
  ValueChanged<CatalogSort> onSortChanged,
  ValueChanged<bool> onSortReversedChanged,
  ValueChanged<String?> onLibraryChanged,
  ValueChanged<CatalogAddedWindow?> onAddedWithinChanged,
});

typedef DiscoveryQuickFilterData = ({
  bool recent,
  bool unwatched,
  bool favorites,
  ValueChanged<bool> onRecentChanged,
  ValueChanged<bool> onUnwatchedChanged,
  ValueChanged<bool> onFavoritesChanged,
});

typedef DiscoveryRatingFilterData = ({
  RangeValues runtime,
  double community,
  double critic,
  ValueChanged<RangeValues> onRuntimeChanged,
  ValueChanged<double> onCommunityChanged,
  ValueChanged<double> onCriticChanged,
});

typedef DiscoveryMetadataFilterData = ({
  TextEditingController genresController,
  DiscoveryFacetSelection<String> genres,
  DiscoveryFacetSelection<String> tags,
  DiscoveryFacetSelection<int> decades,
  DiscoveryFacetSelection<String> officialRatings,
  DiscoveryTriState watched,
  DiscoveryTriState favorite,
  List<String> availableGenres,
  List<String> availableTags,
  List<int> availableDecades,
  List<String> availableRatings,
  VoidCallback onSelectionChanged,
  ValueChanged<DiscoveryTriState> onWatchedChanged,
  ValueChanged<DiscoveryTriState> onFavoriteChanged,
});

typedef DiscoveryPresetFilterData = ({
  TextEditingController nameController,
  Map<String, CatalogFilter> presets,
  ValueChanged<String> onApply,
  VoidCallback onSave,
});
