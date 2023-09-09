import 'package:de_train/src/screens/chat.dart';
import 'package:de_train/src/utils/const.dart';
import 'package:de_train/src/utils/create_material_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// import 'dart:html' as html;

void main() {
  initializeDateFormatting().then((_) => runApp(const MyApp()));

  return runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
        primarySwatch: createMaterialColor(primaryColor),
      ),
      themeMode: ThemeMode.light,
      // darkTheme: ThemeData(
      //   brightness: Brightness.dark,
      // ),
      home: ChatPage(
        key: UniqueKey(),
      ),
    );
  }
}
