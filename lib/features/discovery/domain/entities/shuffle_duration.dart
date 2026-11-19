/// Available lengths for a Shuffle spin, independent of platform motion settings.
enum ShuffleDuration {
  instant(Duration.zero),
  halfSecond(Duration(milliseconds: 500)),
  oneSecond(Duration(seconds: 1)),
  standard(Duration(milliseconds: 2400)),
  fourSeconds(Duration(seconds: 4)),
  sixSeconds(Duration(seconds: 6));

  const ShuffleDuration(this.duration);

  final Duration duration;
}
