class RequestResponse<T> {
  final T? data;
  final T? errorMessage;
  final int? statusCode;
  final bool hasError;

  RequestResponse.success(this.data, this.statusCode)
      : hasError = false,
        errorMessage = null;

  RequestResponse.failure(this.errorMessage, this.statusCode)
      : hasError = true,
        data = null;
}
