import AVFoundation
import Accelerate
import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import Speech

public class AudioToolkitPlugin: NSObject, FlutterPlugin {
  var systemRecorder: AnyObject?
  var isSystemRecording = false
  var isMicRecording = false
  var channel: FlutterMethodChannel?

  public static func register(with registrar: FlutterPluginRegistrar) {
    if #available(macOS 13.0, *) {
      let channel = FlutterMethodChannel(
        name: "audio_toolkit", binaryMessenger: registrar.messenger)
      let instance = AudioToolkitPlugin()
      instance.channel = channel
      instance.systemRecorder = SystemAudioRecorder(channel: channel)
      registrar.addMethodCallDelegate(instance, channel: channel)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(macOS 13.0, *) else {
      result(["result": "false", "errorMessage": "Yêu cầu macOS 13.0 trở lên"])
      return
    }

    if self.systemRecorder == nil {
      self.systemRecorder = SystemAudioRecorder(channel: channel)
    }

    guard let systemRecorder = systemRecorder as? SystemAudioRecorder else {
      result(["result": "false", "errorMessage": "Không khởi tạo được recorder"])
      return
    }

    switch call.method {
    case "initRecording":
      systemRecorder.initRecording { resultCallback in
        switch resultCallback {
        case .success(): result(["result": "true"])
        case .failure(let error):
          result(["result": "false", "errorMessage": error.localizedDescription])
        }
      }

    case "startRecording":
      let language = (call.arguments as? [String: Any])?["language"] as? String ?? "vi-VN"
      Task {
        await systemRecorder.startRecording(language: language) { resultCallback in
          switch resultCallback {
          case .success(): result(["result": "true"])
          case .failure(let error):
            result(["result": "false", "errorMessage": error.localizedDescription])
          }
        }
      }

    case "stopRecording":
      systemRecorder.stopRecording { resultCallback in
        switch resultCallback {
        case .success(let path): result(["result": "true", "path": path])
        case .failure(let error):
          result(["result": "false", "errorMessage": error.localizedDescription])
        }
      }

    case "turnOnMicRecording":

      if self.isMicRecording {
        result(["result": "true", "status": true])
        return
      }
      systemRecorder.turnOnMicRecording { resultCallback in
        switch resultCallback {
        case .success:
          self.isMicRecording = true
          result(["result": "true", "status": true])
        case .failure(let error):
          result(["result": "false", "errorMessage": error.localizedDescription])
        }
      }

    case "turnOffMicRecording":
      systemRecorder.turnOffMicRecording { resultCallback in
        if case .success = resultCallback { self.isMicRecording = false }
        switch resultCallback {
        case .success:
          self.isMicRecording = false
          result(["result": "true", "status": false])
        case .failure(let error):
          result(["result": "false", "errorMessage": error.localizedDescription])
        }
      }

    case "turnOnSystemRecording":
      if self.isSystemRecording {
        result(["result": "true", "status": true])
        return
      }
      Task {
        await systemRecorder.turnOnSystemRecording { resultCallback in
          switch resultCallback {
          case .success:
            result(["result": "true", "status": !self.isSystemRecording])
            self.isSystemRecording = true
          case .failure(let error):
            result(["result": "false", "errorMessage": error.localizedDescription])
          }
        }
      }
    case "turnOffSystemRecording":
      Task {
        await systemRecorder.turnOffSystemRecording { resultCallback in
          switch resultCallback {
          case .success:
            result(["result": "true", "status": !self.isSystemRecording])
            self.isSystemRecording = false
          case .failure(let error):
            result(["result": "false", "errorMessage": error.localizedDescription])
          }
        }
      }

    case "initTranscribeAudio":
      systemRecorder.initTranscribeAudio { resultCallback in
        switch resultCallback {
        case .success:
          result(["result": "true"])
        case .failure(let error):
          result(["result": "false", "errorMessage": error.localizedDescription])
        }
      }

    case "transcribeAudio":
      if let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      {

        let language = args["language"] as? String ?? "vi-VN"
        let url = URL(fileURLWithPath: path)

        Task {
          systemRecorder.transcribeAudio(url: url, language: language) { resultCallback in
            switch resultCallback {
            case .success(let text):
              result(["result": "true", "text": text, "path": path])
            case .failure(let error):
              result([
                "result": "false", "errorMessage": error.localizedDescription, "path": path,
              ])
            }
          }
        }

      } else {
        result(["result": "false", "errorMessage": "Thiếu đường dẫn file"])
      }

    default:
      result(["result": "false", "errorMessage": "Method không hợp lệ"])
    }
  }

}

@available(macOS 13.0, *)
class SystemAudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
  enum AudioQuality: Int {
    case normal = 128
    case good = 192
    case high = 256
    case extreme = 320
  }
  enum AudioFormat: String { case aac, alac, flac, opus }

  var channel: FlutterMethodChannel?

  private var stream: SCStream?
  private var audioFile: AVAudioFile?
  private var fullAudioFile: AVAudioFile?
  private var audioSettings: [String: Any] = [:]
  private var selectedFormat: AudioFormat = .aac

  private var audioEngine: AVAudioEngine?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var speechRecognizer: SFSpeechRecognizer?

  private var isRecording = false
  private var isMicRecording = false
  private var isSpeaking = false
  private var silenceFrameCount = 0
  private var speakingFrameCount = 0
  private var startTime: Date?

  private let sampleRate: Double = 48000
  private let minSpeakingDuration = 0.6
  private let maxSilenceDuration = 0.3

  private var filter: SCContentFilter?

  init(channel: FlutterMethodChannel?) {
    self.channel = channel
  }

  func initRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
      [weak self] content, error in
      guard let self = self else { return }
      if let error = error { return completion(.failure(error)) }
      guard let display = content?.displays.first else {
        return completion(
          .failure(
            self.makeTranscribeError(
              code: 404, message: "Không tìm thấy màn hình")))
      }
      self.filter = SCContentFilter(
        display: display, excludingApplications: [], exceptingWindows: [])
      completion(.success(()))
    }
  }

  func turnOnSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
    guard let filter = self.filter else {
      return completion(
        .failure(
          self.makeTranscribeError(
            code: 404, message: "Chưa initRecording")))
    }
    audioSettings = [
      AVSampleRateKey: 48000,
      AVNumberOfChannelsKey: 2,
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVEncoderBitRateKey: AudioQuality.high.rawValue * 1000,
    ]
    await startSCStream(filter: filter)
    completion(.success(()))
  }

  func turnOffSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
    do {
      fullAudioFile = try prepareAudioFile(suffix: "_full")
      try await stream?.stopCapture()
      stream = nil
      completion(.success(()))
    } catch {
      completion(
        .failure(
          self.makeTranscribeError(
            code: 404, message: error.localizedDescription)))
    }
  }

  func turnOnMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    audioEngine = AVAudioEngine()
    guard let inputNode = audioEngine?.inputNode else {
      return completion(
        .failure(
          self.makeTranscribeError(
            code: 500, message: "Không khởi tạo được audio engine")))
    }

    isMicRecording = true
    let format = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      let db = self.calculateDB(from: buffer)
      DispatchQueue.main.async {
        self.channel?.invokeMethod("dbMic", arguments: String(format: "%.2f", db))
      }
      if self.isMicRecording {
        self.recognitionRequest?.append(buffer)
      }
    }

    do {
      try audioEngine?.start()
      completion(.success(()))
    } catch {
      completion(.failure(error))
    }
  }

  func turnOffMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    cleanupSpeechRecognition()
    completion(.success(()))
  }

  func startRecording(language: String, completion: @escaping (Result<Void, Error>) -> Void) async {
    do {
      isRecording = true
      audioFile = try prepareAudioFile()
      fullAudioFile = try prepareAudioFile(suffix: "_full")
      try await setupSpeechRecognition(language: language)

      completion(.success(()))
    } catch {
      completion(.failure(error))
    }
  }

  func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
    isRecording = false
    isSpeaking = false
    silenceFrameCount = 0
    speakingFrameCount = 0
    recognitionRequest?.endAudio()
    recognitionTask?.finish()
    recognitionTask?.cancel()

    let path = fullAudioFile?.url.path
    audioFile = nil
    fullAudioFile = nil
    cleanupSpeechRecognition()

    guard let finalPath = path else {
      return completion(
        .failure(
          self.makeTranscribeError(
            code: 500, message: "Không tìm thấy file")))
    }
    completion(.success(finalPath))
  }

  func startSCStream(filter: SCContentFilter) async {
    let config = SCStreamConfiguration()

    config.showsCursor = false
    config.capturesAudio = true
    config.sampleRate = audioSettings[AVSampleRateKey] as! Int
    config.channelCount = audioSettings[AVNumberOfChannelsKey] as! Int

    stream = SCStream(filter: filter, configuration: config, delegate: self)

    do {
      guard let stream = stream else {
        print("❌ Stream is nil")
        return
      }

      try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
      try await stream.startCapture()

    } catch {
      print("❌ Lỗi khi start SCStream: \(error)")
    }
  }
  private var dbHistory: [Float] = []
  private var dbSmoothingWindow = 20

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == .audio, let pcmBuffer = sampleBuffer.toPCMBuffer() else { return }

    let db = calculateDB(from: pcmBuffer)

    dbHistory.append(db)
    if dbHistory.count > dbSmoothingWindow {
      dbHistory.removeFirst()
    }

    let averageDB = dbHistory.reduce(0, +) / Float(dbHistory.count)
    let adaptiveThreshold = averageDB - 5

    DispatchQueue.main.async {
      self.channel?.invokeMethod("db", arguments: String(db))
    }

    try? fullAudioFile?.write(from: pcmBuffer)

    guard isRecording else { return }

    if db > adaptiveThreshold {
      if !isSpeaking {
        isSpeaking = true
        startTime = Date()
        silenceFrameCount = 0
        speakingFrameCount = 0
        if audioFile == nil {
          audioFile = try? prepareAudioFile()
        }
      }
      speakingFrameCount += 1
      silenceFrameCount = 0
      try? audioFile?.write(from: pcmBuffer)
    } else if isSpeaking {
      silenceFrameCount += 1
      let silenceDuration = Double(silenceFrameCount) * 1024 / sampleRate
      let speakingDuration = Date().timeIntervalSince(startTime ?? Date())

      if silenceDuration > maxSilenceDuration && speakingDuration > minSpeakingDuration {
        isSpeaking = false
        silenceFrameCount = 0
        speakingFrameCount = 0

        if let file = audioFile {
          let path = file.url.path
          audioFile = try? prepareAudioFile()
          DispatchQueue.main.async {
            self.channel?.invokeMethod("onSystemAudioFile", arguments: ["path": path])
          }
        }
      }
    }
  }

  func initTranscribeAudio(completion: @escaping (Result<String, Error>) -> Void) {
    SFSpeechRecognizer.requestAuthorization { authStatus in
      DispatchQueue.main.async { [self] in
        switch authStatus {
        case .denied:
          completion(
            .failure(
              self.makeTranscribeError(
                code: 401, message: "Người dùng từ chối quyền sử dụng Speech Recognition")))
          return
        case .restricted:
          completion(
            .failure(
              self.makeTranscribeError(
                code: 402, message: "Thiết bị không hỗ trợ Speech Recognition")))
          return
        case .notDetermined:
          completion(
            .failure(
              self.makeTranscribeError(
                code: 403, message: "Quyền Speech Recognition chưa được yêu cầu"))
          )
          return
        case .authorized:
          completion(.success("authorized"))
        @unknown default:
          completion(
            .failure(
              self.makeTranscribeError(code: 406, message: "Trạng thái xác thực không xác định")))
        }
      }
    }
  }

  func transcribeAudio(
    url: URL,
    language: String = "vi-VN",
    completion: @escaping (Result<String, Error>) -> Void
  ) {

    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
    guard let recognizer = recognizer, recognizer.isAvailable else {
      completion(
        .failure(
          self.makeTranscribeError(code: 404, message: "Speech Recognizer không khả dụng")))
      return
    }
    let request = SFSpeechURLRecognitionRequest(url: url)
    recognizer.recognitionTask(with: request) { result, error in
      if let result = result, result.isFinal {
        completion(.success(result.bestTranscription.formattedString))
      } else if let error = error {
        completion(
          .failure(
            self.makeTranscribeError(
              code: 405, message: "❌ Lỗi nhận diện: \(error.localizedDescription)")))
      }
    }
  }

  var lastRecognizedText = ""

  private func setupSpeechRecognition(language: String) async throws {
    // let status = await withCheckedContinuation { continuation in
    //   SFSpeechRecognizer.requestAuthorization { status in
    //     continuation.resume(returning: status)
    //   }
    // }

    // guard status == .authorized else {
    //   self.makeTranscribeError(
    //     code: 402, message: "Speech recognition bị từ chối hoặc không khả dụng")
    // }

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
      recognizer.isAvailable
    else {
      throw self.makeTranscribeError(code: 402, message: "Speech Recognizer không khả dụng")
    }

    speechRecognizer = recognizer
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    recognitionRequest?.shouldReportPartialResults = true

    lastRecognizedText = ""

    recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) {
      result, error in
      if let result = result {
        let fullText = result.bestTranscription.formattedString

        let newText = String(fullText.dropFirst(self.lastRecognizedText.count))

        if !newText.trimmingCharacters(in: .whitespaces).isEmpty {
          self.lastRecognizedText = fullText

          DispatchQueue.main.async {
            self.channel?.invokeMethod("onMicText", arguments: ["text": newText])
          }
        }
      } else if let error = error {
        print("❌ Speech error: \(error.localizedDescription)")
      }
    }
  }
  private func cleanupSpeechRecognition() {
    recognitionRequest = nil
    recognitionTask = nil
    speechRecognizer = nil
  }

  private func makeTranscribeError(code: Int, message: String) -> NSError {
    return NSError(
      domain: "AudioToolkit",
      code: code,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }

  private func prepareAudioFile(suffix: String = "") throws -> AVAudioFile {
    let ext: String =
      ["aac": "m4a", "alac": "caf", "flac": "flac", "opus": "ogg"][selectedFormat.rawValue] ?? "m4a"
    let fileName = "audioToolkit_\(Int(Date().timeIntervalSince1970))\(suffix).\(ext)"
    guard let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    else {
      throw self.makeTranscribeError(
        code: 1001, message: "Không tìm thấy thư mục Downloads")
    }
    return try AVAudioFile(
      forWriting: dir.appendingPathComponent(fileName), settings: audioSettings)
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
