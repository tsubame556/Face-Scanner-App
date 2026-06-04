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
