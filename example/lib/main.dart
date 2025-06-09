import 'dart:async';
import 'dart:io';

import 'package:audio_toolkit/audio_toolkit.dart';
import 'package:audio_toolkit/language_type.dart';
import 'package:audio_toolkit_example/repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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
        child: AudioToolkitScreen(),
      ),
    );
  }
}

class AudioToolkitScreen extends StatefulWidget {
  const AudioToolkitScreen({super.key});

  @override
  State<AudioToolkitScreen> createState() => _AudioToolkitScreenState();
}

class _AudioToolkitScreenState extends State<AudioToolkitScreen> {
  final inputLanguage = ValueNotifier<LanguageType>(LanguageType.vi);
  final outputLanguage = ValueNotifier<LanguageType>(LanguageType.vi);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocProvider(
        create: (context) => AudioToolkitCubit()..init(),
        child: BlocConsumer<AudioToolkitCubit, AudioToolkitState>(
          listenWhen: (previous, current) {
            if (previous is AudioToolkitInitial &&
                current is AudioToolkitInitial) {
              return previous.path != current.path;
            }
            return true;
          },
          listener: (context, state) {
            if (state is AudioToolkitInitial) {
              if (state.path.isNotEmpty) {
                // context
                //     .read<AudioToolkitCubit>()
                //     .transcribeAudioWhisper(state.path);
                return;
              }
              return;
            }
          },
          builder: (context, state) {
            if (state is AudioToolkitInitial) {
              final isRecording = state.isRecording;

              final cubit = context.read<AudioToolkitCubit>();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
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
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                state.isMicRecord
                                    ? cubit.turnOffMicRecording()
                                    : cubit.turnOnMicRecording();
                              },
                              child: Icon(
                                state.isMicRecord ? Icons.mic : Icons.mic_off,
                                size: 40,
                              ),
                            ),
                            SizedBox(width: 16),
                            _buildDbMeter(state.dbMic),
                          ],
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        wrap(inputLanguage, 'Ngôn ngữ đầu vào'),
                        wrap(outputLanguage, 'Dịch sang'),
                        SizedBox(
                          height: 15,
                        ),
                        ElevatedButton.icon(
                          icon: Icon(isRecording
                              ? Icons.stop
                              : Icons.fiber_manual_record),
                          label: Text(isRecording ? 'Dừng ghi' : 'Bắt đầu ghi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isRecording ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          onPressed: () => isRecording
                              ? cubit.stopRecording()
                              : cubit.startRecord(
                                  inputLanguage: inputLanguage.value,
                                  outputLanguage: outputLanguage.value),
                        ),
                      ],
                    ),
                    if (state.text.isNotEmpty)
                      Expanded(
                          child: Row(
                        children: [
                          _buildTranscriptionBox(state.prevText),
                          SizedBox(
                            width: 10,
                          ),
                          _buildTranscriptionBox(state.text)
                        ],
                      )),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget wrap(ValueNotifier<LanguageType> valueNotifier, String title) {
    return Container(
      width: 340,
      child: Row(
        children: [
          Text(title),
          const SizedBox(width: 16),
          Expanded(
            child: ValueListenableBuilder(
                valueListenable: valueNotifier,
                builder: (_, selected, __) {
                  return DropdownButton<LanguageType>(
                    value: selected,
                    isExpanded: true,
                    items: LanguageType.values.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(lang.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        valueNotifier.value = value;
                      }
                    },
                  );
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionBox(List<String> text) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.pinkAccent.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: text.length,
                shrinkWrap: false,
                itemBuilder: (_, index) => Text(
                  text[index],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDbMeter(double db) {
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
          height: 15,
          decoration: BoxDecoration(
            border: Border.all(color: getColor()),
            borderRadius: BorderRadius.circular(999),
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
  StreamSubscription? _dbMicSub;
  StreamSubscription? _sentenceSub;
  StreamSubscription? _sentenceMicSub;

  final List<File> _fileQueue = [];
  bool _isProcessing = false;
  final repo = AudioToolkitRepo();

  AudioToolkitCubit()
      : super(AudioToolkitInitial(
            db: 0.0,
            isRecording: false,
            isMicRecord: false,
            text: [],
            prevText: [],
            dbMic: 0.0,
            path: '',
            isSystemRecord: true));

  Future<void> init() async {
    await audioToolkit.init();

    _dbSub = audioToolkit.onDbAudio.listen((db) {
      final current = state;
      if (current is AudioToolkitInitial) {
        emit(current.copyWith(db: db, isSystemRecord: true));
      }
    });
    _dbMicSub = audioToolkit.onMicDb.listen(
      (db) {
        final current = state;
        if (current is AudioToolkitInitial) {
          emit(current.copyWith(dbMic: db, isMicRecord: true));
        }
      },
    );
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
          emit(current.copyWith(db: db, isSystemRecord: true));
        }
      });
    }
  }

  Future<void> turnOffMicRecording() async {
    final res = await audioToolkit.turnOffMicRecording();
    if (res.result) {
      final current = state;
      if (current is AudioToolkitInitial) {
        emit(current.copyWith(dbMic: -160, isMicRecord: false));
        _dbMicSub?.cancel();
      }
    }
  }

  Future<void> turnOnMicRecording() async {
    final res = await audioToolkit.turnOnMicRecording(LanguageType.en);
    if (res.result) {
      _dbMicSub = audioToolkit.onMicDb.listen(
        (db) {
          final current = state;
          if (current is AudioToolkitInitial) {
            emit(current.copyWith(dbMic: db, isMicRecord: true));
          }
        },
      );
    }
  }

  Future<void> startRecord(
      {required LanguageType inputLanguage,
      required LanguageType outputLanguage}) async {
    final current0 = state;
    if (current0 is AudioToolkitInitial) {
      emit(
        current0.copyWith(
          text: [
            '[${DateFormat.Hms().format(DateTime.now())}] Ấn start record',
            ...current0.text
          ],
        ),
      );
    }
    final current = state;
    if (current is AudioToolkitInitial) {
      emit(current.copyWith(isRecording: true));
    }

    final res = await audioToolkit.startRecord(inputLanguage);
    if (res.result) {
      final current = state;
      if (current is AudioToolkitInitial) {
        emit(current.copyWith(isRecording: true));
      }
      _sentenceSub = audioToolkit.onSystemAudio.listen(
        (path) async {
          final current0 = state;
          if (current0 is AudioToolkitInitial) {
            emit(current0.copyWith(path: path));
            final file = File(path);

            await waitForFileStable(file);

            _fileQueue.add(file);
            transcribeAudioWhisper(path, outputLanguage);
          }
        },
      );

      _sentenceMicSub = audioToolkit.onMicAudio.listen((text) async {
        final current0 = state;
        if (current0 is AudioToolkitInitial) {
          emit(current0.copyWith(prevText: [text]));

          final translated =
              await repo.translateWithOpenAI(text, outputLanguage);
          if (translated != null) {
            final current = state;
            if (current is AudioToolkitInitial) {
              emit(
                current.copyWith(
                  text: [
                    '[${DateFormat.Hms().format(DateTime.now())}] $translated',
                  ],
                ),
              );
            }
          }
        }
      });
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
      _sentenceMicSub?.cancel();
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

  Future<void> waitForFileStable(File file,
      {Duration timeout = const Duration(seconds: 3)}) async {
    final startTime = DateTime.now();
    int lastSize = 0;

    while (DateTime.now().difference(startTime) < timeout) {
      final currentSize = await file.length();
      if (currentSize > 0 && currentSize == lastSize) {
        return;
      }
      lastSize = currentSize;
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  Future<void> transcribeAudioWhisper(
      String path, LanguageType language) async {
    if (_isProcessing || _fileQueue.isEmpty) return;

    _isProcessing = true;
    final file = _fileQueue.removeAt(0);

    try {
      final String? message = await repo.transcribeWithWhisper(
        file,
      );

      if (message != null) {
        final cleaned = message.trim();

        final current = state;
        if (current is AudioToolkitInitial) {
          emit(
            current.copyWith(
              prevText: [
                '[${DateFormat.Hms().format(DateTime.now())}] $message',
                ...current.prevText
              ],
            ),
          );
        }

        final isBlocked = listBlock.any(
            (blocked) => cleaned.toLowerCase() == blocked.trim().toLowerCase());

        if (!isBlocked) {
          final translated = await repo.translateWithOpenAI(cleaned, language);
          if (translated != null) {
            final current = state;
            if (current is AudioToolkitInitial) {
              // List<String> updatedText = [...latest.text, translated];
              // emit(latest.copyWith(text: updatedText));

              // final translated2 = await repo.translateWithOpenAI(
              //     updatedText.join(), LanguageType.vi);

              emit(
                current.copyWith(
                  text: [
                    '[${DateFormat.Hms().format(DateTime.now())}] $translated',
                    ...current.text
                  ],
                ),
              );
            }
          }
        } else {
          print("🚫 Bỏ qua câu bị chặn: $cleaned");
        }
      }
    } catch (e) {
    } finally {
      _isProcessing = false;
      try {
        // await file.delete();
      } catch (e) {}
      transcribeAudioWhisper(path, language);
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

  @override
  Future<void> close() async {
    _dbSub?.cancel();
    _dbMicSub?.cancel();
    _sentenceMicSub?.cancel();
    _sentenceSub?.cancel();
    audioToolkit.dispose();
    return super.close();
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
  final List<String> prevText;
  final bool isRecording;
  final bool isSystemRecord;
  final bool isMicRecord;
  final double db;
  final double dbMic;
  final String path;
  const AudioToolkitInitial(
      {required this.isRecording,
      required this.text,
      required this.prevText,
      required this.db,
      required this.dbMic,
      required this.isSystemRecord,
      required this.path,
      required this.isMicRecord});

  AudioToolkitInitial copyWith(
      {bool? isRecording,
      bool? isSystemRecord,
      double? db,
      List<String>? text,
      List<String>? prevText,
      String? path,
      double? dbMic,
      bool? isMicRecord}) {
    return AudioToolkitInitial(
        text: text ?? this.text,
        isSystemRecord: isSystemRecord ?? this.isSystemRecord,
        isRecording: isRecording ?? this.isRecording,
        db: db ?? this.db,
        dbMic: dbMic ?? this.dbMic,
        isMicRecord: isMicRecord ?? this.isMicRecord,
        prevText: prevText ?? this.prevText,
        path: path ?? this.path);
  }

  @override
  List<Object> get props => [
        isRecording,
        db,
        text,
        path,
        isSystemRecord,
        isMicRecord,
        dbMic,
        prevText
      ];
}

List<String> listBlock = [
  "Các bạn hãy đăng kí cho kênh lalaschool Để không bỏ lỡ những video hấp dẫn",
  "Hãy subscribe cho kênh Ghiền Mì Gõ Để không bỏ lỡ những video hấp dẫn",
  "Hẹn gặp lại các bạn trong những video tiếp theo nhé",
  "Phụ đề được thực hiện bởi cộng đồng Amara.org",
  "Hẹn gặp lại các bạn trong những video tiếp theo",
  "Hẹn gặp lại các bạn trong những video tiếp theo nhé!",
  "Cảm ơn và hẹn gặp lại.",
  "HẸN ĐẠI GIA ĐÌNH VIDEO TIẾP THEO NHÉ CÁC BẠN ^^",
  "Hẹn gặp lại các bạn trong những video tiếp theo nhé!",
  "Chào đại gia đình",
  "HẸN GẶP LẠI NHỚ ĐĂNG KÍ KÊNH NHÉ!!!",
  "Hẹn gặp lại các bạn trong những video tiếp theo nhé.",
  "CẢM ƠN KHÁN GIẢ ĐÃ THEO DÕI CỦA CÁC BẠN",
  "Nhớ like, share và đăng ký kênh của mình nhé!",
  "Hãy subscribe cho kênh La La School Để không bỏ lỡ những video hấp dẫn",
  "Đừng quên đăng kí cho kênh lalaschool Để không bỏ lỡ những video hấp dẫn",
  "CẢM ƠN KHÁN GIẢ ĐẠI GIA ĐÌNH VÀ CÁC BẠN ĐÃ THEO DÕI VÀ ĐĂNG KÝ KÊNH",
  "HẸN ĐẠI GIA ĐÌNH THÂN THƯƠNG",
  "HÃY ĐĂNG KÍ KÊNH NHÉ ĐẠI GIA ĐÌNH ^^",
  "Hẹn gặp lại các bạn trong những video tiếp theo!",
  "HẸN CÁC BẠN ĐẠI GIA ĐÌNH THANH THANH THANH THANH THANH THANH THANH THANH"
];
