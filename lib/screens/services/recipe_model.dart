class RecipeRecommendation {
  final String food;
  final String ingredients;
  final String directions;
  final String totalTime;
  final double rating;
  final String servings;

  RecipeRecommendation({
    required this.food,
    required this.ingredients,
    required this.directions,
    required this.totalTime,
    required this.rating,
    required this.servings,
  });

  factory RecipeRecommendation.fromJson(Map<String, dynamic> json) {
    return RecipeRecommendation(
      food: json['food'] ?? 'Unknown',
      ingredients: json['ingredients'] ?? '',
      directions: json['directions'] ?? '',
      totalTime: json['total_time'] ?? '20 mins',
      rating: (json['rating'] ?? 0.0).toDouble(),
      servings: json['servings']?.toString() ?? '1',
    );
  }
} 
