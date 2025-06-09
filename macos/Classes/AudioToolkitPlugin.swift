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
        self.wrapResult(resultCallback, result: result)
      }

    case "startRecording":
      let language = (call.arguments as? [String: Any])?["language"] as? String ?? "vi-VN"
      systemRecorder.startRecording(language: language) { resultCallback in
        self.wrapResult(resultCallback, result: result)
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
        if case .success = resultCallback { self.isMicRecording = true }
        self.wrapResult(resultCallback, result: result, key: "status")
      }

    case "turnOffMicRecording":
      systemRecorder.turnOffMicRecording { resultCallback in
        if case .success = resultCallback { self.isMicRecording = false }
        self.wrapResult(resultCallback, result: result, key: "status", inverse: true)
      }

    case "turnOnSystemRecording":
      if self.isSystemRecording {
        result(["result": "true", "status": true])
        return
      }
      systemRecorder.turnOnSystemRecording { resultCallback in
        if case .success = resultCallback { self.isSystemRecording = true }
        self.wrapResult(resultCallback, result: result, key: "status")
      }

    case "turnOffSystemRecording":
      Task {
        await systemRecorder.turnOffSystemRecording { resultCallback in
          if case .success = resultCallback { self.isSystemRecording = false }
          self.wrapResult(resultCallback, result: result, key: "status", inverse: true)
        }
      }

    default:
      result(["result": "false", "errorMessage": "Method không hợp lệ"])
    }
  }

  private func wrapResult(
    _ resultCallback: Result<Void, Error>, result: @escaping FlutterResult, key: String = "result",
    inverse: Bool = false
  ) {
    switch resultCallback {
    case .success:
      result(["result": "true", key: inverse ? false : true])
    case .failure(let error):
      result(["result": "false", "errorMessage": error.localizedDescription])
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

  // MARK: - Public properties
  var channel: FlutterMethodChannel?

  // MARK: - Internal states
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
  private let silenceThresholdDB: Float = -35
  private let minSpeakingDuration = 0.6
  private let maxSilenceDuration = 0.5

  private var filter: SCContentFilter?

  // MARK: - Initialization
  init(channel: FlutterMethodChannel?) {
    self.channel = channel
  }

  // MARK: - System Audio Setup
  func initRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
      [weak self] content, error in
      guard let self = self else { return }
      if let error = error { return completion(.failure(error)) }
      guard let display = content?.displays.first else {
        return completion(.failure(self.makeError(404, "Không tìm thấy màn hình")))
      }
      self.filter = SCContentFilter(
        display: display, excludingApplications: [], exceptingWindows: [])
      completion(.success(()))
    }
  }

  func turnOnSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    guard let filter = self.filter else {
      return completion(.failure(makeError(404, "Chưa initRecording")))
    }
    prepareAudioSettings()
    Task {
      await startSCStream(filter: filter)
      completion(.success(()))
    }
  }

  func turnOffSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
    do {
      try await stream?.stopCapture()
      stream = nil
      completion(.success(()))
    } catch {
      completion(.failure(makeError(404, error.localizedDescription)))
    }
  }

  // MARK: - Mic Recording
  func turnOnMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    audioEngine = AVAudioEngine()
    guard let inputNode = audioEngine?.inputNode else {
      return completion(.failure(makeError(500, "Không khởi tạo được audio engine")))
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

  func startRecording(language: String, completion: @escaping (Result<Void, Error>) -> Void) {
    do {
      isRecording = true
      audioFile = try prepareAudioFile()
      fullAudioFile = try prepareAudioFile(suffix: "_full")

      try setupSpeechRecognition(language: language)
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
    recognitionTask?.cancel()

    let path = fullAudioFile?.url.path
    audioFile = nil
    fullAudioFile = nil
    cleanupSpeechRecognition()

    guard let finalPath = path else {
      return completion(.failure(makeError(500, "Không tìm thấy file")))
    }
    completion(.success(finalPath))
  }

  func startSCStream(filter: SCContentFilter) async {
    let config = SCStreamConfiguration()
    config.width = 2
    config.height = 2
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
  // MARK: - Stream Callback
  private func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == .audio, let pcmBuffer = sampleBuffer.toPCMBuffer() else { return }

    let db = calculateDB(from: pcmBuffer)
    DispatchQueue.main.async {
      self.channel?.invokeMethod("db", arguments: String(db))
    }

    try? fullAudioFile?.write(from: pcmBuffer)
    guard isRecording else { return }

    if db > silenceThresholdDB {
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

  // MARK: - Helpers
  private func setupSpeechRecognition(language: String) throws {
    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
      throw makeError(402, "Speech recognizer không khả dụng")
    }

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    recognitionRequest?.shouldReportPartialResults = true
    recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { result, error in
      if let result = result {
        let text = result.bestTranscription.formattedString
        DispatchQueue.main.async {
          self.channel?.invokeMethod("onMicText", arguments: ["text": text])
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

  private func prepareAudioSettings() {
    audioSettings = [
      AVSampleRateKey: 48000,
      AVNumberOfChannelsKey: 2,
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVEncoderBitRateKey: AudioQuality.high.rawValue * 1000,
    ]
  }

  private func prepareAudioFile(suffix: String = "") throws -> AVAudioFile {
    let ext: String =
      ["aac": "m4a", "alac": "caf", "flac": "flac", "opus": "ogg"][selectedFormat.rawValue] ?? "m4a"
    let fileName = "audioToolkit_\(Int(Date().timeIntervalSince1970))\(suffix).\(ext)"
    guard let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    else {
      throw makeError(1001, "Không tìm thấy thư mục Downloads")
    }
    return try AVAudioFile(
      forWriting: dir.appendingPathComponent(fileName), settings: audioSettings)
  }

  private func makeError(_ code: Int, _ message: String) -> NSError {
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
