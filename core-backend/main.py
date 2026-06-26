from fastapi import FastAPI, File, UploadFile, Form, BackgroundTasks
import shutil
import os
import uuid
from typing import Optional

from app.services.arkit_mesh_processor import process_face_mesh
from app.services.mouth_teeth_service import extract_teeth_from_video
from app.services.avatar_assembly_service import build_personalized_avatar

app = FastAPI(title="Avatar Generation API", description="iPhoneの顔スキャンデータからバストアップアバターを生成するAPI")

UPLOAD_DIR = "data/uploads"
OUTPUT_DIR = "data/outputs"
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

latest_job_id: Optional[str] = None

@app.post("/api/v1/generate_avatar")
async def generate_avatar(
    background_tasks: BackgroundTasks,
    face_mesh_file: UploadFile = File(..., description="顔データJSONファイル"),
    face_texture_file: UploadFile = File(None, description="テクスチャ画像"),
    hairstyle_id: int = Form(..., description="選択された髪型のID (1~8)")
):
    """
    iPhoneスキャンアプリからデータを受け取り、アバター生成パイプラインを非同期で開始する
    """
    global latest_job_id
    job_id = str(uuid.uuid4())
    latest_job_id = job_id
    
    job_dir = os.path.join(UPLOAD_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)
    
    # 1. ファイルの保存
    json_data_path = os.path.join(job_dir, face_mesh_file.filename)
    with open(json_data_path, "wb") as f:
        shutil.copyfileobj(face_mesh_file.file, f)
        
    texture_path = ""
    if face_texture_file:
        texture_path = os.path.join(job_dir, face_texture_file.filename)
        with open(texture_path, "wb") as f:
            shutil.copyfileobj(face_texture_file.file, f)
            
    # 2. 非同期で重い3D生成処理をキック
    background_tasks.add_task(
        run_generation_pipeline, 
        job_id, 
        json_data_path, 
        texture_path, 
        hairstyle_id
    )
    
    return {"status": "accepted", "job_id": job_id, "message": "アバター生成処理を開始しました。"}

def run_generation_pipeline(job_id: str, json_data_path: str, texture_path: str, hairstyle_id: int):
    """
    GPUサーバー上で実行される重い処理のオーケストレーション
    """
    print(f"[Job {job_id}] パイプライン開始...")
    
    try:
        # Step 1: 新生アバターの生成（JSONデータとテクスチャからのGLBフルビルド）
        print(f"[Job {job_id}] Step 1: アバターフルアセンブリ中...")
        final_glb_path = os.path.join(OUTPUT_DIR, f"{job_id}_avatar.glb")
        
        # avatar_assembly_serviceに全てを委譲する
        from app.services.avatar_assembly_service import build_personalized_avatar
        build_personalized_avatar(json_data_path, texture_path, hairstyle_id, final_glb_path)
        
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

from fastapi.responses import FileResponse

@app.get("/api/v1/download/{job_id}")
async def download_avatar(job_id: str):
    """
    生成完了したGLBファイルをダウンロードする
    """
    final_glb_path = os.path.join(OUTPUT_DIR, f"{job_id}_avatar.glb")
    if os.path.exists(final_glb_path):
        return FileResponse(final_glb_path, media_type="model/gltf-binary", filename=f"{job_id}_avatar.glb")
    return {"error": "not_found"}

@app.get("/api/v1/jobs/latest")
async def get_latest_job():
    """
    最新のJob IDを取得する（Unityの自動同期用）
    """
    if latest_job_id:
        return {"job_id": latest_job_id}
    return {"error": "no_jobs"}
