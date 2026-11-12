class ComicPreference {
  const ComicPreference({
    required this.comicId,
    this.chapterIndex = 0,
    this.flipReading = false,
  });

  final String comicId;
  final int chapterIndex;
  final bool flipReading;
}
