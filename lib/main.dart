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
      home: Yata(),
    );
  }
}

class Yata extends StatefulWidget {
  @override
  _YataState createState() => _YataState();
}

class _YataState extends State<Yata> {
  final _text_controller = new TextEditingController();
  final _scroll_controller = new ScrollController();

  static const _nothing_todo = "Great! Nothing TODO!";
  static const _nothing_done = "Oh! You haven't done anything yet!";

  List<String> _todos = []; //["A", "B", "C", "D", "E", "F", "G", "H"];
  List<String> _done = [];

  FocusNode _focus_node;
  int _index = 0;

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

  generateTODOPage(BuildContext context) {
    return Column(
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
            //       done in its own page (buttomnavigationbar)
            child: ListView.builder(
              padding: EdgeInsets.all(16.0),
              controller: _scroll_controller,
              itemCount: _todos.length,
              itemBuilder: (BuildContext context, int index) {
                return Container(
                  child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Container(
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(),
                          borderRadius: BorderRadius.all(
                            Radius.circular(20)
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: Text(_todos[index])),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _done.insert(0, _todos[index]);
                                  _todos.removeAt(index);
                                });
                              },
                              child: const Icon(Icons.check),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _todos.removeAt(index);
                                });
                              },
                              child: const Icon(Icons.clear),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  generateDonePage(BuildContext context) {
    return Text("DAMN");
  }

  getCurrentPage(BuildContext context) {
    if (_index == 0) {
      return generateTODOPage(context);
    } else if (_index == 1) {
      return generateDonePage(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: getCurrentPage(context),

            /* else if (_index == 1) {
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
            }
          ], */
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialogBoxForAddingTODO(context);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (int index) {
          setState(() {_index = index;});
        },
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_bulleted),
            label: "TODOs",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check),
            label: "Done",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.delete),
            label: "Trash",
          ),
        ],
      ),
    );
  }
}

