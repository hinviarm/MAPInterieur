import 'package:flame/components.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:wakelock/wakelock.dart';
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
//import 'package:sensors_plus/sensors_plus.dart';
import 'package:simple_kalman/simple_kalman.dart';
import 'service/variables.dart';
import 'package:sensors/sensors.dart';
import 'routeur.dart';
import 'calculRapport.dart';
import 'user.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //Flame.device.fullScreen();
  Flame.device.setOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(GameWidget(game: MyGame()));
}

enum TtsState { playing, stopped, paused, continued }

class MyGame extends FlameGame with HasGameRef, HasCollisionDetection, HasTappables,  ScrollDetector, ScaleDetector {
  /*MyGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: 1920,
            height: 1080,
          )..viewfinder.anchor = Anchor.bottomCenter,
        );
   */
  //final world = Level();
  //SpriteComponent girl = SpriteComponent();
  //SpriteComponent background = SpriteComponent();
  //SpriteComponent background2 = SpriteComponent();
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




  late TiledComponent component;
  TextPaint dialogue = TextPaint(style: const TextStyle(fontSize: 26));
  // Pas touche
  int _counter = 0;
  double distance1 = 0.0;
  double distance2 = 0.0;
  double distance3 = 0.0;
  var coordonnee = {'x': 0.0, 'y': 0.0};
  Routeur R1 = new Routeur('', 0, 0.0, 0.0);
  Routeur R2 = new Routeur('', 0, 0.0, 0.0);
  Routeur R3 = new Routeur('', 0, 0.0, 0.0);
  NetworkSecurity STA_DEFAULT_SECURITY = NetworkSecurity.WPA;
  List<WiFiAccessPoint> accessPoints = <WiFiAccessPoint>[];
  List<Routeur> MaListe = [];

  // event returned from accelerometer stream
  AccelerometerEvent _eventAccel = new AccelerometerEvent(0.0, 0.0, 0.0);

  // event returned from gyroscope stream
  GyroscopeEvent _eventGyro = new GyroscopeEvent(0, 0, 0);

  // execution time for each cycle per milliseconds, 20.000 mHz
  int _lsmTime = 20;

  // Filter
  Variables _algorithm = new Variables();

  late FlutterTts flutterTts;
  TtsState ttsState = TtsState.stopped;

  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;
  var stopLecture = 0;
  String? language;

  //String? engine;
  //double volume = 1;
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

  Future<void> huntWiFis() async {
    final result = await WiFiScan.instance.startScan();
    // reset access points.
    // get scanned results
    final results = await WiFiScan.instance.getScannedResults();
    accessPoints = <WiFiAccessPoint>[];
    accessPoints = results;

    for (var routeur in MaListe) {
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

  Map<String, double> triangulation() {
    //Sides sera fournit par le web service
    MaListe.sort((a, b) => a.force.abs().compareTo(b.force.abs()));
    debugPrint(MaListe.toString());
    R1 = MaListe[0];
    R2 = MaListe[1];
    R3 = MaListe[2];
    List<double> Sides = [
      distanceSide(R1, R2),
      distanceSide(R1, R3),
      distanceSide(R2, R3)
    ];
    double scaleFactor =
        calculateScaleFactor(Sides, [R1.distance, R2.distance, R3.distance]);
    debugPrint("!!!!!!!!!!!!!!!! " + scaleFactor.toString());
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
    return coordinates;
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    huntWiFis();
    coordonnee = triangulation();
  }

  initTts() {
    flutterTts = FlutterTts();

    _algorithm = Variables();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      print("Playing");
      ttsState = TtsState.playing;
    });

    if (isAndroid) {
      flutterTts.setInitHandler(() {
        print("TTS Initialized");
      });
    }

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

  Future<dynamic> _getLanguages() async => await flutterTts.getLanguages;

  Future<dynamic> _getEngines() async => await flutterTts.getEngines;

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

  void setPosition(
      AccelerometerEvent currentAccel, GyroscopeEvent currentGyro) {
    if (currentAccel == null && currentGyro == null) {
      return;
    }

    _algorithm.update(
      currentAccel.x,
      currentAccel.y,
      currentAccel.z,
      currentGyro.x,
      currentGyro.y,
      currentGyro.z,
    );
  }

  void startTimer() {
    // if the accelerometer subscription hasn't been created, go ahead and create it
    accelerometerEvents.listen((AccelerometerEvent event) {
      _eventAccel = event;
    });
    gyroscopeEvents.listen((GyroscopeEvent event) {
      _eventGyro = event;
    });
    setPosition(_eventAccel, _eventGyro);
    // Accelerometer events come faster than we need them so a timer
    // is used to only proccess them every 20 milliseconds
    /*
    Timer.periodic(Duration(milliseconds: _lsmTime), (_) {
      // (20*500) = 1000 milliseconds, equals 1 seconds.
      // proccess the current event

    });
     */
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) {
      ttsState = TtsState.stopped;
    }
  }

  //sqrt(Vinit+2*accélération*Distance)
  void mouvement() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      _eventAccel = event;
    });
    /*userAccelerometerEvents.listen(
            (UserAccelerometerEvent event) {
              _eventAccelUser = event;
        });*/
    gyroscopeEvents.listen((GyroscopeEvent event) {
      _eventGyro = event;
    });
    /*magnetometerEvents.listen((MagnetometerEvent event) {
      _magnetometer = event;
    });*/
  }

  Future<void> compassHeading() async {
    // create realtime compass value as integer
    await FlutterCompass.events?.listen((event) {
      direction = event.heading!;

      direction = direction < 0 ? (360 + direction) : direction;
      double diff = direction - prevValue;
      if (diff.abs() > 180) {
        if (prevValue > direction) {
          diff = 360 - (direction - prevValue).abs();
        } else {
          diff = 360 - (prevValue - direction).abs();
          diff = diff * -1;
        }
      }
      angle += (diff / 360);
      prevValue = direction;
    });
    //angle = direction * (pi / 180) * -1;
    angle = direction;
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
  void onScaleStart(_) {
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
  Future<void> onLoad() async {
    await images.loadAllImages();
    component =
        await TiledComponent.load('Construction.tmx', Vector2.all(16));
    //final gameSize = gameRef.size;
    // To add a position component in the center of the screen for example:
    // (when the camera isn't moved)
    //component.position = gameSize;
    component.size = Vector2(size[0], size[1] - 40);
    add(component);
    final screenWidth = size[0];
    final screenHeight = size[1];
    final coordonnees = component.tileMap.getLayer<ObjectGroup>('Coordonnees');
      for(final individu in coordonnees!.objects){
        if(individu.class_ == 'User'){
          xInitial = individu.x;
          yInitial = individu.y;
          //user.position = Vector2((screenWidth - characterSize) / 2,(screenHeight - characterSize) / 2);
          user.position = Vector2(xInitial, yInitial);
          add(user);
          //component.position = Vector2(xInitial, yInitial);
          // Set the camera to follow the player
          //camera.followComponent(user, worldBounds: Rect.fromLTWH(0, 0, component.size.x, component.size.y));
          // Set up the camera to follow the player
          //camera = CameraComponent(world: world);
          camera.viewfinder.anchor = Anchor.topCenter;
          camera.follow(user);

          //add(camera);
        }
    }

    // Se connecte au web service pour récupérer les ssid et coordonnées dans le magasin
    Routeur routeur1 = new Routeur('TP-Link_CB90', 0, 2.0, 3.5);
    Routeur routeur2 = new Routeur('Livebox-E670', 0, 0.0, 0.0);
    Routeur routeur3 = new Routeur('SFR_48F0', 0, 0.0, 4.0);
    Routeur routeur4 = new Routeur('Bbox-8669418E', 0, 2.0, 3.5);
    Routeur routeur5 = new Routeur('Extender_F1B6D3', 0, 2.0, 3.5);
    Routeur routeur6 = new Routeur('Extender_CCE909', 0, 0.0, 4.0);
    //MaListe.add(routeur1);
    MaListe.add(routeur2);
    //MaListe.add(routeur3);
    //MaListe.add(routeur4);
    MaListe.add(routeur5);
    MaListe.add(routeur6);
    super.onLoad();
    initTts();

    location();
    //mouvement();
    // initialize flame audio background music
    FlameAudio.bgm.initialize();

  }

  void lecture(String texte) async {
    await Future.delayed(Duration(seconds: 8), () => _speak(texte));
  }

  @override
  void update(double dt) {
    //location();
    //mouvement();
    //startTimer();

    initPlatformState();
    super.update(dt);
    double valx = (coordonnee['x']!);
    double valy = (coordonnee['y']!);
    if (!valx.isNaN && !valy.isNaN) {
      //user.x = 30 * valx + 3 * dt;
      //user.y = 30 * valy + 3 * dt;
      user.x = 50 * valx + xInitial;
      user.y = 50 * valy + yInitial;
      //user.x = xInitial;
      //user.y = yInitial;
      if(user.x > deltax){
        deltax = deltax + size[0];
        component.position.x = deltax;
      }
      if(user.y > deltay){
        deltay = deltay + size[1];
        component.position.y = deltay;
      }

      camera.update(dt);
      //camera.follow(user);
    }

    if (valx < 1.0 && valy > 2.5){
      lecture('Vous êtes proche du routeur chinois');
    } else if (valx < 1.5 && valy < 1.5){
      lecture('Vous êtes proche du routeur wifi');
    }else if (valx > 1.0 && valy > 2.5){
      lecture('Vous êtes proche du routeur TPLink');
    }else {
      lecture('êtes vous perdu ?');
    }
    debugPrint('Tis is girl.x -------------------: ${user.x.toString()}');
    debugPrint('Tis is girl.y -------------------: ${user.y.toString()}');
    debugPrint(
        "Les coordonnées sont : ${coordonnee['x'].toString()} et ${coordonnee['y'].toString()}");

  }

  @override
  void render(Canvas canvas) {
    dialogue.render(canvas, "Bouge", Vector2(10, size[1] - 100));
    super.render(canvas);
    Wakelock.enable();
    /*if (!musicPlaying) {
      FlameAudio.bgm.play('music.ogg');
      musicPlaying = true;
    }
     */
  }
}
