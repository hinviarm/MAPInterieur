import 'dart:core';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sliding_box/flutter_sliding_box.dart';
import 'package:cache_storage/cache_storage.dart';
import 'boutique.dart';
import 'main.dart';

class ButtonScreen extends StatefulWidget {
  const ButtonScreen({Key? key, required this.game}) : super(key: key);

  final MyGame game;
  @override
  State<ButtonScreen> createState() => ButtonScreenState(game: game);
}

class ButtonScreenState extends State<ButtonScreen> {
  // Avoid creating searchbase instance in build method
  // to preserve state on hot reloading
  final BoxController boxController = BoxController();
  final TextEditingController textEditingController = TextEditingController();

  ButtonScreenState({Key? key, required this.game}) : super();
  final MyGame game;
  List<String> displayedBoutique = [];
  List<String> nomBoutiques = [];
  late Boutique boutiqArrivee;
  late List<Boutique> boutiques = [Boutique("Test", 0, 0.0, 0.0)];
  final cacheStorage = CacheStorage.open();
  static const ThemeMode themeMode = ThemeMode.light;

  void _searchChanged() {
    if (textEditingController != null && textEditingController.text != "") {
      setState(() {
        displayedBoutique = List.from(nomBoutiques
            .where((name) => name.contains(textEditingController.value.text)));
      });
    } else {
      setState(() {
        displayedBoutique = List.from(nomBoutiques);
      });
    }
  }

  void recupBoutiques() async {
    boutiques = cacheStorage.match(key: 'boutiques');
    for (var boutique in boutiques) {
      nomBoutiques.add(boutique.nom);
      debugPrint("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& boutique: " + boutique.nom);
    }
    // Start listening to changes.
    //textEditingController.addListener(_searchChanged);
    textEditingController.addListener(() {
      _searchChanged();
      boxController.setSearchBody(
        child: ListView.builder(
          itemCount: displayedBoutique.length,
          itemBuilder: (context, index) {
            return Card(
              child: ListTile(
                title: Text(displayedBoutique[index]),
                onTap: () async {
                  if (cacheStorage.has(key: 'destination')) {
                    cacheStorage.deleteBy(key: 'destination');
                  }
                  textEditingController.text = displayedBoutique[index];
                  boutiqArrivee = boutiques
                      .where((boutique) =>
                          boutique.nom == textEditingController.value.text)
                      .firstOrNull!;
                  cacheStorage.save(
                    key: 'destination',
                    value: boutiqArrivee,
                  );
                  boxController.hideSearchBox();
                },
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    recupBoutiques();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          ButtonScreenState.themeMode == ThemeMode.light
              ? Brightness.dark
              : Brightness.light,
      systemNavigationBarColor: Theme.of(context).colorScheme.background,
    ));
    double appBarHeight = MediaQuery.of(context).size.height * 0.1;
    if (appBarHeight < 95) appBarHeight = 95;
    double maxHeightBox =
        (MediaQuery.of(context).size.height - appBarHeight) / 2;
    return Scaffold(
      body: SlidingBox(
        controller: boxController,
        minHeight: 0,
        maxHeight: maxHeightBox,
        color: Theme.of(context).colorScheme.background,
        style: BoxStyle.sheet,
        backdrop: Backdrop(
          fading: false,
          overlay: false,
          color: Theme.of(context).colorScheme.secondary,
          body: Stack(
            children: [GameWidget(game: widget.game)],
          ),
          appBar: BackdropAppBar(
              title: Container(
                margin: const EdgeInsets.only(left: 15),
                child: Text(
                  "Homêli",
                  style: TextStyle(
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              leading: Icon(
                Icons.menu,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 30,
              ),
              searchBox: SearchBox(
                controller: textEditingController,
                color: Theme.of(context).colorScheme.background,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 18),
                body: Center(
                  child: ListView.builder(
                    itemCount: displayedBoutique.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text(displayedBoutique[index]),
                        ),
                      );
                    },
                  ),
                ),
                draggableBody: true,
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                  child: SizedBox.fromSize(
                    size: const Size.fromRadius(25),
                    child: IconButton(
                      iconSize: 27,
                      icon: Icon(
                        Icons.search_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        textEditingController.text = "";
                        boxController.showSearchBox();
                        recupBoutiques();
                      },
                    ),
                  ),
                ),
              ]),
        ),
        bodyBuilder: (sc, pos) => _body(sc, pos),
        collapsedBody: _collapsedBody(),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    // This also removes the _printLatestValue listener.
    textEditingController.dispose();
    boxController.dispose();
    cacheStorage.delete();
    super.dispose();
  }

  _body(ScrollController sc, double pos) {
    sc.addListener(() {
      print("scrollController position: ${sc.position.pixels}");
    });
    return Center(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              text: 'Partager ma localisation',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                height: 2.5,
                letterSpacing: 0.7,
              ),
              recognizer: new TapGestureRecognizer()..onTap = () {},
            ),
          ),
          RichText(
            text: TextSpan(
              text: 'Marquer ma localisation',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                height: 2.5,
                letterSpacing: 0.7,
              ),
              recognizer: new TapGestureRecognizer()..onTap = () {},
            ),
          ),
          RichText(
            text: TextSpan(
              text: 'Nous contacter',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                height: 2.5,
                letterSpacing: 0.7,
              ),
              recognizer: new TapGestureRecognizer()..onTap = () {},
            ),
          )
        ],
      ),
    );
  }

  _collapsedBody() {
    return Center(
      child: Text(
        "Collapsed Body",
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 25,
        ),
      ),
    );
  }
}

class MyTheme {
  static call({required ThemeMode themeMode}) {
    if (themeMode == ThemeMode.light) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          background: Color(0xFFFFFFFF),
          onBackground: Color(0xFF222222),
          primary: Color(0xff607D8B),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xff607D8B),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFFF5252),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xff607D8B),
          onSurface: Color(0xFFFFFFFF),
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          background: Color(0xFF222222),
          onBackground: Color(0xFFEEEEEE),
          primary: Color(0xff324148),
          onPrimary: Color(0xFFEEEEEE),
          secondary: Color(0xff41555e),
          onSecondary: Color(0xff324148),
          error: Color(0xFFFF5252),
          onError: Color(0xFFEEEEEE),
          surface: Color(0xff324148),
          onSurface: Color(0xFFEEEEEE),
        ),
      );
    }
  }
}
