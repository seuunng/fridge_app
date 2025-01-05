import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  final String title;
  final List<String> items;
  final String selectedItem;
  final void Function(String) onItemChanged;
  final void Function(String) onItemDeleted;
  final void Function() onAddNewItem;

  CustomDropdown({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onItemChanged,
    required this.onItemDeleted,
    required this.onAddNewItem,
  });

  @override
  _CustomDropdownState createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  bool _isDropdownOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Spacer(),
            DropdownButton<String>(
              value: widget.items.contains(widget.selectedItem)
                  ? widget.selectedItem
                  : null,
              items: widget.items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface)),
                          if (_isDropdownOpen) ...[
                            Flexible(
                              // Expanded 대신 Flexible을 사용합니다.
                              fit: FlexFit.loose, // 자식이 가용한 공간을 최대한 덜 차지하도록 설정
                              child: Container(), // 여기에 원하는 위젯을 넣을 수 있습니다.
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 16,
                              ),
                              onPressed: () {
                                widget.onItemDeleted(item);
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                );
              }).toList()
                ..add(
                  DropdownMenuItem<String>(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('새 항목 추가'),
                      ],
                    ),
                  ),
                ),
              onChanged: (String? newValue) {
                if (newValue == 'add') {
                  widget.onAddNewItem();
                } else if (newValue != null) {
                  widget.onItemChanged(newValue);
                }
                setState(() {
                  _isDropdownOpen = false; // 선택 시 드롭다운 닫힘
                });
              },
              onTap: () {
                setState(() {
                  _isDropdownOpen = !_isDropdownOpen; // 드롭다운 열림/닫힘 토글
                });
              },
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}
