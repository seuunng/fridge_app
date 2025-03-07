import 'dart:math';

// 랜덤 별명 생성기
String generateRandomNickname() {
  final List<String> adjectives = [
    "행복한 ", "푸른 ", "밝은 ", "용감한 ", "멋진 ", "부드러운 ", "깨끗한 ", "귀여운 ", "따뜻한 ", "재미있는 ",
    "상냥한 ", "활기찬 ", "빛나는 ", "다정한 ", "깜찍한 ", "든든한 ", "우아한 ", "고요한 ", "아름다운 ", "목마른 ",
    "졸린 ", "신나는 ", "궁금한 ", "날고싶은 ", "쉬고싶은 ", "숨고싶은 ", "부끄러운 ", "똑똑한 ", "느긋한 ",
    "엉뚱한 ", "쫄깃쫄깃한 ", "느끼한 ", "화끈한 ", "반짝이는 ",
  ];

  final List<String> nouns = [
    "마카롱", "바게트", "햄버거", "소다캔", "주전자", "바나나", "당근", "초코칩", "치즈볼", "구름빵",
    "솜사탕", "치타", "다람쥐", "오리너구리", "젤리곰", "피카츄", "루돌프", "까마귀", "코뿔소", "아이스크림",
    "붕어빵", "삐약이", "알약", "팝콘", "만두왕", "감자칩", "마요네즈", "호빵맨", "콩나물", "초코우유",
    "라면왕", "찜닭", "꿀떡", "비빔밥", "고구마", "떡볶이", "버블티", "감자튀김", "쥬스박스", "피자조각",
  ];

  final random = Random();
  final randomAdjective = adjectives[random.nextInt(adjectives.length)];
  final randomNoun = nouns[random.nextInt(nouns.length)];

  return '$randomAdjective$randomNoun';
}