import AVFoundation
import Accelerate
import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import Speech

public class AudioToolkitPlugin: NSObject, FlutterPlugin {
  var systemRecorder: AnyObject?
  var micRecorder: AnyObject?

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
      instance.micRecorder = MicAudioRecorder(channel: channel)

      registrar.addMethodCallDelegate(instance, channel: channel)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if #available(macOS 13.0, *) {

      if self.systemRecorder == nil {
        self.systemRecorder = SystemAudioRecorder(channel: channel)
      }

      if self.micRecorder == nil {
        self.micRecorder = SystemAudioRecorder(channel: channel)
      }

      guard let systemRecorder = systemRecorder as? SystemAudioRecorder else {
        result(["result": "false", "errorMessage": "Không khởi tạo được recorder"])
        return
      }

      guard let micRecorder = micRecorder as? MicAudioRecorder else {
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
      case "startMicRecording":
        if self.isMicRecording {
          result(["result": "true", "status": true])
          self.isMicRecording = true
          return
        }
        Task {
          await micRecorder.startMicRecording { resultCallback in
            switch resultCallback {
            case .success:
              result(["result": "true"])
              self.isMicRecording = true
            case .failure(let error):
              result(["result": "false", "errorMessage": error.localizedDescription])
            }
          }
        }
        break
      case "stopMicRecording":
        Task {
          await micRecorder.stopMicRecording { resultCallback in
            switch resultCallback {
            case .success:
              result(["result": "true"])
              self.isMicRecording = false
            case .failure(let error):
              result(["result": "false", "errorMessage": error.localizedDescription])
            }
          }
        }
        break
      case "startSystemRecording":
        if self.isSystemRecording {
          result(["result": "true", "status": true])
          return
        }
        Task {
          await systemRecorder.startSystemRecording { resultCallback in
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
      case "stopSystemRecording":
        Task {
          await systemRecorder.stopSystemRecording { resultCallback in
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
        if let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        {

          let language = args["language"] as? String ?? "vi-VN"
          let url = URL(fileURLWithPath: path)

          Task {
            await systemRecorder
              .transcribeAudio(url: url, language: language) { transcription in
                if let text = transcription {
                  result(["result": "true", "text": text])
                } else {
                  result(["result": "false", "errorMessage": "Không thể nhận diện âm thanh"])
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
  var audioSettings: [String: Any] = [:]
  var selectedFormat: AudioFormat = .aac
  var filter: SCContentFilter?
  var startTime: Date?
  var speakingFrameCount: Int = 0

  func initRecording(completion: @escaping (Result<Void, Error>) -> Void) {

    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
      [weak self] content, error in
      guard let self = self else { return }

      if let error = error {
        completion(.failure(error))
        return
      }

      guard let display = content?.displays.first else {
        let screenError = NSError(
          domain: "SystemAudioRecorder",
          code: 404,
          userInfo: [
            NSLocalizedDescriptionKey: "Không tìm thấy màn hình hoặc chưa cấp quyền ghi màn hình"
          ])
        completion(.failure(screenError))
        return
      }

      self.filter = SCContentFilter(
        display: display, excludingApplications: [], exceptingWindows: [])
      completion(.success(()))
    }
  }
  func startSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    guard let filter = self.filter else {
      let screenError = NSError(
        domain: "SystemAudioRecorder",
        code: 404,
        userInfo: [
          NSLocalizedDescriptionKey: "Gọi startSystemRecording mà chưa initRecording trước đó"
        ])
      completion(.failure(screenError))
      return
    }

    // 3. Chuẩn bị và bắt đầu stream
    self.prepareAudioSettings()
    self.prepareAudioFile()

    Task {
      await self.startSCStream(filter: filter)
    }

    completion(.success(()))
  }

  // func startSystemRecording(language: String, completion: @escaping (Result<Void, Error>) -> Void) {
  //   SFSpeechRecognizer.requestAuthorization { authStatus in
  //     DispatchQueue.main.async {
  //       switch authStatus {
  //       case .authorized:
  //         print("✅ Đã được cấp quyền")

  //         self.transcribeLanguage = language

  //         guard let filter = self.filter else {
  //           let screenError = NSError(
  //             domain: "SystemAudioRecorder",
  //             code: 404,
  //             userInfo: [
  //               NSLocalizedDescriptionKey: "Gọi startSystemRecording mà chưa initRecording trước đó"
  //             ])
  //           completion(.failure(screenError))
  //           return
  //         }

  //         // 3. Chuẩn bị và bắt đầu stream
  //         self.prepareAudioSettings()
  //         self.prepareAudioFile()

  //         Task {
  //           await self.startSCStream(filter: filter)
  //         }

  //         completion(.success(()))

  //       case .denied:
  //         completion(
  //           .failure(
  //             NSError(
  //               domain: "SystemAudioRecorder",
  //               code: 401,
  //               userInfo: [
  //                 NSLocalizedDescriptionKey: "Người dùng từ chối quyền sử dụng Speech Recognition"
  //               ]
  //             )
  //           ))

  //       case .restricted:
  //         completion(
  //           .failure(
  //             NSError(
  //               domain: "SystemAudioRecorder",
  //               code: 402,
  //               userInfo: [NSLocalizedDescriptionKey: "Thiết bị không hỗ trợ Speech Recognition"]
  //             )
  //           ))

  //       case .notDetermined:
  //         completion(
  //           .failure(
  //             NSError(
  //               domain: "SystemAudioRecorder",
  //               code: 403,
  //               userInfo: [NSLocalizedDescriptionKey: "Quyền Speech Recognition chưa được yêu cầu"]
  //             )
  //           ))

  //       @unknown default:
  //         completion(
  //           .failure(
  //             NSError(
  //               domain: "SystemAudioRecorder",
  //               code: 500,
  //               userInfo: [NSLocalizedDescriptionKey: "Trạng thái quyền không xác định"]
  //             )
  //           ))
  //       }
  //     }
  //   }
  // }

  func stopSystemRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
    Task {
      do {
        try await stream?.stopCapture()
        stream = nil
        audioFile = nil
        completion(.success(()))
      } catch {
        let screenError = NSError(
          domain: "SystemAudioRecorder",
          code: 404,
          userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription
          ])
        completion(.failure(screenError))
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

  private func prepareAudioFile() {
    let fileExt: String
    switch selectedFormat {
    case .aac: fileExt = "m4a"
    case .alac: fileExt = "caf"
    case .flac: fileExt = "flac"
    case .opus: fileExt = "ogg"
    }

    let fileName = "recording_\(Int(Date().timeIntervalSince1970)).\(fileExt)"
    if let downloadDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
      .first
    {
      let url = downloadDir.appendingPathComponent(fileName)
      do {
        audioFile = try AVAudioFile(forWriting: url, settings: audioSettings)
      } catch {
        print("❌ Lỗi tạo file ghi: \(error)")
      }
    }
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
    guard outputType == .audio, let file = audioFile else { return }

    if let pcmBuffer = sampleBuffer.toPCMBuffer() {

      do {
        let db: Float = self.calculateDB(from: pcmBuffer)
        DispatchQueue.main.async {
          self.channel?.invokeMethod("db", arguments: String(db))
        }

        if db > -90 {
          if !isSpeaking {
            isSpeaking = true
            startTime = Date()
            speakingFrameCount = 0
          }
          speakingFrameCount += 1

          try file.write(from: pcmBuffer)

          if let start = startTime,
            Date().timeIntervalSince(start) >= 2.0
          {

            if speakingFrameCount >= 10 {
              let url = file.url
              self.audioFile = nil
              prepareAudioFile()
              self.channel?.invokeMethod(
                "onSentenceDetected",
                arguments: ["path": url.path]
              )

            } else {
              print("🛑 Bỏ đoạn vì không đủ nội dung âm thanh")
            }

            isSpeaking = false
          }

        } else {
          isSpeaking = false
          speakingFrameCount = 0
        }

      } catch {
        print("❌ Ghi vào file lỗi: \(error)")
      }
    }
  }

  func transcribeAudio(
    url: URL, language: String = "vi-VN", completion: @escaping (String?) -> Void
  ) {
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))

    guard let recognizer = recognizer, recognizer.isAvailable else {
      completion(nil)
      return
    }

    let request = SFSpeechURLRecognitionRequest(url: url)
    recognizer.recognitionTask(with: request) { result, error in
      if let result = result, result.isFinal {
        completion(result.bestTranscription.formattedString)
      } else if let error = error {
        print("❌ Lỗi nhận diện: \(error.localizedDescription)")
        completion(nil)
      }
    }
  }

  func calculateDB(from buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData?[0] else { return -160 }
    let frameLength = Int(buffer.frameLength)
    var rms: Float = 0
    vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
    let avgPower = 20 * log10(rms)
    return avgPower.isFinite ? avgPower : -160
  }
}

@available(macOS 13.0, *)
class MicAudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput {

  var channel: FlutterMethodChannel?

  init(channel: FlutterMethodChannel?) {
    self.channel = channel
  }

  var micEngine: AVAudioEngine?
  var micInputNode: AVAudioInputNode?
  var micFormat: AVAudioFormat?
  var micAudioFile: AVAudioFile?
  var isSpeaking = false
  var startTime: Date?
  var speakingFrameCount: Int = 0

  func startMicRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
    micEngine = AVAudioEngine()
    guard let micEngine = micEngine else {
      completion(
        .failure(
          NSError(
            domain: "MicEngine", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Không tạo được AVAudioEngine"])))
      return
    }

    micInputNode = micEngine.inputNode
    guard let inputNode = micInputNode else {
      completion(
        .failure(
          NSError(
            domain: "MicEngine", code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Không truy cập được mic input"])))
      return
    }

    micFormat = inputNode.inputFormat(forBus: 0)
    prepareMicAudioFile()

    isSpeaking = false
    speakingFrameCount = 0
    startTime = nil

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: micFormat) { [weak self] buffer, _ in
      guard let self = self, let file = self.micAudioFile else { return }

      let db = self.calculateDB(from: buffer)
      DispatchQueue.main.async {
        self.channel?.invokeMethod("db", arguments: String(db))
      }

      do {
        if db > -75 {
          if !isSpeaking {
            isSpeaking = true
            startTime = Date()
            speakingFrameCount = 0
          }
          speakingFrameCount += 1

          try file.write(from: buffer)

          if let start = startTime,
            Date().timeIntervalSince(start) >= 2.0,
            speakingFrameCount >= 10
          {
            let url = file.url
            self.micAudioFile = nil
            self.prepareMicAudioFile()

            self.channel?.invokeMethod("onSentenceDetected", arguments: ["path": url.path])
            isSpeaking = false
          }

        } else {
          isSpeaking = false
          speakingFrameCount = 0
        }

      } catch {
        print("❌ Ghi mic vào file lỗi: \(error)")
      }
    }

    do {
      try micEngine.start()
      completion(.success(()))
    } catch {
      completion(.failure(error))
    }
  }

  func stopMicRecording(completion: @escaping (Result<Void, Error>) -> Void) async {
    micInputNode?.removeTap(onBus: 0)
    micEngine?.stop()
    micAudioFile = nil
    completion(.success(()))
  }

  private func prepareMicAudioFile() {
    guard let format = micFormat else { return }

    let fileName = "mic_\(Int(Date().timeIntervalSince1970)).m4a"
    if let downloadDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
      .first
    {
      let url = downloadDir.appendingPathComponent(fileName)
      do {
        micAudioFile = try AVAudioFile(forWriting: url, settings: format.settings)
      } catch {
        print("❌ Lỗi tạo file mic audio: \(error)")
      }
    }
  }
  func calculateDB(from buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData?[0] else { return -160 }
    let frameLength = Int(buffer.frameLength)
    var rms: Float = 0
    vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
    let avgPower = 20 * log10(rms)
    return avgPower.isFinite ? avgPower : -160
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
