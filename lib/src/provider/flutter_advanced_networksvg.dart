import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter_advanced_networkimage_2/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage_2/src/utils.dart';

class AdvancedNetworkSvg extends PictureProvider<AdvancedNetworkSvg> {
  AdvancedNetworkSvg(
    this.url, {
    required this.decoder,
    this.scale = 1.0,
    this.header,
    this.colorFilter,
    this.useDiskCache = false,
    this.retryLimit = 5,
    this.retryDuration = const Duration(milliseconds: 500),
    this.retryDurationFactor = 1.5,
    this.timeoutDuration = const Duration(seconds: 5),
    this.loadedCallback,
    this.loadFailedCallback,
    this.fallbackAssetImage,
    this.fallbackImage,
    this.cacheRule,
    this.getRealUrl,
    this.printError = false,
    this.skipRetryStatusCode,
  });

  final String url;
  final PictureInfoDecoderBuilder<Uint8List?> decoder; // Define decoder explicitly
  final double scale;
  final Map<String, String>? header;
  final ColorFilter? colorFilter;
  final bool useDiskCache;
  final int retryLimit;
  final Duration retryDuration;
  final double retryDurationFactor;
  final Duration timeoutDuration;
  final Function? loadedCallback;
  final Function? loadFailedCallback;
  final String? fallbackAssetImage;
  final Uint8List? fallbackImage;
  final CacheRule? cacheRule;
  final UrlResolver? getRealUrl;
  final bool printError;
  final List<int>? skipRetryStatusCode;

  @override
  Future<AdvancedNetworkSvg> obtainKey(PictureConfiguration configuration) {
    return SynchronousFuture<AdvancedNetworkSvg>(this);
  }

  @override
  PictureStreamCompleter load(
    AdvancedNetworkSvg key, {
    PictureErrorListener? onError,
  }) {
    return OneFramePictureStreamCompleter(
      _loadAsync(key, onError: onError),
      informationCollector: () sync* {
        yield DiagnosticsProperty<PictureProvider>('Picture provider', this);
        yield DiagnosticsProperty<AdvancedNetworkSvg>('Picture key', key);
      },
    );
  }

  Future<PictureInfo> _loadAsync(
    AdvancedNetworkSvg key, {
    PictureErrorListener? onError,
  }) async {
    assert(key == this);

    try {
      Uint8List? imageData;
      if (useDiskCache) {
        imageData = await loadFromDiskCache();
      } else {
        imageData = await loadFromRemote(
          key.url,
          key.header,
          key.retryLimit,
          key.retryDuration,
          key.retryDurationFactor,
          key.timeoutDuration,
          key.getRealUrl,
        );
      }

      if (imageData == null) {
        throw StateError('Failed to load $url.');
      }

      if (key.loadedCallback != null) key.loadedCallback!();
      return await decoder(imageData, key.colorFilter, key.toString(), onError: onError);
    } catch (e) {
      if (key.printError) {
        print('Error loading image from $url: $e');
      }

      if (key.loadFailedCallback != null) key.loadFailedCallback!();
      
      if (key.fallbackAssetImage != null) {
        final ByteData imageData = await rootBundle.load(key.fallbackAssetImage!);
        return await decoder(
          imageData.buffer.asUint8List(),
          key.colorFilter,
          key.toString(),
          onError: onError,
        );
      }

      if (key.fallbackImage != null) {
        return await decoder(
          key.fallbackImage!,
          key.colorFilter,
          key.toString(),
          onError: onError,
        );
      }

      throw e;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is AdvancedNetworkSvg) {
      return url == other.url &&
          scale == other.scale &&
          useDiskCache == other.useDiskCache &&
          retryLimit == other.retryLimit &&
          retryDurationFactor == other.retryDurationFactor &&
          retryDuration == other.retryDuration;
    }
    return false;
  }

  @override
  int get hashCode => ui.hashValues(
    url,
    scale,
    useDiskCache,
    retryLimit,
    retryDuration,
    retryDurationFactor,
    timeoutDuration,
  );

  @override
  String toString() {
    return '$runtimeType("$url", scale: $scale, useDiskCache: $useDiskCache, retryLimit: $retryLimit, retryDurationFactor: $retryDurationFactor, retryDuration: $retryDuration, timeoutDuration: $timeoutDuration)';
  }
}

