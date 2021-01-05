import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart' show required;
import 'package:flutter/widgets.dart';

final String _externalViewerServiceName = 'com example desktop';

// FIXME Offer static configuration as fail safe
class ServiceDiscoveryCubit extends Cubit<ResolvedBonsoirService> {
  final String type;

  BonsoirDiscovery _discovery;
  StreamSubscription<BonsoirDiscoveryEvent> _discoverySubscription;

  ServiceDiscoveryCubit({
    @required this.type,
  }) : super(null) {
    start();
  }

  Future<void> start() async {
    if (_discovery == null || _discovery.isStopped) {
      _discovery = BonsoirDiscovery(type: type);
      await _discovery.ready;
    }
    emit(null);
    await _discovery.start();
    _discoverySubscription = _discovery.eventStream.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.DISCOVERY_SERVICE_RESOLVED) {
        if (event.service.name == _externalViewerServiceName) {
          final service = event.service as ResolvedBonsoirService;
          print('External viewer discovered on ${service.ip}, port ${service.port}');
          emit(service);
        }
      } else if (event.type == BonsoirDiscoveryEventType.DISCOVERY_SERVICE_LOST) {
        if (event.service.name == _externalViewerServiceName) {
          print('External viewer lost');
          emit(null);
        }
      }
    });
  }

  Future<void> stop() async {
    emit(null);
    if (_discoverySubscription != null) await _discoverySubscription.cancel();
    _discoverySubscription = null;
    if (_discovery != null) await _discovery.stop();
  }
}
