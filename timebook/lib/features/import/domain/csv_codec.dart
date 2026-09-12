import 'dart:convert';

import 'package:gbk_codec/gbk_codec.dart';

/// 解码账单文件字节：优先严格 UTF-8，失败则按 GBK（微信 CSV 常为 GBK）。
String decodeCsvBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return gbk.decode(bytes);
  }
}