import os
import trimesh
import numpy as np

def process_face_mesh(mesh_obj_path: str) -> str:
    """
    Step 1: iPhoneから送られた生の高精度メッシュ（ARFaceGeometry）を処理する。
    """
    print(f"  [Mesh Processor] 入力メッシュの解析: {mesh_obj_path}")
    
    output_temp_path = mesh_obj_path + "_base_head.obj"
    
    try:
        # ARKitのメッシュを読み込み
        face_mesh = trimesh.load(mesh_obj_path, force='mesh')
        print(f"  [Mesh Processor] メッシュロード成功: {len(face_mesh.vertices)} 頂点")
        
        # 新アーキテクチャ: テンプレート・マッピング方式のため、
        # ここでのTrimeshによる静的な結合（Stitching）は廃止します。
        # 代わりに、送られてきた生メッシュを軽くスムージングし、
        # 輪郭パラメータ抽出用のガイドデータとして後続のAssemblyへ渡します。
        trimesh.smoothing.filter_taubin(face_mesh)
        
        # 処理したガイドメッシュを保存
        face_mesh.export(output_temp_path)
        print(f"  [Mesh Processor] ガイド用顔面メッシュの最適化完了: {output_temp_path}")
        
    except Exception as e:
        print(f"  [Mesh Processor] 警告: メッシュ処理中にエラー ({e})。ダミーファイルを出力します。")
        with open(output_temp_path, "w") as f:
            f.write("DUMMY_OBJ_DATA")
            
    return output_temp_path
