import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

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
        dividerTheme: DividerThemeData(
          thickness: 1,
          space: 50,
          color: Color(0xFF888888),
        ),
      ),
      initialRoute: "/",
      getPages: [
        GetPage(name: "/", page: () => YataBaseScreen(child: YataTODOScreen())),
        GetPage(name: "/todo", page: () => YataBaseScreen(child: YataTODOScreen())),
        GetPage(name: "/done", page: () => YataBaseScreen(child: YataDoneScreen())),
        GetPage(name: "/bin", page: () => YataBaseScreen(child: YataDeleteScreen())),
        GetPage(name: "/register", page: () => RegisterScreen()),
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
        return LoginScreen(); // TODO: toNamed and all
        // on successful authentication I need to reload

      if (!elementsController.hasLoaded) {
        elementsController.load();
        return LoadingScreen();
      }

      // TODO: scaffold and onn in this one (make contentScreen smaller)
      return child;
    });
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

class YataContentScreen extends StatelessWidget {
  final ElementsController elementsController = ElementsController.findOrCreate();
  final AuthController authController = AuthController.findOrCreate();

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
      appBar: AppBar(
        title: const Text("Yata"),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.bottomSheet(
              Container(
                color: Colors.white,
                height: 200.0,
                child: Column(
                  children: <Widget>[
                    Text(
                      authController.name,
                      style: Theme.of(context).textTheme.headline4,
                    ),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(authController.user),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(authController.email),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Get.back();
                        authController.logout();
                        elementsController.reset();
                      },
                      child: const Text("logout"),
                    )
                  ],
                ),
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
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
                var items = elementsController.getList(elementsList);
                var len = items.length;

                return len == 0 ? Center(child: Text(defaultText)) : Scrollbar(
                  controller: _scrollController,
                  isAlwaysShown: true,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.0),
                    controller: _scrollController,
                    itemCount: len,
                    itemBuilder: (BuildContext context, int index) {
                      return Card(
                        child: MaterialBanner(
                          content: Text(items[index].content),
                          actions: <Widget>[
                              mainButton.generateElevatedButton(index),
                              secondaryButton.generateTextButton(index),
                          ],
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

class LoginScreen extends StatelessWidget {
  final AuthController controller = AuthController.findOrCreate();

  Rx<AuthExceptionCause> _exception = Rx<AuthExceptionCause>(null);

  final focusNode = FocusNode();
  final passwordFieldFocusNode = FocusNode();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  AuthExceptionCause get exception => _exception.value;

  set exception(AuthExceptionCause cause) {
    _exception.value = cause;
    _exception.refresh();
  }

  @override
  void dispose() {
    focusNode.dispose();
    passwordFieldFocusNode.dispose();
    usernameController.dispose();
    passwordController.dispose();
  }

  Widget _renderException(String msg) {
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color.fromARGB(52, 158, 28, 35)),
      ),
      color: Color(0xFFFFE3E6),
      child: ListTile(
        title: Text(msg),
        trailing: TextButton(
          onPressed: () => exception = null,
          child: Icon(
            Icons.clear,
            color: Color.fromARGB(154, 158, 28, 35),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKey: (RawKeyEvent event) {
          if (focusNode.hasPrimaryFocus &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              event.runtimeType == RawKeyUpEvent)
            submit();
        },
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400
            ),
            child: Column(
              children: <Widget>[
                Obx(() {
                  switch (exception) {
                    case AuthExceptionCause.unauthorized:
                      return _renderException(
                        "Incorrect username or password"
                      );
                    case AuthExceptionCause.networkError:
                      return _renderException(
                        "Oops, something went wrong with the " +
                        "connection. Please try again."
                      );
                    default:
                      return Container();
                  }
                }),
                Container(
                  constraints: BoxConstraints(
                    maxHeight:250,
                  ),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: usernameController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Username or E-Mail Address",
                              ),
                              onSubmitted: (_) => passwordFieldFocusNode.requestFocus(),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              focusNode: passwordFieldFocusNode,
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Password",
                              ),
                              onSubmitted: (_) => submit(),
                            ),
                          ),
                          Flexible(
                            flex: 1,
                            child: Row(
                              children: <Widget> [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: submit,
                                    child: Text("Sign in"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget> [
                    Expanded(
                      child: Divider(),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5.0),
                      child: Text(
                        "New to Yata?",
                        style: TextStyle(
                          color: Theme.of(context).dividerTheme.color,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(),
                    ),
                  ],
                ),
                Row(
                  children: <Widget> [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Get.toNamed("/register"),
                        child: Text("Register"),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  submit() async {
    // This if statement is a simple validator. Ugly, but it saves a
    // few HTTP requests to the auth server
    if (usernameController.text.length == 0 ||
        passwordController.text.length == 0)
    {
      exception = AuthExceptionCause.unauthorized;
      return;
    }

    try {
      await controller.login(
        usernameController.text.trim(),
        passwordController.text,
      );
    } catch (e) {
      exception = e.cause;
    }
  }
}

class RegisterScreen extends StatelessWidget {
  final focusNode = FocusNode();
  final passwordFieldFocusNode = FocusNode();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    focusNode.dispose();
    passwordFieldFocusNode.dispose();
    usernameController.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKey: (RawKeyEvent event) {
          if (focusNode.hasPrimaryFocus &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              event.runtimeType == RawKeyUpEvent)
            submit();
        },
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400
            ),
            child: Column(
              children: <Widget>[
                /*
                Obx(() {
                  switch (exception) {
                    case AuthExceptionCause.unauthorized:
                      return _renderException(
                        "Incorrect username or password"
                      );
                    case AuthExceptionCause.networkError:
                      return _renderException(
                        "Oops, something went wrong with the " +
                        "connection. Please try again."
                      );
                    default:
                      return Container();
                  }
                }),
                */
                Container(
                  constraints: BoxConstraints(
                    maxHeight:350,
                  ),
                  // TODO: connect with controllers and focus nodes
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: EdgeInsets.only(bottom:10.0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    flex:1,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: "First name",
                                      ),
                                    ),
                                  ),
                                  Container(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 5.0),
                                    )
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: "Last name",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: usernameController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Username",
                              ),
                              onSubmitted: (_) => passwordFieldFocusNode.requestFocus(),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: usernameController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Email",
                              ),
                              onSubmitted: (_) => passwordFieldFocusNode.requestFocus(),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              focusNode: passwordFieldFocusNode,
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Password",
                              ),
                              onSubmitted: (_) => submit(),
                            ),
                          ),
                          Flexible(
                            flex: 1,
                            child: Row(
                              children: <Widget> [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: submit,
                                    child: Text("Register"),
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.all<Color>(Colors.green),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  submit() {}
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

class AlertDialogContentContainer extends StatelessWidget {
  final Widget child;

  AlertDialogContentContainer({this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 600),
      child: child
    );
  }
}

debugPrintJWT(String token) {
  var split = token.split(".");

  var header = json.decode(utf8.decode(base64.decode(base64Url.normalize(split[0]))));
  print("header");
  print(header);

  var claims = json.decode(utf8.decode(base64.decode(base64Url.normalize(split[1]))));
  print("claims");
  print(claims);
}

class AuthController extends YataController {
  static const KEYCLOAK_BASE =
    //"http://localhost:8080/auth/realms/yata/protocol/openid-connect";
    "http://localhost:9998";

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
        // we don't care what error is thrown by authentication
        // (most likely a 400 Bad Request header when the refresh
        // token is expired), because we just fallback to the login
        // screen and delete the not working refresh token from
        // local storage
        try {
          await _authenticate(TokenRequest.refreshToken(token));
        } catch (_) {
          await logout();
        }
      }
      hasLoaded = true;
    });
  }

  factory AuthController.findOrCreate() {
    try {
      return Get.find();
    } catch (_) {
      return Get.put(AuthController());
    }
  }

  get accessToken => _accessToken;

  get user => _accessToken.claims["preferred_username"];
  get email => _accessToken.claims["email"];
  get name => _accessToken.claims["name"];

  get isAuthenticated => _isAuthenticated.value;

  set isAuthenticated(bool newIsAuthenticated) =>
    _isAuthenticated.value = newIsAuthenticated;

  int get accessTokenExpiresIn => (
    (_accessToken.claims["exp"] - _accessToken.claims["iat"]) * 0.98
  ).toInt();

  login(String username, String password) async {
    await _authenticate(TokenRequest.password(username, password));
  }

  logout() async {
    _accessToken = null;
    _refreshToken = null;

    var ls = await LocalStorage.getInstance();
    ls.remove("refresh_token");

    isAuthenticated = false;
  }

  Future<void> _cyclicallyRefreshToken() {
    Future.delayed(Duration(seconds: accessTokenExpiresIn), () {
      // User could have logged between the call of this function and
      // its execution. Authentication with a refresh token only works
      // if the user is authenticated in the first place.
      if (isAuthenticated) {
        _authenticate(
          TokenRequest.refreshToken(_refreshToken.toCompactSerialization())
        );
      }
    });
  }

  _authenticate(TokenRequest request) async {
    var response = await _getTokenResponse(request);

    switch (response.statusCode) {
      case 200:
        await _setTokenFromResponse(response);
        _cyclicallyRefreshToken();
        break;
      case 401:
        throw AuthException.unauthorized();
      default:
        throw AuthException.unexpectedStatusCode(response.statusCode);
    }
  }

  Future<http.Response> _getTokenResponse(TokenRequest request) async {
    try {
      return await _client.post(
        "$KEYCLOAK_BASE/token",
        headers: {
          "content-type": "application/json",
        },
        body: json.encode(request.generateRequestBody()),
      );
    } catch (e) {
      throw AuthException.networkError();
    }
  }

  _setTokenFromResponse(http.Response response) async {
    var responseBody = json.decode(response.body);

    var access = JsonWebToken.unverified(responseBody["access_token"]);
    var accessVerified = await access.verify(_keyStore);

    //debugPrintJWT(responseBody["access_token"]);

    if (accessVerified) {
      _accessToken = access;
      _refreshToken = JsonWebToken.unverified(responseBody["refresh_token"]);

      _saveRefreshTokenToPersistentMemory();

      isAuthenticated = true;
    } else {
      throw AuthException.tokenVerificationError();
    }
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
    } catch (e) {
      print(e.message);
    } finally {
      hasLoaded = true;
    }
  }

  reset() {
    _todos.value.clear();
    _todos.refresh();

    _done.value.clear();
    _done.refresh();

    _deleted.value.clear();
    _deleted.refresh();

    hasLoaded = false;
  }

  _setElementsFromJsonString(String jsonString) {
    var jsonElements = jsonDecode(jsonString);

    for (var jsonElement in jsonElements) {
      _addElement(Element.fromJson(jsonElement));
    }

    _sortByCreated();
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
    // TODO: error mangement
    try {
      var response = await client.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "content-type": "application/json",
        },
        body: json.encode({"content": content}),
      );
      var element = Element.fromJson(jsonDecode(response.body));
      _addElement(element);
      // TODO: addSorted !!!!
      _sortByCreated();
    } catch (e) {
      print(e.runtimeType);
      print(e.message);
    }
  }

  setDone(int index) {
    _putStatus(_todos[index].id, ElementStatus.Done);
    _changeLocalStatus(_todos, index, ElementStatus.Done);
  }

  unsetDone(int index) {
    _putStatus(_done[index].id, ElementStatus.Todo);
    _changeLocalStatus(_done, index, ElementStatus.Todo);
  }

  unsetDeleted(int index) {
    _putStatus(_deleted[index].id, ElementStatus.Todo);
    _changeLocalStatus(_deleted, index, ElementStatus.Todo);
  }

  setTODODeleted(int index) {
    _putStatus(_todos[index].id, ElementStatus.Deleted);
    _changeLocalStatus(_todos, index, ElementStatus.Deleted);
  }

  setDoneDeleted(int index) {
    _putStatus(_done[index].id, ElementStatus.Deleted);
    _changeLocalStatus(_done, index, ElementStatus.Deleted);
  }

  _putStatus(String elementId, ElementStatus status) async {
    var url = "http://localhost:9999/${authController.user}/$elementId/status";
    var token = authController.accessToken.toCompactSerialization();

    try {
      var response = await client.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "content-type": "application/json",
        },
        body: json.encode({"status": elementStatusToString(status)}),
      );

      // TODO: handle wrong status codes
      print(response.statusCode);

    } catch (e) {
      print(e.message);
    }
  }

  _changeLocalStatus(RxList<Element> src, int index, ElementStatus status) {
    src[index].status = status;
    _addElement(src[index]);
    src.removeAt(index);
    src.refresh();
    _sortByCreated();
  }

  deleteCompletely(int index) async {
    var elementId = _deleted[index].id;
    var url = "http://localhost:9999/${authController.user}/$elementId";
    var token = authController.accessToken.toCompactSerialization();

    try {
      var response = await client.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "content-type": "application/json",
        },
      );

      print(response.statusCode);
    } catch (e) {
      print(e.message);
    }

    _deleted.value.removeAt(index);
    _deleted.refresh();
  }

  deleteAllCompletely() async {
    var url = "http://localhost:9999/${authController.user}/empty_bin";
    var token = authController.accessToken.toCompactSerialization();

    try {
      var response = await client.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "content-type": "application/json",
        },
      );

      print(response.statusCode);
    } catch (e) {
      print(e.message);
    }

    _deleted.value = <Element>[];
    _deleted.refresh();
  }

  getList(ElementsList list) {
    switch (list) {
      case ElementsList.todos: return UnmodifiableListView(_todos.value);
      case ElementsList.done: return UnmodifiableListView(_done.value);
      case ElementsList.deleted: return UnmodifiableListView(_deleted.value);
    }
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

enum AuthExceptionCause {
  unauthorized, networkError, unexpectedStatusCode,
  tokenVerificationError
}

class AuthException {
  AuthExceptionCause cause;
  String message;

  // TODO: messages for users
  AuthException.unauthorized() :
    this.cause = AuthExceptionCause.unauthorized,
    this.message = "Auth server has returned a 401 status code";

  AuthException.networkError() :
    this.cause = AuthExceptionCause.networkError,
    this.message = "Auth server unreachable";

  AuthException.unexpectedStatusCode(int statusCode) :
    this.cause = AuthExceptionCause.unexpectedStatusCode,
    this.message = "Unexpectedly received status $statusCode " +
                   "from auth server";

  AuthException.tokenVerificationError() :
    this.cause = AuthExceptionCause.tokenVerificationError,
    this.message = "Could not verify token. Perhaps the key store " +
                   "of the auth server is not yet loaded";

}

class TokenRequest {
  String _grant_type;
  String _username;
  String _password;
  String _refreshToken;

  TokenRequest.password(this._username, this._password) :
    this._grant_type = "password";

  TokenRequest.refreshToken(this._refreshToken) :
    this._grant_type = "refresh_token";

  Map<String, dynamic> generateRequestBody() {
    switch (_grant_type) {
      case "password":
        return { "Password": {
          "username": _username,
          "password": _password,
        }};
      case "refresh_token":
        return { "RefreshToken": {
          "refresh_token": _refreshToken,
        }};
    }
  }
}

// TODO: match ElementStatus instead of list
enum ElementsList { todos, done, deleted }

// TODO: static class as wrapper with the methods
enum ElementStatus { Todo, Done, Deleted }

ElementStatus stringToElementStatus(String str) =>
  ElementStatus.values.firstWhere(
    (e) => elementStatusToString(e) == str);

String elementStatusToString(ElementStatus status) =>
  status.toString().split(".")[1];

class Element {
  String id;
  String content;
  ElementStatus status;
  DateTime created;

  Element({this.id, this.content, this.status, this.created});

  Element.fromJson(Map<String, dynamic> jsonElement) : this(
    id: jsonElement["id"],
    content: jsonElement["content"],
    status: stringToElementStatus(jsonElement["status"]),
    created: DateTime.parse(jsonElement["created"]),
  );

  @override
  toString() {
    return "Element{id: $id, content: $content, status: $status, " +
      "created: $created}";
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
