import UIKit
import ARKit
import SceneKit

enum CaptureState {
    case initialization
    case angleScanning
    case pronunciation
    case processing
    case completed
}

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
    private var resendButton: UIButton!
    
    // MARK: - State
    private var currentState: CaptureState = .initialization
    private var currentFaceAnchor: ARFaceAnchor?
    private var capturedDirections: Set<HeadDirection> = [.center]
    
    // Data collection for median face
    private var vertexFrames = [[simd_float3]]()
    private var faceUVs = [simd_float2]()
    private var faceIndices = [Int16]()
    private var capturedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupARSession()
        checkSavedData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func appWillResignActive() {
        sceneView.session.pause()
    }
    
    @objc private func appDidBecomeActive() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDidBecomeActive()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appWillResignActive()
    }

    private func setupUI() {
        view.backgroundColor = .black
        
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        view.addSubview(sceneView)
        
        let ringSize: CGFloat = 280
        progressRing = ProgressRingView(frame: CGRect(x: 0, y: 0, width: ringSize, height: ringSize))
        progressRing.center = view.center
        view.addSubview(progressRing)
        
        warningLabel = UILabel()
        warningLabel.textColor = .systemYellow
        warningLabel.textAlignment = .center
        warningLabel.font = UIFont.boldSystemFont(ofSize: 16)
        warningLabel.numberOfLines = 2
        warningLabel.isHidden = true
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(warningLabel)
        
        instructionLabel = UILabel()
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.boldSystemFont(ofSize: 20)
        instructionLabel.numberOfLines = 0
        instructionLabel.text = "顔を円の中に入れてください"
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)
        
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
        
        resendButton = UIButton(type: .system)
        resendButton.setTitle("前回のデータを再送信", for: .normal)
        resendButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        resendButton.backgroundColor = .systemGreen
        resendButton.setTitleColor(.white, for: .normal)
        resendButton.layer.cornerRadius = 25
        resendButton.isHidden = true
        resendButton.translatesAutoresizingMaskIntoConstraints = false
        resendButton.addTarget(self, action: #selector(resendData), for: .touchUpInside)
        view.addSubview(resendButton)
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            warningLabel.bottomAnchor.constraint(equalTo: progressRing.topAnchor, constant: -20),
            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            pronunciationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            pronunciationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pronunciationButton.widthAnchor.constraint(equalToConstant: 250),
            pronunciationButton.heightAnchor.constraint(equalToConstant: 50),
            
            resendButton.bottomAnchor.constraint(equalTo: pronunciationButton.topAnchor, constant: -20),
            resendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resendButton.widthAnchor.constraint(equalToConstant: 250),
            resendButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    

    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func checkSavedData() {
        let jsonURL = getDocumentsDirectory().appendingPathComponent("saved_face_data.json")
        let imageURL = getDocumentsDirectory().appendingPathComponent("saved_texture.jpg")
        if FileManager.default.fileExists(atPath: jsonURL.path) && FileManager.default.fileExists(atPath: imageURL.path) {
            DispatchQueue.main.async {
                self.resendButton.isHidden = false
            }
        }
    }
    
    @objc private func resendData() {
        let jsonURL = getDocumentsDirectory().appendingPathComponent("saved_face_data.json")
        let imageURL = getDocumentsDirectory().appendingPathComponent("saved_texture.jpg")
        
        guard let jsonData = try? Data(contentsOf: jsonURL),
              let imageData = try? Data(contentsOf: imageURL) else {
            instructionLabel.text = "保存されたデータが見つかりません"
            return
        }
        
        instructionLabel.text = "再アップロード中..."
        resendButton.isHidden = true
        pronunciationButton.isEnabled = false
        uploadToServer(jsonData: jsonData, imageData: imageData)
    }

    private func setupARSession() {
        currentState = .angleScanning
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        checkLightingConditions(lightEstimate: frame.lightEstimate)
        
        if currentState == .pronunciation {
            // テクスチャ用の画像を取得しておく（ブレが少ない最初の数フレームなどで）
            if capturedImage == nil {
                capturedImage = convertPixelBufferToUIImage(pixelBuffer: frame.capturedImage)
                
                // 真のUV座標を計算（カメラ投影マトリクスを使用）
                if let faceAnchor = currentFaceAnchor {
                    let viewportSize = capturedImage!.size
                    let imageWidth = Float(viewportSize.width)
                    let imageHeight = Float(viewportSize.height)
                    
                    var newUVs = [simd_float2]()
                    
                    for vertex in faceAnchor.geometry.vertices {
                        // 1. ローカル座標をワールド座標に変換
                        let vertex4 = simd_float4(vertex.x, vertex.y, vertex.z, 1.0)
                        let worldPos4 = faceAnchor.transform * vertex4
                        let worldPos3 = simd_float3(worldPos4.x, worldPos4.y, worldPos4.z)
                        
                        // 2. カメラのレンズ情報を用いて2Dピクセル座標へ投影
                        let projected = frame.camera.projectPoint(worldPos3, orientation: .landscapeRight, viewportSize: viewportSize)
                        
                        // 3. 0.0〜1.0のUV座標に正規化
                        let u = Float(projected.x) / imageWidth
                        let v = Float(projected.y) / imageHeight
                        newUVs.append(simd_float2(u, v))
                    }
                    self.faceUVs = newUVs
                }
            }
        }
    }
    
    private func convertPixelBufferToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        // フロントカメラは右に90度回転しているので、upに変えることで正しい向きに
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
    }

    private func checkLightingConditions(lightEstimate: ARLightEstimate?) {
        guard let estimate = lightEstimate else { return }
        var warningText = ""
        if estimate.ambientIntensity < 800 {
            warningText += "部屋が暗すぎます。明るい場所へ移動してください。\n"
        }
        if let directional = estimate as? ARDirectionalLightEstimate {
            if directional.primaryLightIntensity > 1500 {
                warningText += "顔に強い影が入っています。光の向きを調整してください。"
            }
        }
        DispatchQueue.main.async {
            self.warningLabel.text = warningText
            self.warningLabel.isHidden = warningText.isEmpty
        }
    }

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
        } else if currentState == .pronunciation {
            // 毎フレームの頂点を記録する
            let vertices = Array(faceAnchor.geometry.vertices)
            vertexFrames.append(vertices)
            
            // 初回にインデックスを記録
            if faceIndices.isEmpty {
                faceIndices = Array(faceAnchor.geometry.triangleIndices)
            }
        }
    }
    
    private func processAngleScanning(transform: simd_float4x4) {
        let pitch = asin(max(-1.0, min(1.0, transform.columns.2.y)))
        let yaw = atan2(-transform.columns.2.x, transform.columns.2.z)
        let pitchDeg = pitch * 180 / .pi
        let yawDeg = yaw * 180 / .pi
        
        var detectedDirection: HeadDirection = .center
        let tiltDistance = sqrt(pitchDeg * pitchDeg + yawDeg * yawDeg)
        
        if tiltDistance > 15.0 {
            let angle = atan2(pitchDeg, yawDeg)
            var sector = Int(round(angle / (.pi / 4)))
            if sector < 0 { sector += 8 }
            switch sector {
            case 0: detectedDirection = .left
            case 1: detectedDirection = .downLeft
            case 2: detectedDirection = .down
            case 3: detectedDirection = .downRight
            case 4: detectedDirection = .right
            case 5: detectedDirection = .upRight
            case 6: detectedDirection = .up
            case 7: detectedDirection = .upLeft
            default: break
            }
        }
        
        if detectedDirection != .center && !capturedDirections.contains(detectedDirection) {
            capturedDirections.insert(detectedDirection)
            DispatchQueue.main.async {
                self.progressRing.updateProgress(for: detectedDirection)
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
        UIView.animate(withDuration: 0.5) {
            self.pronunciationButton.isHidden = false
        }
    }

    @objc private func startPronunciationCapture() {
        currentState = .pronunciation
        vertexFrames.removeAll()
        capturedImage = nil
        
        instructionLabel.text = "「あ、い、う、え、お」と\nゆっくりはっきり発音してください"
        pronunciationButton.setTitle("録画中...", for: .normal)
        pronunciationButton.backgroundColor = .systemGray
        pronunciationButton.isUserInteractionEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.stopPronunciationCapture()
        }
    }
    
    private func stopPronunciationCapture() {
        currentState = .processing
        instructionLabel.text = "撮影完了！顔の中央値を計算中..."
        pronunciationButton.isHidden = true
        progressRing.isHidden = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.processAndUploadData()
        }
    }
    
    private func processAndUploadData() {
        // 1. 中央値（ニュートラル顔）の計算
        let medianVertices = calculateMedianVertices()
        
        // 2. 52個のBlendshape Deltasの抽出
        let blendshapes = generateBlendshapeDeltas()
        
        // 3. JSON文字列の生成
        var jsonDict = [String: Any]()
        
        // 頂点配列の変換
        let vertsArray = medianVertices.map { [$0.x, $0.y, $0.z] }
        jsonDict["neutral_vertices"] = vertsArray
        
        // UV配列の変換
        let uvsArray = faceUVs.map { [$0.x, $0.y] }
        jsonDict["uvs"] = uvsArray
        
        // インデックス配列の変換
        jsonDict["indices"] = faceIndices
        jsonDict["blendshapes"] = blendshapes
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: []) else {
            DispatchQueue.main.async {
                self.instructionLabel.text = "JSON生成エラー"
            }
            return
        }
        
        // 4. 画像データの取得
        guard let image = capturedImage, let imageData = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async {
                self.instructionLabel.text = "画像取得エラー"
            }
            return
        }
        
        // 5. 送信

        let jsonURL = getDocumentsDirectory().appendingPathComponent("saved_face_data.json")
        let imageURL = getDocumentsDirectory().appendingPathComponent("saved_texture.jpg")
        try? jsonData.write(to: jsonURL)
        try? imageData.write(to: imageURL)
        
        DispatchQueue.main.async {
            self.instructionLabel.text = "サーバーへアップロード中..."
            self.resendButton.isHidden = true
        }

        
        uploadToServer(jsonData: jsonData, imageData: imageData)
    }
    
    private func calculateMedianVertices() -> [simd_float3] {
        guard !vertexFrames.isEmpty else { return [] }
        let vertexCount = vertexFrames[0].count
        var medianVertices = [simd_float3]()
        medianVertices.reserveCapacity(vertexCount)
        
        for i in 0..<vertexCount {
            var xVals = [Float](); xVals.reserveCapacity(vertexFrames.count)
            var yVals = [Float](); yVals.reserveCapacity(vertexFrames.count)
            var zVals = [Float](); zVals.reserveCapacity(vertexFrames.count)
            
            for frame in vertexFrames {
                xVals.append(frame[i].x)
                yVals.append(frame[i].y)
                zVals.append(frame[i].z)
            }
            
            xVals.sort()
            yVals.sort()
            zVals.sort()
            
            let mid = vertexFrames.count / 2
            let median = simd_float3(xVals[mid], yVals[mid], zVals[mid])
            medianVertices.append(median)
        }
        return medianVertices
    }
    
    private func generateBlendshapeDeltas() -> [String: [[Float]]] {
        let allLocations: [ARFaceAnchor.BlendShapeLocation] = [
            .browDownLeft, .browDownRight, .browInnerUp, .browOuterUpLeft, .browOuterUpRight,
            .cheekPuff, .cheekSquintLeft, .cheekSquintRight,
            .eyeBlinkLeft, .eyeBlinkRight, .eyeLookDownLeft, .eyeLookDownRight, .eyeLookInLeft, .eyeLookInRight,
            .eyeLookOutLeft, .eyeLookOutRight, .eyeLookUpLeft, .eyeLookUpRight, .eyeSquintLeft, .eyeSquintRight, .eyeWideLeft, .eyeWideRight,
            .jawForward, .jawLeft, .jawOpen, .jawRight,
            .mouthClose, .mouthDimpleLeft, .mouthDimpleRight, .mouthFrownLeft, .mouthFrownRight, .mouthFunnel,
            .mouthLeft, .mouthLowerDownLeft, .mouthLowerDownRight, .mouthPressLeft, .mouthPressRight, .mouthPucker,
            .mouthRight, .mouthRollLower, .mouthRollUpper, .mouthShrugLower, .mouthShrugUpper, .mouthSmileLeft, .mouthSmileRight,
            .mouthStretchLeft, .mouthStretchRight, .mouthUpperUpLeft, .mouthUpperUpRight,
            .noseSneerLeft, .noseSneerRight, .tongueOut
        ]
        
        guard let defaultGeometry = ARFaceGeometry(blendShapes: [:]) else { return [:] }
        
        var dict = [String: [[Float]]]()
        
        for loc in allLocations {
            if let geo = ARFaceGeometry(blendShapes: [loc: 1.0]) {
                var deltas = [[Float]]()
                deltas.reserveCapacity(geo.vertices.count)
                for i in 0..<geo.vertices.count {
                    let v1 = geo.vertices[i]
                    let v0 = defaultGeometry.vertices[i]
                    deltas.append([v1.x - v0.x, v1.y - v0.y, v1.z - v0.z])
                }
                dict[loc.rawValue] = deltas
            }
        }
        return dict
    }
    
    private func uploadToServer(jsonData: Data, imageData: Data) {
        let url = URL(string: "https://monster-ancient-tried-boundaries.trycloudflare.com/api/v1/generate_avatar")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // JSON
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"face_mesh_file\"; filename=\"face_data.json\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(jsonData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 画像
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"face_texture_file\"; filename=\"texture.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 髪型ID
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"hairstyle_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("1\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.instructionLabel.text = "送信失敗: サーバーに接続できません"
                    self.resendButton.isHidden = false
                    self.pronunciationButton.isEnabled = true
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.instructionLabel.text = "送信失敗: サーバーエラー (\(httpResponse.statusCode))"
                    return
                }
                self.instructionLabel.text = "送信成功！\nフルアバター生成を開始しました。"
            }
        }
        task.resume()
    }
}

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
        let gap: CGFloat = 0.08
        
        let directionsMap: [(HeadDirection, CGFloat)] = [
            (.right, 0), (.downRight, .pi / 4), (.down, .pi / 2), (.downLeft, 3 * .pi / 4),
            (.left, .pi), (.upLeft, 5 * .pi / 4), (.up, 3 * .pi / 2), (.upRight, 7 * .pi / 4)
        ]
        
        for (direction, angle) in directionsMap {
            let startAngle = angle - segmentAngle / 2 + gap
            let endAngle = angle + segmentAngle / 2 - gap
            let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.darkGray.cgColor
            layer.lineWidth = 15
            layer.lineCap = .round
            self.layer.addSublayer(layer)
            segmentLayers[direction] = layer
        }
    }
    
    func updateProgress(for direction: HeadDirection) {
        if let layer = segmentLayers[direction] {
            layer.strokeColor = UIColor.systemGreen.cgColor
        }
    }
    
    func setCompleted() {
        for layer in segmentLayers.values {
            layer.strokeColor = UIColor.systemGreen.cgColor
        }
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.transform = .identity
            }
        }
    }
}
