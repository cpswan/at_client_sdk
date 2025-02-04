import 'dart:convert';
import 'dart:typed_data';
import 'package:crypton/crypton.dart';
import 'package:crypto/crypto.dart';
import 'package:at_client/at_client.dart';

import 'package:at_functional_test/src/at_demo_credentials.dart'
    as demo_credentials;

class TestUtils {
  static AtClientPreference getPreference(String atsign) {
    var preference = AtClientPreference();
    preference.hiveStoragePath = 'test/hive/client';
    preference.commitLogPath = 'test/hive/client/commit';
    preference.isLocalStoreRequired = true;
    preference.privateKey = demo_credentials.pkamPrivateKeyMap[atsign];
    preference.rootDomain = 'vip.ve.atsign.zone';
    preference.decryptPackets = false;
    preference.pathToCerts = 'test/testData/cert.pem';
    preference.tlsKeysSavePath = 'test/tlsKeysFile';
    return preference;
  }

  static String generatePKAMDigest(String atSign, String challenge) {
    var privateKey = demo_credentials.pkamPrivateKeyMap[atSign]!;
    privateKey = privateKey.trim();
    var key = RSAPrivateKey.fromString(privateKey);
    challenge = challenge.trim();
    var sign =
        key.createSHA256Signature(Uint8List.fromList(utf8.encode(challenge)));
    return base64Encode(sign);
  }

  static String generateCramDigest(String atSign, String challenge) {
    var cramSecret = demo_credentials.cramKeyMap[atSign];
    var combo = '$cramSecret$challenge';
    var bytes = utf8.encode(combo);
    var digest = sha512.convert(bytes);
    return digest.toString();
  }
}
