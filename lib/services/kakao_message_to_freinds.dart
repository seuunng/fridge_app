import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class KakaoMessageToFreinds {
  Future<List<Friend>> fetchFriends() async {
    try {
      // 카카오톡 친구 목록 가져오기
      Friends friends = await TalkApi.instance.friends();
      print("친구 목록 가져오기 성공: ${friends.elements?.length ?? 0}명");
      return friends.elements ?? [];
    } catch (error) {
      print('친구 목록 가져오기 실패 $error');
      return [];
    }
  }
  Future<void> sendMessageToFriends(String uuid) async {
    try {
      int templateId = 116665; // 템플릿 ID
      await TalkApi.instance.sendCustomMessage(
        receiverUuids: [uuid], // 메시지를 보낼 친구 UUID
        templateId: templateId,
      );
      print('메시지 보내기 성공');
    } catch (error) {
      print('메시지 보내기 실패 $error');
    }
  }
}
