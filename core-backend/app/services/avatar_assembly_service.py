import os
import json
import numpy as np
import shutil
import cv2
import mediapipe as mp
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Attributes, Buffer, BufferView, Accessor,
    Material, Texture, TextureInfo, Image as GLTFImage, PbrMetallicRoughness,
    ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER, FLOAT, UNSIGNED_INT, VEC2, VEC3, SCALAR
)



def build_personalized_avatar(json_data_path: str, texture_path: str, hairstyle_id: int, output_glb_path: str):
    print(f"  [Avatar Assembly] JSONメッシュデータからGLBをフルビルドします: {json_data_path}")
    
    with open(json_data_path, 'r') as f:
        data = json.load(f)
        
    vertices = np.array(data["neutral_vertices"], dtype=np.float32)
    uvs = np.array(data["uvs"], dtype=np.float32)
    # ARKitのインデックスは三角形リスト
    indices = np.array(data["indices"], dtype=np.uint32)
    blendshapes = data.get("blendshapes", {})

    print("  [Avatar Assembly] iOSから送信された真のUV座標（カメラ投影マトリクス）を使用します")

    binary_data = bytearray()
    gltf = GLTF2()
    
    def add_buffer_view(data_bytes, target):
        offset = len(binary_data)
        binary_data.extend(data_bytes)
        padding = (4 - (len(binary_data) % 4)) % 4
        binary_data.extend(b'\x00' * padding)
        
        bv = BufferView(
            buffer=0,
            byteOffset=offset,
            byteLength=len(data_bytes),
            target=target
        )
        gltf.bufferViews.append(bv)
        return len(gltf.bufferViews) - 1
        
    # Vertices
    v_bytes = vertices.tobytes()
    v_bv = add_buffer_view(v_bytes, ARRAY_BUFFER)
    v_acc = Accessor(
        bufferView=v_bv,
        componentType=FLOAT,
        count=len(vertices),
        type=VEC3,
        min=vertices.min(axis=0).tolist(),
        max=vertices.max(axis=0).tolist()
    )
    gltf.accessors.append(v_acc)
    v_idx = len(gltf.accessors) - 1
    
    # UVs
    u_bytes = uvs.tobytes()
    u_bv = add_buffer_view(u_bytes, ARRAY_BUFFER)
    u_acc = Accessor(
        bufferView=u_bv,
        componentType=FLOAT,
        count=len(uvs),
        type=VEC2
    )
    gltf.accessors.append(u_acc)
    u_idx = len(gltf.accessors) - 1
    
    # Indices
    i_bytes = indices.tobytes()
    i_bv = add_buffer_view(i_bytes, ELEMENT_ARRAY_BUFFER)
    i_acc = Accessor(
        bufferView=i_bv,
        componentType=UNSIGNED_INT,
        count=len(indices),
        type=SCALAR
    )
    gltf.accessors.append(i_acc)
    i_idx = len(gltf.accessors) - 1
    
    primitive = Primitive(
        attributes=Attributes(POSITION=v_idx, TEXCOORD_0=u_idx),
        indices=i_idx,
        material=0
    )
    
    # Morph targets
    target_names = []
    targets = []
    for bs_name, bs_deltas in blendshapes.items():
        deltas = np.array(bs_deltas, dtype=np.float32)
        d_bytes = deltas.tobytes()
        d_bv = add_buffer_view(d_bytes, ARRAY_BUFFER)
        d_acc = Accessor(
            bufferView=d_bv,
            componentType=FLOAT,
            count=len(deltas),
            type=VEC3,
            min=deltas.min(axis=0).tolist(),
            max=deltas.max(axis=0).tolist()
        )
        gltf.accessors.append(d_acc)
        d_idx = len(gltf.accessors) - 1
        targets.append(Attributes(POSITION=d_idx))
        target_names.append(bs_name)
        
    if targets:
        primitive.targets = targets

    mesh = Mesh(primitives=[primitive], weights=[0.0] * len(targets))
    if target_names:
        mesh.extras = {"targetNames": target_names}
        
    gltf.meshes.append(mesh)
    gltf.nodes.append(Node(mesh=0))
    gltf.scenes.append(Scene(nodes=[0]))
    gltf.scene = 0
    
    # Material and Texture
    material = Material(
        pbrMetallicRoughness=PbrMetallicRoughness(
            metallicFactor=0.0,
            roughnessFactor=0.8,
        ),
        alphaMode="OPAQUE",
        doubleSided=True
    )
    
    if texture_path and os.path.exists(texture_path):
        with open(texture_path, 'rb') as f:
            img_bytes = f.read()
        img_bv = add_buffer_view(img_bytes, None)
        gltf.images.append(GLTFImage(bufferView=img_bv, mimeType="image/jpeg"))
        gltf.textures.append(Texture(source=0))
        material.pbrMetallicRoughness.baseColorTexture = TextureInfo(index=0)
        
    gltf.materials.append(material)
    
    gltf.buffers.append(Buffer(byteLength=len(binary_data)))
    gltf.set_binary_blob(bytes(binary_data))
    
    gltf.save(output_glb_path)
    print(f"  [Avatar Assembly] パーソナライズ完了！全52表情・テクスチャ対応GLBを生成しました: {output_glb_path}")

