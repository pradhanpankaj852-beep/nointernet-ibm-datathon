import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class MeshService {
  static const Strategy defaultStrategy = Strategy.P2P_CLUSTER;

  static Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.storage,
      Permission.photos,
      Permission.videos,
    ].request();
  }

  static Future<bool> startAdvertising({
    required String userName,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) async {
    await stopRadio();
    return await Nearby().startAdvertising(
      userName,
      defaultStrategy,
      onConnectionInitiated: onConnectionInitiated,
      onConnectionResult: onConnectionResult,
      onDisconnected: onDisconnected,
    );
  }

  static Future<bool> startDiscovery({
    required String userName,
    required OnEndpointFound onEndpointFound,
    required OnEndpointLost onEndpointLost,
  }) async {
    await stopRadio();
    return await Nearby().startDiscovery(
      userName,
      defaultStrategy,
      onEndpointFound: onEndpointFound,
      onEndpointLost: onEndpointLost,
    );
  }

  static Future<void> sendText(String endpointId, String text) async {
    Uint8List bytes = Uint8List.fromList(utf8.encode(text));
    await Nearby().sendBytesPayload(endpointId, bytes);
  }

  static Future<int> sendFile(String endpointId, String filePath) async {
    return await Nearby().sendFilePayload(endpointId, filePath);
  }

  static Future<void> stopRadio() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
  }
}