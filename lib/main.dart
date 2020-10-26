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
  static const _nothing_deleted = "There is nothing here!";

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

  deleteCompletely(int index) {
    setState(() {
      Navigator.pop(context);
      _elements.deleteCompletely(index);
    });
  }

  showDialogBoxForAddingTODO() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        // TODO: this in abstraction
        return AlertDialog(
          content: AlertDialogContentContainer(
            // TODO: this in abstraction
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
            // TODO: this in abstraction
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

  showDialogBoxForDeletingItemCompletely(int index) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return RawKeyboardListener(
          focusNode: _focus_node,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event.logicalKey == LogicalKeyboardKey.enter)
              deleteCompletely(index);
          },
          // TODO: abstract this
          child: AlertDialog(
            content: AlertDialogContentContainer(
              child: Text("Are you sure you want to delete this item?"),
            ),
            actions: <Widget>[
              // TODO: abstract this
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _text_controller.clear();
                },
                child: const Text("CANCEL"),
              ),
              // TODO: abstract this
              ElevatedButton(
                onPressed: () {
                  deleteCompletely(index);
                },
                child: const Text("DELETE"),
              )
            ],
          ),
        );
      }
    );
  }

  getCurrentPage() {
    switch (_index) {
      case 0: return YataPage(
        title: "TODO:",
        defaultText: _nothing_todo,
        elementsList: _elements.todos,
        mainButton: YataButtonTemplate(
          action: (int index) => () {
            setState(() {
              _elements.setDone(index);
            });
          },
          child: const Icon(Icons.check),
        ),
        secondaryButton: YataButtonTemplate(
          action: (int index) => () {
            setState(() {
              _elements.setTODODeleted(index);
            });
          },
          child: const Icon(Icons.clear),
        ),
      );
      case 1: return YataPage(
        title: "Done:",
        defaultText: _nothing_done,
        elementsList: _elements.done,
        mainButton: YataButtonTemplate(
          action: (int index) => () {
            setState(() {
              _elements.setDoneDeleted(index);
            });
          },
          child: const Icon(Icons.clear),
        ),
        secondaryButton: YataButtonTemplate(
          action: (int index) => () {
            setState(() {
              _elements.unsetDone(index);
            });
          },
          child: const Icon(Icons.restore),
        ),
      );
      case 2: return YataPage(
        title: "Deleted:",
        defaultText: _nothing_deleted,
        elementsList: _elements.deleted,
        mainButton: YataButtonTemplate(
          action: (int index) => () {
            showDialogBoxForDeletingItemCompletely(index);
          },
          child: const Icon(Icons.delete),
        ),
        secondaryButton: YataButtonTemplate(
          action: (int index) => () {
            setState(() {
              _elements.unsetDeleted(index);
            });
          },
          child: const Icon(Icons.restore),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: getCurrentPage(),
      ),
      // TODO: FloatingActionButton for delete all
      floatingActionButton: (_index > 0) ? null : FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialogBoxForAddingTODO();
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
            label: "Bin",
          ),
        ],
      ),
    );
  }
}

class YataPage extends StatelessWidget {
  final _scroll_controller = new ScrollController();

  final String title;
  final String defaultText;

  final List<String> elementsList;

  final YataButtonTemplate mainButton;
  final YataButtonTemplate secondaryButton;

  YataPage({
    this.title,
    this.defaultText,
    this.elementsList,
    this.mainButton,
    this.secondaryButton});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.headline3,
        ),
        Expanded(
          child: elementsList.length == 0 ? Center(child: Text(defaultText)) : Scrollbar(
            controller: _scroll_controller,
            isAlwaysShown: true,
            child: ListView.builder(
              padding: EdgeInsets.all(16.0),
              controller: _scroll_controller,
              itemCount: elementsList.length,
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
                            Expanded(child: Text(elementsList[index])),
                            mainButton.generateElevatedButton(index),
                            secondaryButton.generateTextButton(index),
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

typedef YataButtonAction = Null Function() Function(int);

class YataButtonTemplate {
  final Widget child;
  final YataButtonAction action;

  YataButtonTemplate({this.child, this.action});

  generateElevatedButton(int index) {
    return ElevatedButton(
      onPressed: action(index),
      child: child,
    );
  }

  generateTextButton(int index) {
    return TextButton(
      onPressed: action(index),
      child: child,
    );
  }
}

class AlertDialogContentContainer extends Container {
  AlertDialogContentContainer({Widget child}) : super(child:child);

  @override
  build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      width: width > 600.0 ? 600.0 : width,
      child: child,
    );
  }
}
