import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:collection';
import 'dart:io';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(YataApp());
}

class YataApp extends StatelessWidget {
  static const String title = "yata";

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: "/",
      getPages: [
        GetPage(name: "/", page: () => YataTODOScreen()),
        GetPage(name: "/todo", page: () => YataTODOScreen()),
        GetPage(name: "/done", page: () => YataDoneScreen()),
        GetPage(name: "/bin", page: () => YataDeleteScreen()),
      ],
    );
  }
}

class YataTODOScreen extends StatelessWidget {
  ElementsController controller;

  YataTODOScreen() :  controller = getElementsController();

  @override
  Widget build(BuildContext context) {
    return YataScreen(
      title: "TODOs:",
      defaultText: "Great! Nothing TODO!",
      elementsList: ElementsList.todos,
      mainButton: YataButtonTemplate(
        action: (int index) => controller.setDone(index),
        child: const Icon(Icons.check),
      ),
      secondaryButton: YataButtonTemplate(
        action: (int index) => controller.setTODODeleted(index),
        child: const Icon(Icons.clear),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.dialog(dialogForAddingTODO()),
        child: const Icon(Icons.add),
      ),
    );
  }

  dialogForAddingTODO() {
    var textController = TextEditingController();
    var focusNode = FocusNode();

    var addTODO = () {
      if (textController.text.length > 0) {
        controller.addTODO(textController.text);
        Get.back();
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
          onPressed: () => Get.back(),
          child: const Text("CANCEL"),
        ),
        ElevatedButton(
          onPressed: () => addTODO(),
          child: const Text("ADD TODO"),
        )
      ],
    );
  }
}

class YataDoneScreen extends StatelessWidget {
  ElementsController controller;

  YataDoneScreen() : controller = getElementsController();

  @override
  Widget build(BuildContext context) {
    return YataScreen(
      title: "Done:",
      defaultText: "Oh! You haven't done anything yet!",
      elementsList: ElementsList.done,
      mainButton: YataButtonTemplate(
        action: (int index) => controller.setDoneDeleted(index),
        child: const Icon(Icons.clear),
      ),
      secondaryButton: YataButtonTemplate(
        action: (int index) => controller.unsetDone(index),
        child: const Icon(Icons.restore),
      ),
    );
  }
}

class YataDeleteScreen extends StatelessWidget {
  ElementsController controller;

  YataDeleteScreen() : controller = getElementsController();

  @override
  Widget build(BuildContext context) {
    return YataScreen(
      title: "Deleted:",
      defaultText: "There is nothing here!",
      elementsList: ElementsList.deleted,
      mainButton: YataButtonTemplate(
        action: (int index) => Get.dialog(dialogForDeleting(index: index)),
        child: const Icon(Icons.delete),
      ),
      secondaryButton: YataButtonTemplate(
        action: (int index) => controller.unsetDeleted(index),
        child: const Icon(Icons.restore),
      ),
      floatingActionButton: Obx(() =>
        controller.getList(ElementsList.deleted).length > 0 ?
          FloatingActionButton(
            child: const Icon(Icons.delete),
            onPressed: () => Get.dialog(dialogForDeleting()),
          ) : Container()),
    );
  }

  dialogForDeleting({int index: null}) {
    var focusNode = FocusNode();

    var deleteCompletely = () {
      index == null ?
        controller.deleteAllCompletely() : controller.deleteCompletely(index);
      Get.back();
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
            onPressed: () => Get.back(),
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
}

class YataScreen extends StatelessWidget {
  final ElementsController controller = Get.find();
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
              child: Obx(() {
                var items = controller.getList(elementsList);
                var len = items.length;

                return len == 0 ? Center(child: Text(defaultText)) : Scrollbar(
                  controller: _scrollController,
                  isAlwaysShown: true,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.0),
                    controller: _scrollController,
                    itemCount: len,
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
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: elementsList.index,
        onTap: (int index) {
          if (index != elementsList.index)
            controller.routeByIndex(index);
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
      ),
    );
  }
}

class AlertDialogContentContainer extends StatelessWidget {
  final Widget child;

  AlertDialogContentContainer({this.child});

  @override
  Widget build(BuildContext context) {
    final width = Get.width > 600.0 ? 600.0 : Get.width;
    return Container(child: child, width: width);
  }
}

ElementsController getElementsController() {
  ElementsController controller;

  try {
    controller = Get.find();
  } catch (_) {
    controller = Get.put(ElementsController());
    // TODO: loading screen while this is processing
    //       (put this into build or something (wrap with Obx maybe))
    //
    //        ListBuilder elements from Row to Card

    var client = http.Client();

    client.post(
      "http://localhost:9999/todos",
      headers: {"content-type": "application/json"},
      body: jsonEncode({"value": "testy"})
    ).then((response) {
      print("Got Response: ${response.statusCode}");
      print("Got Response: ${response.body}");
    });

    client.get("http://localhost:9999/").then((response) {
      controller.setElementsFromJsonString(response.body);
      print("Gotten Elements from server");
      print("Gotten Elements from server: ${response.body}");

      client.close();
    });

  }

  return controller;
}

class ElementsController extends GetxController {
  final elements = Elements().obs;

  getList(ElementsList list) => elements.value.getList(list);

  routeByIndex(int index) {
    switch (index) {
      case 0: Get.toNamed("/todo"); break;
      case 1: Get.toNamed("/done"); break;
      case 2: Get.toNamed("/bin"); break;
    }
  }

  setElementsFromJsonString(String jsonString) {
    var jsonElements = jsonDecode(jsonString);

    elements.value.todos = List<String>.from(jsonElements["todos"]);
    elements.value.done = List<String>.from(jsonElements["done"]);
    elements.value.deleted = List<String>.from(jsonElements["deleted"]);

    elements.refresh();
  }

  // TODO: evertime I call refresh I also need to send the server
  //       an updated state

  addTODO(String value) {
    elements.value.addTODO(value);
    elements.refresh();
  }

  setDone(int index) {
    elements.value.setDone(index);
    elements.refresh();
  }

  unsetDone(int index) {
    elements.value.unsetDone(index);
    elements.refresh();
  }

  setTODODeleted(int index) {
    elements.value.setTODODeleted(index);
    elements.refresh();
  }

  setDoneDeleted(int index) {
    elements.value.setDoneDeleted(index);
    elements.refresh();
  }

  unsetDeleted(int index) {
    elements.value.unsetDeleted(index);
    elements.refresh();
  }

  deleteCompletely(int index) {
    elements.value.deleteCompletely(index);
    elements.refresh();
  }

  deleteAllCompletely() {
    elements.value.deleteAllCompletely();
    elements.refresh();
  }
}

enum ElementsList { todos, done, deleted }

class Elements {
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
  }

  setDone(int index) => _move(todos, done, index);
  unsetDone(int index) => _move(done, todos, index);
  setTODODeleted(int index) => _move(todos, deleted, index);
  setDoneDeleted(int index) => _move(done, deleted, index);
  unsetDeleted(int index) => _move(deleted, todos, index);

  deleteCompletely(int index) {
    deleted.removeAt(index);
  }

  deleteAllCompletely() {
    deleted = [];
  }

  _move(src, dest, int index) {
    dest.insert(0, src[index]);
    src.removeAt(index);
  }
}

class YataButtonTemplate {
  final Widget child;
  final Function(int) action;

  YataButtonTemplate({this.child, this.action});

  generateElevatedButton(int index) {
    return ElevatedButton(
      onPressed: () => action(index),
      child: child,
    );
  }

  generateTextButton(int index) {
    return TextButton(
      onPressed: () => action(index),
      child: child,
    );
  }
}
