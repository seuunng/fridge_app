import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeModel {
  final String id;
  final String userID;
  final String difficulty;
  final int serving;
  final int time;
  final List<String> foods;
  final List<String> themes;
  final List<String> methods;
  final String recipeName;
  final List<Map<String, String>> steps;
  final List<String> mainImages;
  double rating;
  int views;
  DateTime date;

  RecipeModel({
    required this.id,
    required this.userID,
    required this.difficulty,
    required this.serving,
    required this.time,
    required this.foods,
    required this.themes,
    required this.methods,
    required this.recipeName,
    required this.steps,
    required this.mainImages,
    required this.date,
    this.rating = 0.0,
    this.views = 0,
  });

  factory RecipeModel.fromFirestore(Map<String, dynamic> data) {
    List<Map<String, String>> stepsList = [];
    if (data['steps'] != null) {
      stepsList = List<Map<String, String>>.from(
        (data['steps'] as List<dynamic>).map((step) {
          return Map<String, String>.from(step as Map<String, dynamic>);
        }),
      );
    }

    return RecipeModel(
      id: data['ID'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      recipeName: data['recipeName'] ?? '',
      difficulty: data['difficulty'] ?? '',
      serving: data['serving'] ?? 0,
      foods: List<String>.from(data['foods'] ?? []),
      steps: stepsList,
      methods: List<String>.from(data['methods'] ?? []),
      themes: List<String>.from(data['themes'] ?? []),
      time: data['time'] ?? 0,
      userID: data['userID'] ?? '',
      mainImages: List<String>.from(data['mainImages'] ?? []),
      rating: (data['rating'] ?? 0).toDouble(),
      views: data['views'] ?? 0,
    );
  }
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RecipeModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toFirestore() {
    return {
      'ID': id,
      'userID': userID,
      'difficulty': difficulty,
      'serving': serving,
      'time': time,
      'foods': foods,
      'themes': themes,
      'methods': methods,
      'recipeName': recipeName,
      'steps': steps
          .map((step) => {
                'description': step['description'],
                'image': step['image'],
              })
          .toList(),
      'mainImages': mainImages, // 메인사진 저장
      'rating': rating, // 별점 저장
      'views': views,
      'date': date
    };
  }
}
