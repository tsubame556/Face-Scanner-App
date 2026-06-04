# Project History

## 2026-06-04
- **新規プロジェクト作成**: 独自3D頭部アバター生成パイプラインの構築を開始。
- **iOSアプリベース構築**: `ScannerApp_Swift/FaceCaptureViewController.swift` を作成。ARKitを用いたFaceID風スキャンUI、全方位アングル判定、環境光検知、ARFaceGeometry抽出ロジックを実装。
- **GPUバックエンドベース構築**: `core-backend/` ディレクトリを作成し、FastAPIベースの `main.py` および各種生成サービス（`arkit_mesh_processor.py`, `mouth_teeth_service.py`, `avatar_assembly_service.py`）の骨組み、`requirements.txt` を実装。
- **Git初期化**: プロジェクト全体の変更追跡のためGitリポジトリを初期化。

## 2026-06-04 (Update)
- **iOS通信処理実装**: `FaceCaptureViewController.swift` にて、取得したARFaceGeometryを.obj文字列に変換し、発音動画・BlendshapeログとともにFastAPIへ送信する `URLSession` のMultipartアップロードロジックを追加。
- **Pythonバックエンド処理実装**: 
  - `arkit_mesh_processor.py`: `trimesh` を用いたARKit顔メッシュの読み込みとスムージング処理（将来の胸像Stitching用ベース）を実装。
  - `mouth_teeth_service.py`: `cv2` (OpenCV) を用いた動画からの最大開口フレーム(`jawOpen`)の抽出と、歯メッシュのスケーリングシミュレーションを実装。
  - `avatar_assembly_service.py`: `trimesh.Scene` を用いて頭部・歯・髪型の3Dパーツを結合し、最終的な `.glb` を出力するアセンブリロジックを実装。

## 2026-06-04 (Update 2)
- **Unity GLBダウンロード処理**: `AvatarFetcher.cs` を新規作成し、GPUバックエンドから生成完了したGLBファイルを非同期でダウンロードし、`UniGLTF` (既存パッケージ) を用いてランタイムでシーン上にロード・インスタンス化する処理を実装。

## 2026-06-04 (Update 3)
- **UI改修**: iPhoneスキャン時のUIを改良。単一の破線リングから、8方向に分割されたセグメントUIに変更し、取得完了した角度のパーツだけが緑色に変わる仕様を実装。

## 2026-06-04 (Update 4)
- **UI/UX改修**: 顔の向き判定（角度スキャン）のアルゴリズムを、X/Y軸のしきい値判定から、放射状（Radial）の角度計算ベースに変更。これにより、斜め方向（右下、左下など）の判定が劇的にスムーズになった。

## 2026-06-04 (Update 5)
- **バグ修正**: バックグラウンド移行時のARKit/Metalに起因するクラッシュ（IOGPUMetalError）を防ぐため、アプリのライフサイクル監視を追加。

## 2026-06-04 (Update 6)
- **設定変更**: iOSアプリの送信先URLをMacの実際のローカルIP（10.46.3.210）に変更。

## 2026-06-04 (Update 7)
- **設定変更**: iOSアプリからMacへの通信URLをIPアドレス（10.46.3.210）からBonjourホスト名（yamamotokyousoranonotobukkukonpyuta.local）に変更。Wi-Fiの隔離設定を回避し、USBケーブル経由でも通信できるように修正。

## 2026-06-04 (Update 8)
- **ドキュメント作成**: README.mdを作成し、全体の処理フローと独自開発の切り分けを文書化。

## 2026-06-04 (Update 9)
- **API追加**: FastAPIバックエンドにGLBファイルのダウンロード用エンドポイント（/api/v1/download/{job_id}）を追加。
- **Unity設定変更**: AvatarFetcherの接続先をlocalhostに変更。

## 2026-06-04 (Update 10)
- **Unity改修**: AvatarFetcherにStart()メソッドを追加し、Job IDが入力されていればPlayボタン押下時に自動でダウンロードが始まるように修正。
