import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'dart:convert'; // json.encode, json.decode를 위한 패키지
import 'package:http/http.dart' as http; // HTTP 요청을 위한 패키지s

final emailUrl = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

void showShareOptions(
  BuildContext context,
  String fromEmail,
  String toEmail,
  String nickname,
  String recipeName,
  String recipeUrl,
) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '공유하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.chat),
              title: Text('카카오톡으로 공유하기'),
              onTap: () {
                _shareToKakaoTalk(recipeName, recipeUrl);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.link),
              title: Text('링크 복사하기'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: recipeUrl)).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('링크가 복사되었습니다!')),
                  );
                  Navigator.pop(context);
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('메일로 보내기'),
              onTap: () {
                sendEmail(fromEmail, toEmail, nickname, recipeName, recipeUrl);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _shareToKakaoTalk(String recipeName, String recipeUrl) async {
  bool isKakaoTalkSharingAvailable =
      await ShareClient.instance.isKakaoTalkSharingAvailable();
print('recipeUrl $recipeUrl');
  if (isKakaoTalkSharingAvailable) {
    try {
      Uri uri = await ShareClient.instance.shareScrap(url: recipeUrl);
      await ShareClient.instance.launchKakaoTalk(uri);
    } catch (error) {
      print('카카오톡 공유 실패 $error');
    }
  } else {
    try {
      Uri shareUrl = await WebSharerClient.instance
          .makeScrapUrl(url: recipeUrl, templateArgs: {'key1': 'value1'});
      await launchBrowserTab(shareUrl, popupOpen: true);
    } catch (error) {
      print('카카오톡 공유 실패 $error');
    }
  }
}

Future<void> sendEmail(String fromEmail, String toEmail, String nickname,
    String recipeName, String recipeUrl) async {
  const String emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  try {
    final response = await http.post(
      Uri.parse(emailJsUrl),
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': dotenv.env['EMAILJS_SERVICE_ID'],
        'template_id': dotenv.env['RECIPE_TEMPLATE_ID'],
        'user_id': dotenv.env['EMAILJS_USER_ID'],
        'template_params': {
          'from_email': fromEmail,
          'to_email': toEmail,
          'nickname': nickname,
          'recipe_name': recipeName,
          'recipe_url': recipeUrl
        },
      }),
    );
  } catch (e) {
    print('이메일 전송 중 오류 발생: $e');
  }
}
