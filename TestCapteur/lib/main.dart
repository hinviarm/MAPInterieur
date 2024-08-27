import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';
import 'package:volume_watcher/volume_watcher.dart';
import 'package:wakelock/wakelock.dart';
import 'package:http/http.dart' as http;
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:dart_numerics/dart_numerics.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flame_tiled/flame_tiled.dart';
import 'package:cache_storage/cache_storage.dart';
import 'package:dijkstra/dijkstra.dart';
import 'package:epitaph_ips/epitaph_ips.dart';
//import 'package:sensors_plus/sensors_plus.dart';
import 'package:simple_kalman/simple_kalman.dart';
import 'service/variables.dart';
import 'package:sensors/sensors.dart';
import 'dart:convert' as convert;
import 'routeur.dart';
import 'boutique.dart';
import 'calculRapport.dart';
import 'KalmanFilter.dart';
import 'user.dart';
import 'button_screen.dart';

void main() {
  var game = MyGame();
  WidgetsFlutterBinding.ensureInitialized();
  Flame.device.setOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(MaterialApp(home:ButtonScreen(game: game)));
}

enum TtsState { playing, stopped, paused, continued }

class MyGame extends FlameGame with HasGameRef, HasCollisionDetection, TapDetector, ScrollDetector, ScaleDetector {

  final user = User(position: Vector2(0.0,0.0));
  bool avance = true;
  bool monte = true;
  String? wifiName = 'NaN';
  final double characterSize = 200.0;
  double altitude = 0.0;
  double longitude = 0.0;
  double latitude = 0.0;
  double distance = 0.0;
  double xInitial = 0.0;
  double yInitial = 0.0;
  List<double> listX =[];
  List<double> listY =[];
  String ssid = "";
  KalmanFilter kf = new KalmanFilter(0.1, 1.4, 1.0, 0);
  List<List> pairsList = [[]];
  // TODO à recevoir via l'API
  Map graph = {
    0: {1: 1, 2: 1},
    1: {0: 1, 2: 1, 3: 1},
    2: {0: 1, 1: 1, 3: 1},
    3: {1: 1, 2: 1}
  };
  final cacheStorage = CacheStorage.open();

  late TiledComponent component;
  SpriteComponent destinationComp = SpriteComponent();
  Boutique destination = Boutique("init", 0, 0.0, 0.0);
  // Pas touche
  double distance1 = 0.0;
  double distance2 = 0.0;
  double distance3 = 0.0;
  var coordonnee = {'x': 0.0, 'y': 0.0};
  Routeur R1 = new Routeur('', 0, 0.0, 0.0);
  Routeur R2 = new Routeur('', 0, 0.0, 0.0);
  Routeur R3 = new Routeur('', 0, 0.0, 0.0);
  NetworkSecurity STA_DEFAULT_SECURITY = NetworkSecurity.WPA;
  List<WiFiAccessPoint> accessPoints = <WiFiAccessPoint>[];
  List<Routeur> routeurs = [];
  List<Boutique> boutiques = [];
  late Routeur rproch;
  late List<SpriteComponent> listRoutVar = [];
  late FlutterTts flutterTts;
  TtsState ttsState = TtsState.stopped;

  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;
  var stopLecture = 0;
  String? language;

  late List<Vector2> points = [];
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  bool musicPlaying = false;

  double direction = 0.0;
  double angle = 0.0;
  double prevValue = 0.0;
  double direcPrecValue = 0.0;
  double deltax = 0.0;
  double deltay = 0.0;
  double xfinal = 0.0;
  double yfinal = 0.0;
  int hfinal = 0;
  bool execute = false;
  bool trace = false;
  bool estTourne = false;
  bool neg = false;

  Future<void> _DetectWifi() async {
    final results = await WiFiScan.instance.getScannedResults();
    accessPoints = <WiFiAccessPoint>[];
    accessPoints = results..sort((a, b) => a.level.compareTo(b.level));
    ssid = accessPoints.last.ssid;
    for (var acc in accessPoints){
      debugPrint("Les Signaux wifi disponibles sont: "+ acc.ssid+ ' level : '+acc.level.toString());
    }
    debugPrint("Le signal le plus élevé est: "+ ssid);
    // Se connecte au web service pour récupérer les ssid et coordonnées dans le magasin
      var urlString =
          'http://149.202.45.36:8002/consultation?ssid=${ssid}';
      var url = Uri.parse(urlString);
      _Detection(url);
  }


  void _Detection(Uri url) async {
    var response = await http.get(url);
    List<String> nomboutiques = [];
    if (response.statusCode == 200) {
      //var wordShow = (convert.jsonDecode(response.body)as List)?.map((item) => item as String)?.toList();
      if(cacheStorage.has(key: 'boutiques') || cacheStorage.has(key: 'routeurs')){
        cacheStorage.delete();
      }
      execute = true;
      boutiques = [];
      routeurs = [];
      var wordShow = convert.jsonDecode(response.body);
      if (wordShow.toString() != "[]") {
        for (var elem in wordShow) {
          elem = elem
              .toString()
              .replaceAll("[", "")
              .replaceAll("]", "")
              .split(", ");
          debugPrint('Liste chargée : '+ elem[4]+' '+elem[0]+' '+elem[1]+' '+elem[2]+' '+elem[3]);
          if(elem[4] == "1"){
            routeurs.add(Routeur(elem[0], int.parse(elem[3]), double.parse(elem[1]), double.parse(elem[2])));
            pairsList.add([elem[1],elem[2]]);
          }
          else{
            boutiques.add(Boutique(elem[0], int.parse(elem[3]), double.parse(elem[1]), double.parse(elem[2])));
            nomboutiques.add(elem[0]);
          }
        }
        cacheStorage.save(
          key: 'routeurs',
          value: routeurs,
        );
        cacheStorage.save(
          key: 'boutiques',
          value: boutiques,
        );
      }
    }
  }

  Future<void> huntWiFis() async {
    final result = await WiFiScan.instance.startScan();
    // reset access points.
    // get scanned results
    final results = await WiFiScan.instance.getScannedResults();
    accessPoints = <WiFiAccessPoint>[];
    accessPoints = results;

    for (var routeur in routeurs) {
      for (var accessPoint in accessPoints) {
        if (routeur.nom == accessPoint.ssid) {
          routeur.distance = 10 *
              calculerDistance(accessPoint.level.toDouble(),
                  accessPoint.frequency.toDouble());
          routeur.force = accessPoint.level;
          debugPrint(
              'Routeur : ${routeur.nom.toString()} de frequence :${accessPoint.frequency.toString()} , de force : ${routeur.force.toString()} distance : ${routeur.distance.toString()}');
        }
      }
    }
  }

  double distanceSide(Routeur R1, Routeur R2) {
    return sqrt(pow((R1.x - R2.x), 2) + pow((R1.y - R2.y), 2));
  }
/*
  //Initialize calculator
  Calculator calculator = LMA();

//Very basic models for unscented Kalman filter
  Matrix fxUserLocation(Matrix2 x, double dt, List? args) {
    List<double> list = [
      x[1][0] * dt + x[0][0],
      x[1][0],
      x[3][0] * dt + x[2][0],
      x[3][0]
    ];
    return Matrix2.fromFlattenedList(list, 4, 1);
  }

  Matrix hxUserLocation(Matrix2 x, List? args) {
    return Matrix.row([x[0][0], x[0][2]]);
  }
 */
  Map<String, double> triangulation() {
    //Sides sera fournit par le web service
    routeurs.sort((a, b) => a.force.abs().compareTo(b.force.abs()));
    debugPrint(routeurs.toString());
    R1 = routeurs[0];
    R2 = routeurs[1];
    R3 = routeurs[2];
    List<double> Sides = [
      distanceSide(R1, R2),
      distanceSide(R1, R3),
      distanceSide(R2, R3)
    ];
    debugPrint('R1 ' + R1.x.toString()+ ' '+ R1.y.toString()+' R2 '+ R2.x.toString()+' '+R2.y.toString());
    double scaleFactor =
        calculateScaleFactor(Sides, [R1.distance, R2.distance, R3.distance]);
    debugPrint("!!!!!!!!!!!!!!!! " + scaleFactor.toString());
    debugPrint('Sides '+Sides[0].toString());
    double a = (-2 * R1.x) + (2 * R2.x);
    double b = (-2 * R1.y) + (2 * R2.y);
    double c = pow(R1.distance / scaleFactor, 2).toDouble() -
        pow(R2.distance / scaleFactor, 2).toDouble() -
        pow(R1.x, 2).toDouble() +
        pow(R2.x, 2).toDouble() -
        pow(R1.y, 2).toDouble() +
        pow(R2.y, 2).toDouble();
    double d = (-2 * R2.x) + (2 * R3.x);
    double e = (-2 * R2.y) + (2 * R3.y);
    double f = pow(R2.distance / scaleFactor, 2).toDouble() -
        pow(R3.distance / scaleFactor, 2).toDouble() -
        pow(R2.x, 2).toDouble() +
        pow(R3.x, 2).toDouble() -
        pow(R2.y, 2).toDouble() +
        pow(R3.y, 2).toDouble();

    double x = (c * e - f * b);
    x = x / (e * a - b * d);

    double y = (c * d - a * f);
    y = y / (b * d - a * e);

    var coordinates = {
      'x': (x * 100).round() / 100,
      'y': (y * 100).round() / 100
    };

    print("Weighted x coordinate: " + x.toString());

    print("Weighted y coordinate: " + y.toString());

    /*
    // Filtre de Kalman
    if(listX.length < 5){
      listX.add(x);
      listY.add(y);
    } else {
      listX.removeAt(0);
    }
      final kalman = SimpleKalman(errorMeasure: 4, errorEstimate: 10, q: 0.065);
    //user.x = 50 * x + xInitial;
    //user.y = 50 * y + yInitial;
      user.x = 50 * kalman.filtered(listX.last) + xInitial;
      user.y = 50 * kalman.filtered(listY.last) + yInitial;

     */
    //user.x = 50 * x + xInitial;
    //user.y = 50 * y + yInitial;
    user.x = 100 * kf.getFilteredValue(x) + xInitial;
    user.y = -300 + 100 * kf.getFilteredValue(y) + yInitial;
if(points.isNotEmpty){
  points[0] = Vector2(user.x, user.y);
}else{
  points.add(Vector2(user.x, user.y));
}
      /*
//Sigma point function for unscented Kalman filter
    SigmaPointFunction sigmaPoints = MerweFunction(4, 0.1, 2.0, 1.0);

//Initialize filter
    Filter filter = SimpleUKF(4, 2, 0.3, hxUserLocation, fxUserLocation, sigmaPoints, sigmaPoints.numberOfSigmaPoints());

//Initialize tracker
    Tracker tracker = Tracker(calculator, filter);

//Engage tracker by calling this method with a list with at least 3 Beacon instances
    tracker.initiateTrackingCycle(...);

//The result of the tracker can be called as follows
    tracker.finalPosition;

//Raw calculated position and filtered position can be called as well
    tracker.calculatedPosition;
    tracker.filteredPosition;
       */

      if(user.x > deltax){
        deltax = deltax + size[0];
        camera.viewfinder.position.x = deltax;
      }
      if(user.y > deltay){
        deltay = deltay + size[1];
        camera.viewfinder.position.y = deltay;
      }
    if (trace == true){
      if(xfinal + 0.5 < x){
        if(estTourne && neg == true){
          lecture('Allez sur votre gauche');
        }else {
          lecture('Allez sur votre droite');
        }
      }else if (xfinal - 0.5 > x){
        if(estTourne && neg == true){
          lecture('Allez sur votre droite');
        }else {
          lecture('Allez sur votre gauche');
        }
      }
      if(yfinal + 0.5 < y){
        lecture('La cible est devant vous');
      }
      if (yfinal - 0.5 > y || ((yfinal + 0.5 < y) && neg == true)){
        lecture('La cible est devant vous');
        if(yfinal - 0.5 > y){ neg = true;}
        else{ neg = false;}
        if(!estTourne) {
          camera.viewfinder.angle += pi;
          user.angle += pi;
          estTourne = true;
        }
      }
      if((((xfinal + 0.5) >= x && xfinal <= x ) || ((xfinal - 0.5) <= x && xfinal >= x))&&(((yfinal + 0.5) >= y && yfinal <= y ) || ((yfinal - 0.5) <= y && yfinal >= y))){
        trace = false;
        lecture("Vous êtes arrivés à destination");
        world.remove(destinationComp);
      }
    }
    else {
      lecture('Vous êtes au coordonnées x' + ((x * 100).round() / 100).toString().replaceAll('.', ',') + 'et y' + ((x * 100).round() / 100).toString().replaceAll('.', ','));
    }

    debugPrint('user.x -------------------: ${user.x.toString()} -----------Deltax : $deltax');
    debugPrint('user.y -------------------: ${user.y.toString()} -----------Deltay : $deltay');
    debugPrint(
        "Les coordonnées sont : ${coordonnee['x'].toString()} et ${coordonnee['y'].toString()}");

    return coordinates;
  }

  Future<void> initPlatformState() async {
    huntWiFis();
    coordonnee = triangulation();
  }

  initTts() {
    flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      print("Playing");
      ttsState = TtsState.playing;
    });

    flutterTts.setCompletionHandler(() {
      print("Complete");
      ttsState = TtsState.stopped;
    });

    flutterTts.setCancelHandler(() {
      print("Cancel");
      ttsState = TtsState.stopped;
    });

    flutterTts.setErrorHandler((msg) {
      print("error: $msg");
      ttsState = TtsState.stopped;
    });
  }

  Future _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }
  // Méthode pour ajuster le volume
  Future<void> setVolume(double newVolume) async {
    volume = newVolume.clamp(0.0, 1.0);
    await flutterTts.setVolume(volume);
  }

  // Méthode pour gérer les changements de volume
  void onVolumeChange(double newVolume) {
    setVolume(newVolume);
  }

  Future _speak(String text) async {
    //await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (text != null) {
      if (text!.isNotEmpty) {
        await flutterTts.speak(text!);
      }
    }
  }

  Future _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) {
      ttsState = TtsState.stopped;
    }
  }

  double calculerDistance(double puissanceSignal, double frequence) {
    double exp =
        (27.55 - (20 * log10(frequence)) + puissanceSignal.abs()) / 20.0;
    return pow(10.0, exp).toDouble();
  }

  void location() async {
    Location location = new Location();
    LocationData locationData;
    locationData = await location.getLocation();
    altitude = locationData.altitude!;
    longitude = locationData.longitude!;
    latitude = locationData.latitude!;
    // Nom du réseau
    wifiName = await WiFiForIoTPlugin.getSSID();
    print(wifiName);
    // Force du signal
    int? signalStrength = await WiFiForIoTPlugin.getCurrentSignalStrength();
    debugPrint(signalStrength.toString());
    // Fréquence du signal
    int? wifiFrequency = await WiFiForIoTPlugin.getFrequency();
    debugPrint(wifiFrequency.toString());
    // Calcul
    distance = 10 *
        calculerDistance(signalStrength!.toDouble(), wifiFrequency!.toDouble());
    debugPrint('Distance : $distance mètres');
  }

  void stopCameraFollow() {
    // Remove the FollowBehavior from the camera's viewfinder
    camera.viewfinder.children.whereType<FollowBehavior>().forEach((behavior) {
      camera.viewfinder.remove(behavior);
    });
  }

  void clampZoom() {
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(0.05, 3.0);
  }

  static const zoomPerScrollUnit = 0.02;

  @override
  void onScroll(PointerScrollInfo info) {
    camera.viewfinder.zoom +=
        info.scrollDelta.global.y.sign * zoomPerScrollUnit;
    clampZoom();
  }

  late double startZoom;

  @override
  void onScaleStart(ScaleStartInfo info) {
    startZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final currentScale = info.scale.global;

    if (!currentScale.isIdentity()) {
      camera.viewfinder.zoom = startZoom * currentScale.y;
      clampZoom();
    } else {
      final delta = info.delta.global;
      camera.viewfinder.position.translate(-delta.x, -delta.y);
    }
  }

  @override
  void onTapDown(TapDownInfo info){
    super.onTapDown(info);
    component.flipHorizontallyAroundCenter();
  }

  @override
  Future<void> onLoad() async {
    await images.loadAllImages();
    if(!execute) {
      await _DetectWifi();
    }
    component =
        await TiledComponent.load('Construction.tmx', Vector2.all(16));
    component.size = Vector2(size[0], size[1] - 40);
    world.add(component);

    final coordonnees = component.tileMap.getLayer<ObjectGroup>('Coordonnees');
      for(final individu in coordonnees!.objects){
        if(individu.class_ == 'User'){
          xInitial = individu.x;
          yInitial = individu.y;
          user.position = Vector2(xInitial, yInitial);
          world.add(user);
          camera.viewfinder.anchor = Anchor.center;
        }
    }
    for(int i = 0; i < routeurs.length; i++) {
      listRoutVar.add(SpriteComponent());
      world.add(listRoutVar[i]
        ..sprite = await loadSprite('routeur.png')
        ..size = Vector2(32, 32)
        ..x = xInitial + 100 * routeurs[i].x
        ..y = -300 + yInitial + 100 * routeurs[i].y);
    }
    camera.follow(user);

    super.onLoad();
    initTts();
    VolumeWatcher.addListener(onVolumeChange);
    // initialize flame audio background music
    FlameAudio.bgm.initialize();

  }

  void indicateur() async{
    destination = cacheStorage.match(key: 'destination');
    lecture("Vous allez chez "+ destination.nom);
    xfinal = destination.x;
    yfinal = destination.y;
    hfinal = destination.etage;
    Routeur imaginaire = new Routeur("Imaginaire", hfinal, xfinal, yfinal);
    double tmpdist = distanceSide(imaginaire, routeurs[0]);
    rproch = routeurs[0];
    trace = true;
    estTourne = false;
    if(world.contains(destinationComp)){
      world.remove(destinationComp);
    }
    world.add(destinationComp
      ..sprite = await loadSprite("destination.png")
      ..size = Vector2(32, 32)
      ..x = xInitial + 100 * xfinal
      ..y = -300 + yInitial + 100 * yfinal);
    if(points.isEmpty) {
      points.insert(0, Vector2(user.x, user.y));
      points.insert(1,
          Vector2(xInitial + 100 * xfinal, -300 + yInitial + 100 * yfinal));
    }else{
      points.insert(1,
        Vector2(xInitial + 100 * xfinal, -300 + yInitial + 100 * yfinal));
    }
    // Calcule toutes les distances à la destination
    for(var rout in routeurs) {
      if(distanceSide(imaginaire, rout) < tmpdist){
        tmpdist = distanceSide(imaginaire, rout);
        rproch = rout;
      }
      // Todo l'un ou l'autre
      //var output1 = Dijkstra.findPathFromPairsList(pairsList, from, to);
      //var output2 = Dijkstra.findPathFromGraph(graph, from, to);
    }
  }

  Vector2 pointDeborde(Vector2 point, String methode) {
    // Déterminer les points de contact avec les bords de l'écran
    double x = point.x;
    double y = point.y;
    Vector2 reference = camera.viewfinder.position;
    debugPrint('size x ${reference.x.toString()}, $methode');
    debugPrint('size y ${reference.y.toString()} $methode');
    debugPrint('point x ${x.toString()}, $methode');
    debugPrint('point y ${y.toString()}, $methode');
    if (point.x < 0) {
      x = 0;
    } else if (point.x > reference.x) {
      x = reference.x;
    }

    if (point.y < 0) {
      y = 0;
    } else if (point.y > reference.y) {
      y = reference.y;
    }
    debugPrint('point x2 ${x.toString()}, $methode');
    debugPrint('point y2 ${y.toString()}, $methode');
    return Vector2(x, y);
  }

  void lecture(String texte) async {
    await Future.delayed(Duration(seconds: 8), () => _speak(texte));
  }

  @override
  void update(double dt) {
    //location();
    //mouvement();
    //startTimer();
// TODO Condition à revoir
    if (!cacheStorage.has(key: 'destination') || cacheStorage.match(key: 'destination') != destination) {
      indicateur();
    }
    initPlatformState();
    super.update(dt);
    //user.x += 10 * dt;
    //user.y += 10 * dt;
    debugPrint('-----------------------------------------------------------------------------------');
    debugPrint("Camera position: ${camera.viewfinder.position}");
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    Wakelock.enable();
    /*if (!musicPlaying) {
      FlameAudio.bgm.play('music.ogg');
      musicPlaying = true;
    }
     */
    if(trace) {
      var path = Path();

      // Tracer une ligne entre les deux sprites
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        //..strokeCap = StrokeCap.round
        ..strokeWidth = 32.0;
      final Vector2 endPosition = Vector2(xfinal, yfinal) - Vector2(32, 32)/2;
      /*canvas.drawLine((user.position).toOffset(),
        (endPosition).toOffset(),
        paint,
      );*/
      //path.moveTo(endPosition.x, endPosition.y);

      Vector2 vectArrivee = pointDeborde(Vector2(points.last.x, points.last.y) - Vector2(32,32), 'vectArrivee');

      final controlPoint = (Vector2(points[0].x, points[0].y) + vectArrivee) / 2;
      //path.moveTo(points.last.x - 32, points.last.y -32);
      path.moveTo(vectArrivee.x, vectArrivee.y);
/*
      path.quadraticBezierTo(
        controlPoint.x,
        controlPoint.y,
        points[0].x,
        points[0].y,
      );
 */
      // Créer le chemin en reliant les points
      for (int i = points.length - 2; i >= 0 ; i--) {
        //path.lineTo(points[i].x, points[i].y);
        //debugPrint('Point--------------: '+ i.toString() + '  points ' + points[i].x.toString()+'  y: '+points[i].y.toString());
        //var dx = (points[i].x + points[i+1].x) / 2;
        //var dy = (points[i].y + points[i+1].y) / 2;
        var traceposition = pointDeborde(Vector2(points[i].x, points[i].y), 'traceposition');
        //var tracedxy = pointDeborde(Vector2(dx, dy), 'tracedxy');
        path.relativeLineTo(traceposition.x, traceposition.y);
        //path.quadraticBezierTo(points[i].x, points[i].y, dx, dy);
        //path.quadraticBezierTo( tracedxy.x, tracedxy.y, traceposition.x, traceposition.y);
        //debugPrint(' toto '+ tracedxy.x.toString()+ ' et '+ tracedxy.y.toString());
      }
      //path.lineTo(points[0].x, points[0].y);

      //path.lineTo(xfinal, yfinal);
      //canvas.drawPath(path, paint);
      //canvas.drawLine(endPosition.toOffset(), user.position.toOffset(), paint);
      //path.close();
      final painter = PathPainter(path);
      painter.paint(canvas, size.toSize());
    }
  }

  @override
  void onRemove() {
    super.onRemove();
    _stop();
    VolumeWatcher.removeListener(onVolumeChange as int?);
  }
}

// Créer un CustomPainter pour dessiner des éléments personnalisés
class PathPainter extends CustomPainter {
  final Path path;
  PathPainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = 32.0;

      // Dessiner le chemin
      canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Retourner true si vous souhaitez redessiner le composant
  }
}
