from fastapi import FastAPI, File, UploadFile, Form, BackgroundTasks
import shutil
import os
import uuid
from typing import Optional

from app.services.arkit_mesh_processor import process_face_mesh
from app.services.mouth_teeth_service import extract_teeth_from_video
from app.services.avatar_assembly_service import assemble_avatar

app = FastAPI(title="Avatar Generation API", description="iPhoneの顔スキャンデータからバストアップアバターを生成するAPI")

UPLOAD_DIR = "data/uploads"
OUTPUT_DIR = "data/outputs"
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

@app.post("/api/v1/generate_avatar")
async def generate_avatar(
    background_tasks: BackgroundTasks,
    face_mesh_file: UploadFile = File(..., description="ARFaceGeometryを含むOBJ形式ファイル"),
    pronunciation_video: UploadFile = File(..., description="「あいうえお」発音時の動画ファイル"),
    blendshapes_json: UploadFile = File(..., description="発音時のBlendshapeパラメータログ"),
    hairstyle_id: int = Form(..., description="選択された髪型のID (1~8)")
):
    """
    iPhoneスキャンアプリからデータを受け取り、アバター生成パイプラインを非同期で開始する
    """
    job_id = str(uuid.uuid4())
    job_dir = os.path.join(UPLOAD_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)
    
    # 1. ファイルの保存
    mesh_path = os.path.join(job_dir, face_mesh_file.filename)
    with open(mesh_path, "wb") as f:
        shutil.copyfileobj(face_mesh_file.file, f)
        
    video_path = os.path.join(job_dir, pronunciation_video.filename)
    with open(video_path, "wb") as f:
        shutil.copyfileobj(pronunciation_video.file, f)
        
    json_path = os.path.join(job_dir, blendshapes_json.filename)
    with open(json_path, "wb") as f:
        shutil.copyfileobj(blendshapes_json.file, f)
        
    # 2. 非同期で重い3D生成処理をキック
    background_tasks.add_task(
        run_generation_pipeline, 
        job_id, 
        mesh_path, 
        video_path, 
        json_path, 
        hairstyle_id
    )
    
    return {"status": "accepted", "job_id": job_id, "message": "アバター生成処理を開始しました。"}

def run_generation_pipeline(job_id: str, mesh_path: str, video_path: str, json_path: str, hairstyle_id: int):
    """
    GPUサーバー上で実行される重い処理のオーケストレーション
    """
    print(f"[Job {job_id}] パイプライン開始...")
    
    try:
        # Step 1: ARKitメッシュからバストアップモデルとBlendshapeの構築
        print(f"[Job {job_id}] Step 1: 顔メッシュ処理中...")
        base_head_path = process_face_mesh(mesh_path)
        
        # Step 2: 動画とBlendshapeから歯のテクスチャ・スケール抽出
        print(f"[Job {job_id}] Step 2: 口内・歯の抽出中...")
        teeth_model_path = extract_teeth_from_video(video_path, json_path)
        
        # Step 3: 頭部、歯、髪型を結合して最終GLB生成
        print(f"[Job {job_id}] Step 3: アバター組み立て中...")
        final_glb_path = os.path.join(OUTPUT_DIR, f"{job_id}_avatar.glb")
        assemble_avatar(base_head_path, teeth_model_path, hairstyle_id, final_glb_path)
        
        print(f"[Job {job_id}] パイプライン完了！ 出力先: {final_glb_path}")
        
    except Exception as e:
        print(f"[Job {job_id}] エラー発生: {e}")

@app.get("/api/v1/status/{job_id}")
async def get_status(job_id: str):
    """
    生成状態を確認し、完了していればGLBファイルのダウンロードURLを返す
    """
    final_glb_path = os.path.join(OUTPUT_DIR, f"{job_id}_avatar.glb")
    if os.path.exists(final_glb_path):
        return {"status": "completed", "download_url": f"/api/v1/download/{job_id}"}
    elif os.path.exists(os.path.join(UPLOAD_DIR, job_id)):
        return {"status": "processing"}
    else:
        return {"status": "not_found"}
