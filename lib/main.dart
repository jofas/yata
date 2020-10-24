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

  Elements _elements = new Elements();

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
        _elements.addTODO(_text_controller.text);
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
              onSubmitted: (_) {addTODO();},
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
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () {addTODO();},
              child: const Text("ADD TODO"),
            )
          ],
        );
      }
    );
  }

  // TODO: abstract this thing into its own class
  generateTODOPage(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(
          "TODO:",
          style: Theme.of(context).textTheme.headline3,
        ),
        Expanded(
          child: _elements.todos.length == 0 ? const Center(child: Text(_nothing_todo)) : Scrollbar(
            controller: _scroll_controller,
            isAlwaysShown: true,
            child: ListView.builder(
              padding: EdgeInsets.all(16.0),
              controller: _scroll_controller,
              itemCount: _elements.todos.length,
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
                            Expanded(child: Text(_elements.todos[index])),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _elements.setDone(index);
                                });
                              },
                              child: const Icon(Icons.check),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _elements.setTODODeleted(index);
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(
          "DONE:",
          style: Theme.of(context).textTheme.headline3,
        ),
        Expanded(
          flex: 1,
          child: _elements.done.length == 0 ? const Center(child: Text(_nothing_done)) : Scrollbar(
            controller: _scroll_controller,
            isAlwaysShown: true,
            child: ListView(
              children: _elements.done.asMap().map((int key, String val) {
                return MapEntry(key, Row(
                  children: <Widget>[
                    Expanded(child: Text(val)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _elements.unsetDone(key);
                        });
                      },
                      child: const Icon(Icons.restore),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _elements.setDoneDeleted(key);
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
    );
  }

  getCurrentPage(BuildContext context) {
    if (_index == 0) {
      return generateTODOPage(context);
    } else if (_index == 1) {
      return generateDonePage(context);
    } else {
      return Text("OK");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: getCurrentPage(context),
      ),
      // TODO: show this only on first page
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

class Elements {
  final List<String> todos = [];
  final List<String> done = [];
  final List<String> deleted = [];

  addTODO(String value) => todos.insert(0, value);

  setDone(int index) => _move(todos, done, index);

  unsetDone(int index) => _move(done, todos, index);

  setTODODeleted(int index) => _move(todos, deleted, index);

  setDoneDeleted(int index) => _move(done, deleted, index);

  unsetDeleted(int index) => _move(deleted, todos, index);

  deleteCompletely(int index) {
    deleted.removeAt(index);
  }

  _move(src, dest, int index) {
    dest.insert(0, src[index]);
    src.removeAt(index);
  }
}

class YataPage extends StatelessWidget {
  final _scroll_controller = new ScrollController();

  final String _title;
  final String _default_text;

  final List<String> _list;

  // TODO: abstract into own class
  final VoidCallback _main_button_action;
  final VoidCallback _secondary_button_action;

  final IconData _main_button_icon;
  final IconData _secondary_button_icon;

  YataPage(this._title, this._default_text, this._list,
      this._main_button_action, this._secondary_button_action,
      this._main_button_icon, this._secondary_button_icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(
          "TODO:",
          style: Theme.of(context).textTheme.headline3,
        ),
        Expanded(
          child: _list.length == 0 ? Center(child: Text(_default_text)) : Scrollbar(
            controller: _scroll_controller,
            isAlwaysShown: true,
            child: ListView.builder(
              padding: EdgeInsets.all(16.0),
              controller: _scroll_controller,
              itemCount: _list.length,
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
                            Expanded(child: Text(_list[index])),
                            // TODO: I need to supply Icon and callback
                            ElevatedButton(
                              onPressed: _main_button_action,
                              /*
                              () {
                                setState(() {
                                  _elements.setDone(index);
                                });
                              },
                              */
                              child: Icon(_main_button_icon),
                            ),
                            TextButton(
                              onPressed: _secondary_button_action,
                              /*
                              () {
                                setState(() {
                                  _elements.setTODODeleted(index);
                                });
                              },
                              */
                              child: Icon(_secondary_button_icon),
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
}
