class MediaErrorHelper {
  MediaErrorHelper._();

  static String toUserMessage(Object error) {
    final raw = error.toString().trim();
    return raw.replaceAll('Exception: ', '');
  }
}
