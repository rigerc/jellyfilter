import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';

/// The kind of title being discovered, as the `kind` that localized strings
/// select on: `movie` or `series`. Rebuilds when the kind changes.
String watchDiscoveryKind(BuildContext context) => context.select(
  (DiscoveryCubit? cubit) => (cubit?.mediaType ?? CatalogMediaType.movie).name,
);

/// [watchDiscoveryKind] for callbacks, where rebuilding is not possible.
String readDiscoveryKind(BuildContext context) =>
    (context.read<DiscoveryCubit?>()?.mediaType ?? CatalogMediaType.movie).name;

/// Whether TV series are being discovered. Rebuilds when that changes.
bool watchDiscoveringSeries(BuildContext context) =>
    watchDiscoveryKind(context) == CatalogMediaType.series.name;
