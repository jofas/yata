import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:collection';

void main() {
  runApp(YataApp());
}

class YataApp extends StatelessWidget {
  static const String title = "yata";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<Elements>(create: (_) => Elements()),
          ChangeNotifierProvider<IndexChangeNotifier>(create: (_) => IndexChangeNotifier()),
        ],
        child: Yata(),
      ),
    );
  }
}

class Yata extends StatefulWidget {
  @override
  _YataState createState() => _YataState();
}

class _YataState extends State<Yata> {
  static const _nothingTodo = "Great! Nothing TODO!";
  static const _nothingDone = "Oh! You haven't done anything yet!";
  static const _nothingDeleted = "There is nothing here!";

  MaterialPage _todoPage, _donePage, _deletePage;

  List<MaterialPage> pages; // into ChangeNotifier as well

  FocusNode _focus_node;

  _YataState() {
    _todoPage = MaterialPage(
      maintainState: false,
      child: YataTODOScreen(),
    );

    _donePage = MaterialPage(
      maintainState: false,
      child: YataDoneScreen(),
    );

    _deletePage = MaterialPage(
      maintainState: false,
      child: YataDeleteScreen(),
    );

    pages = [_todoPage];
  }

  @override
  initState() {
    super.initState();
    _focus_node = new FocusNode();
  }

  @override
  dispose() {
    _focus_node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IndexChangeNotifier>(
      builder: (context, indexChangeNotifier, child) {
        switch (indexChangeNotifier.index) {
          case 0: pages.add(_todoPage); break;
          case 1: pages.add(_donePage); break;
          case 2: pages.add(_deletePage); break;
        }

        return Navigator(
          pages: pages.toList(),
          onPopPage: (route, result) {
            if (!route.didPop(result))
              return false;
            pages.removeLast();
            return true;
          },
        );
      },
    );
  }
}

class YataTODOScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return YataScreen(
      title: "TODOs:",
      defaultText: "Great! Nothing TODO!",
      elementsList: ElementsList.todos,
      mainButton: YataButtonTemplate(
        action: (elements, int index) => elements.setDone(index),
        child: const Icon(Icons.check),
      ),
      secondaryButton: YataButtonTemplate(
        action: (elements, int index) => elements.setTODODeleted(index),
        child: const Icon(Icons.clear),
      ),
      floatingActionButton: Consumer<Elements>(
        builder: (context, elements, child) {
          return FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => showDialogBoxForAddingTODO(context, elements),
          );
        },
      ),
    );
  }

  showDialogBoxForAddingTODO(context, elements) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        var textController = TextEditingController();
        var focusNode = FocusNode();
        var addTODO = () {
          if (textController.text.length > 0) {
            Navigator.pop(context);
            elements.addTODO(textController.text);
            textController.clear();
          } else {
            focusNode.requestFocus();
          }
        };

        return AlertDialog(
          content: AlertDialogContentContainer(
            child: TextField(
              autofocus: true,
              focusNode: focusNode,
              controller: textController,
              onSubmitted: (_) => addTODO(),
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
                textController.clear();
              },
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () => addTODO(),
              child: const Text("ADD TODO"),
            )
          ],
        );
      }
    );
  }
}

class YataDoneScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return YataScreen(
      title: "Done:",
      defaultText: "Oh! You haven't done anything yet!",
      elementsList: ElementsList.done,
      mainButton: YataButtonTemplate(
        action: (elements, int index) => elements.setDoneDeleted(index),
        child: const Icon(Icons.clear),
      ),
      secondaryButton: YataButtonTemplate(
        action: (elements, int index) => elements.unsetDone(index),
        child: const Icon(Icons.restore),
      ),
    );
  }
}

class YataDeleteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return YataScreen(
      title: "Deleted:",
      defaultText: "There is nothing here!",
      elementsList: ElementsList.deleted,
      mainButton: YataButtonTemplate(
        action: (elements, int index) {
          showDialogBoxForDeleting(context, elements, index: index);
        },
        child: const Icon(Icons.delete),
      ),
      secondaryButton: YataButtonTemplate(
        action: (elements, int index) => elements.unsetDeleted(index),
        child: const Icon(Icons.restore),
      ),
      floatingActionButton: Consumer<Elements>(
        builder: (context, elements, child) {
          if (elements.getList(ElementsList.deleted).length == 0)
            return Container();

          return FloatingActionButton(
            child: const Icon(Icons.delete),
            onPressed: () => showDialogBoxForDeleting(context, elements),
          );
        },
      ),
    );
  }

  showDialogBoxForDeleting(context, elements, {int index: null}) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        var focusNode = FocusNode();
        var deleteCompletely = () {
          Navigator.pop(context);
          index == null ?
            elements.deleteAllCompletely() : elements.deleteCompletely(index);
        };

        return RawKeyboardListener(
          focusNode: focusNode,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event.logicalKey == LogicalKeyboardKey.enter)
              deleteCompletely();
          },
          child: AlertDialog(
            content: AlertDialogContentContainer(
              child: index == null ?
                Text("Are you sure you want to delete all items in the bin?") :
                Text("Are you sure you want to delete this item?"),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () => deleteCompletely(),
                child: const Text("DELETE"),
              )
            ],
          ),
        );
      }
    );
  }

}

class YataScreen extends StatelessWidget {
  final _scrollController = new ScrollController();

  final String title;
  final String defaultText;

  final ElementsList elementsList;

  final YataButtonTemplate mainButton;
  final YataButtonTemplate secondaryButton;

  final ValueChanged<int> onTap;

  final floatingActionButton;

  YataScreen({
    this.title,
    this.defaultText,
    this.elementsList,
    this.mainButton,
    this.secondaryButton,
    this.onTap,
    this.floatingActionButton: null});

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
                    controller: _scrollController,
                    isAlwaysShown: true,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.0),
                      controller: _scrollController,
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
                                    mainButton.generateElevatedButton(elements, index),
                                    secondaryButton.generateTextButton(elements, index),
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
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: Consumer<IndexChangeNotifier>(
        builder: (context, indexChangeNotifier, child) {
          return BottomNavigationBar(
            currentIndex: elementsList.index,
            onTap: (int index) {
              indexChangeNotifier.notifyIfChanged(index);
            },
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
          );
        },
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
  List<String> _todos = [];
  List<String> _done = [];
  List<String> _deleted = [];

  getList(ElementsList list) {
    switch (list) {
      case ElementsList.todos: return UnmodifiableListView(_todos);
      case ElementsList.done: return UnmodifiableListView(_done);
      case ElementsList.deleted: return UnmodifiableListView(_deleted);
    }
  }

  addTODO(String value) {
    _todos.insert(0, value);
    notifyListeners();
  }

  setDone(int index) => _move(_todos, _done, index);

  unsetDone(int index) => _move(_done, _todos, index);

  setTODODeleted(int index) => _move(_todos, _deleted, index);

  setDoneDeleted(int index) => _move(_done, _deleted, index);

  unsetDeleted(int index) => _move(_deleted, _todos, index);

  deleteCompletely(int index) {
    _deleted.removeAt(index);
    notifyListeners();
  }

  deleteAllCompletely() {
    _deleted = [];
    notifyListeners();
  }

  _move(src, dest, int index) {
    dest.insert(0, src[index]);
    src.removeAt(index);
    notifyListeners();
  }
}

class IndexChangeNotifier with ChangeNotifier {
  int index = 0;

  notifyIfChanged(int newIndex) {
    if (index != newIndex) {
      index = newIndex;
      notifyListeners();
    }
  }
}

class YataButtonTemplate {
  final Widget child;
  final Function(Elements, int) action;

  YataButtonTemplate({this.child, this.action});

  generateElevatedButton(elements, int index) {
    return ElevatedButton(
      onPressed: () => action(elements, index),
      child: child,
    );
  }

  generateTextButton(elements, int index) {
    return TextButton(
      onPressed: () => action(elements, index),
      child: child,
    );
  }
}
