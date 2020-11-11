import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:collection';
import 'dart:io';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

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
        GetPage(name: "/", page: () => LoginOrAppScreen(child: YataTODOScreen())),
        GetPage(name: "/todo", page: () => LoginOrAppScreen(child: YataTODOScreen())),
        GetPage(name: "/done", page: () => LoginOrAppScreen(child: YataDoneScreen())),
        GetPage(name: "/bin", page: () => LoginOrAppScreen(child: YataDeleteScreen())),
      ],
    );
  }
}

class LoginOrAppScreen extends StatelessWidget {
  AuthController controller;

  Widget child;

  LoginOrAppScreen({this.child}) : controller = AuthController.findOrCreate();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isAuthenticated)
        return LoginScreen();

      // TODO: here I can make call to API
      return child;
    });
  }
}

class LoginScreen extends StatelessWidget {
  final AuthController controller = Get.find();

  final _formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TODO: proper login screen with username/password input,
      //       which is passed to the authController calling the
      //       REST API of keycloak
      body: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(10.0),
              child: TextFormField(
                controller: usernameController,
                validator: (value) {
                  if (value.isEmpty)
                    return "Can't be empty";
                  return null;
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Username or E-Mail Address",
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10.0),
              child: TextFormField(
                controller: passwordController,
                validator: (value) {
                  if (value.isEmpty)
                    return "Can't be empty";
                  return null;
                },
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Password",
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState.validate()) {
                  await controller.login(
                    usernameController.text,
                    passwordController.text,
                  );
                  // TODO: authController should
                  // have observable enum whether
                  // request was successful or not
                }
              },
              child: Text("Login"),
            )
          ],
        ),
      ),
    );
  }
}

class YataTODOScreen extends StatelessWidget {
  ElementsController controller;

  YataTODOScreen() : controller = ElementsController.findOrCreate();

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
          onPressed: () => Get.back(), // TODO: dispose focusNode and textcontroller
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

  YataDoneScreen() : controller = ElementsController.findOrCreate();

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

  YataDeleteScreen() : controller = ElementsController.findOrCreate();

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

    // TODO: into controller
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

debugPrintJWT(String token) {
  var split = token.split(".");

  var header = json.decode(utf8.decode(base64.decode(base64Url.normalize(split[0]))));
  print(header);
}

class AuthController extends GetxController {
  final _isAuthenticated = false.obs;
  final _keyStore = JsonWebKeyStore();

  JsonWebToken _accessToken, _refreshToken;

  AuthController() {
    http.get(
      "http://localhost:8080/auth/realms/yata/protocol/openid-connect/certs"
    ).then((response) {
      _keyStore.addKeySet(JsonWebKeySet.fromJson(json.decode(response.body)));
    });
  }

  factory AuthController.findOrCreate() {
    AuthController controller;

    try {
      controller = Get.find();
    } catch (_) {
      controller = Get.put(AuthController());
      // TODO: look for auth response in local storage
      //       if there and refresh_token is still valid, refresh
      //       if refresh successful -> logged in
      //
      //       save response to local storage

    }
    return controller;
  }

  get isAuthenticated => _isAuthenticated.value;

  set isAuthenticated(bool newIsAuthenticated) {
    _isAuthenticated.value = newIsAuthenticated;
    _isAuthenticated.refresh();
  }

  login(String username, String password) async {
    print("$username $password");

    // TODO: catch connection errors
    //       clean username from trailing whitespaces
    var response = await http.post(
      "http://localhost:8080/auth/realms/yata/protocol/openid-connect/token",
      body: {
        "username": username,
        "password": password,
        "client_id": "yata_frontend",
        "grant_type": "password",
      }
    );

    var success = await _setTokenFromResponse(response);

    if (success) {
      _cyclicallyRefreshToken();
      isAuthenticated = true;
    }
  }

  _cyclicallyRefreshToken() async {
    var seconds = (
      (_accessToken.claims["exp"] - _accessToken.claims["iat"]) * 0.98
    ).toInt();

    Future.delayed(Duration(seconds: seconds), () async {
      var response = await http.post(
        "http://localhost:8080/auth/realms/yata/protocol/openid-connect/token",
        body: {
          "refresh_token": _refreshToken.toCompactSerialization(),
          "client_id": "yata_frontend",
          "grant_type": "refresh_token",
        }
      );

      isAuthenticated = await _setTokenFromResponse(response);

      if (isAuthenticated)
      {
        print("successfully refreshed token");
        _cyclicallyRefreshToken();
      }
    });
  }

  Future<bool> _setTokenFromResponse(response) async {
    if (response.statusCode == 200) {
      var responseBody = json.decode(response.body);

      var access = JsonWebToken.unverified(responseBody["access_token"]);
      var accessVerified = await access.verify(_keyStore);

      if (accessVerified) {
        _accessToken = access;
        _refreshToken = JsonWebToken.unverified(responseBody["refresh_token"]);
        return true;
      }

      print("token verification error");
      return false;
    }

    print("response error");
    return false;
  }
}

class ElementsController extends GetxController {
  final elements = Elements().obs;
  final client = http.Client();

  ElementsController() {
    // TODO: loading screen while this is processing
    //       (put this into build or something (wrap with Obx maybe))
    //
    //        ListBuilder elements from Row to Card

    // TODO: this into method and call method in build of YataPage

    client.get("http://localhost:9999/").then((response) {
      // TODO: error management
      setElementsFromJsonString(response.body);
      print("Gotten Elements from server");
      print("Gotten Elements from server: ${response.body}");
    });
  }

  factory ElementsController.findOrCreate() {
    ElementsController controller;

    try {
      controller = Get.find();
    } catch (_) {
      controller = Get.put(ElementsController());
    }
    return controller;
  }

  addTODO(String value) {
    elements.value.addTODO(value);
    _post(path: "add_todo", body: jsonEncode({"value": value}));
    elements.refresh();
  }

  setDone(int index) {
    elements.value.setDone(index);
    _post(path: "set_done/$index");
    elements.refresh();
  }

  unsetDone(int index) {
    elements.value.unsetDone(index);
    _post(path: "unset_done/$index");
    elements.refresh();
  }

  unsetDeleted(int index) {
    elements.value.unsetDeleted(index);
    _post(path: "unset_deleted/$index");
    elements.refresh();
  }

  setTODODeleted(int index) {
    elements.value.setTODODeleted(index);
    _post(path: "set_todo_deleted/$index");
    elements.refresh();
  }

  setDoneDeleted(int index) {
    elements.value.setDoneDeleted(index);
    _post(path: "set_done_deleted/$index");
    elements.refresh();
  }

  deleteCompletely(int index) {
    elements.value.deleteCompletely(index);
    _post(path: "delete_completely/$index");
    elements.refresh();
  }

  deleteAllCompletely() {
    elements.value.deleteAllCompletely();
    _post(path: "delete_completely");
    elements.refresh();
  }

  getList(ElementsList list) => elements.value.getList(list);

  // TODO: not in controller
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

  _post({String path, String body: null}) {
    client.post(
      "http://localhost:9999/$path",
      headers: {"content-type": "application/json"},
      body: body,
    ).then((response) {
      // TODO: error management
      print("Got Response: ${response.statusCode}");
    });
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
  unsetDeleted(int index) => _move(deleted, todos, index);
  setTODODeleted(int index) => _move(todos, deleted, index);
  setDoneDeleted(int index) => _move(done, deleted, index);

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
