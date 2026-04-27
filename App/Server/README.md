# rPPG WebSocket Streaming Server

FastAPI를 사용한 WebSocket 기반 실시간 스트리밍 서버입니다.

## 기능

- WebSocket을 통한 실시간 양방향 통신
- 서버-스트리밍 형식의 데이터 전송
- rPPG (remote Photoplethysmography) 데이터 스트리밍 시뮬레이션
- 다중 클라이언트 연결 지원

## 설치

```bash
pip install -r requirements.txt
```

## 실행

```bash
python main.py
```

또는 uvicorn을 직접 사용:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## 사용 방법

1. 서버 실행 후 브라우저에서 `http://localhost:8000` 접속
2. "연결" 버튼 클릭하여 WebSocket 연결
3. "스트리밍 시작" 버튼 클릭하여 실시간 데이터 수신 시작
4. "스트리밍 중지" 버튼으로 스트리밍 중지

## API 엔드포인트

### WebSocket
- `ws://localhost:8000/ws` - WebSocket 연결 엔드포인트

### HTTP
- `GET /` - 테스트용 HTML 페이지
- `GET /health` - 서버 상태 확인

## WebSocket 메시지 형식

### 클라이언트 → 서버

**스트리밍 시작:**
```json
{
  "action": "start_streaming",
  "fps": 30
}
```

**스트리밍 중지:**
```json
{
  "action": "stop_streaming"
}
```

### 서버 → 클라이언트

**스트리밍 데이터:**
```json
{
  "frame": 1,
  "timestamp": "2024-01-01T12:00:00",
  "heart_rate": 75.5,
  "signal_strength": 0.823,
  "rppg_signal": [0.1, 0.2, 0.3, ...]
}
```

**상태 메시지:**
```json
{
  "status": "streaming_started",
  "fps": 30,
  "message": "스트리밍이 시작되었습니다."
}
```

## 커스터마이징

`stream_data()` 함수를 수정하여 실제 rPPG 처리 로직을 구현할 수 있습니다:

```python
async def stream_data(websocket: WebSocket, fps: int = 30):
    # 실제 비디오 프레임 처리
    # rPPG 알고리즘 적용
    # 결과를 WebSocket으로 전송
    pass
```

## 참고사항

- 기본 FPS는 30입니다. 필요에 따라 조정 가능합니다.
- 다중 클라이언트 연결을 지원합니다.
- 연결이 끊기면 자동으로 정리됩니다.
