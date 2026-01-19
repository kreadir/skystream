import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_torrent_server/flutter_torrent_server.dart';
import 'package:flutter_torrent_server/flutter_torrent_server_platform_interface.dart';
import 'package:flutter_torrent_server/flutter_torrent_server_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterTorrentServerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterTorrentServerPlatform {

  @override
  Future<int> start() => Future.value(8090);

  @override
  Future<void> stop() => Future.value();

  @override
  Future<String?> addTorrent(String link) => Future.value("hash");

  @override
  Future<Map<String, dynamic>?> getTorrentStatus(String hash) => Future.value({});
}

void main() {
  final FlutterTorrentServerPlatform initialPlatform = FlutterTorrentServerPlatform.instance;

  test('$MethodChannelFlutterTorrentServer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterTorrentServer>());
  });

  test('start', () async {
    FlutterTorrentServer flutterTorrentServerPlugin = FlutterTorrentServer();
    MockFlutterTorrentServerPlatform fakePlatform = MockFlutterTorrentServerPlatform();
    FlutterTorrentServerPlatform.instance = fakePlatform;

    expect(await flutterTorrentServerPlugin.start(), 8090);
  });
}
