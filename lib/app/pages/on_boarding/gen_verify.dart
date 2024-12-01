import 'dart:convert';
import 'dart:math';

import 'package:credible/app/interop/didkit/didkit.dart';
import 'package:credible/app/interop/secure_storage/secure_storage.dart';
import 'package:credible/app/interop/trustchain/trustchain.dart';
import 'package:credible/app/pages/profile/models/config.dart';
import 'package:credible/app/shared/key_generation.dart';
import 'package:credible/app/shared/widget/back_leading_button.dart';
import 'package:credible/app/shared/widget/base/button.dart';
import 'package:credible/app/shared/widget/base/page.dart';
import 'package:credible/app/shared/widget/base/text_field.dart';
import 'package:credible/app/shared/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:logging/logging.dart';

class OnBoardingGencVerifyPage extends StatefulWidget {
  @override
  _OnBoardingGencVerifyPageState createState() =>
      _OnBoardingGencVerifyPageState();
}

class _OnBoardingGencVerifyPageState extends State<OnBoardingGencVerifyPage> {
  int _random = 0;
  bool _valid = false;
  List<String> _mnemonic = [];
  bool _isWaiting = false;

  late TextEditingController _mnemonicFirstController;
  late bool _mnemonicFirstEdited;
  late bool _mnemonicFirstValid;

  late TextEditingController _mnemonicRandomController;
  late bool _mnemonicRandomEdited;
  late bool _mnemonicRandomValid;

  late TextEditingController _mnemonicLastController;
  late bool _mnemonicLastEdited;
  late bool _mnemonicLastValid;

  String get _mnemonicFirst => _mnemonic.first;

  String get _mnemonicRandom => _mnemonic[_random];

  String get _mnemonicLast => _mnemonic.last;

  bool _validate(TextEditingController controller, String compare) {
    final text = controller.text;
    return text.isNotEmpty && text.compareTo(compare) == 0;
  }

  void _validateAll() {
    final firstValid = _validate(_mnemonicFirstController, _mnemonicFirst);
    final randomValid = _validate(_mnemonicRandomController, _mnemonicRandom);
    final lastValid = _validate(_mnemonicLastController, _mnemonicLast);

    setState(() {
      _mnemonicFirstValid = firstValid;
      _mnemonicRandomValid = randomValid;
      _mnemonicLastValid = lastValid;
      _valid = firstValid && randomValid && lastValid;
    });
  }

  void _setFirstEdited() {
    setState(() {
      _mnemonicFirstEdited = true;
    });
  }

  void _setRandomEdited() {
    setState(() {
      _mnemonicRandomEdited = true;
    });
  }

  void _setLastEdited() {
    setState(() {
      _mnemonicLastEdited = true;
    });
  }

  @override
  void initState() {
    super.initState();

    _mnemonicFirstEdited = false;
    _mnemonicFirstValid = false;
    _mnemonicFirstController = TextEditingController();
    _mnemonicFirstController.addListener(_validateAll);
    _mnemonicFirstController.addListener(_setFirstEdited);

    _mnemonicRandomEdited = false;
    _mnemonicRandomValid = false;
    _mnemonicRandomController = TextEditingController();
    _mnemonicRandomController.addListener(_validateAll);
    _mnemonicRandomController.addListener(_setRandomEdited);

    _mnemonicLastEdited = false;
    _mnemonicLastValid = false;
    _mnemonicLastController = TextEditingController();
    _mnemonicLastController.addListener(_validateAll);
    _mnemonicLastController.addListener(_setLastEdited);

    Future.delayed(Duration.zero, () {
      _loadKey();
    });
  }

  Future<void> _loadKey() async {
    final mnemonic =
        (await SecureStorageProvider.instance.get('mnemonic'))!.split(' ');
    final random = Random().nextInt(mnemonic.length - 2) + 1;

    setState(() {
      _mnemonic = mnemonic;
      _random = random;
    });
  }

  String _ordinal(final int i) {
    var j = i % 10, k = i % 100;
    if (j == 1 && k != 11) {
      return '${i}st';
    }
    if (j == 2 && k != 12) {
      return '${i}nd';
    }
    if (j == 3 && k != 13) {
      return '${i}rd';
    }
    return '${i}th';
  }

  String get _randomStr {
    return _ordinal(_random + 1);
  }

  Future<void> generateKey(BuildContext context) async {
    final log = Logger('credible/on-boarding/key-generation');

    final localizations = AppLocalizations.of(context)!;
    try {
      final mnemonic = (await SecureStorageProvider.instance.get('mnemonic'))!;
      final key = await KeyGeneration.privateKey(mnemonic);
      final didKey =
          DIDKitProvider.instance.keyToDID(Constants.defaultDIDMethod, key);
      final didIon = jsonDecode(await trustchain_ffi.createOperationMnemonic(
              mnemonic: mnemonic))['did']
          .toString();
      await SecureStorageProvider.instance.set('key', key);
      await SecureStorageProvider.instance
          .set(ConfigModel.didIonMethodKey, 'false');
      await SecureStorageProvider.instance.set(ConfigModel.didKeyKey, didKey);
      await SecureStorageProvider.instance.set(ConfigModel.didIonKey, didIon);
      await SecureStorageProvider.instance.set(ConfigModel.rootEventTimeKey,
          const String.fromEnvironment('rootEventTime', defaultValue: ''));
      await SecureStorageProvider.instance.set(
          ConfigModel.trustchainEndpointKey,
          const String.fromEnvironment('trustchainEndpoint', defaultValue: ''));
      await Modular.to.pushReplacementNamed('/on-boarding/success');
    } catch (error) {
      log.severe('something went wrong when generating a key', error);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text(localizations.errorGeneratingKey),
      ));

      await Modular.to.pushReplacementNamed('/on-boarding/key');
    }
  }

  void _onSubmit() async {
    setState(() => _isWaiting = true);
    await generateKey(context);
    setState(() => _isWaiting = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BasePage(
      title: localizations.onBoardingGenVerifyTitle,
      titleLeading: BackLeadingButton(),
      scrollView: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            localizations.onBoardingGenVerifyInstruction(_randomStr),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.subtitle2,
          ),
          const SizedBox(height: 32.0),
          BaseTextField(
            label: localizations.onBoardingGenVerifyMnemonicLabel('First'),
            controller: _mnemonicFirstController,
            error: _mnemonicFirstEdited && !_mnemonicFirstValid
                ? localizations.onBoardingGenVerifyMnemonicError('first')
                : null,
          ),
          const SizedBox(height: 16.0),
          BaseTextField(
            label: localizations.onBoardingGenVerifyMnemonicLabel(_randomStr),
            controller: _mnemonicRandomController,
            error: _mnemonicRandomEdited && !_mnemonicRandomValid
                ? localizations.onBoardingGenVerifyMnemonicError(_randomStr)
                : null,
          ),
          const SizedBox(height: 16.0),
          BaseTextField(
            label: localizations.onBoardingGenVerifyMnemonicLabel('Last'),
            controller: _mnemonicLastController,
            error: _mnemonicLastEdited && !_mnemonicLastValid
                ? localizations.onBoardingGenVerifyMnemonicError('last')
                : null,
          ),
          const SizedBox(height: 32.0),
          BaseButton.primary(
            onPressed: _valid ? _onSubmit : null,
            child: _isWaiting
                ? Text('Please wait...') // TODO: add to localizations.
                : Text(localizations.onBoardingGenVerifyButton),
          ),
        ],
      ),
    );
  }
}
