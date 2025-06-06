import 'package:dio/dio.dart';

enum RequestMethod { get, post, delete }

extension RequestMethodExt on RequestMethod {
  String get name {
    switch (this) {
      case RequestMethod.get:
        return 'GET';
      case RequestMethod.post:
        return 'POST';
      case RequestMethod.delete:
        return 'DELETE';
    }
  }

  Options get options {
    return Options(method: name);
  }

  static RequestMethod? getRequestMethodFromOptionName(String name) {
    switch (name.toUpperCase()) {
      case 'GET':
        return RequestMethod.get;
      case 'POST':
        return RequestMethod.post;
      case 'DELETE':
        return RequestMethod.delete;
      default:
        return null;
    }
  }
}
