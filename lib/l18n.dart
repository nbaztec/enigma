import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

l18n(BuildContext context) {
  return AppLocalizations.of(context)!;
}

var localizationsDelegates = AppLocalizations.localizationsDelegates;
var supportedLocales = AppLocalizations.supportedLocales;