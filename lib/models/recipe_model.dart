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
  final String? link;  // 웹 레시피 링크 추가

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
    this.link,  // 웹 레시피의 경우 사용
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
      link: data['link'],  // Firestore 데이터에 링크가 있으면 저장
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
      'views': views,
      'date': date,
      'link': link,
    };
  }
  factory RecipeModel.fromWeb({
    required String title,
    required String link,
    required String image,
    required List<String> foods,
  }) {
    return RecipeModel(
      id: '',  // 웹 레시피의 경우 Firestore ID가 없으므로 빈 값
      userID: '',  // 웹 레시피에는 userID가 필요하지 않음
      difficulty: '',  // 웹 레시피는 난이도 정보 없음
      serving: 0,
      time: 0,
      steps: [],
      date: DateTime.now(),
      recipeName: title,
      mainImages: [image],
      rating: 0.0,  // 웹 레시피는 별점 정보가 없으므로 기본값 사용
      foods: foods,
      methods: [],
      themes: [],
      link: link,
    );
  }
}
