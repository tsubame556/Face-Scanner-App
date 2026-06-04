import os
import trimesh

os.makedirs("core-backend/data/assets/base_model", exist_ok=True)
os.makedirs("core-backend/data/assets/hair", exist_ok=True)

skull = trimesh.creation.icosphere(subdivisions=3, radius=0.08)
skull.apply_translation([0, 0.05, -0.02])
neck = trimesh.creation.cylinder(radius=0.03, height=0.1)
neck.apply_translation([0, -0.05, -0.02])
base_head = trimesh.util.concatenate([skull, neck])
base_head.export("core-backend/data/assets/base_model/base_head.obj")

hair = trimesh.creation.icosphere(subdivisions=2, radius=0.085)
hair.apply_translation([0, 0.06, -0.03])
hair.export("core-backend/data/assets/hair/hair_1.glb")

print("Assets generated successfully.")
