import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show hashValues, Codec, FrameInfo;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_advanced_networkimage_2/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage_2/src/utils.dart';

// The AdvancedNetworkSvg class is modified to use updated methods and structures from flutter_svg.
class AdvancedNetworkSvg extends PictureProvider<AdvancedNetworkSvg> {
  final String url;
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

  AdvancedNetworkSvg(
    this.url, {
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

  @override
  Future<AdvancedNetworkSvg> obtainKey(PictureConfiguration picture) {
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
    Uint8List? imageData;

    if (useDiskCache) {
      try {
        imageData = await loadFromDiskCache();
        if (imageData != null) {
          if (key.loadedCallback != null) {
            key.loadedCallback!();
          }
          return await decode(imageData, key.colorFilter, key.toString(), onError: onError);
        }
      } catch (e) {
        if (key.printError) {
          print(e);
        }
      }
    }

    imageData = await loadFromRemote(
      key.url,
      key.header,
      key.retryLimit,
      key.retryDuration,
      key.retryDurationFactor,
      key.timeoutDuration,
      null,
      key.getRealUrl,
      printError: key.printError,
    );

    if (imageData != null) {
      if (key.loadedCallback != null) {
        key.loadedCallback!();
      }
      return await decode(imageData, key.colorFilter, key.toString(), onError: onError);
    }

    if (key.loadFailedCallback != null) {
      key.loadFailedCallback!();
    }

    if (key.fallbackAssetImage != null) {
      ByteData assetImageData = await rootBundle.load(key.fallbackAssetImage!);
      return await decode(assetImageData.buffer.asUint8List(), key.colorFilter, key.toString(), onError: onError);
    }

    if (key.fallbackImage != null) {
      return await decode(key.fallbackImage!, key.colorFilter, key.toString(), onError: onError);
    }

    throw StateError('Failed to load $url.');
  }

  Future<PictureInfo> decode(
    Uint8List? imageData, 
    ColorFilter? colorFilter, 
    String keyString, 
    {PictureErrorListener? onError},
  ) {
    if (onError != null) {
      return await SvgPicture.decodePictureStream(
        imageData!,
        keyString,
        onError: onError,
      );
    }
    return SvgPicture.decodePictureStream(imageData!, keyString);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final AdvancedNetworkSvg typedOther = other;
    return url == typedOther.url && scale == typedOther.scale;
  }

  @override
  int get hashCode => ui.hashValues(url, scale);
}

