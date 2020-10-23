import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const _nothing_todo = "Great! Nothing TODO!";
  static const _nothing_done = "Oh! You haven't done anything yet!";

  List<String> _todos = [];
  List<String> _done = [];

  addTODO(String value) {
    setState(() {
      Navigator.pop(context);
      _text_controller.clear();
      _todos.add(value);
    });
  }

  showDialogBoxWithString(BuildContext context) {
    return (String value) async {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (RawKeyEvent event) {
              if (event.isKeyPressed(LogicalKeyboardKey.enter))
                addTODO(value);
            },
            child: AlertDialog(
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
                  onPressed: () {addTODO(value);},
                  child: const Text(
                    "Yes",
                    style: TextStyle(color: Colors.green),
                  ),
                )
              ],
            ),
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
            Expanded(
              flex: 2,
              child: _todos.length == 0 ? const Center(child: Text(_nothing_todo)) : Scrollbar(
                //isAlwaysShown: true,
                // TODO: to builder
                child: ListView(
                  children: _todos.asMap().map((int key, String val) {
                    return MapEntry(key, Row(
                      // TODO: make this one sexier to look at and
                      //       give this column a fixed size and make todos
                      //       scrollable
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
              ),
            ),
            Text("DONE:",
              style: Theme.of(context).textTheme.headline3,
            ),
            Expanded(
              flex: 1,
              child: _done.length == 0 ? const Center(child: Text(_nothing_done)) : ListView(
                children: _done.asMap().map((int key, String val) {
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
                        child: const Text("Undo"),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _done.removeAt(key);
                          });
                        },
                        child: const Text("Delete"),
                      ),
                    ],
                  ));
                }).values.toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

