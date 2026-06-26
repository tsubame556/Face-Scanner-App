import pygltflib
import struct

gltf = pygltflib.GLTF2().load("core-backend/data/assets/base_model/template.glb")
binary_data = bytearray(gltf.binary_blob())

# Get POSITION accessor
pos_accessor_idx = gltf.meshes[0].primitives[0].attributes.POSITION
pos_accessor = gltf.accessors[pos_accessor_idx]
buffer_view = gltf.bufferViews[pos_accessor.bufferView]

start = buffer_view.byteOffset + pos_accessor.byteOffset
count = pos_accessor.count

# Unpack vertices
vertices = []
for i in range(count):
    offset = start + i * 12
    x, y, z = struct.unpack('<fff', binary_data[offset:offset+12])
    vertices.append([x, y, z])

# Scale by 1.2
for i in range(count):
    vertices[i][0] *= 1.2
    vertices[i][1] *= 1.2
    vertices[i][2] *= 1.2
    
# Pack back
for i in range(count):
    offset = start + i * 12
    binary_data[offset:offset+12] = struct.pack('<fff', *vertices[i])

gltf.set_binary_blob(bytes(binary_data))
gltf.save("core-backend/data/outputs/test_morphed.glb")
print("Done")
