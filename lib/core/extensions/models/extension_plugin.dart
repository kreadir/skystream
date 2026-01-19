class ExtensionPlugin {
  final String id;             // Unique Plugin ID (e.g. "com.hexated.superstream")
  final String name;           // Display Name (e.g. "SuperStream")
  final String internalName;   // Internal Class Name (e.g. "SuperStream")
  final String repositoryId;   // "com.hexated" or "LocalAssets"
  final String sourceUrl;      // Download Link or Local Path
  final int version;
  final String? iconUrl;
  
  // Metadata (Native Parity)
  final List<String> authors;  // e.g. ["Hexated"]
  final String? description;   // e.g. "Watch movies and TV shows"
  final List<String>? tvTypes; // e.g. ["TvType.Movie", "TvType.Anime"]
  final String? language;      // e.g. "en"
  final int? fileSize;         // In bytes
  final int status; // 0: Down, 1: Ok, 2: Slow, 3: Beta

  ExtensionPlugin({
    required this.id,
    required this.name,
    required this.internalName,
    required this.repositoryId,
    required this.sourceUrl,
    required this.version,
    this.status = 1,
    this.iconUrl,
    this.authors = const [],
    this.description,
    this.tvTypes,
    this.language,
    this.fileSize,
  });

  /// The Globally Unique ID
  String get packageId => id;
  
  /// Helper to check if this is a debug/asset plugin
  bool get isDebug => id.endsWith('.debug');

  /// Local File Path relative to plugin root
  /// e.g. "plugin/[id]/plugin.js"
  /// Updated to use ID as directory name for uniqueness
  String get filePath => "$repositoryId/$id/plugin.js";

  /// Factory constructor to parse from JSON (SitePlugin format or meta.json)
  factory ExtensionPlugin.fromJson(Map<String, dynamic> json, String repositoryId) {
    // Legacy fallback: valid internalName or name
    final internal = json['internalName'] as String? ?? 'UnknownInternalName';
    final fallbackId = "$repositoryId.$internal";

    return ExtensionPlugin(
      id: json['id'] as String? ?? fallbackId,
      name: json['name'] as String? ?? 'Unknown Plugin',
      internalName: internal,
      repositoryId: repositoryId,
      sourceUrl: json['url'] as String? ?? '',
      version: json['version'] as int? ?? 0,
      status: json['status'] as int? ?? 1,
      iconUrl: json['iconUrl'] as String?,
      authors: (json['authors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'] as String?,
      tvTypes: (json['tvTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      language: json['language'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }
}
