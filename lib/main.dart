import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Key;
import 'package:http/http.dart' as http;
import 'package:hex/hex.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:encrypt/encrypt.dart';
import 'dart:developer' as dev;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BigInt prime = BigInt.parse(
      '2519590847565789349402718324004839857142928212620403202777713783604366202070759555626401852588078440319989000889524345065854122758866688128587994947295862217267141979470472965420143143795456620222894513280219498070259966552162299342219321326844827929251973103819829821622445966589517287470093510435292976797507737790503236678909283015000734176730575835889059968026457832840035684297260429891061074821074388469629237581865175912064925096551495638841291927263901336308286602687269310282869331393304719337733344535422019926721680085385725646120332007023784237275458593770238788380303516666348330953849225241878667384160471232398798549252973532603871132889585584845987538896458580147290431254862178712094379024038050216422992278778861674962467606049291502693741747220284895508152116175869202624981225204862749658373128982055872146607625594321939210117046603778962636623940811418265860012799274421139910737649870489438719907779821118960331465310620710137480106982340634643619033723152504672548729892523722184419268358439923702724601654766828771153178402560248163882946092156369877902399642605223943262896569260602112916760348399219909796026186831302675752064202048659254011660969414138496445873332821688424743753514572540936618272375309662270870267494380651029694295');
  final BigInt generator = BigInt.two;
  BigInt? alicePrivateKey;
  BigInt? alicePublicKey;
  BigInt? sharedSecret;
  Uint8List? aesKey;
  Encrypter? encrypter;

  File? _selectedImage;
  String _encyrptedImage = '';
  String _encyrptedPosition = '';

  @override
  void initState() {
    super.initState();
    generateKeys();
  }

  Future<void> sendData(String encryptedImage, String encryptedPosition) async {
    // Create the JSON body
    Map<String, dynamic> body = {
      'image': encryptedImage,
      'location': encryptedPosition,
    };
    try {
// Specify your endpoint URL
      final url = Uri.parse('http://172.25.10.111:8000/data');
      print('rani hna 1');
      // Send the POST request
      http.Response response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        // Successfully uploaded
        print('Image uploaded successfully');
      } else {
        // Handle error
        print('Image upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception --> $e');
    }
  }

  Future _pickImageFromCamera() async {
    final returnedImage =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (returnedImage == null) return;
    setState(() {
      _selectedImage = File(returnedImage.path);
    });
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location services are demied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied forever');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<String> encryptingData(String plainText) async {
    String encryptedText;
    //using a fixed iv in both server and sensor for simplification
    final iv = IV.fromUtf8('df1e180949793972');
    try {
      final encrypted = encrypter!.encrypt(plainText, iv: iv);
      encryptedText = encrypted.base64;
    } on Exception catch (e) {
      encryptedText = e.toString();
    }
    return encryptedText;
  }

  void generateKeys() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    alicePrivateKey = BigInt.parse(HEX.encode(bytes), radix: 16);
    alicePublicKey = generator.modPow(alicePrivateKey!, prime);
    print("ok 1");
    await performKeyExchange();
    print("ok 2");
  }

  // Future<void> sendData(String data) async {
  //   print("aes key before  sending : $aesKey");
  //   data = await encryptingData(data);
  //   // Create the JSON body
  //   Map<String, dynamic> body = {
  //     'data': data,
  //   };
  //   try {
  //     // Specify your endpoint URL
  //     final url = Uri.parse('http://172.25.10.111:8000/data');
  //     // Send the POST request
  //     http.Response response = await http.post(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode(body),
  //     );
  //     setState(() {
  //       iconColor = !iconColor;
  //     });
  //     if (response.statusCode == 200) {
  //       // Successfully uploaded
  //       print('data sent successfully');
  //     } else {
  //       // Handle error
  //       print('data failed: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Exception --> $e');
  //   }
  // }

  Future<void> performKeyExchange() async {
    print('dakhel');
    final response = await http.post(
      Uri.parse('http://172.25.10.111:8000/key-exchange'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'alicePublicKey': alicePublicKey.toString(),
      }),
    );
    print('dakhel 2');
    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      final bobPublicKey = BigInt.parse(responseBody['bobPublicKey']);
      sharedSecret = bobPublicKey.modPow(alicePrivateKey!, prime);
      dev.log("clé partagée : $sharedSecret");

      //using a fixed iv in both server and sensor for simplification
      // Derive AES key from shared secret
      aesKey = deriveAesKey(sharedSecret!);
      print(aesKey);
      // Encrypt a message using AES with the derived key and fixed IV
      encrypter = Encrypter(
          AES(Key.fromBase64(base64.encode(aesKey!)), mode: AESMode.cbc));
    } else {
      throw Exception('Failed to perform key exchange');
    }
  }

  Uint8List deriveAesKey(BigInt sharedSecret) {
    // Fixed hardcoded salt
    final Uint8List salt = Uint8List.fromList(
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);

    // Convert shared secret to bytes
    final sharedSecretHex = sharedSecret.toRadixString(16);
    final sharedSecretBytes = Uint8List.fromList(HEX.decode(sharedSecretHex));

    const iterationCount = 1000; // Number of iterations
    const keyLength = 16; // Key length in bytes (16 bytes = 128 bits)

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    final params = Pbkdf2Parameters(salt, iterationCount, keyLength);
    pbkdf2.init(params);

    String sharedhex = HEX.encode(sharedSecretBytes);

    if (sharedhex[0] == "0") {
      sharedhex = "0x" + sharedhex.substring(1);
    } else {
      sharedhex = "0x" + sharedhex;
    }
    Uint8List byteArray = Uint8List.fromList(utf8.encode(sharedhex));
    print("hex shared  ${sharedhex}");

    print("sharedSecretBytesarray ${byteArray}");
    // Derive the AES key
    final aesKey = pbkdf2.process(byteArray);
    print('aeskey: $aesKey');
    return aesKey;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('GPS & camera sensors'),
          centerTitle: true,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Container(
          height: 80,
          width: 80,
          child: FittedBox(
            child: FloatingActionButton(
              child: Icon(
                Icons.camera,
              ),
              onPressed: () async {
                await _pickImageFromCamera();
                List<int> imageBytes = await _selectedImage!.readAsBytes();
                String base64Image = base64Encode(imageBytes);
                _encyrptedImage = await encryptingData(base64Image);
                print("encr data: $_encyrptedImage");
                _getCurrentLocation().then((value) async {
                  print("la valeur : $value");
                  String base64Position = base64Encode(
                      utf8.encode('${value.latitude};${value.longitude}'));
                  print("position base64 --> $base64Position");
                  _encyrptedPosition = await encryptingData(base64Position);

                  print("encr data: $_encyrptedPosition");
                  sendData(_encyrptedImage, _encyrptedPosition);
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
