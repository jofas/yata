import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:collection';

void main() {
  runApp(Yata());
}

class Yata extends StatefulWidget {
  @override
  _YataState createState() => _YataState();
}

class _YataState extends State<Yata> {
  static const String _title = "yata";

  final _text_controller = new TextEditingController();
  final _scroll_controller = new ScrollController();

  static const _nothing_todo = "Great! Nothing TODO!";
  static const _nothing_done = "Oh! You haven't done anything yet!";
  static const _nothing_deleted = "There is nothing here!";

  MaterialPage _todoPage, _donePage, _deletePage;

  List<MaterialPage> pages;

  FocusNode _focus_node;
  int _index = 0;

  _YataState() {
    _todoPage = MaterialPage(
      maintainState: false,
      child: YataPage(
        index: 0,
        title: "TODO:",
        defaultText: _nothing_todo,
        elementsList: ElementsList.todos,
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
        onTap: onTap,
      ),
    );

    _donePage = MaterialPage(
      maintainState: false,
      child: YataPage(
        index: 1,
        title: "Done:",
        defaultText: _nothing_done,
        elementsList: ElementsList.done,
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
        onTap: onTap,
      ),
    );

    _deletePage = MaterialPage(
      maintainState: false,
      child: YataPage(
        index: 2,
        title: "Deleted:",
        defaultText: _nothing_deleted,
        elementsList: ElementsList.deleted,
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
        onTap: onTap,
      ),
    );

    pages = [_todoPage];
  }

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChangeNotifierProvider<Elements>(
        create: (context) => Elements(),
        child: Navigator(
          pages: pages.toList(),
          onPopPage: (route, result) {
            if (!route.didPop(result))
              return false;

            setState(() {
              pages.removeLast();
            });

            return true;
          },
        ),
      ),
    );
  }

  onTap(int index) {
    if (_index != index)
      setState(() {
        _index = index;
        switch (_index) {
          case 0: pages.add(_todoPage); break;
          case 1: pages.add(_donePage); break;
          case 2: pages.add(_deletePage); break;
        }
      });
  }

  /*
  getFloatingActionButton() {
    if (_index == 0) {
      return FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialogBoxForAddingTODO();
        },
      );
    }

    if (_index == 2 && _elements.deleted.length > 0) {
      return FloatingActionButton(
        child: const Icon(Icons.delete),
        onPressed: () {
          showDialogBoxForDeletingAllItemsCompletely();
        },
      );
    }
  }

  showDialogBoxForAddingTODO() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: AlertDialogContentContainer(
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

  showDialogBoxForDeletingItemCompletely(int index) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return RawKeyboardListener(
          focusNode: _focus_node,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event.logicalKey == LogicalKeyboardKey.enter)
              deleteCompletely(index: index);
          },
          child: AlertDialog(
            content: AlertDialogContentContainer(
              child: Text("Are you sure you want to delete this item?"),
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
                onPressed: () {
                  deleteCompletely(index: index);
                },
                child: const Text("DELETE"),
              )
            ],
          ),
        );
      }
    );
  }

  showDialogBoxForDeletingAllItemsCompletely() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return RawKeyboardListener(
          focusNode: _focus_node,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event.logicalKey == LogicalKeyboardKey.enter)
              deleteCompletely();
          },
          child: AlertDialog(
            content: AlertDialogContentContainer(
              child: Text("Are you sure you want to delete all items in the bin?"),
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
                onPressed: () {
                  deleteCompletely();
                },
                child: const Text("DELETE"),
              )
            ],
          ),
        );
      }
    );
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

  deleteCompletely({int index}) {
    setState(() {
      Navigator.pop(context);
      index == null ?
        _elements.deleteAllCompletely() :
        _elements.deleteCompletely(index);
    });
  }
  */
}

class YataPage extends StatelessWidget {
  final _scroll_controller = new ScrollController();

  final int index;

  final String title;
  final String defaultText;

  final ElementsList elementsList;

  final YataButtonTemplate mainButton;
  final YataButtonTemplate secondaryButton;

  final ValueChanged<int> onTap;

  YataPage({
    this.index,
    this.title,
    this.defaultText,
    this.elementsList,
    this.mainButton,
    this.secondaryButton,
    this.onTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.headline3,
            ),
            Expanded(
              child: Consumer<Elements>(
                builder: (context, elements, child) {
                  final items = elements.getList(elementsList);

                  return items.length == 0 ? Center(child: Text(defaultText)) : Scrollbar(
                    controller: _scroll_controller,
                    isAlwaysShown: true,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.0),
                      controller: _scroll_controller,
                      itemCount: items.length,
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
                                    Expanded(child: Text(items[index])),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
      //floatingActionButton: getFloatingActionButton(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: onTap,
        items: const <BottomNavigationBarItem>[
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

// TODO: back to something normal (StatelessWidget)
class AlertDialogContentContainer extends Container {
  AlertDialogContentContainer({Widget child}) : super(child:child);

  @override
  BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    this.constraints = BoxConstraints.tightFor(
      width: width > 600.0 ? 600.0 : width
    );
    return super.build(context);
  }
}

enum ElementsList { todos, done, deleted }

class Elements with ChangeNotifier {
  List<String> todos = [];
  List<String> done = [];
  List<String> deleted = [];

  getList(ElementsList list) {
    switch (list) {
      case ElementsList.todos: return UnmodifiableListView(todos);
      case ElementsList.done: return UnmodifiableListView(done);
      case ElementsList.deleted: return UnmodifiableListView(deleted);
    }
  }

  addTODO(String value) {
    todos.insert(0, value);
    notifyListeners();
  }

  setDone(int index) => _move(todos, done, index);

  unsetDone(int index) => _move(done, todos, index);

  setTODODeleted(int index) => _move(todos, deleted, index);

  setDoneDeleted(int index) => _move(done, deleted, index);

  unsetDeleted(int index) => _move(deleted, todos, index);

  deleteCompletely(int index) {
    deleted.removeAt(index);
    notifyListeners();
  }

  deleteAllCompletely() {
    deleted = [];
    notifyListeners();
  }

  _move(src, dest, int index) {
    dest.insert(0, src[index]);
    src.removeAt(index);
    notifyListeners();
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
