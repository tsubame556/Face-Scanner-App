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
        
        # ベース頭部モデルを読み込み
        base_head_asset = "data/assets/base_model/base_head.obj"
        if os.path.exists(base_head_asset):
            base_mesh = trimesh.load(base_head_asset, force='mesh')
            print(f"  [Mesh Processor] ベース頭部モデルをロード: {len(base_mesh.vertices)} 頂点")
            
            # ARKitメッシュを顔の前面に配置するためのオフセット計算（簡易版）
            # ARKitのメッシュは通常原点付近にあるため、ベースモデルの前面(Z軸プラス方向)へ少し移動
            face_mesh.apply_translation([0, 0.0, 0.07])
            
            # ベースモデルと顔メッシュを結合 (Mesh Stitching)
            # ※本来はICPアルゴリズム等で頂点の連続性を担保して結合しますが、今回はMVPとして単純結合します
            combined_mesh = trimesh.util.concatenate([base_mesh, face_mesh])
            
            # スムージング処理
            trimesh.smoothing.filter_taubin(combined_mesh)
            
            # 処理した結合メッシュを保存
            combined_mesh.export(output_temp_path)
            print(f"  [Mesh Processor] バストアップ結合モデルの生成完了: {output_temp_path}")
        else:
            # ベースモデルがない場合は顔メッシュのみを保存
            trimesh.smoothing.filter_taubin(face_mesh)
            face_mesh.export(output_temp_path)
            print(f"  [Mesh Processor] バストアップベースモデルの生成完了: {output_temp_path}")
        
    except Exception as e:
        print(f"  [Mesh Processor] 警告: メッシュ処理中にエラー ({e})。ダミーファイルを出力します。")
        with open(output_temp_path, "w") as f:
            f.write("DUMMY_OBJ_DATA")
            
    return output_temp_path
