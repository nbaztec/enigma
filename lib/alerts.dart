import 'package:flutter/material.dart';

import 'l18n.dart';

showAlertDialog(BuildContext context, String message) {
  // set up the button
  Widget okButton = TextButton(
    child: Text(l18n(context).ok),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );

  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: Text(l18n(context).error),
    content: Text(message),
    actions: [
      okButton,
    ],
  );

  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

showSuccessDialog(BuildContext context, String message, [Function? callback]) {
  // set up the button
  Widget okButton = TextButton(
    child: Text(l18n(context).goNext),
    onPressed: () {
      Navigator.of(context).pop();
      callback?.call();
    },
  );

  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: Text(l18n(context).success),
    content: Text(message),
    actions: [
      okButton,
    ],
  );

  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
