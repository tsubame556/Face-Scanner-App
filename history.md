# Project History

## 2026-06-04
- **新規プロジェクト作成**: 独自3D頭部アバター生成パイプラインの構築を開始。
- **iOSアプリベース構築**: `ScannerApp_Swift/FaceCaptureViewController.swift` を作成。ARKitを用いたFaceID風スキャンUI、全方位アングル判定、環境光検知、ARFaceGeometry抽出ロジックを実装。
- **GPUバックエンドベース構築**: `core-backend/` ディレクトリを作成し、FastAPIベースの `main.py` および各種生成サービス（`arkit_mesh_processor.py`, `mouth_teeth_service.py`, `avatar_assembly_service.py`）の骨組み、`requirements.txt` を実装。
- **Git初期化**: プロジェクト全体の変更追跡のためGitリポジトリを初期化。
