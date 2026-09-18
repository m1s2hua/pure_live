import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class _Recorder extends Fake implements RecorderController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Interaction extends Fake implements LocalInteractionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final owners = <LivePlayController>[];

  LivePlayController owner(IptvPlayerStarter starter, {LiveRoom? room}) {
    final initial = room ?? LiveRoom(roomId: 'fixture-room', platform: Sites.bilibiliSite);
    final controller = LivePlayController.withIptvPlayerStarter(starter, room: initial, site: Sites.bilibiliSite);
    controller.state.value = LivePlayState(room: RoomState(detail: initial, success: true));
    owners.add(controller);
    return controller;
  }

  setUp(() {
    Get.lazyPut<RecorderController>(() => _Recorder());
    Get.lazyPut<LocalInteractionController>(() => _Interaction());
  });

  tearDown(() {
    for (final owner in owners) {
      owner.state.close();
      owner.danmakuMessages.close();
      owner.danmakuPresentationRevision.close();
      owner.localGiftEffect.close();
      owner.superChats.close();
    }
    owners.clear();
    Get.reset();
  });

  group('isValidCustomSourceUrl', () {
    test('accepts absolute http and https URLs', () {
      expect(isValidCustomSourceUrl('https://example.com/live.flv'), isTrue);
      expect(isValidCustomSourceUrl('http://example.com/a.m3u8?x=1'), isTrue);
      expect(isValidCustomSourceUrl('  https://example.com/live.flv  '), isTrue);
    });

    test('rejects empty, relative, malformed or unsupported schemes', () {
      expect(isValidCustomSourceUrl(''), isFalse);
      expect(isValidCustomSourceUrl('   '), isFalse);
      expect(isValidCustomSourceUrl('/live.flv'), isFalse);
      expect(isValidCustomSourceUrl('rtmp://example.com/live'), isFalse);
      expect(isValidCustomSourceUrl('https:///nohost'), isFalse);
    });
  });

  test('custom source replaces the URL, exposes one quality and keeps the room', () async {
    final rooms = <LiveRoom>[];
    final controller = owner((room) async {
      rooms.add(room);
      return true;
    });

    final applied = await controller.playCustomSource('  https://fixture/custom.flv  ');

    expect(applied, isTrue);
    expect(rooms, hasLength(1));
    expect(rooms.single.roomId, 'fixture-room');
    expect(controller.state.value.player.playUrls, ['https://fixture/custom.flv']);
    expect(controller.state.value.player.qualites, hasLength(1));
    expect(controller.state.value.player.currentQuality, 0);
    expect(controller.state.value.player.currentLineIndex, 0);
    expect(controller.state.value.room.success, isTrue);
    expect(controller.state.value.room.isLoading, isFalse);
  });

  test('invalid URL or missing room identity starts no playback transaction', () async {
    var calls = 0;
    final controller = owner((_) async {
      calls++;
      return true;
    });

    expect(await controller.playCustomSource('rtmp://fixture/custom'), isFalse);
    expect(await controller.playCustomSource('   '), isFalse);
    expect(calls, 0);
    expect(controller.state.value.player.playUrls, isEmpty);
  });

  test('a rejected custom source reports failure without a false success', () async {
    final controller = owner((_) async => false);

    final applied = await controller.playCustomSource('https://fixture/rejected.flv');

    expect(applied, isFalse);
    expect(controller.state.value.room.success, isFalse);
    expect(controller.state.value.room.isLoading, isFalse);
    expect(controller.state.value.room.loadError, isNotEmpty);
  });

  test('a superseded custom source cannot overwrite the newer replacement', () async {
    var call = 0;
    final gates = <Completer<bool>>[Completer<bool>(), Completer<bool>()];
    final controller = owner((_) => gates[call++].future);

    final first = controller.playCustomSource('https://fixture/first.flv');
    final second = controller.playCustomSource('https://fixture/second.flv');

    gates[1].complete(true);
    expect(await second, isTrue);
    expect(controller.state.value.player.playUrls, ['https://fixture/second.flv']);

    gates[0].complete(true);
    expect(await first, isFalse);
    expect(controller.state.value.player.playUrls, ['https://fixture/second.flv']);
    expect(controller.state.value.room.success, isTrue);
  });
}
