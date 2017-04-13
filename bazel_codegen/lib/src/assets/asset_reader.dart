// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;

import '../errors.dart';
import 'asset_filter.dart';
import 'file_system.dart';

class BazelAssetReader implements AssetReader {
  /// The bazel specific file system.
  ///
  /// Responsible for knowing where bazel stores source and generated files on
  /// disk.
  final BazelFileSystem _fileSystem;

  /// A filter for which assets are allowed to be read.
  final AssetFilter _assetFilter;

  /// Maps package names to path in the bazel file system.
  final Map<String, String> _packageMap;

  int numAssetsReadFromDisk = 0;

  BazelAssetReader(Iterable<String> rootDirs, this._packageMap,
      {AssetFilter assetFilter})
      : _fileSystem = new BazelFileSystem('.', rootDirs),
        _assetFilter = assetFilter;

  BazelAssetReader.forTest(this._packageMap, this._fileSystem)
      : _assetFilter = const _AllowAllAssets();

  @override
  Future<List<int>> readAsBytes(AssetId id) async {
    final filePath = _filePathForId(id);
    numAssetsReadFromDisk++;
    final bytes = _fileSystem.readAsBytesSync(filePath);
    if (bytes == null) {
      throw new CodegenError('Could not find $id at $filePath');
    }
    return bytes;
  }

  @override
  Future<String> readAsString(AssetId id, {Encoding encoding: UTF8}) async {
    final filePath = _filePathForId(id);
    numAssetsReadFromDisk++;
    final contents = _fileSystem.readAsStringSync(filePath, encoding: encoding);
    if (contents == null) {
      throw new CodegenError('Could not find $id at $filePath');
    }
    return contents;
  }

  String _filePathForId(AssetId id) {
    final packagePath = _packageMap[id.package];
    if (!_assetFilter.isValid(id) || packagePath == null) {
      throw new CodegenError('Attempted to read invalid input $id.');
    }
    return p.join(packagePath, id.path);
  }

  @override
  Future<bool> hasInput(AssetId id) async {
    final packagePath = _packageMap[id.package];
    if (packagePath == null) return false;

    final filePath = p.join(packagePath, id.path);
    if (!_assetFilter.isValid(id)) return false;

    return _fileSystem.existsSync(filePath);
  }
}

class _AllowAllAssets implements AssetFilter {
  const _AllowAllAssets();
  @override
  bool isValid(AssetId id) => true;
}
