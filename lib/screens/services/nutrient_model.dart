import 'package:cloud_firestore/cloud_firestore.dart';

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final String mealType;   
  final DateTime timestamp; 

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    required this.mealType,
    required this.timestamp,
  });

  factory FoodEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawTimestamp = data['timestamp'] ?? data['createdAt']; 

    return FoodEntry(
      id: doc.id,
      name: data['name']?.toString() ?? 'Unknown Food',
      calories: (data['calories'] is int) ? data['calories'] : int.tryParse(data['calories']?.toString() ?? '0') ?? 0,
      protein: (data['protein'] is num) ? (data['protein'] as num).toDouble() : double.tryParse(data['protein']?.toString() ?? '0.0') ?? 0.0,
      carbs: (data['carbs'] is num) ? (data['carbs'] as num).toDouble() : double.tryParse(data['carbs']?.toString() ?? '0.0') ?? 0.0,
      sugar: (data['sugar'] is num) ? (data['sugar'] as num).toDouble() : double.tryParse(data['sugar']?.toString() ?? '0.0') ?? 0.0,
      fat: (data['fat'] is num) ? (data['fat'] as num).toDouble() : double.tryParse(data['fat']?.toString() ?? '0.0') ?? 0.0,
      mealType: data['mealType']?.toString() ?? 'Breakfast', 
      timestamp: (rawTimestamp is Timestamp) 
          ? rawTimestamp.toDate() 
          : DateTime.tryParse(rawTimestamp?.toString() ?? '') ?? DateTime.now(),
    );
  }

  // Method for converting Dart Object to a Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'sugar': sugar,
      'mealType': mealType, 
      'timestamp': FieldValue.serverTimestamp(), 
    };
  }
}