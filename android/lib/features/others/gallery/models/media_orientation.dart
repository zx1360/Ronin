int mediaOrientationTurns(double aspectRatio, int currentTurns) {
  if (!aspectRatio.isFinite || aspectRatio <= 0) return currentTurns;
  if (aspectRatio > 1.25) return 1;
  if (aspectRatio < 0.8) return 0;
  return currentTurns;
}
