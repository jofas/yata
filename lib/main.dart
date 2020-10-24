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
  final _scroll_controller = new ScrollController();

  static const _nothing_todo = "Great! Nothing TODO!";
  static const _nothing_done = "Oh! You haven't done anything yet!";

  List<String> _todos = ["A", "B", "C", "D", "E", "F", "G", "H"];
  List<String> _done = [];

  FocusNode _focus_node;

  @override
  initState() {
    super.initState();
    _focus_node = new FocusNode();
  }

  @override
  dispse() {
    _focus_node.dispose();
    super.dispose();
  }

  addTODO() {
    setState(() {
      if (_text_controller.text.length > 0) {
        Navigator.pop(context);
        _todos.insert(0, _text_controller.text);
        _text_controller.clear();
      } else {
        _focus_node.requestFocus();
      }
    });
  }

  showDialogBoxForAddingTODO(BuildContext context) async {

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        var width = MediaQuery.of(context).size.width;
        return AlertDialog(
          content: Container(
            width: width > 600.0 ? 600.0 : width,
            child: TextField(
              autofocus: true,
              focusNode: _focus_node,
              controller: _text_controller,
              onSubmitted: (String _) {addTODO();},
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter a TODO item",
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _text_controller.clear();
              },
              child: const Text(
                "CANCEL",
              ),
            ),
            ElevatedButton(
              onPressed: () {addTODO();},
              child: const Text(
                "ADD TODO",
              ),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(
              "TODO:",
              style: Theme.of(context).textTheme.headline3,
            ),
            Expanded(
              flex: 2,
              child: _todos.length == 0 ? const Center(child: Text(_nothing_todo)) : Scrollbar(
                controller: _scroll_controller,
                isAlwaysShown: true,
                // TODO: to builder
                //       done in its own page (buttomnavigationbar)
                child: ListView(
                  controller: _scroll_controller,
                  children: _todos.asMap().map((int key, String val) {
                    return MapEntry(
                      key,
                      Container(
                        child: Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Container(
                            decoration: ShapeDecoration(
                              shape: RoundedRectangleBorder(
                                side: BorderSide(),
                                borderRadius: BorderRadius.all(Radius.circular(20)),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(child: Text(val)),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _todos.removeAt(key);
                                        _done.insert(0, val);
                                      });
                                    },
                                    child: const Icon(Icons.check),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _todos.removeAt(key);
                                      });
                                    },
                                    child: const Icon(Icons.clear),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).values.toList(),
                ),
              ),
            ),
            Text(
              "DONE:",
              style: Theme.of(context).textTheme.headline3,
            ),
            Expanded(
              flex: 1,
              child: _done.length == 0 ? const Center(child: Text(_nothing_done)) : Scrollbar(
                controller: _scroll_controller,
                isAlwaysShown: true,
                child: ListView(
                  children: _done.asMap().map((int key, String val) {
                    return MapEntry(key, Row(
                      children: <Widget>[
                        Expanded(child: Text(val)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _done.removeAt(key);
                              _todos.insert(0, val);
                            });
                          },
                          child: const Icon(Icons.restore),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _done.removeAt(key);
                            });
                          },
                          child: const Icon(Icons.clear),
                        ),
                      ],
                    ));
                  }).values.toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialogBoxForAddingTODO(context);
        },
      ),
    );
  }
}

