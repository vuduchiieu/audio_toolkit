import 'package:audio_toolkit_example/cubit/audio_toolkit_cubit.dart';
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
      home: Scaffold(
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
                  context.read<AudioToolkitCubit>().transcribeAudio(state.path);
                  return;
                }
                return;
              }
            },
            builder: (context, state) {
              if (state is AudioToolkitInitial) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (state.text.isNotEmpty)
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          padding: EdgeInsets.all(20),
                          color: Colors.pinkAccent.shade100,
                          child: ListView.builder(
                            itemCount: state.text.length,
                            reverse: true,
                            itemBuilder: (context, index) {
                              return Text(
                                state.text[index],
                                style: TextStyle(color: Colors.white),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (state.isSystemRecord) {
                              context
                                  .read<AudioToolkitCubit>()
                                  .turnOffSystemRecording();
                            } else {
                              context
                                  .read<AudioToolkitCubit>()
                                  .turnOnSystemRecording();
                            }
                          },
                          child: Icon(
                              state.isSystemRecord
                                  ? Icons.desktop_mac
                                  : Icons.desktop_access_disabled,
                              size: 40),
                        ),
                        const SizedBox(width: 16),
                        buildDbMeter(state.db),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: Icon(Icons.mic, size: 40),
                        ),
                        const SizedBox(width: 16),
                        buildDbMeter(-160),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(state.isRecording
                          ? Icons.stop
                          : Icons.fiber_manual_record),
                      label:
                          Text(state.isRecording ? 'Dừng ghi' : 'Bắt đầu ghi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            state.isRecording ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        final cubit = context.read<AudioToolkitCubit>();
                        if (state.isRecording) {
                          cubit.stopRecording();
                        } else {
                          cubit.startRecord();
                        }
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  Widget buildDbMeter(double db) {
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
