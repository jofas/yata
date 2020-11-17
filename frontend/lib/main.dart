import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:collection';
import 'dart:io';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:cross_local_storage/cross_local_storage.dart';

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
        GetPage(name: "/", page: () => YataBaseScreen(child: YataTODOScreen())),
        GetPage(name: "/todo", page: () => YataBaseScreen(child: YataTODOScreen())),
        GetPage(name: "/done", page: () => YataBaseScreen(child: YataDoneScreen())),
        GetPage(name: "/bin", page: () => YataBaseScreen(child: YataDeleteScreen())),
      ],
    );
  }
}

class YataBaseScreen extends StatelessWidget {
  final AuthController authController = AuthController.findOrCreate();
  final ElementsController elementsController = ElementsController.findOrCreate();

  final Widget child;

  YataBaseScreen({this.child}) : super();

  @override
  Widget build(BuildContext context) {
    return Obx(() {

      if (!authController.hasLoaded)
        return LoadingScreen();

      if (!authController.isAuthenticated)
        return LoginScreen();

      if (!elementsController.hasLoaded) {
        elementsController.load();
        return LoadingScreen();
      }

      return child;
    });
  }
}

class LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final AuthController controller = AuthController.findOrCreate();

  final _formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
  final ElementsController controller = ElementsController.findOrCreate();

  @override
  Widget build(BuildContext context) {
    return YataContentScreen(
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
          onPressed: () {
            textController.dispose();
            focusNode.dispose();
            Get.back();
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
}

class YataDoneScreen extends StatelessWidget {
  final ElementsController controller = ElementsController.findOrCreate();

  @override
  Widget build(BuildContext context) {
    return YataContentScreen(
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
  final ElementsController controller = ElementsController.findOrCreate();

  @override
  Widget build(BuildContext context) {
    return YataContentScreen(
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

class YataContentScreen extends StatelessWidget {
  final ElementsController controller = ElementsController.findOrCreate();

  final _scrollController = ScrollController();

  final String title;
  final String defaultText;

  final ElementsList elementsList;

  final YataButtonTemplate mainButton;
  final YataButtonTemplate secondaryButton;

  final ValueChanged<int> onTap;

  final floatingActionButton;

  YataContentScreen({
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
                      // TODO: from Container to Card
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
                                  Expanded(child: Text(items[index].content)),
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
            switch (index) {
              case 0: Get.toNamed("/todo"); break;
              case 1: Get.toNamed("/done"); break;
              case 2: Get.toNamed("/bin"); break;
            }
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

class AuthController extends YataController {
  static const KEYCLOAK_BASE =
    "http://localhost:8080/auth/realms/yata/protocol/openid-connect";

  final _isAuthenticated = false.obs;

  final _keyStore = JsonWebKeyStore();
  final _client = http.Client();

  JsonWebToken _accessToken, _refreshToken;

  AuthController() : super() {
    _client.get("$KEYCLOAK_BASE/certs").then((response) {
      _keyStore.addKeySet(JsonWebKeySet.fromJson(json.decode(response.body)));
    });

    _getRefreshTokenFromPersistentMemory().then((token) async {
      if (token != null) {
        _refreshToken = JsonWebToken.unverified(token);
        await _cyclicallyRefreshToken();
      }
      hasLoaded = true;
    });
  }

  factory AuthController.findOrCreate() {
    AuthController controller;

    try {
      controller = Get.find();
    } catch (_) {
      controller = Get.put(AuthController());
    }
    return controller;
  }

  get accessToken => _accessToken;

  get user => _accessToken.claims["preferred_username"];

  get isAuthenticated => _isAuthenticated.value;

  set isAuthenticated(bool newIsAuthenticated) {
    _isAuthenticated.value = newIsAuthenticated;
    _isAuthenticated.refresh();
  }

  int get accessTokenExpiresIn => (
    (_accessToken.claims["exp"] - _accessToken.claims["iat"]) * 0.98
  ).toInt();

  login(String username, String password) async {
    print("$username $password");

    // TODO: catch connection errors
    //       clean username from trailing whitespaces
    var response = await _client.post("$KEYCLOAK_BASE/token",
      body: {
        "username": username,
        "password": password,
        "client_id": "yata_frontend",
        "grant_type": "password",
      }
    );

    _setAuthenticationAndCyclicallyRefreshToken(response);
  }

  Future<void> _cyclicallyRefreshToken() async {
    var response = await _client.post("$KEYCLOAK_BASE/token",
      body: {
        "refresh_token": _refreshToken.toCompactSerialization(),
        "client_id": "yata_frontend",
        "grant_type": "refresh_token",
      }
    );

    _setAuthenticationAndCyclicallyRefreshToken(response);
  }

  _setAuthenticationAndCyclicallyRefreshToken(http.Response response) async {
    isAuthenticated = await _setTokenFromResponse(response);

    if (isAuthenticated)
      Future.delayed(
        Duration(seconds: accessTokenExpiresIn),
        _cyclicallyRefreshToken,
      );
  }

  // TODO bool -> Error
  Future<bool> _setTokenFromResponse(http.Response response) async {
    if (response.statusCode == 200) {
      var responseBody = json.decode(response.body);

      var access = JsonWebToken.unverified(responseBody["access_token"]);
      var accessVerified = await access.verify(_keyStore);

      if (accessVerified) {
        _accessToken = access;
        _refreshToken = JsonWebToken.unverified(responseBody["refresh_token"]);

        _saveRefreshTokenToPersistentMemory();

        return true;
      }

      print("token verification error");
      return false;
    }

    print("response error");
    return false;
  }

  Future<String> _getRefreshTokenFromPersistentMemory() async {
    var ls = await LocalStorage.getInstance();
    return ls.get("refresh_token");
  }

  _saveRefreshTokenToPersistentMemory() async {
    var ls = await LocalStorage.getInstance();
    ls.setString("refresh_token", _refreshToken.toCompactSerialization());
    print("saved refresh_token to persistent memory");
  }
}

class ElementsController extends YataController {
  RxList<Element> _todos = <Element>[].obs;
  RxList<Element> _done = <Element>[].obs;
  RxList<Element> _deleted = <Element>[].obs;

  final client = http.Client();

  final AuthController authController = AuthController.findOrCreate();

  ElementsController() : super();

  factory ElementsController.findOrCreate() {
    try {
      return Get.find();
    } catch (_) {
      return Get.put(ElementsController());
    }
  }

  load() async {
    // TODO: error management
    try {
      var token = authController.accessToken.toCompactSerialization();
      var response = await client.get(
        "http://localhost:9999/${authController.user}",
        headers: {
          "Authorization": "Bearer $token",
        }
      );

      _setElementsFromJsonString(response.body);
    } finally {
      hasLoaded = true;
    }
  }

  _setElementsFromJsonString(String jsonString) {
    var jsonElements = jsonDecode(jsonString);

    for (var jsonElement in jsonElements) {
      var element = _parseElement(jsonElement);
      _addElement(element);
    }

    _sortByCreated();

    print(_todos.value);
    // TODO: get whole element as return from post to /add_todo

    // TODO: implement operations
  }

  // TODO: to named constructor
  Element _parseElement(Map<String, dynamic> jsonElement) {
    return Element(
      id: jsonElement["id"],
      content: jsonElement["content"],
      status: stringToElementStatus(jsonElement["status"]),
      created: DateTime.parse(jsonElement["created"]),
    );
  }

  _addElement(Element element) {
    switch (element.status) {
      case ElementStatus.Todo:
        _todos.value.add(element);
        _todos.refresh();
        break;
      case ElementStatus.Done:
        _done.value.add(element);
        _done.refresh();
        break;
      case ElementStatus.Deleted:
        _deleted.value.add(element);
        _deleted.refresh();
        break;
    }
  }

  _sortByCreated() {
    int Function(Element, Element) compare =
      (a, b) => -a.created.compareTo(b.created);

    _todos.value.sort(compare);
    _done.value.sort(compare);
    _deleted.value.sort(compare);
  }

  addTODO(String content) async {
    var url = "http://localhost:9999/${authController.user}/add_todo";
    var token = authController.accessToken.toCompactSerialization();

    try {
      var response = await client.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "content-type": "application/json",
        },
        body: json.encode({"content": content}),
      );
      var element = _parseElement(jsonDecode(response.body));
      _addElement(element);
      _sortByCreated();
    } catch (e) {
      print(e.runtimeType);
      print(e.message);
    }
  }

  setDone(int index) {
    return;
  }

  unsetDone(int index) {
    return;
  }

  unsetDeleted(int index) {
    return;
  }

  setTODODeleted(int index) {
    return;
  }

  setDoneDeleted(int index) {
    return;
  }

  deleteCompletely(int index) {
    return;
  }

  deleteAllCompletely() {
    return;
  }

  getList(ElementsList list) {
    switch (list) {
      case ElementsList.todos: return UnmodifiableListView(_todos.value);
      case ElementsList.done: return UnmodifiableListView(_done.value);
      case ElementsList.deleted: return UnmodifiableListView(_deleted.value);
    }
  }

  _post({String path, String body: null}) async {

  }
}

class YataController extends GetxController {
  final _hasLoaded = false.obs;

  get hasLoaded => _hasLoaded.value;

  set hasLoaded(bool newHasLoaded) {
    _hasLoaded.value = newHasLoaded;
    _hasLoaded.refresh();
  }
}

enum ElementsList { todos, done, deleted }

enum ElementStatus { Todo, Done, Deleted }

ElementStatus stringToElementStatus(String str) =>
  ElementStatus.values.firstWhere(
    (e) => e.toString().split(".")[1] == str);

class Element {
  String id;
  String content;
  ElementStatus status;
  DateTime created;

  Element({this.id, this.content, this.status, this.created});

  @override
  toString() {
    return "Element{id: $id, content: $content, status: $status, " +
      "created: $created}";
  }
}

/*
class Elements {
  List<String> todos = [];
  List<String> done = [];
  List<String> deleted = [];

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
*/

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
