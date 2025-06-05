import 'dart:async';
import 'dart:io';

import 'package:audio_toolkit/audio_toolkit.dart';
import 'package:audio_toolkit/language_type.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/src/equatable.dart';

part 'audio_toolkit_state.dart';

class AudioToolkitCubit extends Cubit<AudioToolkitState> {
  final audioToolkit = AudioToolkit.instance;
  StreamSubscription? _dbSub;
  StreamSubscription? _sentenceSub;

  AudioToolkitCubit()
      : super(AudioToolkitInitial(
            db: 0.0,
            isRecording: false,
            text: [],
            path: '',
            isSystemRecord: true));

  Future<void> init() async {
    await audioToolkit.init();
    _dbSub = audioToolkit.onDbAudio.listen((db) {
      final current = state;
      if (current is AudioToolkitInitial) {
        _dbSub = audioToolkit.onDbAudio.listen((db) {
          final current = state;
          if (current is AudioToolkitInitial) {
            emit(current.copyWith(db: db, isSystemRecord: true));
          }
        });
      }
    });
  }

  Future<void> turnOffSystemRecording() async {
    final res = await audioToolkit.turnOffSystemRecording();
    if (res.result) {
      final current = state;
      if (current is AudioToolkitInitial) {
        emit(current.copyWith(db: -160, isSystemRecord: false));
        _dbSub?.cancel();
      }
    }
  }

  Future<void> turnOnSystemRecording() async {
    final res = await audioToolkit.turnOnSystemRecording();
    if (res.result) {
      _dbSub = audioToolkit.onDbAudio.listen((db) {
        final current = state;
        if (current is AudioToolkitInitial) {
          emit(current.copyWith(
            db: db,
          ));
        }
      });
    }
  }

  Future<void> startRecord() async {
    final res = await audioToolkit.startRecord();
    if (res.result) {
      final current = state;
      if (current is AudioToolkitInitial) {
        emit(current.copyWith(isRecording: true));
      }

      final current0 = state;
      if (current0 is AudioToolkitInitial) {
        _sentenceSub = audioToolkit.onSentenceDetected.listen(
          (path) {
            print('path: $path');
            transcribeAudio(path);
          },
        );
      }
    }
  }

  Future<void> stopRecording() async {
    final res = await audioToolkit.stopRecording();
    if (res.result) {
      final current = state;
      if (current is AudioToolkitInitial) {
        emit(current.copyWith(isRecording: false));
      }
      _sentenceSub?.cancel();
    }
  }

  Future<void> transcribeAudio(String path) async {
    final res = await audioToolkit.transcribeAudio(path, LanguageType.vi);
    if (res.result) {
      final current = state;
      if (current is AudioToolkitInitial) {
        final text = res.text;
        if (text != null) {
          List<String> updatedText = [text, ...current.text];
          emit(current.copyWith(text: updatedText));
        }
      }
    }
    if (res.path != null) {
      final file = File(res.path ?? '');
      await file.delete();
    }
  }
}
