import UIKit
import ARKit
import SceneKit

enum CaptureState {
    case initialization
    case angleScanning   // 顔をぐるっと回して全角度のデータを取るフェーズ
    case pronunciation   // 「あいうえお」を撮影するフェーズ
    case completed
}

// 顔の向くべき8方向（上、下、左、右、斜め4方向）
enum HeadDirection: Int, CaseIterable {
    case center = 0, up, down, left, right, upLeft, upRight, downLeft, downRight
}

class FaceCaptureViewController: UIViewController, ARSessionDelegate, ARSCNViewDelegate {

    // MARK: - UI Components
    private var sceneView: ARSCNView!
    private var instructionLabel: UILabel!
    private var warningLabel: UILabel!
    private var progressRing: ProgressRingView!
    private var pronunciationButton: UIButton!
    
    // MARK: - State
    private var currentState: CaptureState = .initialization
    private var currentFaceAnchor: ARFaceAnchor?
    
    // どの方向を向き終わったかのフラグ
    private var capturedDirections: Set<HeadDirection> = [.center]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupARSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard ARFaceTrackingConfiguration.isSupported else {
            warningLabel.text = "エラー: FaceID(TrueDepth)非対応端末です。"
            warningLabel.isHidden = false
            return
        }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        view.addSubview(sceneView)
        
        // 進捗リング（FaceID風の円形UI）
        let ringSize: CGFloat = 280
        progressRing = ProgressRingView(frame: CGRect(x: 0, y: 0, width: ringSize, height: ringSize))
        progressRing.center = view.center
        view.addSubview(progressRing)
        
        // 暗さ・影の警告ラベル（リングの上）
        warningLabel = UILabel()
        warningLabel.textColor = .systemYellow
        warningLabel.textAlignment = .center
        warningLabel.font = UIFont.boldSystemFont(ofSize: 16)
        warningLabel.numberOfLines = 2
        warningLabel.isHidden = true
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(warningLabel)
        
        // 指示ラベル（画面上部）
        instructionLabel = UILabel()
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.boldSystemFont(ofSize: 20)
        instructionLabel.numberOfLines = 0
        instructionLabel.text = "顔を円の中に入れてください"
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)
        
        // あいうえお撮影ボタン（最初は隠しておく）
        pronunciationButton = UIButton(type: .system)
        pronunciationButton.setTitle("「あいうえお」撮影開始", for: .normal)
        pronunciationButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        pronunciationButton.backgroundColor = .systemRed
        pronunciationButton.setTitleColor(.white, for: .normal)
        pronunciationButton.layer.cornerRadius = 25
        pronunciationButton.isHidden = true
        pronunciationButton.translatesAutoresizingMaskIntoConstraints = false
        pronunciationButton.addTarget(self, action: #selector(startPronunciationCapture), for: .touchUpInside)
        view.addSubview(pronunciationButton)
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            warningLabel.bottomAnchor.constraint(equalTo: progressRing.topAnchor, constant: -20),
            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            pronunciationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            pronunciationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pronunciationButton.widthAnchor.constraint(equalToConstant: 250),
            pronunciationButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupARSession() {
        currentState = .angleScanning
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 環境光のチェック
        checkLightingConditions(lightEstimate: frame.lightEstimate)
    }
    
    private func checkLightingConditions(lightEstimate: ARLightEstimate?) {
        guard let estimate = lightEstimate else { return }
        
        var warningText = ""
        
        // 部屋の明るさチェック (1000ルーメン以下は暗いと判定)
        if estimate.ambientIntensity < 800 {
            warningText += "部屋が暗すぎます。明るい場所へ移動してください。\n"
        }
        
        // 強い影（指向性ライト）のチェック
        if let directional = estimate as? ARDirectionalLightEstimate {
            // primaryLightIntensity が強すぎると顔の半分に影ができる
            if directional.primaryLightIntensity > 1500 {
                warningText += "顔に強い影が入っています。光の向きを調整してください。"
            }
        }
        
        DispatchQueue.main.async {
            self.warningLabel.text = warningText
            self.warningLabel.isHidden = warningText.isEmpty
        }
    }

    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor
        
        DispatchQueue.main.async {
            if self.currentState == .angleScanning {
                self.instructionLabel.text = "顔を円に沿ってゆっくり回してください"
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor
        
        if currentState == .angleScanning {
            processAngleScanning(transform: faceAnchor.transform)
        }
    }
    
    // MARK: - Angle Scanning Logic
    private func processAngleScanning(transform: simd_float4x4) {
        // TransformマトリックスからEuler角（Pitch, Yaw）を抽出
        let pitch = asin(max(-1.0, min(1.0, transform.columns.2.y))) // 上下
        let yaw = atan2(-transform.columns.2.x, transform.columns.2.z) // 左右
        
        // 角度（ラジアン）を度数法に変換
        let pitchDeg = pitch * 180 / .pi
        let yawDeg = yaw * 180 / .pi
        
        // しきい値（約20度顔を傾けたらクリアとする）
        let threshold: Float = 20.0
        
        var detectedDirection: HeadDirection = .center
        
        if pitchDeg > threshold {
            detectedDirection = yawDeg > threshold ? .downLeft : (yawDeg < -threshold ? .downRight : .down)
        } else if pitchDeg < -threshold {
            detectedDirection = yawDeg > threshold ? .upLeft : (yawDeg < -threshold ? .upRight : .up)
        } else {
            if yawDeg > threshold { detectedDirection = .left }
            else if yawDeg < -threshold { detectedDirection = .right }
        }
        
        if detectedDirection != .center && !capturedDirections.contains(detectedDirection) {
            capturedDirections.insert(detectedDirection)
            
            DispatchQueue.main.async {
                self.progressRing.updateProgress(for: detectedDirection)
                
                // 8方向すべて完了したか？ (centerを含めて9)
                if self.capturedDirections.count == HeadDirection.allCases.count {
                    self.scanningCompleted()
                }
            }
        }
    }
    
    private func scanningCompleted() {
        currentState = .pronunciation
        instructionLabel.text = "スキャン完了！\n次に「あいうえお」を撮影します。"
        progressRing.setCompleted()
        
        // 録画ボタンを表示
        UIView.animate(withDuration: 0.5) {
            self.pronunciationButton.isHidden = false
        }
    }

    // MARK: - Actions
    @objc private func startPronunciationCapture() {
        instructionLabel.text = "「あ、い、う、え、お」と\nゆっくりはっきり発音してください"
        pronunciationButton.setTitle("録画中... (タップで完了)", for: .normal)
        pronunciationButton.backgroundColor = .systemGray
        
        // TODO: ここでAVAssetWriterによる動画とDepthの保存を開始する
        // 今回のベース実装では、シミュレーションとして数秒後に自動で完了扱いにして送信処理へ移行します。
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.stopPronunciationCapture()
        }
    }
    
    private func stopPronunciationCapture() {
        instructionLabel.text = "撮影完了！サーバーへ送信中..."
        pronunciationButton.isHidden = true
        progressRing.isHidden = true
        
        // メッシュと動画(ダミー)をサーバーへ送信
        exportAndUploadData()
    }
    
    // MARK: - Network Upload
    private func exportAndUploadData() {
        guard let geometry = currentFaceAnchor?.geometry else {
            warningLabel.text = "メッシュデータが見つかりません"
            warningLabel.isHidden = false
            return
        }
        
        // 1. ARFaceGeometryをOBJ形式の文字列に変換
        var objData = ""
        for v in geometry.vertices {
            objData += "v \(v.x) \(v.y) \(v.z)\n"
        }
        for t in geometry.textureCoordinates {
            objData += "vt \(t.x) \(t.y)\n"
        }
        
        // indicesは[v1, v2, v3, v1, v2, v3...]の1次元配列
        let indices = geometry.triangleIndices
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i1 = indices[i] + 1
            let i2 = indices[i+1] + 1
            let i3 = indices[i+2] + 1
            // 法線(vn)は省略し、頂点(v)とテクスチャ座標(vt)のみを指定
            objData += "f \(i1)/\(i1) \(i2)/\(i2) \(i3)/\(i3)\n"
        }
        
        // 2. サーバーへ送信 (Multipart Form)
        let url = URL(string: "http://192.168.x.x:8000/api/v1/generate_avatar")! // 実際のGPUサーバーのIPに変更
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // メッシュデータ(OBJ)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"face_mesh_file\"; filename=\"face.obj\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        body.append(objData.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // 動画データ (ここではダミーバイト列)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pronunciation_video\"; filename=\"pronunciation.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append("DUMMY_VIDEO_DATA".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Blendshapes JSON (ここではダミーバイト列)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"blendshapes_json\"; filename=\"blendshapes.json\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append("{\"jawOpen\": 0.8}".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // 髪型ID
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"hairstyle_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("1\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.instructionLabel.text = "送信失敗: \(error.localizedDescription)"
                    return
                }
                self.instructionLabel.text = "送信成功！\nGPUサーバーで生成処理を開始しました。"
            }
        }
        task.resume()
    }
}

// MARK: - Custom UI View (進捗リング)
class ProgressRingView: UIView {
    
    private var segmentLayers: [HeadDirection: CAShapeLayer] = [:]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupRing()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupRing() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = bounds.width / 2 - 10
        let segmentAngle = (2 * CGFloat.pi) / 8.0
        let gap: CGFloat = 0.08 // セグメント間の隙間
        
        // 各方向に対応する中心角度 (0 は 3時の方向)
        let directionsMap: [(HeadDirection, CGFloat)] = [
            (.right, 0),
            (.downRight, .pi / 4),
            (.down, .pi / 2),
            (.downLeft, 3 * .pi / 4),
            (.left, .pi),
            (.upLeft, 5 * .pi / 4),
            (.up, 3 * .pi / 2),
            (.upRight, 7 * .pi / 4)
        ]
        
        for (direction, angle) in directionsMap {
            let startAngle = angle - segmentAngle / 2 + gap
            let endAngle = angle + segmentAngle / 2 - gap
            
            let path = UIBezierPath(arcCenter: center,
                                    radius: radius,
                                    startAngle: startAngle,
                                    endAngle: endAngle,
                                    clockwise: true)
            
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.darkGray.cgColor // 未取得はダークグレー
            layer.lineWidth = 15
            layer.lineCap = .round
            
            self.layer.addSublayer(layer)
            segmentLayers[direction] = layer
        }
    }
    
    func updateProgress(for direction: HeadDirection) {
        // 対象の方向を取得したら、その部分の円弧だけを緑色に変更する
        if let layer = segmentLayers[direction] {
            layer.strokeColor = UIColor.systemGreen.cgColor
        }
    }
    
    func setCompleted() {
        for layer in segmentLayers.values {
            layer.strokeColor = UIColor.systemGreen.cgColor
        }
        
        // 完了のポップアニメーション
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.transform = .identity
            }
        }
    }
}
