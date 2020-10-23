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
  final _nothing_todo = "Great! Nothing TODO!";
  final _nothing_done = "Oh! You haven't done anything yet!";

  List<String> _todos = [];
  List<String> _done = [];

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
                    // TODO: make this one sexier to look at and
                    //       add meachnism for deleting and crossing
                    //       out todo items
                    //
                    //       crossing out -> second list with done
                    //       elements
                    //
                    //       ability to move todos around
                    _todos.add(value);
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
      body: Padding(
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
            Text(
              "TODO:",
              style: Theme.of(context).textTheme.headline3,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: _todos.length == 0 ? <Widget>[Text(_nothing_todo)] : _todos.asMap().map((int key, String val) {
                return MapEntry(key, Row(
                  children: <Widget>[
                    Text(val),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _todos.removeAt(key);
                          _done.add(val);
                        });
                      },
                      child: Text("Done"),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _todos.removeAt(key);
                        });
                      },
                      child: Text("Delete"),
                    ),
                  ],
                ));
              }).values.toList(),
            ),
            Text("DONE:",
              style: Theme.of(context).textTheme.headline3,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: _done.length == 0 ? <Widget>[Text(_nothing_done)] : _done.asMap().map((int key, String val) {
                return MapEntry(key, Row(
                  children: <Widget>[
                    Text(val),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _done.removeAt(key);
                          _todos.add(val);
                        });
                      },
                      child: Text("Undone"),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _done.removeAt(key);
                        });
                      },
                      child: Text("Delete"),
                    ),
                  ],
                ));
              }).values.toList(),
            ),
          ],
        ),
      ),
    );
  }
}

