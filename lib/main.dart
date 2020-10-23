import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final String title = "yata";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _text_controller = new TextEditingController();
  List<Widget> _todos = [];

  showDialogBoxWithString(BuildContext context) {
    return (String value) async {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Text(
              'Are you sure you want to add "$value" to your TODOs?'
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _text_controller.clear();
                },
                child: const Text(
                  "No",
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                    _text_controller.clear();
                    _todos.add(
                        Text(value)
                    );
                  });
                },
                child: const Text(
                  "Yes",
                  style: TextStyle(color: Colors.green),
                ),
              )
            ],
          );
        },
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _text_controller,
                onSubmitted: showDialogBoxWithString(context),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Enter a TODO item",
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: _todos,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

