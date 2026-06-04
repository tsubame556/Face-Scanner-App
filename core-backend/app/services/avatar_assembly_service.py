import os
import trimesh

def assemble_avatar(base_head_path: str, teeth_model_path: str, hairstyle_id: int, output_glb_path: str):
    """
    Step 3: ベースの頭部メッシュ、独自生成された歯メッシュ、および選択された髪型モデルを結合し、
    最終的なバストアップモデルのGLBファイルを出力する。
    """
    print(f"  [Avatar Assembly] 頭部({base_head_path})と歯({teeth_model_path})をロードします")
    
    hair_asset_path = f"data/assets/hair/hair_{hairstyle_id}.glb"
    print(f"  [Avatar Assembly] 髪型アセットを適用: {hair_asset_path}")
    
    try:
        # 1. 結合済みの頭部メッシュ（ベース＋ARKit顔面）をロード
        if os.path.exists(base_head_path):
            head_mesh = trimesh.load(base_head_path, force='mesh')
        else:
            raise FileNotFoundError(f"頭部メッシュが見つかりません: {base_head_path}")
            
        # 肌色の仮マテリアル（単色）を適用する
        # ※本来はカメラ画像から生成したテクスチャをUVマッピングします
        if hasattr(head_mesh.visual, 'face_colors'):
            head_mesh.visual.face_colors = [255, 220, 177, 255] # 肌色
        
        # 2. 歯モデルをロードまたは生成
        if os.path.exists(teeth_model_path):
            teeth_mesh = trimesh.load(teeth_model_path, force='mesh')
        else:
            teeth_mesh = trimesh.creation.box(extents=[0.04, 0.01, 0.02])
        # 歯を適切な位置（口内）へオフセット
        teeth_mesh.apply_translation([0, 0.02, 0.05])
        
        # 3. 髪型アセットをロード
        if os.path.exists(hair_asset_path):
            hair_mesh = trimesh.load(hair_asset_path, force='mesh')
        else:
            hair_mesh = trimesh.creation.capsule(radius=0.1, height=0.2)
            hair_mesh.apply_translation([0, 0.1, 0])
            
        # 複数のメッシュをTrimeshのSceneに追加して結合
        scene = trimesh.Scene([head_mesh, teeth_mesh, hair_mesh])
        
        # GLB形式で出力
        scene.export(output_glb_path)
        print(f"  [Avatar Assembly] 結合完了！GLBファイルを生成しました: {output_glb_path}")
        
    except Exception as e:
        print(f"  [Avatar Assembly] 警告: 結合処理中にエラー ({e})。空のファイルを生成します。")
        with open(output_glb_path, "w") as f:
            f.write("ERROR_GLB")
