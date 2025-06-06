import 'dart:collection';
import 'package:audio_toolkit_example/api/request_method.dart';
import 'package:audio_toolkit_example/api/request_response.dart';
import 'package:dio/dio.dart';

final _baseOptions = BaseOptions(
  responseType: ResponseType.json,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
);

class ApiClient {
  static final Dio _dio = Dio(_baseOptions);

  static Future<RequestResponse<T>> fetch<T>(
    String url, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? searchParams,
    Map<String, dynamic>? headers,
    Options? options,
    String? token,
    RequestMethod method = RequestMethod.post,
    BaseOptions? baseOptions,
    bool? isFormData,
  }) async {
    headers ??= HashMap();

    if (options == null) {
      options = method.options;
    } else {
      options.method = method.name;
    }

    if (token != null) {
      headers.putIfAbsent('Authorization', () => "Bearer $token");
    } else {
      final token0 = '';
      headers.putIfAbsent('Authorization', () => "Bearer $token0");
    }

    options.headers = headers;
    if (isFormData != true) {
      options.contentType = Headers.jsonContentType;
    } else {
      options.contentType = Headers.multipartFormDataContentType;
    }

    if (baseOptions != null) _dio.options = baseOptions;

    try {
      final response = await _dio.request<T>(
        url,
        data: (isFormData == true ? FormData.fromMap(data ?? {}) : data),
        queryParameters: searchParams,
        options: options,
      );

      return RequestResponse.success(response.data, response.statusCode);
    } on DioException catch (e) {
      return RequestResponse.failure(e.response?.data, e.response?.statusCode);
    } catch (e) {
      return RequestResponse.failure(null, 500);
    }
  }
}
