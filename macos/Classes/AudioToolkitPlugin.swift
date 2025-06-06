import AVFoundation
import Accelerate
import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import Speech

public class AudioToolkitPlugin: NSObject, FlutterPlugin {
  var systemRecorder: AnyObject?

  var isSystemRecording: Bool = false
  var isMicRecording: Bool = false

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
    if #available(macOS 13.0, *) {

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
          case .success:
            result(["result": "true"])
            break
          case .failure(let error):
            result(["result": "false", "errorMessage": error.localizedDescription])
            break
          }
        }
        break
      case "startRecording":
        systemRecorder.startRecording { resultCallback in
          switch resultCallback {
          case .success:
            result(["result": "true"])
            break
          case .failure(let error):
            result(["result": "false", "errorMessage": error.localizedDescription])
            break
          }
        }
        break

      case "stopRecording":
        systemRecorder.stopRecording { resultCallback in
          switch resultCallback {
          case .success(let path):
            result(["result": "true", "path": path])
          case .failure(let error):
            result(["result": "false", "errorMessage": error.localizedDescription])
          }
        }
        break
      case "turnOnMicRecording":
        if self.isMicRecording {
          result(["result": "true", "status": true])
          return
        }
        Task {
          systemRecorder.turnOnMicRecording { resultCallback in
            switch resultCallback {
            case .success:
              self.isMicRecording = true
              result(["result": "true", "status": true])
            case .failure(let error):
              result(["result": "false", "errorMessage": error.localizedDescription])
            }
          }
        }
        break
      case "turnOffMicRecording":
        Task {
          systemRecorder.turnOffMicRecording { resultCallback in
            switch resultCallback {
            case .success:
              self.isMicRecording = false
              result(["result": "true", "status": false])
            case .failure(let error):
              result(["result": "false", "errorMessage": error.localizedDescription])
            }
          }
        }
        break
      case "turnOnSystemRecording":
        if self.isSystemRecording {
          result(["result": "true", "status": true])
          return
        }
        Task {
          systemRecorder.turnOnSystemRecording { resultCallback in
            switch resultCallback {
            case .success:
              result(["result": "true", "status": !self.isSystemRecording])
              self.isSystemRecording = true
            case .failure(let error):
              result(["result": "false", "errorMessage": error.localizedDescription])
            }
          }
        }
        break
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
        break

      case "initTranscribeAudio":
        systemRecorder.initTranscribeAudio { resultCallback in
          switch resultCallback {
          case .success:
            result(["result": "true"])
          case .failure(let error):
            result(["result": "false", "errorMessage": error.localizedDescription])
          }
        }
        break

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
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Thiếu path", details: nil))
        }

        break
      default:
        result(["result": "false", "errorMessage": "Method không hợp lệ"])
      }
    } else {
      result(["result": "false", "errorMessage": "Yêu cầu macOS 13.0 trở lên"])
    }
  }
}

@available(macOS 13.0, *)
class SystemAudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput {

  var channel: FlutterMethodChannel?

  init(channel: FlutterMethodChannel?) {
    self.channel = channel
  }

  enum AudioQuality: Int {
    case normal = 128
    case good = 192
    case high = 256
    case extreme = 320
  }

  enum AudioFormat: String {
    case aac, alac, flac, opus
  }
  var isSpeaking = false
  var stream: SCStream?
  var audioFile: AVAudioFile?
  var fullAudioFile: AVAudioFile?
  var audioSettings: [String: Any] = [:]
  var selectedFormat: AudioFormat = .aac
  var filter: SCContentFilter?
  var startTime: Date?
  var speakingFrameCount: Int = 0
  var isRecording = false

  var audioEngine: AVAudioEngine?
  var speechRecognizer: SFSpeechRecognizer?
  var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  var recognitionTask: SFSpeechRecognitionTask?

  var silenceFrameCount: Int = 0
  let sampleRate: Double = 48000

  func initRecording(completion: @escaping (Result<Void, Error>) -> Void) {

    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
      [weak self] content, error in
      guard let self = self else { return }

      if let error = error {
        completion(.failure(error))
        return
      }

      guard let display = content?.displays.first else {
        completion(
          .failure(
            self.makeTranscribeError(
              code: 404, message: "Không tìm thấy màn hình hoặc chưa cấp quyền ghi màn hình")))
        return
      }

      self.filter = SCContentFilter(
        display: display, excludingApplications: [], exceptingWindows: [])
      completion(.success(()))
    }
  }

  func startRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    do {
      isRecording = true
      audioFile = try prepareAudioFile()
      fullAudioFile = try prepareAudioFile(suffix: "_full")
      completion(.success(()))
    } catch {
      completion(.failure(error))
    }
  }

  func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
    if let path: String = fullAudioFile?.url.path {
      completion(.success(path))
    } else {
      completion(
        .failure(
          self.makeTranscribeError(code: 500, message: "Không tìm thấy file full audio")
        ))
    }
    isRecording = false
    audioFile = nil
    fullAudioFile = nil
  }

  func turnOnSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    guard let filter = self.filter else {
      completion(
        .failure(
          self.makeTranscribeError(
            code: 404, message: "Gọi startSystemRecording mà chưa initRecording trước đó")))
      return
    }
    self.prepareAudioSettings()
    Task {
      await self.startSCStream(filter: filter)
      completion(.success(()))
    }

  }

  func turnOffSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
    Task {
      do {
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
    let fileExt: String
    switch selectedFormat {
    case .aac: fileExt = "m4a"
    case .alac: fileExt = "caf"
    case .flac: fileExt = "flac"
    case .opus: fileExt = "ogg"
    }

    let fileName = "audioToolkit_\(Int(Date().timeIntervalSince1970))\(suffix).\(fileExt)"
    guard let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    else {
      throw NSError(
        domain: "prepareAudioFile", code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy thư mục Downloads"])
    }

    let url = dir.appendingPathComponent(fileName)

    return try AVAudioFile(forWriting: url, settings: audioSettings)
  }

  private func startSCStream(filter: SCContentFilter) async {
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
  func stream(
    _: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == .audio else { return }

    if let pcmBuffer = sampleBuffer.toPCMBuffer() {
      let db: Float = self.calculateDB(from: pcmBuffer)
      DispatchQueue.main.async {
        self.channel?.invokeMethod("db", arguments: String(db))
      }
      if let fullFile = fullAudioFile {
        do {
          try fullFile.write(from: pcmBuffer)
        } catch {
          print("❌ Ghi vào fullAudioFile lỗi: \(error)")
        }
      }
      if db > -30 {
        if !isSpeaking {
          isSpeaking = true
          startTime = Date()
          silenceFrameCount = 0
          speakingFrameCount = 0
        }
        speakingFrameCount += 1
        silenceFrameCount = 0
        try? audioFile?.write(from: pcmBuffer)
      } else if isSpeaking {
        silenceFrameCount += 1

        let silenceDuration = Double(silenceFrameCount) * 1024 / sampleRate
        let speakingDuration = Date().timeIntervalSince(startTime ?? Date())

        if silenceDuration > 0.8 && speakingDuration > 1.5 {
          isSpeaking = false
          silenceFrameCount = 0
          speakingFrameCount = 0
          let url = audioFile?.url
          self.audioFile = try? prepareAudioFile()
          DispatchQueue.main.async {
            self.channel?.invokeMethod("onSystemAudioFile", arguments: ["path": url?.path])
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

  func calculateDB(from buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData?[0] else { return -60 }
    let frameLength = Int(buffer.frameLength)
    var rms: Float = 0
    vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
    let avgPower = 20 * log10(rms)
    return avgPower.isFinite ? avgPower : -60
  }

  func makeTranscribeError(code: Int, message: String) -> NSError {
    return NSError(
      domain: "transcribeAudio",
      code: code,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }

  func turnOnMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    self.audioEngine = AVAudioEngine()

    guard let inputNode = self.audioEngine?.inputNode else {
      completion(
        .failure(
          self.makeTranscribeError(
            code: 500, message: "Không khởi tạo được audio engine")
        )
      )
      return
    }

    do {
      self.audioFile = try prepareAudioFile(suffix: "_mic")
    } catch {
      completion(.failure(error))
      return
    }

    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
      let db = self.calculateDB(from: buffer)
      DispatchQueue.main.async {
        self.channel?.invokeMethod("dbMic", arguments: String(format: "%.2f", db))
      }

      if db > -45 {
        if !self.isSpeaking {
          self.isSpeaking = true
          self.startTime = Date()
          self.silenceFrameCount = 0
          self.speakingFrameCount = 0
        }
        self.speakingFrameCount += 1
        self.silenceFrameCount = 0
        try? self.audioFile?.write(from: buffer)
      } else if self.isSpeaking {
        self.silenceFrameCount += 1

        let silenceDuration = Double(self.silenceFrameCount) * 1024 / recordingFormat.sampleRate
        let speakingDuration = Date().timeIntervalSince(self.startTime ?? Date())

        if silenceDuration > 0.5 && speakingDuration > 1.5 {
          self.isSpeaking = false
          self.silenceFrameCount = 0
          self.speakingFrameCount = 0

          let url = self.audioFile?.url
          self.audioFile = try? self.prepareAudioFile(suffix: "_mic")
          DispatchQueue.main.async {
            self.channel?.invokeMethod("onMicAudioFile", arguments: ["path": url?.path])
          }
        }
      }
    }

    do {
      try self.audioEngine?.start()
      completion(.success(()))
    } catch {
      completion(.failure(error))
    }
  }

  func turnOffMicRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine = nil
    audioFile = nil
    isSpeaking = false
    speakingFrameCount = 0
    silenceFrameCount = 0
    completion(.success(()))
  }

}

@available(macOS 13.0, *)
extension CMSampleBuffer {
  func toPCMBuffer() -> AVAudioPCMBuffer? {
    guard let formatDesc = CMSampleBufferGetFormatDescription(self),
      let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
    else { return nil }

    let format = AVAudioFormat(streamDescription: asbd)
    let frameCount = UInt32(CMSampleBufferGetNumSamples(self))

    guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: frameCount) else {
      return nil
    }
    pcmBuffer.frameLength = frameCount

    guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else { return nil }

    var dataPointer: UnsafeMutablePointer<Int8>?
    var totalLength = 0

    let status = CMBlockBufferGetDataPointer(
      blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength,
      dataPointerOut: &dataPointer)

    if status == noErr, let dataPointer = dataPointer {
      memcpy(pcmBuffer.audioBufferList.pointee.mBuffers.mData, dataPointer, totalLength)
      return pcmBuffer
    }
    return nil
  }
}
