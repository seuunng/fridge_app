/// 사전 정의된 식품 카테고리 순서
const List<String> predefinedCategoryFridge = [
  '채소',
  '과일',
  '육류',
  '수산물',
  '유제품',
  '가공식품',
  '곡류',
  '견과류',
  '양념',
  '음료/주류',
  '즉석식품',
  '디저트/빵류',
];

//레시피 검색용 우선순위
Map<String, int> categoryPriority = {
  "육류": 10,
  "수산물": 9,
  "채소": 8,
  "과일": 7,
  "곡류": 6,
  "유제품": 5,
  "견과류": 5,
  "양념": 4,
  "가공식품": 3,
  "즉석식품": 2,
  "음료/주류": 1,
  "디저트/빵류": 1,
};

final Map<String, String> categoryImages = {
  '유제품': 'dairy_products.svg',
  '디저트/빵류': 'dessert.svg',
  '과일': 'fruits.svg',
  '즉석식품': 'instant.svg',
  '육류': 'meat.svg',
  '견과류': 'nuts.svg',
  '가공식품': 'processed_foods.svg',
  '곡류': 'rice.svg',
  '양념': 'seasoning.svg',
  '음료/주류': 'soft_drink.svg',
  '채소': 'vegetable.svg',
  '수산물': 'seafood.svg',
};