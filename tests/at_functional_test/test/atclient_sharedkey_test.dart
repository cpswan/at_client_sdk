import 'package:at_client/at_client.dart';
import 'package:at_client/src/encryption_service/encryption_manager.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_functional_test/src/at_keys_intialializer.dart';
import 'package:at_functional_test/src/sync_service.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  late AtClientManager atClientManager;
  late AtClient atClient;
  var sharedWithAtSign = '@bob🛠';
  var currentAtSign = '@alice🛠';
  var namespace = 'wavi';

  setUpAll(() async {
    var preference = TestUtils.getPreference(currentAtSign);
    atClientManager = await AtClientManager.getInstance()
        .setCurrentAtSign(currentAtSign, namespace, preference);
    atClient = atClientManager.atClient;
    // To setup encryption keys
    await AtEncryptionKeysLoader.getInstance()
        .setEncryptionKeys(atClientManager.atClient, currentAtSign);
  });

  test('shared key - check sharedKey and checksum in metadata', () async {
    var phoneKey = AtKey()
      ..key = 'location'
      ..sharedWith = sharedWithAtSign;
    var value = 'NewJersey';
    var putResult = await atClient.put(phoneKey, value);
    expect(putResult, true);
    var metadata = await atClient.getMeta(phoneKey);
    expect(metadata!.sharedKeyEnc, isNotEmpty);
    expect(metadata.pubKeyCS, isNotEmpty);
  });

  test('sharedKey and checksum metadata sync to local storage', () async {
    var phoneKey = AtKey()
      ..key = 'phone'
      ..sharedWith = sharedWithAtSign
      ..sharedBy = currentAtSign
      ..metadata = (Metadata()..ttl = 120000);
    var value = '+91 887 888 3435';
    var encryptionService =
        AtKeyEncryptionManager(atClient).get(phoneKey, currentAtSign);
    var encryptedValue = await encryptionService.encrypt(phoneKey, value);
    var result = await atClient.getRemoteSecondary()!.executeCommand(
        'update:sharedKeyEnc:${phoneKey.metadata?.sharedKeyEnc}:pubKeyCS:${phoneKey.metadata?.pubKeyCS}:${phoneKey.sharedWith}:${phoneKey.key}.$namespace$currentAtSign $encryptedValue\n',
        auth: true);
    expect(result != null, true);
    await FunctionalTestSyncService.getInstance()
        .syncData(atClientManager.atClient.syncService);
    var metadata = await atClient.getMeta(phoneKey);
    expect(metadata?.sharedKeyEnc, isNotEmpty);
    expect(metadata?.pubKeyCS, isNotEmpty);
  });
}
