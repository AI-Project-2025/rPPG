from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import asyncio
import json
import time
from typing import List
from datetime import datetime

# rPPG / 모델 관련 추가 import
import os
import cv2
import csv
import collections
import numpy as np
import onnxruntime as ort
import base64

app = FastAPI(title="rPPG WebSocket Streaming Server")


# ===============================================================
# rPPG 관련 유틸 클래스 / 함수들 (질문에서 제공한 코드 기반)
# ===============================================================
class KalmanFilter1D:
    """1차원 칼만 필터"""
    def __init__(self, processNoise=1.0, measurementNoise=2.0, initialState=0.0, initialEstimateError=1.0):
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
        self.estimate = initialState
        self.estimateError = initialEstimateError

    def update(self, measurement):
        prediction = self.estimate
        predictionError = self.estimateError + self.processNoise
        kalmanGain = predictionError / (predictionError + self.measurementNoise)
        self.estimate = prediction + kalmanGain * (measurement - prediction)
        self.estimateError = (1 - kalmanGain) * predictionError
        return self.estimate

    def reset(self, initialState=0.0):
        self.estimate = initialState
        self.estimateError = 1.0


class OpenCVFaceDetector:
    """OpenCV Haar Cascade를 사용한 얼굴 감지기"""
    def __init__(self, min_confidence=0.5):
        cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        self.face_cascade = cv2.CascadeClassifier(cascade_path)

    def detect(self, frame_bgr):
        gray = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY)
        faces = self.face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(60, 60),
        )
        detections = []
        for (x, y, w, h) in faces:
            detections.append({'box': (int(x), int(y), int(w), int(h)), 'confidence': 1.0})
        return detections

    def close(self):
        pass


class MeasurementLogger:
    """실시간 코드의 CSV 로거 (원하면 저장 on/off)"""
    def __init__(self, filename=None):
        if filename is None:
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"hr_measurements_{ts}.csv"
        self.filename = filename
        self.start_time = time.time()
        with open(self.filename, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['timestamp', 'elapsed_time', 'hr', 'bvp', 'fps'])
        print(f"측정 데이터를 '{self.filename}'에 저장합니다.")

    def log(self, hr, bvp, fps):
        timestamp = datetime.now().isoformat()
        elapsed = time.time() - self.start_time
        with open(self.filename, 'a', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([timestamp, f"{elapsed:.2f}", f"{hr:.2f}", f"{bvp:.6f}", f"{fps:.1f}"])


# ===============================================================
# ONNX 세션 / 상태 로드
# - 사용자의 기존 실시간 코드(main.py) 구현을 그대로 사용
#   (load_state, load_model)
# - model.onnx 는 (img, state, dt) -> (bvp, new_state) 형태로 동작
# ===============================================================

def load_state(path: str):
    """state.json 을 로드하여 dict 형태로 반환"""
    with open(path, 'r') as f:
        return json.load(f)


def load_model(path: str):
    """
    model.onnx 를 로드하여 (facial_img, state, dt) -> (bvp, new_state) 형태의
    래퍼 함수를 반환 (사용자가 제공한 기존 코드 그대로)
    """
    model = ort.InferenceSession(path)

    def run(img, state, dt=1 / 30):
        # img: (H, W, C) float32 [0,1], 36x36x3
        # state: dict (state_name -> ndarray)
        # dt: 시간 간격
        result = model.run(
            None,
            {
                "arg_0.1": img[None, None],  # 배치/채널 차원 추가
                "onnx::Mul_37": [dt],
                **state,
            },
        )
        bvp, new_state = result[0][0, 0], result[1:]
        return bvp, dict(zip(state, new_state))

    return run


# 상태/모델/세션 생성
STATE_PATH = "state.json"
MODEL_PATH = "model.onnx"
WELCH_PATH = "welch_psd.onnx"
HR_PATH = "get_hr.onnx"

state = load_state(STATE_PATH)
model = load_model(MODEL_PATH)

welch_session = ort.InferenceSession(WELCH_PATH) if os.path.exists(WELCH_PATH) else None
hr_session = ort.InferenceSession(HR_PATH) if os.path.exists(HR_PATH) else None
face_detector = OpenCVFaceDetector(min_confidence=0.5)


def get_hr_from_onnx(bvp_array):
    """
    10초 버퍼(BVP)를 Welch PSD → get_hr.onnx로 HR(BPM) 추정
    """
    if welch_session is None or hr_session is None:
        return float("nan")

    try:
        bvp_tensor = np.array(bvp_array, dtype=np.float32).reshape(1, 1, -1)
        outputs = welch_session.run(None, {'input': bvp_tensor})
        freqs, psd = outputs[0], outputs[1]
        hr_output = hr_session.run(None, {'freqs': freqs, 'psd': psd})
        hr_bpm = hr_output[0].item()

        if np.isnan(hr_bpm) or hr_bpm <= 0:
            return float("nan")

        # ONNX가 직접 산출한 BPM 값을 그대로 사용
        return hr_bpm
    except Exception:
        return float("nan")

# WebSocket 연결 관리
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"클라이언트 연결됨. 총 연결 수: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        print(f"클라이언트 연결 해제됨. 총 연결 수: {len(self.active_connections)}")

    async def send_personal_message(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def broadcast(self, message: str):
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception as e:
                print(f"전송 오류: {e}")
                disconnected.append(connection)
        
        # 연결이 끊어진 소켓 제거
        for conn in disconnected:
            self.disconnect(conn)

manager = ConnectionManager()


@app.get("/")
async def get():
    """테스트용 HTML 페이지"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>rPPG WebSocket Streaming Test</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f5f5f5;
            }
            .container {
                background: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            button {
                background-color: #4CAF50;
                color: white;
                padding: 10px 20px;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 16px;
                margin: 5px;
            }
            button:hover {
                background-color: #45a049;
            }
            button:disabled {
                background-color: #cccccc;
                cursor: not-allowed;
            }
            #stopBtn {
                background-color: #f44336;
            }
            #stopBtn:hover {
                background-color: #da190b;
            }
            #messages {
                height: 400px;
                overflow-y: auto;
                border: 1px solid #ddd;
                padding: 10px;
                margin-top: 20px;
                background-color: #fafafa;
                font-family: monospace;
                font-size: 12px;
            }
            .status {
                padding: 10px;
                margin: 10px 0;
                border-radius: 4px;
            }
            .connected {
                background-color: #d4edda;
                color: #155724;
            }
            .disconnected {
                background-color: #f8d7da;
                color: #721c24;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>rPPG WebSocket Streaming Test</h1>
            <div id="status" class="status disconnected">연결 안됨</div>
            <div>
                <button id="connectBtn" onclick="connect()">연결</button>
                <button id="disconnectBtn" onclick="disconnect()" disabled>연결 해제</button>
                <button id="startBtn" onclick="startStreaming()" disabled>스트리밍 시작</button>
                <button id="stopBtn" onclick="stopStreaming()" disabled>스트리밍 중지</button>
            </div>

            <h3>실시간 웹캠 미리보기</h3>
            <img id="preview" width="320" height="240" style="border:1px solid #ddd; background:#000; object-fit:cover;" />

            <h3>실시간 rPPG 시각화</h3>
            <div>현재 HR (BPM): <span id="hrValue">-</span></div>
            <canvas id="rppgCanvas" width="800" height="200" style="border:1px solid #ddd; margin-top:10px;"></canvas>

            <h3>HR 추정 값 (시간 경과)</h3>
            <canvas id="hrCanvas" width="800" height="150" style="border:1px solid #ddd; margin-top:10px;"></canvas>
        </div>

        <script>
            let ws = null;
            let streamingInterval = null;

            // rPPG 시각화용 버퍼 (모델 BVP 출력의 시간 시퀀스)
            // 10초 구간을 기준으로, 30fps 가정 → 300 포인트
            const rppgBuffer = [];
            const maxRppgPoints = 300; // 10초(30fps) 기준 시각화 길이
            for (let i = 0; i < maxRppgPoints; i++) {
                rppgBuffer.push(0);
            }

            // HR 시각화용 버퍼 (시간에 따른 BPM 시퀀스)
            const hrBuffer = [];
            const maxHrPoints = 300;
            for (let i = 0; i < maxHrPoints; i++) {
                hrBuffer.push(0);
            }

            function updateStatus(connected) {
                const statusDiv = document.getElementById('status');
                const connectBtn = document.getElementById('connectBtn');
                const disconnectBtn = document.getElementById('disconnectBtn');
                const startBtn = document.getElementById('startBtn');
                const stopBtn = document.getElementById('stopBtn');

                if (connected) {
                    statusDiv.textContent = '연결됨';
                    statusDiv.className = 'status connected';
                    connectBtn.disabled = true;
                    disconnectBtn.disabled = false;
                    startBtn.disabled = false;
                } else {
                    statusDiv.textContent = '연결 안됨';
                    statusDiv.className = 'status disconnected';
                    connectBtn.disabled = false;
                    disconnectBtn.disabled = true;
                    startBtn.disabled = true;
                    stopBtn.disabled = true;
                }
            }

            function addMessage(message) {
                // 디버그 로그가 필요하면 console 로만 출력
                console.log(message);
            }

            function drawRppg() {
                const canvas = document.getElementById('rppgCanvas');
                const ctx = canvas.getContext('2d');
                const w = canvas.width;
                const h = canvas.height;

                ctx.clearRect(0, 0, w, h);

                if (rppgBuffer.length === 0) {
                    return;
                }

                const minVal = Math.min(...rppgBuffer);
                const maxVal = Math.max(...rppgBuffer);
                const range = (maxVal - minVal) || 1.0;

                ctx.beginPath();
                ctx.strokeStyle = '#007bff';
                ctx.lineWidth = 2;

                rppgBuffer.forEach((v, idx) => {
                    const x = (idx / (rppgBuffer.length - 1)) * w;
                    const norm = (v - minVal) / range;
                    const y = h - norm * h;
                    if (idx === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                });

                ctx.stroke();
            }

            function drawHr() {
                const canvas = document.getElementById('hrCanvas');
                const ctx = canvas.getContext('2d');
                const w = canvas.width;
                const h = canvas.height;

                ctx.clearRect(0, 0, w, h);

                if (hrBuffer.length === 0) {
                    return;
                }

                // HR 범위를 대략 40~180 BPM 로 가정 (원래 코드 hr_min, hr_max)
                const yMin = 40;
                const yMax = 180;
                const yRange = yMax - yMin;

                ctx.beginPath();
                ctx.strokeStyle = '#28a745';
                ctx.lineWidth = 2;

                hrBuffer.forEach((v, idx) => {
                    const x = (idx / (maxHrPoints - 1)) * w;
                    const clamped = Math.max(yMin, Math.min(yMax, v));
                    const norm = (clamped - yMin) / yRange;  // 0~1
                    const y = h - norm * h;
                    if (idx === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                });

                ctx.stroke();
            }

            function connect() {
                const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = `${protocol}//${window.location.host}/ws`;
                
                ws = new WebSocket(wsUrl);

                ws.onopen = function(event) {
                    addMessage('WebSocket 연결 성공');
                    updateStatus(true);
                };

                ws.onmessage = function(event) {
                    try {
                        const data = JSON.parse(event.data);

                        // HR 값 표시
                        if (typeof data.heart_rate === 'number') {
                            document.getElementById('hrValue').textContent = data.heart_rate.toFixed(2);
                            // HR 버퍼에 기록 (시계열)
                            hrBuffer.push(data.heart_rate);
                            while (hrBuffer.length > maxHrPoints) {
                                hrBuffer.shift();
                            }
                            drawHr();
                        }

                        // rPPG 데이터 버퍼에 추가
                        if (Array.isArray(data.rppg_signal)) {
                            for (const v of data.rppg_signal) {
                                rppgBuffer.push(v);
                            }
                            while (rppgBuffer.length > maxRppgPoints) {
                                rppgBuffer.shift();
                            }
                            drawRppg();
                        }

                        // 웹캠 프레임 표시 (서버에서 온 base64 JPEG)
                        if (data.frame_image) {
                            const img = document.getElementById('preview');
                            img.src = 'data:image/jpeg;base64,' + data.frame_image;
                        }

                        // 디버그 로그
                        addMessage(`수신: ${JSON.stringify(data)}`);
                    } catch (e) {
                        addMessage(`수신(JSON 파싱 실패): ${event.data}`);
                    }
                };

                ws.onerror = function(error) {
                    addMessage(`오류: ${error}`);
                };

                ws.onclose = function(event) {
                    addMessage('WebSocket 연결 종료');
                    updateStatus(false);
                    if (streamingInterval) {
                        clearInterval(streamingInterval);
                        streamingInterval = null;
                    }
                };
            }

            function disconnect() {
                if (ws) {
                    ws.close();
                    ws = null;
                }
                stopStreaming();
            }

            function startStreaming() {
                if (!ws || ws.readyState !== WebSocket.OPEN) {
                    alert('먼저 WebSocket에 연결하세요.');
                    return;
                }

                const startBtn = document.getElementById('startBtn');
                const stopBtn = document.getElementById('stopBtn');
                startBtn.disabled = true;
                stopBtn.disabled = false;

                // 서버에 스트리밍 시작 요청
                ws.send(JSON.stringify({
                    "action": "start_streaming",
                    "fps": 30  // 초당 프레임 수
                }));

                addMessage('스트리밍 시작 요청 전송');
            }

            function stopStreaming() {
                if (ws && ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({
                        "action": "stop_streaming"
                    }));
                }

                const startBtn = document.getElementById('startBtn');
                const stopBtn = document.getElementById('stopBtn');
                startBtn.disabled = false;
                stopBtn.disabled = true;

                addMessage('스트리밍 중지 요청 전송');
            }

            // 페이지 로드 시 빈 그래프 한 번 그려두기
            window.addEventListener('load', () => {
                drawRppg();
                drawHr();
            });
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html)


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket 엔드포인트 - 실시간 스트리밍"""
    await manager.connect(websocket)
    streaming_active = False
    stream_task = None

    try:
        while True:
            # 클라이언트로부터 메시지 수신
            data = await websocket.receive_text()
            
            try:
                message = json.loads(data)
                action = message.get("action")

                if action == "start_streaming":
                    if not streaming_active:
                        streaming_active = True
                        fps = message.get("fps", 30)
                        stream_task = asyncio.create_task(
                            stream_data(websocket, fps)
                        )
                        await manager.send_personal_message(
                            json.dumps({
                                "status": "streaming_started",
                                "fps": fps,
                                "message": "스트리밍이 시작되었습니다."
                            }),
                            websocket
                        )

                elif action == "stop_streaming":
                    streaming_active = False
                    if stream_task:
                        stream_task.cancel()
                        try:
                            await stream_task
                        except asyncio.CancelledError:
                            pass
                    await manager.send_personal_message(
                        json.dumps({
                            "status": "streaming_stopped",
                            "message": "스트리밍이 중지되었습니다."
                        }),
                        websocket
                    )

                else:
                    await manager.send_personal_message(
                        json.dumps({
                            "status": "error",
                            "message": f"알 수 없는 액션: {action}"
                        }),
                        websocket
                    )

            except json.JSONDecodeError:
                await manager.send_personal_message(
                    json.dumps({
                        "status": "error",
                        "message": "잘못된 JSON 형식입니다."
                    }),
                    websocket
                )

    except WebSocketDisconnect:
        manager.disconnect(websocket)
        if stream_task:
            stream_task.cancel()
    except Exception as e:
        print(f"WebSocket 오류: {e}")
        manager.disconnect(websocket)
        if stream_task:
            stream_task.cancel()


async def stream_data(websocket: WebSocket, fps: int = 30):
    """
    웹캠에서 프레임을 읽고, rPPG 파이프라인(질문에서 제공한 로직과 동일한 구성)을 통해
    BVP 및 HR(BPM)을 추정하여 WebSocket으로 실시간 전송
    """
    global state

    # 웹캠 열기
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        await manager.send_personal_message(
            json.dumps({
                "status": "error",
                "message": "웹캠을 열 수 없습니다. 카메라 장치를 확인하세요."
            }),
            websocket
        )
        return

    # FPS 설정
    measured_fps = float(fps) if fps and fps > 0 else 30.0
    delay = 1.0 / measured_fps

    # 윈도우 / 버퍼 설정 (10초 슬라이딩 윈도우 - HR 계산용)
    WINDOW_SEC = 10
    WINDOW_SIZE_FRAMES = int(measured_fps * WINDOW_SEC)
    bvp_buffer = collections.deque([0.0] * WINDOW_SIZE_FRAMES, maxlen=WINDOW_SIZE_FRAMES)

    # rPPG 시각화용: 원래 코드의 rppg_series (프레임별 BVP) 역할
    rppg_history = collections.deque(maxlen=300)

    # HR 칼만 필터
    hr_kf = KalmanFilter1D(processNoise=1.0, measurementNoise=2.0)
    hr_display = 0.0
    # HR 업데이트 주기 (초 단위, 예: 1초마다 새 HR 계산)
    HR_UPDATE_SEC = 1.0
    hr_last_update_frame = 0

    # BBox 칼만 스무딩 필터
    pn, mn = 1e-2, 5e-1
    kf_bbox_x = KalmanFilter1D(pn, mn)
    kf_bbox_y = KalmanFilter1D(pn, mn)
    kf_bbox_w = KalmanFilter1D(pn, mn)
    kf_bbox_h = KalmanFilter1D(pn, mn)
    bbox_initialized = False

    last_face_detected_frame = -1
    FACE_TIMEOUT_SEC = 2.0
    face_timeout_frames = int(FACE_TIMEOUT_SEC * measured_fps)

    frame_count = 0

    try:
        while True:
            loop_start = time.time()

            ret, frame = cap.read()
            if not ret:
                await manager.send_personal_message(
                    json.dumps({
                        "status": "error",
                        "message": "웹캠에서 프레임을 읽을 수 없습니다."
                    }),
                    websocket
                )
                break

            frame_count += 1

            # 얼굴 감지
            detections = face_detector.detect(frame)
            facial_img = None

            if detections:
                detection = detections[0]
                raw_x, raw_y, raw_w, raw_h = detection['box']
                h, w = frame.shape[:2]

                # BBox 칼만 초기화
                if not bbox_initialized:
                    kf_bbox_x.reset(raw_x)
                    kf_bbox_y.reset(raw_y)
                    kf_bbox_w.reset(raw_w)
                    kf_bbox_h.reset(raw_h)
                    bbox_initialized = True

                # BBox 칼만 스무딩
                s_x = int(kf_bbox_x.update(raw_x))
                s_y = int(kf_bbox_y.update(raw_y))
                s_w = int(kf_bbox_w.update(raw_w))
                s_h = int(kf_bbox_h.update(raw_h))

                # 이마 포함 높이 확장
                s_h = int(s_h * 1.2)
                s_y = int(s_y - (s_h * 0.2 / 2))

                # 안전한 크롭
                x1, y1 = max(0, s_x), max(0, s_y)
                x2, y2 = min(w, s_x + s_w), min(h, s_y + s_h)
                if x2 > x1 and y2 > y1:
                    face_crop = frame[y1:y2, x1:x2]
                    if face_crop.size > 0:
                        face_rgb = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
                        resized = cv2.resize(face_rgb, (36, 36), interpolation=cv2.INTER_AREA)
                        facial_img = (resized.astype(np.float32) / 255.0)

                last_face_detected_frame = frame_count

            # === BVP 추정 ===
            if facial_img is not None and model is not None:
                dt = 1.0 / measured_fps
                output, state = model(facial_img, state, dt=dt)
                bvp_val = float(output)
            else:
                bvp_val = 0.0
                # 얼굴 감지 실패가 일정 시간 이상 지속되면 리셋
                if bbox_initialized and (frame_count - last_face_detected_frame) > face_timeout_frames:
                    bvp_buffer = collections.deque([0.0] * WINDOW_SIZE_FRAMES, maxlen=WINDOW_SIZE_FRAMES)
                    hr_kf.reset(0.0)
                    hr_display = 0.0
                    bbox_initialized = False

            # 버퍼 업데이트 (슬라이딩 윈도우 - HR 계산용)
            bvp_buffer.append(bvp_val)
            # 프레임별 BVP 기록 (원래 코드의 rppg_series 와 동일 개념)
            rppg_history.append(bvp_val)

            # HR 계산 (Welch + HR onnx) - 고정된 10초 윈도우 기준 BPM
            # -> 지정한 간격(HR_UPDATE_SEC)마다 한 번만 재계산
            if frame_count - hr_last_update_frame >= int(measured_fps * HR_UPDATE_SEC):
                current_hr_raw = get_hr_from_onnx(list(bvp_buffer))
                if not np.isnan(current_hr_raw) and current_hr_raw > 40:
                    hr_display = hr_kf.update(current_hr_raw)
                    hr_last_update_frame = frame_count
                # 비정상 값이면 이전 값 유지

            # rPPG 시그널: 원래 코드에서의 rppg_series 를 실시간으로 전달
            rppg_signal = list(rppg_history)

            # 전송 데이터 구성 (기존 프런트엔드와 키 맞춤)
            stream_data_payload = {
                "frame": frame_count,
                "timestamp": datetime.now().isoformat(),
                "heart_rate": round(hr_display, 2) if hr_display > 0 else None,
                "signal_strength": float(abs(bvp_val)),
                "rppg_signal": [float(x) for x in rppg_signal],
                "bvp": float(bvp_val),
            }

            # 웹캠 프레임을 JPEG로 인코딩하여 base64로 전송 (미리보기용)
            try:
                _, jpeg_buf = cv2.imencode(".jpg", frame)
                frame_b64 = base64.b64encode(jpeg_buf).decode("ascii")
                stream_data_payload["frame_image"] = frame_b64
            except Exception:
                pass

            await websocket.send_text(json.dumps(stream_data_payload))

            # FPS 유지
            elapsed = time.time() - loop_start
            sleep_time = max(0.0, delay - elapsed)
            await asyncio.sleep(sleep_time)

    except asyncio.CancelledError:
        print("스트리밍 작업 취소됨")
        raise
    except Exception as e:
        print(f"스트리밍 오류: {e}")
        await manager.send_personal_message(
            json.dumps({
                "status": "error",
                "message": f"스트리밍 오류: {str(e)}"
            }),
            websocket
        )
    finally:
        cap.release()


@app.get("/health")
async def health_check():
    """헬스 체크 엔드포인트"""
    return {
        "status": "healthy",
        "active_connections": len(manager.active_connections),
        "timestamp": datetime.now().isoformat()
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
