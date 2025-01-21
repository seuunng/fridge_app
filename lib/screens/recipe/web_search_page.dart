
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http; // HTTP 요청 처리
import 'package:webview_flutter/webview_flutter.dart'; // WebView 사용

class WebSearchPage extends StatefulWidget {
  @override
  _WebSearchPageState createState() => _WebSearchPageState();
}

class _WebSearchPageState extends State<WebSearchPage> {
  WebViewController? _controller;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  @override
  void initState() {
    super.initState();
    // WebViewController 초기화
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://www.google.com'));
  }


  // void _performSearch(String query) async {
  //   try {
  //     final results = await fetchSearchResults(query);
  //     setState(() {
  //       _results = results;
  //     });
  //   } catch (e) {
  //     print('Error fetching search results: $e');
  //   }
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
      ),
      body: _controller == null
          ? Center(child: CircularProgressIndicator()) // 컨트롤러 초기화 전 로딩 표시
          : WebViewWidget(controller: _controller!),
      // Column(
      //   children: [
      //     Padding(
      //       padding: const EdgeInsets.all(8.0),
      //       child: Row(
      //         children: [
      //           Expanded(
      //             child: TextField(
      //               controller: _searchController,
      //               decoration: InputDecoration(
      //                 hintText: 'Enter search keyword',
      //                 border: OutlineInputBorder(),
      //               ),
      //               onSubmitted: (value) {
      //                 _performSearch(value);
      //               },
      //             ),
      //           ),
      //           IconButton(
      //             icon: Icon(Icons.search),
      //             onPressed: () {
      //               _performSearch(_searchController.text);
      //             },
      //           ),
      //         ],
      //       ),
      //     ),
      //     Expanded(
      //       child: _results.isEmpty
      //           ? Center(child: Text('No results found'))
      //           : ListView.builder(
      //         itemCount: _results.length,
      //         itemBuilder: (context, index) {
      //           final result = _results[index];
      //           return ListTile(
      //             title: Text(result['title'] ?? 'No title'),
      //             subtitle: Text(result['snippet'] ?? 'No description'),
      //             onTap: () {
      //               // 웹 페이지 열기
      //               if (result['link'] != null) {
      //                 Navigator.push(
      //                   context,
      //                   MaterialPageRoute(
      //                     builder: (context) => WebView(
      //                       initialUrl: result['link'],
      //                       javascriptMode:
      //                       JavascriptMode.unrestricted,
      //                     ),
      //                   ),
      //                 );
      //               }
      //             },
      //           );
      //         },
      //       ),
      //     ),
      //   ],
      // ),
    );
  }
}