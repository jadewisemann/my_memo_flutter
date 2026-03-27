import 'package:flutter/material.dart';

import 'ui/theme.dart';
import 'ui/outliner_page.dart';

/// Root MaterialApp configuration for MyMemo.
class MyMemoApp extends StatelessWidget {
  const MyMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyMemo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const OutlinerPage(),
    );
  }
}
