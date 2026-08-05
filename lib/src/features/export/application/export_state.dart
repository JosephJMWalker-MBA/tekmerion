enum ExportState {
  idle,
  selectingScope,
  collecting,
  verifyingSources,
  generatingData,
  generatingPdf,
  packaging,
  verifyingPackage,
  completed,
  failed
}

class ExportStatus {
  const ExportStatus({
    this.state = ExportState.idle,
    this.progress = 0.0,
    this.message,
    this.exportPackageId,
    this.error,
  });
  final ExportState state;
  final double progress;
  final String? message;
  final String? exportPackageId;
  final String? error;

  ExportStatus copyWith({
    ExportState? state,
    double? progress,
    String? message,
    String? exportPackageId,
    String? error,
  }) {
    return ExportStatus(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      exportPackageId: exportPackageId ?? this.exportPackageId,
      error: error ?? this.error,
    );
  }
}
