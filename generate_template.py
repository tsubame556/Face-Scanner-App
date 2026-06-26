import os
import trimesh
import numpy as np
from pygltflib import GLTF2, BufferView, Accessor, ARRAY_BUFFER, FLOAT, VEC3

os.makedirs("core-backend/data/assets/base_model", exist_ok=True)

# 1. Generate base head using trimesh (a more detailed icosphere)
mesh = trimesh.creation.icosphere(subdivisions=3, radius=0.1)

temp_path = "core-backend/data/assets/base_model/temp_base.glb"
mesh.export(temp_path)

# 2. Add morph target using pygltflib
gltf = GLTF2().load(temp_path)
binary_data = bytearray(gltf.binary_blob())

vertices = mesh.vertices
target_deltas = np.zeros_like(vertices, dtype=np.float32)
for i, v in enumerate(vertices):
    if v[1] < -0.02: # mouth area
        target_deltas[i][1] = -0.05 # push down

delta_bytes = target_deltas.tobytes()

byte_offset = len(binary_data)
binary_data.extend(delta_bytes)

# We must align the buffer to 4 bytes
padding = (4 - (len(binary_data) % 4)) % 4
binary_data.extend(b'\x00' * padding)

buffer_view_idx = len(gltf.bufferViews)
gltf.bufferViews.append(BufferView(
    buffer=0,
    byteOffset=byte_offset,
    byteLength=len(delta_bytes),
))

accessor_idx = len(gltf.accessors)
gltf.accessors.append(Accessor(
    bufferView=buffer_view_idx,
    byteOffset=0,
    componentType=FLOAT,
    count=len(target_deltas),
    type=VEC3,
    min=[float(np.min(target_deltas[:, i])) for i in range(3)],
    max=[float(np.max(target_deltas[:, i])) for i in range(3)]
))

mesh_obj = gltf.meshes[0]
primitive = mesh_obj.primitives[0]
if primitive.targets is None:
    primitive.targets = []
primitive.targets.append({"POSITION": accessor_idx})

if mesh_obj.extras is None:
    mesh_obj.extras = {}
mesh_obj.extras["targetNames"] = ["jawOpen"]

gltf.set_binary_blob(bytes(binary_data))
gltf.buffers[0].byteLength = len(binary_data)
out_path = "core-backend/data/assets/base_model/template.glb"
gltf.save(out_path)

os.remove(temp_path)
print("Template GLB with jawOpen generated at", out_path)
