import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class I18n {
  final String en;
  final String de;

  const I18n(this.en, this.de);
}

class Item {
  final String id;
  final String image;
  final I18n i18n;

  const Item(this.id, this.image, this.i18n);

  String name(String locale) {
    switch (locale) {
      case 'de':
        return this.i18n.de;
      default:
        return this.i18n.en;
    }
  }
}

enum SolutionType { invalid, all, exact }

class Solution {
  final SolutionType type;
  final List<String> items;

  const Solution(this.type, this.items);
}

class Level {
  final String id;
  final Solution solution;
  final I18n i18n;

  const Level(this.id, this.solution, this.i18n);

  String name(String locale) {
    switch (locale) {
      case 'de':
        return this.i18n.de;
      default:
        return this.i18n.en;
    }
  }
}

class SpecialItems {
  final String scan;
  final String check;
  final String reset;
  final String pass;

  const SpecialItems(this.scan, this.check, this.reset, this.pass);
}

class Adventure {
  final String name;
  final HashMap<String, Item> items;
  final List<Level> levels;
  final SpecialItems specialItems;

  const Adventure(this.name, this.items, this.specialItems, this.levels);
}

Future<Adventure> load(String file) async {
  var contents = await rootBundle.loadString(file);
  var root = loadYaml(contents);

  var items = HashMap<String, Item>();
  root['items'].forEach((item) {
    items[item["id"]] = Item(item["id"], item["image"], I18n(item["i18n"]["en"], item["i18n"]["de"]));
  });

  var specialItems = SpecialItems(
    root['special_items']["scan"],
    root['special_items']["check"],
    root['special_items']["reset"],
    root['special_items']["pass"],
  );

  List<Level> levels = [];
  root['levels'].forEach((level) {
    var solutionType = SolutionType.invalid;
    switch (level["solution"]["type"].toString().toLowerCase()) {
      case 'all':
        solutionType = SolutionType.all;
        break;
      case 'exact':
        solutionType = SolutionType.exact;
        break;
    }
    var solutionItems = level["solution"]["items"].cast<String>();
    levels.add(
      Level(level["id"], Solution(solutionType, solutionItems), I18n(level["i18n"]["en"], level["i18n"]["de"])),
    );
  });

  var adventure = Adventure(root["name"], items, specialItems, levels);
  validate(adventure);

  return adventure;
}

validate(Adventure adventure) {
  if (adventure.name.isEmpty) {
    throw Exception("adventure contains empty name");
  }

  adventure.items.forEach((key, item) {
    if (key != item.id) {
      throw Exception("item key '$key' did not match the id '${item.id}'");
    }

    if (item.id.isEmpty) {
      throw Exception("item '$key' contains empty id");
    }

    if (item.image.isEmpty) {
      throw Exception("item '$key' contains empty image");
    }

    if (item.i18n.en.isEmpty) {
      throw Exception("item '$key' contains empty EN translation");
    }

    if (item.i18n.de.isEmpty) {
      throw Exception("item '$key' contains empty DE translation");
    }
  });

  if (!adventure.items.containsKey(adventure.specialItems.scan)) {
    throw Exception("special item 'scan' contains invalid item '${adventure.specialItems.check}'");
  }

  if (!adventure.items.containsKey(adventure.specialItems.check)) {
    throw Exception("special item 'check' contains invalid item '${adventure.specialItems.check}'");
  }

  if (!adventure.items.containsKey(adventure.specialItems.reset)) {
    throw Exception("special item 'reset' contains invalid item '${adventure.specialItems.reset}'");
  }

  if (!adventure.items.containsKey(adventure.specialItems.pass)) {
    throw Exception("special item 'pass' contains invalid item '${adventure.specialItems.pass}'");
  }

  adventure.levels.asMap().forEach((index, level) {
    if (level.id.isEmpty) {
      throw Exception("level '$index' contains empty id");
    }

    if (level.solution.type == SolutionType.invalid) {
      throw Exception("level '$index' contains 'invalid' solution type");
    }

    level.solution.items.forEach((item) {
      if (!adventure.items.containsKey(item)) {
        throw Exception("level '$index' contains invalid item '$item'");
      }
    });

    if (level.i18n.en.isEmpty) {
      throw Exception("level '$index' contains empty EN translation");
    }

    if (level.i18n.de.isEmpty) {
      throw Exception("level '$index' contains empty DE translation");
    }
  });
}
