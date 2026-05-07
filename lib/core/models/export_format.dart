enum ExportFormat {
  csv('.csv', 'CSV'),
  json('.json', 'JSON');

  const ExportFormat(this.extension, this.label);

  final String extension;
  final String label;
}
