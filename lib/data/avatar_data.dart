class AvatarData {
  final String modelGlb;
  final String modelObj;
  final String texture;
  final String? thumbnail;
  final int seed;

  AvatarData({
    required this.modelGlb,
    required this.modelObj,
    required this.texture,
    this.thumbnail,
    required this.seed,
  });

  factory AvatarData.fromJson(Map<String, dynamic> json) {
    // Print the response for debugging
    print('API Response: $json');

    return AvatarData(
      modelGlb: json['model_glb'] as String? ?? '',
      modelObj: json['model_obj'] as String? ?? '',
      texture: json['texture'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      seed: json['seed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model_glb': modelGlb,
      'model_obj': modelObj,
      'texture': texture,
      'thumbnail': thumbnail,
      'seed': seed,
    };
  }
}
