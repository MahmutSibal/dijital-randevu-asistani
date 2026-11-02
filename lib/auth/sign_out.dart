import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';

Future<void> confirmSignOut(BuildContext context) async {
  final session = SessionScope.read(context);
  if (await confirm(
    context,
    'ÇIKIŞ',
    'Oturumunuz kapatılacak. Devam etmek istiyor musunuz?',
  )) {
    await session.signOut();
  }
}
