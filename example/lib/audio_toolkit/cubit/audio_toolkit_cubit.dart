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
      _sentenceSub = audioToolkit.onSentenceDetected.listen(
        (path) async {
          final current0 = state;
          if (current0 is AudioToolkitInitial) {
            emit(current0.copyWith(path: path));
          }
        },
      );
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
      deleteRecordingFilesExceptFull();
    }
  }

  Future<void> deleteRecordingFilesExceptFull() async {
    final downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
    if (await downloadsDir.exists()) {
      final files = downloadsDir.listSync();

      for (var file in files) {
        if (file is File) {
          final name = file.uri.pathSegments.last;

          if (name.startsWith('audioToolkit_') && !name.endsWith('_full.m4a')) {
            try {
              await file.delete();
            } catch (e) {}
          }
        }
      }
    }
  }

  Future<void> transcribeAudio(String path) async {
    final res = await audioToolkit.transcribeAudio(path, LanguageType.vi);
    final current = state;
    if (current is AudioToolkitInitial) {
      if (res.result) {
        final text = res.text;
        if (text != null) {
          List<String> updatedText = [text, ...current.text];
          emit(current.copyWith(text: updatedText));
        }
      } else {
        final text = res.errorMessage;
        if (text != null) {
          List<String> updatedText = [text, ...current.text];
          emit(current.copyWith(text: updatedText));
        }
      }
    }

    if (res.path != null) {
      try {
        final file = File(res.path ?? '');
        await file.delete();
      } catch (e) {}
      final current = state;
      if (current is AudioToolkitInitial) {
        emit(current.copyWith(path: ''));
      }
    }
  }
}
