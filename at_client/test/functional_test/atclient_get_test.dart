import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_commons/at_commons.dart';
import 'package:test/test.dart';

import 'at_demo_credentials.dart' as demo_credentials;
import 'set_encryption_keys.dart';

AtClient? atClient;
void main() {
  Future<void> setUpClient() async {
    var firstAtsign = '@alice🛠';
    var firstAtsignPreference = getAlicePreference(firstAtsign);
    await AtClientImpl.createClient(firstAtsign, 'me', firstAtsignPreference);
    atClient = (await AtClientImpl.getClient(firstAtsign))!;
    atClient!.getSyncManager()!.init(firstAtsign, firstAtsignPreference,
        atClient!.getRemoteSecondary(), atClient!.getLocalSecondary());
    await atClient!.getSyncManager()!.sync();
    // To setup encryption keys
    await setEncryptionKeys(firstAtsign, firstAtsignPreference);
  }

  test('get method - fetching a public key', () async {
    await setUpClient();
    // phone.me@alice🛠
    var metadata = Metadata()..isPublic = true;
    var twitterKey = AtKey()
      ..key = 'twitter'
      ..metadata = metadata;
    var value = 'alice_123';
    var putResult = await atClient!.put(twitterKey, value);
    expect(putResult, true);
    var getResult = await atClient!.get(twitterKey);
    expect(getResult.value, value);
  });

  test('get method - fetching a public key', () async {
    await setUpClient();
    // phone.me@alice🛠
    var metadata = Metadata()..isPublic = true;
    var twitterKey = AtKey()
      ..key = 'twitter'
      ..metadata = metadata;
    var value = 'alice_123';
    var putResult = await atClient!.put(twitterKey, value);
    expect(putResult, true);
    var getResult = await atClient!.get(twitterKey);
    expect(getResult.value, value);
  });

  test('get method - fetching a private key', () async {
    await setUpClient();
    // phone.me@alice🛠
    var metadata = Metadata()..ttr = 8640000;
    var cityKey = AtKey()
      ..key = 'city'
      ..sharedWith = '@bob🛠'
      ..metadata = metadata;
    var value = 'Hyderabad';
    var putResult = await atClient!.put(cityKey, value);
    expect(putResult, true);
    var getResult = await atClient!.get(cityKey);
    expect(getResult.value, value);
  });
}

Future<void> tearDownFunc() async {
  var isExists = await Directory('test/hive').exists();
  if (isExists) {
    Directory('test/hive').deleteSync(recursive: true);
  }
}

AtClientPreference getAlicePreference(String atsign) {
  var preference = AtClientPreference();
  preference.hiveStoragePath = 'test/hive/client';
  preference.commitLogPath = 'test/hive/client/commit';
  preference.isLocalStoreRequired = true;
  preference.syncStrategy = SyncStrategy.IMMEDIATE;
  preference.privateKey = demo_credentials.pkamPrivateKeyMap[atsign];
  preference.rootDomain = 'vip.ve.atsign.zone';
  return preference;
}
