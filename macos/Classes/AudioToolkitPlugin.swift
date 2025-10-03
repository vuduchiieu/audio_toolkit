import AVFoundation
import Accelerate
import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import Speech

@available(macOS 13.0, *)
public class AudioToolkitPlugin: NSObject, FlutterPlugin {
    var systemRecorder: SystemAudioRecorder?
    var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "audio_toolkit",
            binaryMessenger: registrar.messenger)
        let instance = AudioToolkitPlugin()
        instance.channel = channel
        instance.systemRecorder = SystemAudioRecorder(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let recorder = systemRecorder else {
            result(["result": "false", "errorMessage": "Không khởi tạo được recorder"])
            return
        }

        switch call.method {
        case "initRecording":
            recorder.initRecording { completion in
                switch completion {
                case .success(): result(["result": "true"])
                case .failure(let error):
                    result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "startRecording":
            let lang = (call.arguments as? [String: Any])?["language"] as? String ?? "vi-VN"
            Task {
                await recorder.startRecording(language: lang) { completion in
                    switch completion {
                    case .success(): result(["result": "true"])
                    case .failure(let error):
                        result(["result": "false", "errorMessage": error.localizedDescription])
                    }
                }
            }
        case "stopRecording":
            recorder.stopRecording { completion in
                switch completion {
                case .success(let path): result(["result": "true", "path": path])
                case .failure(let error):
                    result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "turnOnMicRecording":
            recorder.turnOnMicRecording { completion in
                switch completion {
                case .success: result(["result": "true", "status": true])
                case .failure(let error):
                    result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "turnOffMicRecording":
            recorder.turnOffMicRecording { completion in
                switch completion {
                case .success: result(["result": "true", "status": false])
                case .failure(let error):
                    result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "turnOnSystemRecording":
            Task {
                await recorder.turnOnSystemRecording { completion in
                    switch completion {
                    case .success: result(["result": "true", "status": true])
                    case .failure(let error):
                        result(["result": "false", "errorMessage": error.localizedDescription])
                    }
                }
            }
        case "turnOffSystemRecording":
            Task {
                await recorder.turnOffSystemRecording { completion in
                    switch completion {
                    case .success: result(["result": "true", "status": false])
                    case .failure(let error):
                        result(["result": "false", "errorMessage": error.localizedDescription])
                    }
                }
            }
        default:
            result(["result": "false", "errorMessage": "Method không hợp lệ"])
        }
    }
}

@available(macOS 13.0, *)
class SystemAudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput {

    var channel: FlutterMethodChannel?
    private var stream: SCStream?

    private var audioEngine: AVAudioEngine?

    // Mic
    private var micRequest: SFSpeechAudioBufferRecognitionRequest?
    private var micTask: SFSpeechRecognitionTask?

    // System
    private var systemRequest: SFSpeechAudioBufferRecognitionRequest?
    private var systemTask: SFSpeechRecognitionTask?

    private var filter: SCContentFilter?

    private let speechQueue = DispatchQueue(label: "audioToolkit.speechQueue")

    init(channel: FlutterMethodChannel?) {
        self.channel = channel
    }

    // MARK: - Setup
    func initRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
            [weak self] content, error in
            guard let self = self else { return }
            if let error = error {
                return completion(.failure(error))
            }
            guard let display = content?.displays.first else {
                return completion(
                    .failure(self.makeError(code: 404, message: "Không tìm thấy màn hình"))
                )
            }
            self.filter = SCContentFilter(
                display: display, excludingApplications: [], exceptingWindows: [])

            completion(.success(()))
            // self.turnOnMicRecording { micResult in
            //     switch micResult {
            //     case .success():
            //         Task {
            //             await self.turnOnSystemRecording { systemResult in
            //                 switch systemResult {
            //                 case .success(): completion(.success(()))
            //                 case .failure(let err): completion(.failure(err))
            //                 }
            //             }
            //         }
            //     case .failure(let err):
            //         completion(.failure(err))
            //     }
            // }
        }
    }

    func startRecording(language: String, completion: @escaping (Result<Void, Error>) -> Void) async
    {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
            recognizer.isAvailable
        else {
            return completion(
                .failure(makeError(code: 402, message: "Speech Recognizer không khả dụng")))
        }
        do {

            if micRequest != nil {
                micTask = recognizer.recognitionTask(with: micRequest!) {
                    [weak self] result, error in
                    guard let self = self else { return }
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        DispatchQueue.main.async {
                            self.channel?.invokeMethod("onMicText", arguments: ["text": text])
                        }
                    } else if let error = error {
                        print("❌ Mic speech error: \(error.localizedDescription)")
                    }
                }
            }

            if systemRequest != nil {
                systemTask = recognizer.recognitionTask(with: systemRequest!) {
                    [weak self] result, error in
                    guard let self = self else { return }
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        DispatchQueue.main.async {
                            self.channel?.invokeMethod("onSystemText", arguments: ["text": text])
                        }
                    } else if let error = error {
                        print("❌ System speech error: \(error.localizedDescription)")
                    }
                }
            }

            completion(.success(()))
        } catch { completion(.failure(error)) }
    }

    func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
        micTask?.cancel()
        micTask = nil
        systemTask?.cancel()
        systemTask = nil
        DispatchQueue.main.async {
            completion(.success(""))
        }
    }

    // MARK: - Microphone
    func turnOnMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else {
            return completion(
                .failure(makeError(code: 500, message: "Không khởi tạo được audio engine")))
        }

        micRequest = SFSpeechAudioBufferRecognitionRequest()
        micRequest?.shouldReportPartialResults = true

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            self?.micRequest?.append(buffer)
            if let db = self?.calculateDB(from: buffer) {
                DispatchQueue.main.async {
                    self?.channel?.invokeMethod("dbMic", arguments: String(format: "%.2f", db))
                }
            }
        }
        do {
            try audioEngine?.start()
            completion(.success(()))
        } catch { completion(.failure(error)) }
    }

    // MARK: - System Audio
    func turnOnSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
        guard let filter = filter else {
            return completion(.failure(makeError(code: 404, message: "Chưa initRecording")))
        }

        systemRequest = SFSpeechAudioBufferRecognitionRequest()
        systemRequest?.shouldReportPartialResults = true

        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            guard let stream = stream else { return }
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            try await stream.startCapture()
        } catch { print("❌ Lỗi SCStream: \(error)") }
        completion(.success(()))
    }

    func turnOffMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        micRequest?.endAudio()
        micTask?.cancel()
        micRequest = nil
        micTask = nil
        completion(.success(()))
    }

    func turnOffSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
        do {
            try await stream?.stopCapture()
            systemRequest?.endAudio()
            systemTask?.cancel()
            systemRequest = nil
            systemTask = nil
            stream = nil
            completion(.success(()))
        } catch { completion(.failure(makeError(code: 404, message: error.localizedDescription))) }
    }

    func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio, let pcmBuffer = sampleBuffer.toPCMBuffer() else { return }
        if let db = calculateDB(from: pcmBuffer) as Float? {
            DispatchQueue.main.async {
                self.channel?.invokeMethod("dbSystem", arguments: String(format: "%.2f", db))
            }
        }
        systemRequest?.append(pcmBuffer)
    }
    private func makeError(code: Int, message: String) -> NSError {
        NSError(domain: "AudioToolkit", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    func calculateDB(from buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return -60 }
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(buffer.frameLength))
        let db = 20 * log10(rms)
        return db.isFinite ? db : -60
    }
}

@available(macOS 13.0, *)
extension CMSampleBuffer {
    func toPCMBuffer() -> AVAudioPCMBuffer? {
        guard let desc = CMSampleBufferGetFormatDescription(self),
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
        else { return nil }
        let format = AVAudioFormat(streamDescription: asbd)
        let frameCount = UInt32(CMSampleBufferGetNumSamples(self))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        var dataPointer: UnsafeMutablePointer<Int8>?
        var totalLength = 0
        guard let block = CMSampleBufferGetDataBuffer(self),
            CMBlockBufferGetDataPointer(
                block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer) == noErr,
            let src = dataPointer
        else { return nil }
        memcpy(buffer.audioBufferList.pointee.mBuffers.mData, src, totalLength)
        return buffer
    }
}
