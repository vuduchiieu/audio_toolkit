class TranslateModel {
  String id;
  String object;
  int created;
  String model;
  List<Choices> choices;
  Usage usage;
  String serviceTier;
  String systemFingerprint;

  TranslateModel({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
    required this.serviceTier,
    required this.systemFingerprint,
  });

  TranslateModel copyWith({
    String? id,
    String? object,
    int? created,
    String? model,
    List<Choices>? choices,
    Usage? usage,
    String? serviceTier,
    String? systemFingerprint,
  }) {
    return TranslateModel(
      id: id ?? this.id,
      object: object ?? this.object,
      created: created ?? this.created,
      model: model ?? this.model,
      choices: choices ?? this.choices,
      usage: usage ?? this.usage,
      serviceTier: serviceTier ?? this.serviceTier,
      systemFingerprint: systemFingerprint ?? this.systemFingerprint,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created': created,
      'model': model,
      'choices': choices,
      'usage': usage,
      'service_tier': serviceTier,
      'system_fingerprint': systemFingerprint,
    };
  }

  factory TranslateModel.fromJson(Map<String, dynamic> json) {
    return TranslateModel(
      id: json['id'] as String,
      object: json['object'] as String,
      created: json['created'] as int,
      model: json['model'] as String,
      choices: (json['choices'] as List<dynamic>)
          .map((e) => Choices.fromJson(e as Map<String, dynamic>))
          .toList(),
      usage: Usage.fromJson(json['usage'] as Map<String, dynamic>),
      serviceTier: json['service_tier'] as String,
      systemFingerprint: json['system_fingerprint'] as String,
    );
  }

  @override
  String toString() =>
      "TranslateModel(id: $id,object: $object,created: $created,model: $model,choices: $choices,usage: $usage,serviceTier: $serviceTier,systemFingerprint: $systemFingerprint)";

  @override
  int get hashCode => Object.hash(id, object, created, model, choices, usage,
      serviceTier, systemFingerprint);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslateModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          object == other.object &&
          created == other.created &&
          model == other.model &&
          choices == other.choices &&
          usage == other.usage &&
          serviceTier == other.serviceTier &&
          systemFingerprint == other.systemFingerprint;
}

class Choices {
  int index;
  Message message;
  String finishReason;

  Choices({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  Choices copyWith({
    int? index,
    Message? message,
    String? finishReason,
  }) {
    return Choices(
      index: index ?? this.index,
      message: message ?? this.message,
      finishReason: finishReason ?? this.finishReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'message': message,
      'finish_reason': finishReason,
    };
  }

  factory Choices.fromJson(Map<String, dynamic> json) {
    return Choices(
      index: json['index'] as int,
      message: Message.fromJson(json['message'] as Map<String, dynamic>),
      finishReason: json['finish_reason'] as String,
    );
  }

  @override
  String toString() =>
      "Choices(index: $index,message: $message,finishReason: $finishReason)";

  @override
  int get hashCode => Object.hash(index, message, finishReason);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Choices &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          message == other.message &&
          finishReason == other.finishReason;
}

class Message {
  String role;
  String content;

  Message({
    required this.role,
    required this.content,
  });

  Message copyWith({
    String? role,
    String? content,
  }) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  @override
  String toString() => "Message(role: $role,content: $content)";

  @override
  int get hashCode => Object.hash(role, content);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          content == other.content;
}

class Usage {
  int promptTokens;
  int completionTokens;
  int totalTokens;
  PromptTokensDetails promptTokensDetails;
  CompletionTokensDetails completionTokensDetails;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.promptTokensDetails,
    required this.completionTokensDetails,
  });

  Usage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    PromptTokensDetails? promptTokensDetails,
    CompletionTokensDetails? completionTokensDetails,
  }) {
    return Usage(
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      promptTokensDetails: promptTokensDetails ?? this.promptTokensDetails,
      completionTokensDetails:
          completionTokensDetails ?? this.completionTokensDetails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
      'prompt_tokens_details': promptTokensDetails,
      'completion_tokens_details': completionTokensDetails,
    };
  }

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      promptTokens: json['prompt_tokens'] as int,
      completionTokens: json['completion_tokens'] as int,
      totalTokens: json['total_tokens'] as int,
      promptTokensDetails: PromptTokensDetails.fromJson(
          json['prompt_tokens_details'] as Map<String, dynamic>),
      completionTokensDetails: CompletionTokensDetails.fromJson(
          json['completion_tokens_details'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() =>
      "Usage(promptTokens: $promptTokens,completionTokens: $completionTokens,totalTokens: $totalTokens,promptTokensDetails: $promptTokensDetails,completionTokensDetails: $completionTokensDetails)";

  @override
  int get hashCode => Object.hash(promptTokens, completionTokens, totalTokens,
      promptTokensDetails, completionTokensDetails);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Usage &&
          runtimeType == other.runtimeType &&
          promptTokens == other.promptTokens &&
          completionTokens == other.completionTokens &&
          totalTokens == other.totalTokens &&
          promptTokensDetails == other.promptTokensDetails &&
          completionTokensDetails == other.completionTokensDetails;
}

class PromptTokensDetails {
  int cachedTokens;
  int audioTokens;

  PromptTokensDetails({
    required this.cachedTokens,
    required this.audioTokens,
  });

  PromptTokensDetails copyWith({
    int? cachedTokens,
    int? audioTokens,
  }) {
    return PromptTokensDetails(
      cachedTokens: cachedTokens ?? this.cachedTokens,
      audioTokens: audioTokens ?? this.audioTokens,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cached_tokens': cachedTokens,
      'audio_tokens': audioTokens,
    };
  }

  factory PromptTokensDetails.fromJson(Map<String, dynamic> json) {
    return PromptTokensDetails(
      cachedTokens: json['cached_tokens'] as int,
      audioTokens: json['audio_tokens'] as int,
    );
  }

  @override
  String toString() =>
      "PromptTokensDetails(cachedTokens: $cachedTokens,audioTokens: $audioTokens)";

  @override
  int get hashCode => Object.hash(cachedTokens, audioTokens);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptTokensDetails &&
          runtimeType == other.runtimeType &&
          cachedTokens == other.cachedTokens &&
          audioTokens == other.audioTokens;
}

class CompletionTokensDetails {
  int reasoningTokens;
  int audioTokens;
  int acceptedPredictionTokens;
  int rejectedPredictionTokens;

  CompletionTokensDetails({
    required this.reasoningTokens,
    required this.audioTokens,
    required this.acceptedPredictionTokens,
    required this.rejectedPredictionTokens,
  });

  CompletionTokensDetails copyWith({
    int? reasoningTokens,
    int? audioTokens,
    int? acceptedPredictionTokens,
    int? rejectedPredictionTokens,
  }) {
    return CompletionTokensDetails(
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      audioTokens: audioTokens ?? this.audioTokens,
      acceptedPredictionTokens:
          acceptedPredictionTokens ?? this.acceptedPredictionTokens,
      rejectedPredictionTokens:
          rejectedPredictionTokens ?? this.rejectedPredictionTokens,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reasoning_tokens': reasoningTokens,
      'audio_tokens': audioTokens,
      'accepted_prediction_tokens': acceptedPredictionTokens,
      'rejected_prediction_tokens': rejectedPredictionTokens,
    };
  }

  factory CompletionTokensDetails.fromJson(Map<String, dynamic> json) {
    return CompletionTokensDetails(
      reasoningTokens: json['reasoning_tokens'] as int,
      audioTokens: json['audio_tokens'] as int,
      acceptedPredictionTokens: json['accepted_prediction_tokens'] as int,
      rejectedPredictionTokens: json['rejected_prediction_tokens'] as int,
    );
  }

  @override
  String toString() =>
      "CompletionTokensDetails(reasoningTokens: $reasoningTokens,audioTokens: $audioTokens,acceptedPredictionTokens: $acceptedPredictionTokens,rejectedPredictionTokens: $rejectedPredictionTokens)";

  @override
  int get hashCode => Object.hash(reasoningTokens, audioTokens,
      acceptedPredictionTokens, rejectedPredictionTokens);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletionTokensDetails &&
          runtimeType == other.runtimeType &&
          reasoningTokens == other.reasoningTokens &&
          audioTokens == other.audioTokens &&
          acceptedPredictionTokens == other.acceptedPredictionTokens &&
          rejectedPredictionTokens == other.rejectedPredictionTokens;
}
