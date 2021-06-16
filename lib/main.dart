import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:enigma/levels.dart';
import 'package:enigma/l18n.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alerts.dart';
import 'items.dart';

const String SHARED_PREF_LEVEL_INDEX = 'levelIndex';
const String SHARED_PREF_GAME_OVER = 'gameOver';
const String SHARED_PREF_ITEMS = 'items';
const String SHARED_PREF_ITEM_COUNT = 'itemCount';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(EnigmaApp(sharedPreferences: sharedPreferences));
}

class EnigmaApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;

  EnigmaApp({Key? key, required this.sharedPreferences}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      title: 'Enigma',
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: Locale('de'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // darkTheme: ThemeData.dark(),
      home: GamePage(
        title: '',
        sharedPreferences: sharedPreferences,
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  GamePage({Key? key, required this.title, required this.sharedPreferences}) : super(key: key);
  final SharedPreferences sharedPreferences;
  final String title;

  @override
  _GamePageState createState() => _GamePageState(sharedPreferences: sharedPreferences);
}

enum _ScanMode {
  none,
  item,
  verify,
  resetLevel,
  resetGame,
}

class _GamePageState extends State<GamePage> {
  static const int MAX_ITEMS = 4;
  final SharedPreferences sharedPreferences;

  int _itemCount = MAX_ITEMS;
  List<Item?> _items = List.filled(MAX_ITEMS, null);
  var _levels = GameLevels;
  var _levelIndex = 0;
  var _gameOver = false;

  // var _scan = false;
  var _scanIndex;

  // var _verifyScan = false;
  Item? _scannedItem;
  var _startup = true;

  var _scanMode = _ScanMode.none;

  QRViewController? _qrController;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  _GamePageState({required this.sharedPreferences}) : super() {
    _loadPreferences();
  }

  void _scanResetLevel() {
    setState(() {
      _scanMode = _ScanMode.resetLevel;
    });
  }

  void _doLevelReset() {
    setState(() {
      _itemCount = MAX_ITEMS;
      _items.fillRange(0, MAX_ITEMS, null);
      _scanMode = _ScanMode.none;
      _storePreferences();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l18n(context).levelReset)));
  }

  void _resetLevel(BuildContext context, Item? scannedItem) {
    if (scannedItem == Items.ELIXIR) {
      showSuccessDialog(context, l18n(context).successMessageResetLevelElixir, () {
        _doLevelReset();
      });
      return;
    }

    if (scannedItem != Items.HOURGLASS) {
      showAlertDialog(context, l18n(context).errItemResetLevelWrong);
      return;
    }

    _doLevelReset();
  }

  void _scanResetGame() {
    setState(() {
      _scanMode = _ScanMode.resetGame;
    });
  }

  void _doGameReset() {
    setState(() {
      _itemCount = MAX_ITEMS;
      _items.fillRange(0, MAX_ITEMS, null);
      _levelIndex = 0;
      _scanMode = _ScanMode.none;
      _scanIndex = null;
      _scannedItem = null;
      _gameOver = false;
      _storePreferences();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l18n(context).gameReset)));
  }

  void _resetGame(BuildContext context, Item? scannedItem) {
    if (scannedItem == Items.ELIXIR) {
      showSuccessDialog(context, l18n(context).successMessageResetGameElixir, () {
        _doGameReset();
      });
      return;
    }

    if (scannedItem != Items.HOURGLASS) {
      showAlertDialog(context, l18n(context).errItemResetGameWrong);
      return;
    }

    _doGameReset();
  }

  void _cancelScan() {
    setState(() {
      _scanMode = _ScanMode.none;
      _scanIndex = null;
      _scannedItem = null;
      _storePreferences();
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_qrController == null) {
      return;
    }

    if (Platform.isAndroid) {
      _qrController!.pauseCamera();
    }
    _qrController!.resumeCamera();
  }

  @override
  void dispose() {
    _qrController?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this._qrController = controller;
    });
    var bounceBack = false;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        if (scanData.format == BarcodeFormat.qrcode) {
          var scanMode = _scanMode;
          _scanMode = _ScanMode.none;
          _scannedItem = decodeStringToItem(scanData.code);
          print('scanned=${_scannedItem == null ? 'null' : _scannedItem!.id}');
          if (!bounceBack) {
            bounceBack = true;
            switch (scanMode) {
              case _ScanMode.item:
                _addItem(context);
                break;
              case _ScanMode.verify:
                _validateLevel(context, _scannedItem);
                break;
              case _ScanMode.resetLevel:
                _resetLevel(context, _scannedItem);
                break;
              case _ScanMode.resetGame:
                _resetGame(context, _scannedItem);
                break;
              default:
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l18n(context).errScanModeInvalid)));
            }
          }
        }
      });
    });
  }

  Widget _qrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400) ? 150.0 : 300.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(borderColor: Colors.red, borderRadius: 10, borderLength: 30, borderWidth: 10, cutOutSize: scanArea),
    );
  }

  void _scanAddItem(BuildContext context, int index) {
    print('index=$index count=$_itemCount, item=${_items[index]}');
    if (_itemCount < 0) {
      showAlertDialog(context, l18n(context).errItemsExceeded);
      return;
    }

    if (_items[index] != null) {
      showAlertDialog(context, l18n(context).errSlotOccupied);
      return;
    }

    setState(() {
      _scanMode = _ScanMode.item;
      _scanIndex = index;
      _storePreferences();
    });
  }

  void _addItem(BuildContext context) {
    if (_itemCount < 0) {
      showAlertDialog(context, l18n(context).errScanIndexNull);
      return;
    }

    if (_scanIndex == null) {
      showAlertDialog(context, l18n(context).errScanIndexNull);
      return;
    }

    if (_items[_scanIndex] != null) {
      showAlertDialog(context, l18n(context).errSlotOccupied);
      return;
    }

    if (_scannedItem == null) {
      showAlertDialog(context, l18n(context).errItemUnknown);
      return;
    }

    if (_items.contains(_scannedItem)) {
      showAlertDialog(context, l18n(context).errItemExists);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l18n(context).added} ${itemFriendlyName(context, _scannedItem!)}!')));
    setState(() {
      _items[_scanIndex!] = _scannedItem!;
      _scannedItem = null;
      _scanIndex = null;
      _itemCount--;
      _storePreferences();
    });
  }

  bool _checkItems() {
    var level = _levels[_levelIndex];
    print('exact=${level.exactSolution} ${_items.toString()} ${level.solution.toString()}');

    if (level.exactSolution) {
      var validItems = _items.where((element) => element != null);
      return validItems == level.solution;
    }

    for (final item in level.solution) {
      if (!_items.contains(item)) {
        return false;
      }
    }
    return true;
  }

  void _scanValidateLevel(BuildContext context) {
    setState(() {
      _scanMode = _ScanMode.verify;
    });
  }

  void _beginNextLevel() {
    setState(() {
      if (_levelIndex < _levels.length) {
        _levelIndex++;

        _itemCount = MAX_ITEMS;
        _items.fillRange(0, MAX_ITEMS, null);
      }
      if (_levelIndex >= _levels.length) {
        _gameOver = true;
      }
      _storePreferences();
    });
  }

  void _validateLevel(BuildContext context, Item? scannedItem) {
    if (scannedItem == Items.ELIXIR) {
      showSuccessDialog(context, l18n(context).successMessageElixir, () {
        _beginNextLevel();
      });
      return;
    }

    if (scannedItem != Items.MAGIC_BALL) {
      showAlertDialog(context, l18n(context).errItemValidateWrong);
      return;
    }

    if (!_checkItems()) {
      showAlertDialog(context, l18n(context).errItemsWrong);
      return;
    }

    showSuccessDialog(context, '${l18n(context).congratulations} ${l18n(context).successMessage}', () {
      _beginNextLevel();
    });
  }

  Image _itemImage(int index) {
    var item = _items[index] == null ? Items.QR : _items[index]!;
    return Image.asset('assets/images/${item.image}');
  }

  @override
  Widget build(BuildContext context) {
    if (_startup) {
      return _startScreen(context);
    }

    return _gameOver ? _finishScreen(context) : _gameScreen(context);
  }

  _startScreen(BuildContext context) => Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(l18n(context).enigma),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Image.asset(
              'assets/images/${Items.ENIGMA.image}',
              height: 256,
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _startup = false;
                });
              },
              child: _levelIndex == 0 && _itemCount == MAX_ITEMS ? Text(l18n(context).begin) : Text(l18n(context).resume),
              style: ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 50)),
            )
          ],
        ),
      ));

  Widget _finishScreen(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Enigma: ${l18n(context).solved}'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                SizedBox(
                  height: 150,
                  child: Image.asset('assets/images/${Items.GIFT.image}'),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 50, 0, 0),
                  child: Text(
                    l18n(context).congratulations,
                    textScaleFactor: 2.0,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const Divider(
                height: 20,
                thickness: 5,
                indent: 20,
                endIndent: 20,
              ),
              SizedBox(height: 50),
            ],
          ),
        ),
        floatingActionButton: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 100,
          children: [
            FloatingActionButton(
              backgroundColor: Colors.redAccent,
              onPressed: _doGameReset,
              heroTag: null,
              tooltip: l18n(context).resetGame,
              child: Icon(Icons.replay),
            ),
          ],
        ),
      );

  Widget _gameScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: _levelIndex < _levels.length ? Text('${l18n(context).stage}: ${levelFriendlyName(context, _levels[_levelIndex])}') : Text(''),
      ),
      body: _scanMode == _ScanMode.none ? _playScreen(context) : _scanScreen(context),
      floatingActionButton: _scanMode == _ScanMode.none ? _buttonsPlayScreen() : _buttonsScanScreen(),
    );
  }

  _buttonsPlayScreen() => Wrap(
        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
        alignment: WrapAlignment.spaceBetween,
        spacing: 100,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: () => _scanValidateLevel(context),
            tooltip: l18n(context).verify,
            heroTag: null,
            child: Icon(Icons.check),
          ),
          GestureDetector(
            onLongPress: _scanResetGame,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: _scanResetLevel,
              heroTag: null,
              child: Icon(Icons.replay),
            ),
          ),
        ],
      );

  _buttonsScanScreen() => FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _cancelScan,
        tooltip: l18n(context).cancel,
        heroTag: null,
        child: Icon(Icons.arrow_back),
      );

  _playScreen(BuildContext context) => Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                child: Text(
                  l18n(context).level,
                  textScaleFactor: 2.0,
                  style: TextStyle(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.double),
                ),
              ),
              Text(
                '${_levelIndex + 1}',
                textScaleFactor: 4.0,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ]),
            const Divider(
              height: 20,
              thickness: 5,
              indent: 20,
              endIndent: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  onPressed: () => _scanAddItem(context, 0),
                  icon: _itemImage(0),
                  iconSize: 128.0,
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                ),
                IconButton(
                  onPressed: () => _scanAddItem(context, 1),
                  icon: _itemImage(1),
                  iconSize: 128.0,
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  onPressed: () => _scanAddItem(context, 2),
                  icon: _itemImage(2),
                  iconSize: 128.0,
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                ),
                IconButton(
                  onPressed: () => _scanAddItem(context, 3),
                  icon: _itemImage(3),
                  iconSize: 128.0,
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                ),
              ],
            ),
            const Divider(
              height: 20,
              thickness: 5,
              indent: 20,
              endIndent: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('${l18n(context).itemsLeftYouHave} '),
                Text(
                  '$_itemCount',
                  style: Theme.of(context).textTheme.headline5,
                ),
                Text(' ${_itemCount == 1 ? l18n(context).item : l18n(context).items} ${l18n(context).itemsLeft}'),
              ],
            ),
            const Divider(
              height: 20,
              thickness: 5,
              indent: 20,
              endIndent: 20,
            ),
            SizedBox(height: 50),
          ],
        ),
      );

  _scanScreen(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            (() {
              switch (_scanMode) {
                case _ScanMode.verify:
                  return Text(
                    l18n(context).itemMagicBall,
                    textScaleFactor: 1.5,
                  );
                case _ScanMode.resetLevel:
                case _ScanMode.resetGame:
                  return Text(
                    l18n(context).itemHourglass,
                    textScaleFactor: 1.5,
                  );
                case _ScanMode.item:
                  return Text(
                    '${l18n(context).slot}: #${_scanIndex + 1}}',
                    textScaleFactor: 1.5,
                  );
                default:
                  return Text('');
              }
            })(),
            Expanded(flex: 4, child: _qrView(context)),
          ],
        ),
      );

  _storePreferences() {
    sharedPreferences.setInt(SHARED_PREF_LEVEL_INDEX, _levelIndex);
    sharedPreferences.setBool(SHARED_PREF_GAME_OVER, _gameOver);
    sharedPreferences.setInt(SHARED_PREF_ITEM_COUNT, _itemCount);
    var itemIds = _items.map((e) => e == null ? '' : e.id).toList();
    sharedPreferences.setStringList(SHARED_PREF_ITEMS, itemIds);
  }

  _loadPreferences() {
    _levelIndex = sharedPreferences.getInt(SHARED_PREF_LEVEL_INDEX) ?? 0;
    _gameOver = sharedPreferences.getBool(SHARED_PREF_GAME_OVER) ?? false;
    _itemCount = sharedPreferences.getInt(SHARED_PREF_ITEM_COUNT) ?? MAX_ITEMS;
    var items = sharedPreferences.getStringList(SHARED_PREF_ITEMS) ?? List.filled(MAX_ITEMS, '');
    _items = items.map((e) => e == '' ? null : decodeStringToItem(e)).toList();
  }
}
