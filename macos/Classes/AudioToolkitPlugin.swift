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
                case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "startRecording":
            let lang = (call.arguments as? [String: Any])?["language"] as? String ?? "vi-VN"
            Task {
                await recorder.startRecording(language: lang) { completion in
                    switch completion {
                    case .success(): result(["result": "true"])
                    case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                    }
                }
            }
        case "stopRecording":
            recorder.stopRecording { completion in
                switch completion {
                case .success(let path): result(["result": "true", "path": path])
                case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "turnOnMicRecording":
            recorder.turnOnMicRecording { completion in
                switch completion {
                case .success: result(["result": "true", "status": true])
                case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "turnOffMicRecording":
            recorder.turnOffMicRecording { completion in
                switch completion {
                case .success: result(["result": "true", "status": false])
                case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "turnOnSystemRecording":
            Task {
                await recorder.turnOnSystemRecording { completion in
                    switch completion {
                    case .success: result(["result": "true", "status": true])
                    case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                    }
                }
            }
        case "turnOffSystemRecording":
            Task {
                await recorder.turnOffSystemRecording { completion in
                    switch completion {
                    case .success: result(["result": "true", "status": false])
                    case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                    }
                }
            }
        case "initTranscribeAudio":
            recorder.initTranscribeAudio { completion in
                switch completion {
                case .success: result(["result": "true"])
                case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription])
                }
            }
        case "transcribeAudio":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(["result": "false", "errorMessage": "Thiếu đường dẫn file"])
                return
            }
            let lang = args["language"] as? String ?? "vi-VN"
            Task {
                recorder.transcribeAudio(url: URL(fileURLWithPath: path), language: lang) { completion in
                    switch completion {
                    case .success(let text): result(["result": "true", "text": text, "path": path])
                    case .failure(let error): result(["result": "false", "errorMessage": error.localizedDescription, "path": path])
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
    enum AudioQuality: Int { case normal = 128, good = 192, high = 256, extreme = 320 }
    enum AudioFormat: String { case aac, alac, flac, opus }

    var channel: FlutterMethodChannel?
    private var stream: SCStream?
    private var audioSettings: [String: Any] = [:]
    private var selectedFormat: AudioFormat = .aac

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastRecognizedText = ""
    private var filter: SCContentFilter?

    private var isRecording = false
    private var isMicRecording = false

    private let speechQueue = DispatchQueue(label: "audioToolkit.speechQueue")

    init(channel: FlutterMethodChannel?) {
        self.channel = channel
    }

    // MARK: - Setup
    func initRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { [weak self] content, error in
            guard let self = self else { return }
            if let error = error { return completion(.failure(error)) }
            guard let display = content?.displays.first else {
                return completion(.failure(self.makeError(code: 404, message: "Không tìm thấy màn hình")))
            }
            self.filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            completion(.success(()))
        }
    }

    func startRecording(language: String, completion: @escaping (Result<Void, Error>) -> Void) async {
        do {
            isRecording = true
            try await setupSpeechRecognition(language: language)
            completion(.success(()))
        } catch { completion(.failure(error)) }
    }

    func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
        isRecording = false
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask?.cancel()
        cleanupSpeechRecognition()
        completion(.success(""))
    }

    // MARK: - Microphone
    func turnOnMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else {
            return completion(.failure(makeError(code: 500, message: "Không khởi tạo được audio engine")))
        }
        isMicRecording = true
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let db = self.calculateDB(from: buffer)
            DispatchQueue.main.async {
                self.channel?.invokeMethod("dbMic", arguments: String(format: "%.2f", db))
            }
            if self.isRecording { self.speechQueue.async { self.recognitionRequest?.append(buffer) } }
        }
        do { try audioEngine?.start(); completion(.success(())) } catch { completion(.failure(error)) }
    }

    func turnOffMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cleanupSpeechRecognition()
        completion(.success(()))
    }

    // MARK: - System Audio
    func turnOnSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
        guard let filter = filter else {
            return completion(.failure(makeError(code: 404, message: "Chưa initRecording")))
        }
        audioSettings = [
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: AudioQuality.high.rawValue * 1000
        ]
        await startSCStream(filter: filter)
        completion(.success(()))
    }

    func turnOffSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
        do {
            try await stream?.stopCapture()
            stream = nil
            completion(.success(()))
        } catch { completion(.failure(makeError(code: 404, message: error.localizedDescription))) }
    }

    func startSCStream(filter: SCContentFilter) async {
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.capturesAudio = true
        config.sampleRate = audioSettings[AVSampleRateKey] as! Int
        config.channelCount = audioSettings[AVNumberOfChannelsKey] as! Int

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            guard let stream = stream else { return }
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            try await stream.startCapture()
        } catch { print("❌ Lỗi SCStream: \(error)") }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, let pcmBuffer = sampleBuffer.toPCMBuffer() else { return }
        let db = calculateDB(from: pcmBuffer)
        DispatchQueue.main.async { self.channel?.invokeMethod("db", arguments: String(format: "%.2f", db)) }
        if isRecording { speechQueue.async { self.recognitionRequest?.append(pcmBuffer) } }
    }

    // MARK: - Transcription
    func initTranscribeAudio(completion: @escaping (Result<String, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized: completion(.success("authorized"))
                case .denied: completion(.failure(self.makeError(code: 401, message: "Người dùng từ chối quyền Speech")))
                case .restricted: completion(.failure(self.makeError(code: 402, message: "Thiết bị không hỗ trợ Speech")))
                case .notDetermined: completion(.failure(self.makeError(code: 403, message: "Chưa yêu cầu quyền Speech")))
                @unknown default: completion(.failure(self.makeError(code: 406, message: "Trạng thái không xác định")))
                }
            }
        }
    }

    func transcribeAudio(url: URL, language: String = "vi-VN", completion: @escaping (Result<String, Error>) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable else {
            return completion(.failure(makeError(code: 404, message: "Speech Recognizer không khả dụng")))
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        recognizer.recognitionTask(with: request) { result, error in
            if let result = result, result.isFinal { completion(.success(result.bestTranscription.formattedString)) }
            else if let error = error { completion(.failure(self.makeError(code: 405, message: error.localizedDescription))) }
        }
    }

    // MARK: - Helpers
    private func setupSpeechRecognition(language: String) async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw makeError(code: 402, message: "Speech recognition bị từ chối") }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable else {
            throw makeError(code: 402, message: "Speech Recognizer không khả dụng")
        }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                
               if text != self.lastRecognizedText {
                        self.lastRecognizedText = text
                        DispatchQueue.main.async { self.channel?.invokeMethod("onMicText", arguments: ["text": text]) }
                    }
                
             
            } else if let error = error { print("❌ Speech error: \(error.localizedDescription)") }
        }
    }

    private func cleanupSpeechRecognition() {
        recognitionRequest = nil
        recognitionTask = nil
        lastRecognizedText = ""
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
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc) else { return nil }
        let format = AVAudioFormat(streamDescription: asbd)
        let frameCount = UInt32(CMSampleBufferGetNumSamples(self))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        var dataPointer: UnsafeMutablePointer<Int8>?
        var totalLength = 0
        guard let block = CMSampleBufferGetDataBuffer(self),
              CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr,
              let src = dataPointer else { return nil }
        memcpy(buffer.audioBufferList.pointee.mBuffers.mData, src, totalLength)
        return buffer
    }
}
