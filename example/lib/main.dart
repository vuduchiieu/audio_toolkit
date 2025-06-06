import 'dart:async';
import 'dart:io';

import 'package:audio_toolkit/audio_toolkit.dart';
import 'package:audio_toolkit/language_type.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (_) => AudioToolkitCubit()..init(),
        child: const AudioToolkitScreen(),
      ),
    );
  }
}

class AudioToolkitScreen extends StatelessWidget {
  const AudioToolkitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<AudioToolkitCubit, AudioToolkitState>(
        listenWhen: (prev, curr) =>
            prev is AudioToolkitInitial &&
            curr is AudioToolkitInitial &&
            prev.path != curr.path,
        listener: (context, state) {
          if (state is AudioToolkitInitial && state.path.isNotEmpty) {
            context.read<AudioToolkitCubit>().transcribeAudio(state.path);
          }
        },
        builder: (context, state) {
          if (state is! AudioToolkitInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.text.isNotEmpty)
                  Expanded(child: _buildTranscriptionBox(state.text)),
                const SizedBox(height: 30),
                _buildRecordingControls(context, state),
                const SizedBox(height: 16),
                _buildMicSection(),
                const SizedBox(height: 16),
                _buildRecordingButton(context, state),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTranscriptionBox(List<String> text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.pinkAccent.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: text.length,
        itemBuilder: (_, index) => Text(
          text[index],
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildRecordingControls(
      BuildContext context, AudioToolkitInitial state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            final cubit = context.read<AudioToolkitCubit>();
            state.isSystemRecord
                ? cubit.turnOffSystemRecording()
                : cubit.turnOnSystemRecording();
          },
          child: Icon(
            state.isSystemRecord
                ? Icons.desktop_mac
                : Icons.desktop_access_disabled,
            size: 40,
          ),
        ),
        const SizedBox(width: 16),
        _buildDbMeter(state.db),
      ],
    );
  }

  Widget _buildMicSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic, size: 40),
        SizedBox(width: 16),
        // Hiếu định làm mic riêng ở đây sau, placeholder db -160
        _buildDbMeter(-160),
      ],
    );
  }

  Widget _buildRecordingButton(
      BuildContext context, AudioToolkitInitial state) {
    final isRecording = state.isRecording;
    final cubit = context.read<AudioToolkitCubit>();

    return ElevatedButton.icon(
      icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
      label: Text(isRecording ? 'Dừng ghi' : 'Bắt đầu ghi'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isRecording ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: () =>
          isRecording ? cubit.stopRecording() : cubit.startRecord(),
    );
  }

  static Widget _buildDbMeter(double db) {
    final normalized = ((db + 60).clamp(0, 60)) / 60;

    Color getColor() {
      if (db > -20) return Colors.red;
      if (db > -40) return Colors.orange;
      return Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Âm lượng hiện tại: ${(normalized * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 6),
        Container(
          width: 240,
          height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 240 * normalized,
              height: 14,
              decoration: BoxDecoration(
                color: getColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
    await Future.wait([
      audioToolkit.init(),
      audioToolkit.turnOnSystemRecording(),
      audioToolkit.turnOnMicRecording(),
    ]);
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
