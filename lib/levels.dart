import 'package:flutter/cupertino.dart';

import 'items.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Level {
  final String id;
  final List<Item> solution;
  final bool exactSolution;

  const Level(this.id, this.solution, this.exactSolution);
}

class Levels {
  static const SKI = const Level('SKI', [Items.SNOWBOARD, Items.HELMET, Items.SNOW_BOOTS], false);
  static const HIKING = const Level('HIKING', [Items.HIKE_BOOTS, Items.WATER_BOTTLE, Items.HEAD_LIGHT], false);
  static const CHINA = const Level('CHINA', [Items.HOT_POT, Items.VEGETABLES, Items.CHOPSTICKS], false);
  static const RETURN = const Level('RETURN', [Items.AIRPLANE, Items.TICKETS], false);
  static const PADLOCK = const Level('PADLOCK', [Items.KEYS], true);
  static const TAPE = const Level('TAPE', [Items.KNIFE, Items.SHARP_STONE], false);
  static const SCREWS = const Level('SCREWS', [Items.X_SCREWDRIVER, Items.FLAT_SCREWDRIVER], false);
  static const NUM_CODE = const Level('NUM_CODE', [Items.NUM_4, Items.NUM_2, Items.NUM_20, Items.NUM_13], true);
}

const List<Level> GameLevels = [
  Levels.SKI,
  Levels.HIKING,
  Levels.CHINA,
  Levels.RETURN,
  Levels.PADLOCK,
  Levels.TAPE,
  Levels.SCREWS,
  Levels.NUM_CODE,
];

Item? decodeStringToItem(String value) {
  switch (value) {
    case 'NULL':
      return Items.NULL;
    case 'GIFT':
      return Items.GIFT;
    case 'MAGIC_BALL':
      return Items.MAGIC_BALL;
    case 'HOURGLASS':
      return Items.HOURGLASS;
    case 'ELIXIR':
      return Items.ELIXIR;
    case 'QR':
      return Items.QR;
    case 'SNOWBOARD':
      return Items.SNOWBOARD;
    case 'HELMET':
      return Items.HELMET;
    case 'SNOW_BOOTS':
      return Items.SNOW_BOOTS;
    case 'HIKE_BOOTS':
      return Items.HIKE_BOOTS;
    case 'HEAD_LIGHT':
      return Items.HEAD_LIGHT;
    case 'WATER_BOTTLE':
      return Items.WATER_BOTTLE;
    case 'HOT_POT':
      return Items.HOT_POT;
    case 'VEGETABLES':
      return Items.VEGETABLES;
    case 'CHOPSTICKS':
      return Items.CHOPSTICKS;
    case 'CANDLE':
      return Items.CANDLE;
    case 'LIGHTER':
      return Items.LIGHTER;
    case 'AIRPLANE':
      return Items.AIRPLANE;
    case 'KEYS':
      return Items.KEYS;
    case 'KNIFE':
      return Items.KNIFE;
    case 'SHARP_STONE':
      return Items.SHARP_STONE;
    case 'X_SCREWDRIVER':
      return Items.X_SCREWDRIVER;
    case 'FLAT_SCREWDRIVER':
      return Items.FLAT_SCREWDRIVER;
    case 'ALLEN_KEY':
      return Items.ALLEN_KEY;
    case 'DRILL':
      return Items.DRILL;
    case 'NUM_4':
      return Items.NUM_4;
    case 'NUM_2':
      return Items.NUM_2;
    case 'NUM_20':
      return Items.NUM_20;
    case 'NUM_13':
      return Items.NUM_13;
    case 'NUM_21':
      return Items.NUM_21;
    case 'NUM_31':
      return Items.NUM_31;
    default:
      return null;
  }
}

itemFriendlyName(BuildContext context, Item item) {
  switch (item) {
    case Items.NULL:
      return AppLocalizations.of(context)!.itemNull;
    case Items.GIFT:
      return AppLocalizations.of(context)!.itemGift;
    case Items.MAGIC_BALL:
      return AppLocalizations.of(context)!.itemMagicBall;
    case Items.ELIXIR:
      return AppLocalizations.of(context)!.itemElixir;
    case Items.QR:
      return AppLocalizations.of(context)!.itemQr;
    case Items.SNOWBOARD:
      return AppLocalizations.of(context)!.itemSnowboard;
    case Items.HELMET:
      return AppLocalizations.of(context)!.itemHelmet;
    case Items.SNOW_BOOTS:
      return AppLocalizations.of(context)!.itemSnowBoots;
    case Items.HIKE_BOOTS:
      return AppLocalizations.of(context)!.itemHikeBoots;
    case Items.HEAD_LIGHT:
      return AppLocalizations.of(context)!.itemHeadLight;
    case Items.WATER_BOTTLE:
      return AppLocalizations.of(context)!.itemWaterBottle;
    case Items.HOT_POT:
      return AppLocalizations.of(context)!.itemHotPot;
    case Items.VEGETABLES:
      return AppLocalizations.of(context)!.itemVegetables;
    case Items.CHOPSTICKS:
      return AppLocalizations.of(context)!.itemChopsticks;
    case Items.CANDLE:
      return AppLocalizations.of(context)!.itemCandle;
    case Items.LIGHTER:
      return AppLocalizations.of(context)!.itemLighter;
    case Items.AIRPLANE:
      return AppLocalizations.of(context)!.itemAirplane;
    case Items.KEYS:
      return AppLocalizations.of(context)!.itemKeys;
    case Items.KNIFE:
      return AppLocalizations.of(context)!.itemKnife;
    case Items.SHARP_STONE:
      return AppLocalizations.of(context)!.itemSharpStone;
    case Items.X_SCREWDRIVER:
      return AppLocalizations.of(context)!.itemXScrewdriver;
    case Items.FLAT_SCREWDRIVER:
      return AppLocalizations.of(context)!.itemFlatScrewdriver;
    case Items.ALLEN_KEY:
      return AppLocalizations.of(context)!.itemAllenKey;
    case Items.DRILL:
      return AppLocalizations.of(context)!.itemDrill;
    case Items.NUM_4:
      return AppLocalizations.of(context)!.itemNum4;
    case Items.NUM_2:
      return AppLocalizations.of(context)!.itemNum2;
    case Items.NUM_20:
      return AppLocalizations.of(context)!.itemNum20;
    case Items.NUM_13:
      return AppLocalizations.of(context)!.itemNum13;
    case Items.NUM_21:
      return AppLocalizations.of(context)!.itemNum21;
    case Items.NUM_31:
      return AppLocalizations.of(context)!.itemNum31;
    default:
      return 'UNKNOWN';
  }
}


levelFriendlyName(BuildContext context, Level level) {
  switch (level) {
    case Levels.SKI:
      return AppLocalizations.of(context)!.levelSki;
    case Levels.HIKING:
      return AppLocalizations.of(context)!.levelHiking;
    case Levels.CHINA:
      return AppLocalizations.of(context)!.levelChina;
    case Levels.RETURN:
      return AppLocalizations.of(context)!.levelReturn;
    case Levels.PADLOCK:
      return AppLocalizations.of(context)!.levelPadlock;
    case Levels.TAPE:
      return AppLocalizations.of(context)!.levelTape;
    case Levels.SCREWS:
      return AppLocalizations.of(context)!.levelScrews;
    case Levels.NUM_CODE:
      return AppLocalizations.of(context)!.levelNumCode;
    default:
      return 'UNKNOWN';
  }
}

class ItemScanner {
  final List<Item> allSolutionItems = [
    Items.HELMET,
    Items.SNOWBOARD,
    Items.SNOW_BOOTS,
    Items.HIKE_BOOTS,
    Items.HEAD_LIGHT,
    Items.WATER_BOTTLE,
    Items.HOT_POT,
    Items.VEGETABLES,
    Items.CHOPSTICKS,
    // Items.CANDLE,
    // Items.LIGHTER,
    Items.AIRPLANE,
    Items.TICKETS,
    Items.KEYS,
    Items.KNIFE,
    Items.SHARP_STONE,
    Items.X_SCREWDRIVER,
    Items.FLAT_SCREWDRIVER,
    // Items.ALLEN_KEY,
    // Items.DRILL,
    Items.NUM_4,
    Items.NUM_2,
    Items.NUM_20,
    Items.NUM_13,
    // Items.NUM_21,
    // Items.NUM_31,
  ];

  var _index = 0;

  reset() {
    _index = 0;
  }

  Item getItem() {
    var items = allSolutionItems;
    var item = items[_index];
    _index++;
    if (_index == items.length) {
      _index = 0;
    }
    return item;
  }
}
