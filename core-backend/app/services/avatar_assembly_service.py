import os
import trimesh
import pygltflib
import struct
import numpy as np
import shutil

def assemble_avatar(base_head_path: str, teeth_model_path: str, hairstyle_id: int, output_glb_path: str):
    """
    Step 3 (New Architecture): テンプレート・マッピング方式
    - 事前定義された表情（Blendshapes）付きテンプレートGLBを読み込む。
    - iPhoneから取得した顔面メッシュ（base_head_path）の輪郭・サイズを解析する。
    - テンプレートモデルをそのサイズに合わせて変形（Morph）し、パーソナライズする。
    - Blendshapesを破壊せずにGLBとして出力する。
    """
    print(f"  [Avatar Assembly] ガイドメッシュ({base_head_path})から輪郭を解析し、テンプレートを変形します")
    
    template_glb_path = "data/assets/base_model/template.glb"
    if not os.path.exists(template_glb_path):
        print("  [Avatar Assembly] テンプレートGLBが見つからないため、ダミー処理に移行します。")
        with open(output_glb_path, "w") as f: f.write("ERROR")
        return
        
    try:
        # 1. お客様の顔のサイズ（Bounding Box）を取得
        guide_mesh = trimesh.load(base_head_path, force='mesh')
        guide_extents = guide_mesh.extents
        
        # 2. テンプレートGLBのロード
        gltf = pygltflib.GLTF2().load(template_glb_path)
        binary_data = bytearray(gltf.binary_blob())
        
        # 3. テンプレートの頂点データ(POSITION)を取得して書き換える
        pos_accessor_idx = gltf.meshes[0].primitives[0].attributes.POSITION
        pos_accessor = gltf.accessors[pos_accessor_idx]
        buffer_view = gltf.bufferViews[pos_accessor.bufferView]
        
        start = buffer_view.byteOffset + pos_accessor.byteOffset
        count = pos_accessor.count
        
        vertices = []
        for i in range(count):
            offset = start + i * 12
            x, y, z = struct.unpack('<fff', binary_data[offset:offset+12])
            vertices.append([x, y, z])
            
        temp_vertices = np.array(vertices)
        temp_extents = temp_vertices.max(axis=0) - temp_vertices.min(axis=0)
        
        # 4. スケール計算（ガイドメッシュのサイズに合わせる）
        scale_x = guide_extents[0] / temp_extents[0] if temp_extents[0] > 0 else 1.0
        scale_y = guide_extents[1] / temp_extents[1] if temp_extents[1] > 0 else 1.0
        scale_z = guide_extents[2] / temp_extents[2] if temp_extents[2] > 0 else 1.0
        
        for i in range(count):
            vertices[i][0] *= scale_x
            vertices[i][1] *= scale_y
            vertices[i][2] *= scale_z
            offset = start + i * 12
            binary_data[offset:offset+12] = struct.pack('<fff', *vertices[i])
            
        # バイナリデータを更新
        gltf.set_binary_blob(bytes(binary_data))
        
        # 保存
        gltf.save(output_glb_path)
        print(f"  [Avatar Assembly] パーソナライズ完了！表情対応GLBを生成しました: {output_glb_path}")
        
    except Exception as e:
        print(f"  [Avatar Assembly] 警告: 変形処理中にエラー ({e})。そのままテンプレートを出力します。")
        shutil.copy2(template_glb_path, output_glb_path)
