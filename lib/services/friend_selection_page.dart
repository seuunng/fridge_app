import 'package:flutter/material.dart';
import 'package:food_for_later_new/services/kakao_message_to_freinds.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class FriendSelectionPage extends StatelessWidget {
  final KakaoMessageToFreinds kakaoMessageToFreinds = KakaoMessageToFreinds();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("친구 선택"),
      ),
      body: FutureBuilder<List<Friend>>(
        future: kakaoMessageToFreinds.fetchFriends(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('친구 목록 로드 실패'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('친구가 없습니다'));
          }

          final friends = snapshot.data!;
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(friend.profileThumbnailImage ?? ''),
                ),
                title: Text(friend.profileNickname ?? 'Unknown'),
                onTap: () async {
                  // 친구 선택 시 메시지 전송
                  await kakaoMessageToFreinds.sendMessageToFriends(friend.uuid!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${friend.profileNickname}에게 메시지 전송 완료')),
                  );
                  Navigator.pop(context); // 페이지 닫기
                },
              );
            },
          );
        },
      ),
    );
  }
}
