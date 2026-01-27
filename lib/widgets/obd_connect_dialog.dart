import 'package:flutter/material.dart';
import '../services/obd_service.dart';
import '../core/permissions/ensure_bt_permissions.dart';
import '../providers/obd_provider.dart';

Future<void> showObdConnectDialog(
  BuildContext context, {
  required OBDService obd,
  required String target,
}) async {
  final btOn = await obd.ensureEnabled();
  if (!btOn) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez activer le Bluetooth.')),
      );
    }
    return;
  }

  final granted = await ensureBluetoothPermissions();
  if (!granted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions Bluetooth refusées.')),
      );
    }
    return;
  }

  final msg = ValueNotifier<String>(
    "Connexion à l'adaptateur ELM327 ...\nBluetooth: $target",
  );
  var canceled = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: msg,
              builder: (_, value, __) => Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                canceled = true;
                try {
                  await obd.disconnect();
                } catch (_) {}
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              },
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    ),
  );

  await Future.delayed(const Duration(milliseconds: 80));

  try {
    msg.value = "Connexion à l'adaptateur ELM327 ...\nBluetooth: $target";
    await obd.connect(target);
    if (canceled) return;

    msg.value = "Connexion à l'UCE ...";
    final ok = await obd.handshakeEcu();
    if (canceled) return;

    Navigator.of(context, rootNavigator: true).maybePop();

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connecté à l'ELM327 et à l'UCE")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ELM327 OK, handshake ECU invalide")),
      );
    }
  } catch (e) {
    Navigator.of(context, rootNavigator: true).maybePop();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Échec de connexion'),
        content: Text(e.toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  } finally {
    msg.dispose();
  }
}

Future<void> showObdConnectDialogWithController(
  BuildContext context, {
  required OBDController ctrl,
  required String target,
}) async {
  final msg = ValueNotifier<String>(
    "Connexion à l'adaptateur ELM327 ...\nBluetooth: $target",
  );
  var canceled = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: msg,
              builder: (_, value, __) => Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                canceled = true;
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              },
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    ),
  );

  await Future.delayed(const Duration(milliseconds: 80));

  try {
    msg.value = "Connexion à l'adaptateur ELM327 ...\nBluetooth: $target";
    await ctrl.connectTo(target);
    if (canceled) return;
    Navigator.of(context, rootNavigator: true).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Connexion terminée")),
    );
  } catch (e) {
    Navigator.of(context, rootNavigator: true).maybePop();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Échec de connexion'),
        content: Text(e.toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  } finally {
    msg.dispose();
  }
}
