import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_client/src/response/at_notification.dart' as at_notification;
import 'package:at_client/src/service/sync/sync_request.dart';
import 'package:at_client/src/service/sync_service_impl.dart';
import 'package:at_client/src/service/notification_service_impl.dart';
import 'package:at_client/src/util/sync_util.dart';
import 'package:at_commons/at_builders.dart';
import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

var mockCommitLogStore = {};

class MockSecondaryKeyStore extends Mock implements SecondaryKeyStore {
  Map<String, AtData> localKeyStore = {
    'mobile.wavi': AtData()..data = '12345',
    'country.wavi': AtData()..data = 'India',
    'location.wavi': AtData()..data = 'Hyderabad',
    'about.wavi': AtData()..data = '@sign',
    'phone.wavi': AtData()..data = '12345'
  };

  @override
  Future<AtData> get(key) async {
    return Future.value(localKeyStore[key]);
  }

  @override
  bool isKeyExists(String key) {
    if (key.startsWith('local:lastreceivedservercommitid')) {
      return false;
    }
    return true;
  }
}

class MockLocalSecondary extends Mock implements LocalSecondary {
  @override
  SecondaryKeyStore? get keyStore => MockSecondaryKeyStore();
}

class MockRemoteSecondary extends Mock implements RemoteSecondary {
  var remoteKeyStore = {};
}

class MockAtClient extends Mock implements AtClient {
  @override
  String? getCurrentAtSign() {
    return '@alice';
  }

  @override
  AtClientPreference getPreferences() {
    return AtClientPreference();
  }
}

class MockAtClientManager extends Mock implements AtClientManager {}

class MockNotificationServiceImpl extends Mock
    implements NotificationServiceImpl {
  @override
  Stream<at_notification.AtNotification> subscribe(
      {String? regex, bool shouldDecrypt = false}) {
    return StreamController<at_notification.AtNotification>().stream;
  }
}

class MockAtCommitLog extends Mock implements AtCommitLog {
  @override
  Future<void> update(CommitEntry commitEntry, int commitId) async {
    mockCommitLogStore.putIfAbsent(
        commitId, () => commitEntry..commitId = commitId);
  }
}

class FakeSyncVerbBuilder extends Fake implements SyncVerbBuilder {}

class FakeUpdateVerbBuilder extends Fake implements UpdateVerbBuilder {}

class FakeStatsVerbBuilder extends Fake implements StatsVerbBuilder {}

class FakeAtKey extends Fake implements AtKey {}

void main() async {
  AtClient mockAtClient = MockAtClient();
  AtClientManager mockAtClientManager = MockAtClientManager();
  NotificationServiceImpl mockNotificationService =
      MockNotificationServiceImpl();
  AtCommitLog mockAtCommitLog = MockAtCommitLog();
  RemoteSecondary mockRemoteSecondary = MockRemoteSecondary();
  LocalSecondary mockLocalSecondary = MockLocalSecondary();

  var syncServiceImpl = await SyncServiceImpl.create(mockAtClient,
      atClientManager: mockAtClientManager,
      notificationService: mockNotificationService,
      remoteSecondary: mockRemoteSecondary) as SyncServiceImpl;
  syncServiceImpl.syncUtil = SyncUtil(atCommitLog: mockAtCommitLog);

  setUp(() {
    reset(mockRemoteSecondary);
  });

  group('A group of positive tests on sync service', () {
    var localCommitId = -1;
    test('sync server changes to local', () async {
      registerFallbackValue(FakeSyncVerbBuilder());
      registerFallbackValue(FakeUpdateVerbBuilder());
      registerFallbackValue(FakeAtKey());

      when(() => mockAtClient.put(
              any(that: LastReceivedServerCommitIdMatcher()), any()))
          .thenAnswer((_) => Future.value(true));
      when(() => mockRemoteSecondary.executeVerb(any()))
          .thenAnswer((_) => Future.value('data:${jsonEncode([
                    {
                      "atKey": "public:twitter.wavi@alice",
                      "value": "twitter.alice",
                      "metadata": {
                        "createdAt": "2021-04-08 12:59:19.251",
                        "updatedAt": "2021-04-08 12:59:19.251"
                      },
                      "commitId": 1,
                      "operation": "+"
                    },
                    {
                      "atKey": "public:instagram.wavi@alice",
                      "value": "instagram.alice",
                      "metadata": {
                        "createdAt": "2021-04-08 07:39:27.616Z",
                        "updatedAt": "2022-06-30 09:41:59.264Z"
                      },
                      "commitId": 2,
                      "operation": "*"
                    }
                  ])}'));

      when(() => mockAtClient.getLocalSecondary())
          .thenAnswer((_) => mockLocalSecondary);
      when(() => mockLocalSecondary.executeVerb(any(), sync: false))
          .thenAnswer((_) => Future.value('data:${++localCommitId}'));
      when(() => mockAtCommitLog.lastSyncedEntry()).thenAnswer((_) =>
          Future.value(
              CommitEntry('phone.wavi', CommitOp.UPDATE, DateTime.now())
                ..commitId = localCommitId));
      when(() => mockAtCommitLog.getChanges(any(), any()))
          .thenAnswer((_) => Future.value([]));
      when(() => mockAtCommitLog.getEntry(any())).thenAnswer((_) =>
          Future.value(
              CommitEntry('phone.wavi', CommitOp.UPDATE, DateTime.now())
                ..commitId = localCommitId));
      when(() =>
              mockAtClient.get(any(that: LastReceivedServerCommitIdMatcher())))
          .thenAnswer((invocation) =>
              throw AtKeyNotFoundException('key is not found in keystore'));

      var serverCommitId = 2;
      var syncRequest = SyncRequest()..result = SyncResult();
      await syncServiceImpl.syncInternal(serverCommitId, syncRequest);
      expect(mockCommitLogStore.isNotEmpty, true);
      mockCommitLogStore.clear();
    });
  });

  group('A group of tests to validate exception chaining in sync service', () {
    test('A test to validate server responds with AtTimeOutException',
        () async {
      registerFallbackValue(FakeSyncVerbBuilder());
      registerFallbackValue(FakeAtKey());
      var localCommitId = -1;

      when(() => mockAtClient.getLocalSecondary())
          .thenAnswer((_) => mockLocalSecondary);
      when(() => mockAtClient.put(
              any(that: LastReceivedServerCommitIdMatcher()), any()))
          .thenAnswer((_) => Future.value(true));
      when(() => mockAtCommitLog.lastSyncedEntry()).thenAnswer((_) =>
          Future.value(
              CommitEntry('phone.wavi', CommitOp.UPDATE, DateTime.now())
                ..commitId = localCommitId));
      when(() => mockAtCommitLog.getChanges(any(), any()))
          .thenAnswer((_) => Future.value([]));
      when(() => mockRemoteSecondary
              .executeVerb(any(that: isA<SyncVerbBuilder>())))
          .thenThrow(AtTimeoutException(
              'Waited for 10000 millis. No response after 90000',
              intent: Intent.syncData,
              exceptionScenario: ExceptionScenario.remoteVerbExecutionFailed));
      when(() => mockRemoteSecondary
              .executeVerb(any(that: isA<StatsVerbBuilder>())))
          .thenAnswer((_) => Future.value('data:${jsonEncode([
                    {"id": "3", "name": "lastCommitID", "value": "5"}
                  ])}'));
      when(() =>
              mockAtClient.get(any(that: LastReceivedServerCommitIdMatcher())))
          .thenAnswer((invocation) =>
              throw AtKeyNotFoundException('key is not found in keystore'));

      // ignore: prefer_typing_uninitialized_variables
      var actualSyncException;

      var listener = MySyncProgressListener();
      syncServiceImpl.addProgressListener(listener);
      syncServiceImpl.sync(onError: (SyncResult syncResult) {
        actualSyncException = syncResult.atClientException;
      });

      await syncServiceImpl.processSyncRequests(
          respectSyncRequestQueueSizeAndRequestTriggerDuration: false);

      while (!listener.syncComplete) {
        await Future.delayed(Duration(milliseconds: 10));
      }

      expect(actualSyncException, isA<AtClientException>());
      expect(actualSyncException.getTraceMessage(),
          'Failed to syncData caused by\nWaited for 10000 millis. No response after 90000');
    });
  });

  group('A group of tests to validate exception during sync processing', () {
    var localCommitId = -1;
    test('invalid batch json from server', () async {
      registerFallbackValue(FakeSyncVerbBuilder());
      registerFallbackValue(FakeUpdateVerbBuilder());
      registerFallbackValue(FakeAtKey());

      when(() => mockAtClient.getLocalSecondary())
          .thenAnswer((_) => mockLocalSecondary);
      when(() => mockAtClient.put(
              any(that: LastReceivedServerCommitIdMatcher()), any()))
          .thenAnswer((_) => Future.value(true));
      when(() => mockRemoteSecondary.executeVerb(any()))
          .thenAnswer((_) => Future.value('data:${jsonEncode([
                    {
                      "atKey": "public:twitter.wavi@alice",
                      "value": "twitter.alice",
                      "metadata": {
                        "createdAt": "2021-04-08 12:59:19.251",
                        "updatedAt": "2021-04-08 12:59:19.251"
                      },
                      "commitId": 1,
                      "operation": "+"
                    },
                    {
                      "atKey": "public:insta.buzz@alice",
                      "value": "insta_buzz",
                      "metadata": {
                        "createdAt": "2021-04-08 07:39:27.616Z",
                        "updatedAt": "2022-06-30 09:41:59.264Z"
                      },
                      "commitId": '2', //invalid data type
                      "operation": "*"
                    },
                    {
                      "atKey": "public:instagram.wavi@alice",
                      "value": "instagram.alice",
                      "metadata": {
                        "createdAt": "2021-04-08 07:39:27.616Z",
                        "updatedAt": "2022-06-30 09:41:59.264Z"
                      },
                      "commitId": 3,
                      "operation": "*"
                    }
                  ])}'));

      when(() => mockAtClient.getLocalSecondary())
          .thenAnswer((_) => mockLocalSecondary);
      when(() => mockLocalSecondary.executeVerb(any(), sync: false))
          .thenAnswer((_) => Future.value('data:${++localCommitId}'));
      when(() => mockAtCommitLog.lastSyncedEntry()).thenAnswer((_) =>
          Future.value(
              CommitEntry('phone.wavi', CommitOp.UPDATE, DateTime.now())
                ..commitId = localCommitId));
      when(() => mockAtCommitLog.getChanges(any(), any()))
          .thenAnswer((_) => Future.value([]));
      when(() => mockAtCommitLog.getEntry(any())).thenAnswer((_) =>
          Future.value(
              CommitEntry('phone.wavi', CommitOp.UPDATE, DateTime.now())
                ..commitId = localCommitId));
      when(() =>
              mockAtClient.get(any(that: LastReceivedServerCommitIdMatcher())))
          .thenAnswer((invocation) =>
              throw AtKeyNotFoundException('key is not found in keystore'));

      var serverCommitId = 2;
      var syncRequest = SyncRequest()..result = SyncResult();
      print('calling sync internal');
      final syncResult =
          await syncServiceImpl.syncInternal(serverCommitId, syncRequest);
      expect(syncResult.keyInfoList, isNotEmpty);
      expect(syncResult.keyInfoList.length, 2);
      expect(syncResult.keyInfoList[0].key, 'public:twitter.wavi@alice');
      expect(syncResult.keyInfoList[1].key, 'public:instagram.wavi@alice');
      mockCommitLogStore.clear();
    });
  });
}

class MySyncProgressListener extends SyncProgressListener {
  bool syncComplete = false;

  @override
  void onSyncProgressEvent(SyncProgress syncProgress) {
    if (syncProgress.syncStatus == SyncStatus.failure ||
        syncProgress.syncStatus == SyncStatus.success) {
      syncComplete = true;
    }
    return;
  }
}

class LastReceivedServerCommitIdMatcher extends Matcher {
  @override
  Description describe(Description description) {
    return description;
  }

  @override
  bool matches(item, Map matchState) {
    if (item is AtKey && item.key!.startsWith('lastreceivedservercommitid')) {
      return true;
    }
    return false;
  }
}
