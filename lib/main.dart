import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseFirestore.instance
      .collection("mensagens")
      .snapshots()
      .listen((snapshot) {
    for (DocumentSnapshot doc in snapshot.docs) {
      print(doc.data);
    }
  });

  runApp(MyApp());
}

final ThemeData kIOSTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final ThemeData kDefaultTheme = ThemeData(
    primarySwatch: Colors.purple, accentColor: Colors.orangeAccent[400]);

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<bool> _ensureLoggedIn() async {
  try {
    GoogleSignInAccount user = googleSignIn.currentUser;

    if (user == null) user = await googleSignIn.signInSilently();

    if (user == null) user = await googleSignIn.signIn();

    if (auth.currentUser == null) {
      GoogleSignInAuthentication credentials =
          await googleSignIn.currentUser.authentication;
      GoogleAuthProvider.credential(
          idToken: credentials.idToken, accessToken: credentials.accessToken);
    }
    return true;
  } catch (e) {
    _toastMessage("Erro ao logar!\n Erro: " + e.toString());
    print(e.toString());
    return false;
  }
}

void _handleSubmitted(String text) async {
  bool logged = await _ensureLoggedIn();
  if (logged) _sendMessage(text: text);
}

void _toastMessage(String text) {
  Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0);
}

void _sendMessage({String text, String imgUrl}) {
  FirebaseFirestore.instance.collection("mensagens").add({
    "text": text,
    "imgUrl": imgUrl,
    "senderName": googleSignIn.currentUser.displayName,
    "senderPhotoUrl": googleSignIn.currentUser.photoUrl
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat App",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? kIOSTheme
          : kDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat App"),
          centerTitle: true,
          elevation:
              Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
                child: StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection("mensagens")
                        .snapshots(),
                    builder: (context, snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.none:
                        case ConnectionState.waiting:
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        default:
                          return ListView.builder(
                              reverse: true,
                              itemCount: snapshot.data.docs.length,
                              itemBuilder: (context, index) {
                                List r =
                                    snapshot.data.docs.reversed.toList();
                                return ChatMessage(r[index].data() );
                              });
                      }
                    })),
            Divider(
              height: 1.0,
            ),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: TextComposer(),
            )
          ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  bool _isComposing = false;
  final _textControler = TextEditingController();

  void _reset() {
    _textControler.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200])))
            : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                icon: Icon(Icons.photo_camera),
                onPressed: () async {
                  bool logged = await _ensureLoggedIn();
                  if (logged) {
                    final picker = ImagePicker();
                    final pickedFile =
                        await picker.getImage(source: ImageSource.camera);
                    File imgFile = File(pickedFile.path);
                    if (imgFile == null) return;
                    final task = FirebaseStorage.instance
                        .ref()
                        .child(googleSignIn.currentUser.id +
                            DateTime.now().millisecondsSinceEpoch.toString())
                        .putFile(imgFile);
                    _sendMessage(
                        imgUrl: task.storage
                            .ref()
                            .getDownloadURL()
                            .toString() //(await task.future).downloadUrl.toString()

                        );
                  }
                },
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textControler,
                decoration:
                    InputDecoration.collapsed(hintText: "Enviar uma Mensagem!"),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: (text) {
                  _handleSubmitted(text);
                  _reset();
                },
              ),
            ),
            Container(
                margin: EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                        child: Text("Enviar"),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textControler.text);
                                _reset();
                              }
                            : null,
                      )
                    : IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textControler.text);
                                _reset();
                              }
                            : null,
                      ))
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final Map<String, dynamic> data;

  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data["senderPhotoUrl"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data["senderName"],
                  style: Theme.of(context).textTheme.subtitle1,
                ),
                Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: data["imgUrl"] != null
                        ? Image.network(
                            data["imgUrl"],
                            width: 250.0,
                          )
                        : Text(data["text"]))
              ],
            ),
          )
        ],
      ),
    );
  }
}
