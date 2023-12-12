import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert' show utf8;

bool isNfcAvalible = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  isNfcAvalible = await NfcManager.instance.isAvailable();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'NFC Writter - MISS22n'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String nfcValue = '';
  bool listenerRunning = false;
  bool writeCounterOnNextContact = false;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Данные с NFC-тега:',
            ),
            Container(
              height: 100,
              width: screenWidth,
              color: Colors.grey,
              child: SingleChildScrollView(
                child: Text(
                  '$nfcValue',
                  style: TextStyle(color: Colors.deepPurpleAccent),
                ),
              ),
            ),
            SizedBox(height: 20),
            _getNfcWidgets(),
          ],
        ),
      ),
    );
  }

  void clearValue() {
    setState(() {
      nfcValue = '';
    });
  }

  Widget _getNfcWidgets() {
    if (isNfcAvalible) {
      final nfcRunning = Platform.isAndroid && listenerRunning;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TextButton(
            onPressed: nfcRunning ? null : _listenForNFCEvents,
            child: Text(Platform.isAndroid
                ? listenerRunning
                    ? 'NFC активен'
                    : 'Начать прослушивание NFC'
                : 'Чтение с NFC-тега'),
          ),
          TextButton(
            onPressed: writeCounterOnNextContact ? null : _showTextInputDialog,
            child: Text(writeCounterOnNextContact
                ? 'Ожидание NFC-тега'
                : 'Переписать тег'),
          ),
          TextButton(
            onPressed: clearValue,
            child: Text('Очистить поле'),
          ),
        ],
      );
    } else {
      if (Platform.isIOS) {
        return const Text("NFC не поддерживается");
      } else {
        return const Text(
            "У вас нет NFC датчика, либо вы не включили его в настройках");
      }
    }
  }

  void _alert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
        duration: const Duration(
          seconds: 2,
        ),
      ),
    );
  }

  Future<void> _listenForNFCEvents() async {
    if (Platform.isAndroid && listenerRunning == false || Platform.isIOS) {
      if (Platform.isAndroid) {
        _alert(
          'Слушатель NFC запущен в фоновом режиме',
        );
        setState(() {
          listenerRunning = true;
        });
      }

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          bool succses = false;
          final ndefTag = Ndef.from(tag);
          if (ndefTag != null) {
            if (writeCounterOnNextContact) {
              setState(() {
                writeCounterOnNextContact = false;
              });

              final ndefRecord = NdefRecord.createText(nfcValue.toString());
              final ndefMessage = NdefMessage([ndefRecord]);

              if (nfcValue.startsWith("BEGIN")) {
                final ndefRecorda = NdefRecord.createMime(
                    'text/vcard', utf8.encode(nfcValue.toString()));
                final ndefMessagea = NdefMessage([ndefRecorda]);
                try {
                  await ndefTag.write(ndefMessagea);
                  _alert('Успешная запись контакта');
                  succses = true;
                } catch (e) {
                  _alert("Что то пошло не так, попробуйте еще раз");
                }
              }else if (nfcValue.startsWith("http")) {
                final ndefRecorda = NdefRecord.createUri(Uri.parse(nfcValue));
                final ndefMessagea = NdefMessage([ndefRecorda]);
                try {
                  await ndefTag.write(ndefMessagea);
                  _alert('Успешная запись контакта');
                  succses = true;
                } catch (e) {
                  _alert("Что то пошло не так, попробуйте еще раз");
                }
              } 
              else {
                try {
                  await ndefTag.write(ndefMessage);
                  _alert('Успешная запись');
                  succses = true;
                } catch (e) {
                  _alert("Что то пошло не так, попробуйте еще раз");
                }
              }
            } else if (ndefTag.cachedMessage != null) {
              var ndefMessage = ndefTag.cachedMessage!;
              if (ndefMessage.records.isNotEmpty &&
                  ndefMessage.records.first.typeNameFormat ==
                      NdefTypeNameFormat.nfcWellknown) {
                final wellKnownRecord = ndefMessage.records.first;

                if (wellKnownRecord.payload.first == 0x02) {
                  final languageCodeAndContentBytes =
                      wellKnownRecord.payload.skip(1).toList();
                  final languageCodeAndContentText =
                      utf8.decode(languageCodeAndContentBytes);
                  final payload = languageCodeAndContentText.substring(2);
                  final accessedText = languageCodeAndContentText;
                  if (accessedText != null) {
                    succses = true;
                    _alert('Текст с метки прочитан');
                    setState(() {
                      nfcValue = accessedText;
                    });
                  }
                }
              }
            }
          }
          if (Platform.isIOS) {
            NfcManager.instance.stopSession();
          }
          if (succses == false) {
            _alert(
              'Неизвестные символы в теге',
            );
          }
        },
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
      );
    }
  }

  @override
  void dispose() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _showTextInputDialog() async {
    String userInput = '';

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Введите текст:'),
          content: TextField(
            maxLines: 12,
            onChanged: (value) {
              userInput = value;
            },
            decoration: InputDecoration(hintText: 'Введите текст'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleUserInput(userInput);
              },
              child: Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  void _handleUserInput(String userInput) {
    nfcValue = userInput;
    _writeNfcTag();
  }

  void _writeNfcTag() {
    setState(() {
      writeCounterOnNextContact = true;
    });

    if (Platform.isAndroid) {
      _alert('Поднесите телефон к метке');
    }
    _listenForNFCEvents();
  }
}
