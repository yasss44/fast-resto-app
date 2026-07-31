enum ApiResult {
  idle,
  loading,
  success,
  error;

  bool get isIdle => this == ApiResult.idle;
  bool get isLoading => this == ApiResult.loading;
  bool get isSuccess => this == ApiResult.success;
  bool get isError => this == ApiResult.error;
}

class ApiState<T> {
  final ApiResult result;
  final T? data;
  final String? error;

  const ApiState({
    this.result = ApiResult.idle,
    this.data,
    this.error,
  });

  ApiState<T> copyWith({
    ApiResult? result,
    T? data,
    String? error,
  }) =>
      ApiState(
        result: result ?? this.result,
        data: data ?? this.data,
        error: error,
      );
}
