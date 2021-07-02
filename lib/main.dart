import 'dart:io';
import 'dart:async';

import 'package:enigma/adventure.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:enigma/l18n.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alerts.dart';

const String SHARED_PREF_LEVEL_INDEX = 'levelIndex';
const String SHARED_PREF_GAME_OVER = 'gameOver';
const String SHARED_PREF_ITEMS = 'items';
const String SHARED_PREF_ITEM_COUNT = 'itemCount';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  try {
    var adventure = await load('assets/adventure.yaml');

    runApp(EnigmaApp(sharedPreferences: sharedPreferences, adventure: adventure));
  } on Exception catch (e) {
    runApp(StartupError(error: e.toString()));
  }
}

class StartupError extends StatelessWidget {
  final String error;

  StartupError({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        error,
        textDirection: TextDirection.ltr,
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}

class EnigmaApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;
  final Adventure adventure;

  EnigmaApp({Key? key, required this.sharedPreferences, required this.adventure}) : super(key: key);

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
        adventure: adventure,
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  GamePage({Key? key, required this.title, required this.sharedPreferences, required this.adventure}) : super(key: key);
  final SharedPreferences sharedPreferences;
  final Adventure adventure;
  final String title;

  @override
  _GamePageState createState() => _GamePageState(sharedPreferences: sharedPreferences, adventure: adventure);
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
  final Adventure adventure;
  final SharedPreferences sharedPreferences;

  int _itemCount = MAX_ITEMS;
  List<Item?> _items = List.filled(MAX_ITEMS, null);
  var _levelIndex = 0;
  var _gameOver = false;

  var _scanIndex;
  Item? _scannedItem;
  var _startup = true;

  var _scanMode = _ScanMode.none;

  QRViewController? _qrController;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  _GamePageState({required this.sharedPreferences, required this.adventure}) : super() {
    _loadPreferences();
  }

  locale(context) => Localizations.localeOf(context).toString();

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
    if (scannedItem?.id == adventure.specialItems.pass) {
      showSuccessDialog(context, l18n(context).successMessageResetLevelElixir, () {
        _doLevelReset();
      });
      return;
    }

    if (scannedItem?.id != adventure.specialItems.reset) {
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
    if (scannedItem?.id == adventure.specialItems.pass) {
      showSuccessDialog(context, l18n(context).successMessageResetGameElixir, () {
        _doGameReset();
      });
      return;
    }

    if (scannedItem?.id != adventure.specialItems.reset) {
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

          _scannedItem = adventure.items[scanData.code];
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
      showAlertDialog(context, l18n(context).errItemsExceeded);
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

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l18n(context).added} ${_scannedItem!.name(locale(context))}!')));
    setState(() {
      _items[_scanIndex!] = _scannedItem!;
      _scannedItem = null;
      _scanIndex = null;
      _itemCount--;
      _storePreferences();
    });
  }

  bool _checkItems() {
    var level = adventure.levels[_levelIndex];
    print('solutionType=${level.solution.type} ${_items.toString()} ${level.solution.toString()}');

    var currentItemIds = _items.where((element) => element != null).map((e) => e!.id).toList();

    switch (level.solution.type) {
      case SolutionType.exact:
        return listEquals(currentItemIds, level.solution.items);
      case SolutionType.all:
        for (final item in level.solution.items) {
          if (!currentItemIds.contains(item)) {
            return false;
          }
        }
        return true;
      default:
        print("solution type is invalid");
        return false;
    }
  }

  void _scanValidateLevel(BuildContext context) {
    setState(() {
      _scanMode = _ScanMode.verify;
    });
  }

  void _beginNextLevel() {
    setState(() {
      if (_levelIndex < adventure.levels.length) {
        _levelIndex++;

        _itemCount = MAX_ITEMS;
        _items.fillRange(0, MAX_ITEMS, null);
      }
      if (_levelIndex >= adventure.levels.length) {
        _gameOver = true;
      }
      _storePreferences();
    });
  }

  void _validateLevel(BuildContext context, Item? scannedItem) {
    if (scannedItem?.id == adventure.specialItems.pass) {
      showSuccessDialog(context, l18n(context).successMessageElixir, () {
        _beginNextLevel();
      });
      return;
    }

    if (scannedItem?.id != adventure.specialItems.check) {
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
    var item = _items[index] == null ? adventure.items[adventure.specialItems.scan]! : _items[index]!;
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
              'assets/images/enigma.png',
              height: 256,
            ),
            // Text(adventure.name),
            Column(children: [
              _lisaAndBastianScreen(),
              Padding(
                padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                child: Text('EDITION', style: const TextStyle(fontSize: 12, color: Colors.black38)),
              ),
            ]),
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
            _lisaAndBastianScreen(),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              SizedBox(
                height: 150,
                child: Image.asset('assets/images/gift.png'),
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
              height: 5,
              thickness: 3,
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
        title:
            _levelIndex < adventure.levels.length ? Text('${l18n(context).stage}: ${adventure.levels[_levelIndex].name(locale(context))}') : Text(''),
      ),
      body: _scanMode == _ScanMode.none ? _playScreen(context) : _scanScreen(context),
      floatingActionButton: _scanMode == _ScanMode.none ? _buttonsPlayScreen() : _buttonsScanScreen(),
    );
  }

  Widget _lisaAndBastianScreen() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Lisa ', style: const TextStyle(fontSize: 30, fontFamily: 'Parisienne')),
          Image.asset('assets/images/rings.png', height: 48),
          Text(' Bastian', style: const TextStyle(fontSize: 30, fontFamily: 'Parisienne')),
        ],
      );

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
                Text('${l18n(context).itemsLeftYouNeed} '),
                Text(
                  '${_solutionItemCount()}',
                  style: Theme.of(context).textTheme.headline5,
                ),
                Text(' ${_solutionItemCount() == 1 ? l18n(context).item : l18n(context).items} ${l18n(context).itemsLeftSucceed}'),
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

  _solutionItemCount() => adventure.levels[_levelIndex].solution.items.length;

  _scanScreen(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            (() {
              switch (_scanMode) {
                case _ScanMode.verify:
                  return Text(
                    adventure.items[adventure.specialItems.check]!.name(locale(context)),
                    textScaleFactor: 1.5,
                  );
                case _ScanMode.resetLevel:
                case _ScanMode.resetGame:
                  return Text(
                    adventure.items[adventure.specialItems.reset]!.name(locale(context)),
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
    _items = items.map((e) => e == '' ? null : adventure.items[e]).toList();
  }
}
