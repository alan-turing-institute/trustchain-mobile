import 'dart:convert';
import 'package:credible/app/interop/trustchain/trustchain.dart';
import 'package:credible/app/pages/credentials/blocs/wallet.dart';
import 'package:credible/app/pages/credentials/models/verification_state.dart';
import 'package:credible/app/shared/config.dart';
import 'package:credible/app/shared/ui/ui.dart';
import 'package:credible/app/shared/widget/base/box_decoration.dart';
import 'package:credible/app/shared/widget/base/button.dart';
import 'package:credible/app/shared/widget/base/page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:credible/app/shared/widget/flutter_json_viewer_presentation.dart';
// import 'package:flutter_json_viewer/flutter_json_viewer.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:logging/logging.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PresentationViewer extends StatefulWidget {
  final String presentation;

  const PresentationViewer({Key? key, required this.presentation})
      : super(key: key);

  @override
  _PresentationViewerState createState() => _PresentationViewerState();
}

class _PresentationViewerState
    extends ModularState<PresentationViewer, WalletBloc> {
  bool showShareMenu = false;
  dynamic issuerDidDocument;
  VerificationState verification = VerificationState.Unverified;

  final logger = Logger('credible/presentation/view');

  @override
  void initState() {
    super.initState();
    verify();
  }

  void verify() async {
    final json = jsonDecode(widget.presentation);
    assert(json.containsKey('holder'));
    final opts = jsonEncode(await ffi_config_instance.get_ffi_config());
    try {
      await trustchain_ffi.vpVerifyPresentation(
          presentation: widget.presentation, opts: opts);
      // If the presentation is more than 15 minutes old, display a warning.
      assert(json.containsKey('proof'));
      assert(json['proof'].containsKey('created'));
      final vp_timestamp = DateTime.parse(json['proof']['created']);
      final vp_age = DateTime.now().difference(vp_timestamp);
      if (vp_age < Duration(minutes: 15)) {
        setState(() {
          verification = VerificationState.Verified;
        });
      } else {
        setState(() {
          verification = VerificationState.VerifiedWithWarning;
        });
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: VerificationState.VerifiedWithWarning.color,
          content:
              Text(localizations.stalePresentationWarning(vp_age.inMinutes)),
        ));
      }
    } on FfiException catch (err) {
      print(err);
      setState(() {
        verification = VerificationState.VerifiedWithError;
      });
    }
  }

  IconButton handleBackButton() {
    return IconButton(
      onPressed: () {
        if (kDebugMode) {
          // Emulator: go to list
          Modular.to.pushReplacementNamed('/credentials/list');
        } else {
          // Release mode: return to scanner
          Modular.to.pushReplacementNamed('/qr-code/scan');
        }
      },
      icon: Icon(
        Icons.arrow_back,
        color: UiKit.palette.icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Add proper localization
    final localizations = AppLocalizations.of(context)!;

    return BasePage(
      title: 'Presentation',
      titleLeading: handleBackButton(),
      navigation: Container(
        color: UiKit.palette.navBarBackground,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            // TODO: replace all Text buttons with icons.
            children: [],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 64.0),
          if (verification == VerificationState.Unverified)
            Center(child: CircularProgressIndicator())
          else ...<Widget>[
            Center(
              child: Text(
                localizations.credentialDetailStatus,
                style: Theme.of(context).textTheme.overline!,
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  verification.icon,
                  color: verification.color,
                ),
                const SizedBox(width: 8.0),
                Text(
                  verification.message,
                  style: Theme.of(context)
                      .textTheme
                      .caption!
                      .apply(color: verification.color),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32.0),
          Container(
            decoration: BaseBoxDecoration(
              color: Colors.white.withOpacity(0.8),
              value: 0.0,
              shapeSize: 256.0,
              anchors: <Alignment>[
                Alignment.topRight,
                Alignment.bottomCenter,
              ],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(0.0, 12.0, 8.0, 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [JsonViewer(jsonDecode(widget.presentation))],
              ),
            ),
          ),
          const SizedBox(height: 32.0),
          BaseButton.primary(
            onPressed: () => Modular.to.pushNamed(
              '/did/chain',
              arguments: [
                jsonDecode(widget.presentation)['verifiableCredential']
                    ['issuer'],
              ],
            ),
            child: Tooltip(
              message: localizations.credentialDetailShowChainTooltip,
              child: Text(
                "Show attestation chain",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: UiKit.palette.credentialText),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
