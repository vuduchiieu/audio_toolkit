part of 'audio_toolkit_cubit.dart';

sealed class AudioToolkitState extends Equatable {
  const AudioToolkitState();

  @override
  List<Object> get props => [];
}

final class InitState extends AudioToolkitState {}

final class AudioToolkitInitial extends AudioToolkitState {
  final List<String> text;
  final bool isRecording;
  final bool isSystemRecord;
  final double db;
  final String path;
  const AudioToolkitInitial({
    required this.isRecording,
    required this.text,
    required this.db,
    required this.isSystemRecord,
    required this.path,
  });

  AudioToolkitInitial copyWith({
    bool? isRecording,
    bool? isSystemRecord,
    double? db,
    List<String>? text,
    String? path,
  }) {
    return AudioToolkitInitial(
        text: text ?? this.text,
        isSystemRecord: isSystemRecord ?? this.isSystemRecord,
        isRecording: isRecording ?? this.isRecording,
        db: db ?? this.db,
        path: path ?? this.path);
  }

  @override
  List<Object> get props => [isRecording, db, text, path];
}
