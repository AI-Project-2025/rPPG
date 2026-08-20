# -*- coding: utf-8 -*-
"""Regenerate ppg_stress_simulator.html with correct UTF-8 Korean."""
from pathlib import Path

HTML = """<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PPG 스트레스 반응 시뮬레이터 (PPG Stress Simulator)</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {
            --bg-color: #f0f4f8;
            --card-bg: #ffffff;
            --text-main: #2d3748;
            --text-muted: #718096;
            --primary: #3182ce;
            --stress: #e53e3e;
            --border: #e2e8f0;
        }
        body {
            font-family: "Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans KR", -apple-system,
                BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            margin: 0;
            padding: 20px;
            line-height: 1.6;
        }
        .container { max-width: 1200px; margin: 0 auto; display: flex; flex-direction: row; gap: 25px; flex-wrap: wrap; }
        header { width: 100%; margin-bottom: 10px; background: var(--card-bg); padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        header h1 { margin: 0 0 10px 0; font-size: 24px; color: #1a202c; }
        header p { margin: 0; color: var(--text-muted); font-size: 14px; }
        .control-panel { flex: 1; min-width: 320px; background: var(--card-bg); padding: 25px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); box-sizing: border-box; }
        .visual-panel { flex: 2; min-width: 500px; display: flex; flex-direction: column; gap: 20px; }
        .card { background: var(--card-bg); padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        .card h2 { margin-top: 0; margin-bottom: 15px; font-size: 16px; font-weight: 600; border-left: 4px solid var(--primary); padding-left: 10px; transition: border-color 0.3s; }
        .btn-group { display: flex; gap: 12px; margin-bottom: 25px; }
        button { flex: 1; padding: 12px; border: 1px solid var(--border); border-radius: 8px; font-size: 14px; font-weight: bold; cursor: pointer; transition: all 0.2s ease; }
        .btn-normal { background-color: #ebf8ff; color: #2b6cb0; border-color: #bee3f8; }
        .btn-normal:hover { background-color: #bbe0ff; }
        .btn-stress { background-color: #fff5f5; color: #c53030; border-color: #fed7d7; }
        .btn-stress:hover { background-color: #ffc9c9; }
        .slider-group { margin-bottom: 22px; }
        .slider-group label { display: block; font-weight: 600; margin-bottom: 8px; font-size: 14px; }
        .slider-label-container { display: flex; justify-content: space-between; align-items: center; }
        .slider-val { font-family: monospace; font-size: 15px; font-weight: bold; color: var(--primary); transition: color 0.3s; }
        input[type="range"] { width: 100%; -webkit-appearance: none; appearance: none; background: #edf2f7; height: 6px; border-radius: 3px; outline: none; margin-top: 8px; }
        input[type="range"]::-webkit-slider-thumb { -webkit-appearance: none; appearance: none; width: 18px; height: 18px; border-radius: 50%; background: var(--primary); cursor: pointer; }
        .info-box { background-color: #f7fafc; border: 1px solid var(--border); border-radius: 8px; padding: 15px; margin-top: 25px; font-size: 13px; color: #4a5568; }
        .info-box ul { margin: 5px 0 0 0; padding-left: 20px; }
        .notch-status { display: inline-block; margin-top: 5px; padding: 2px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        canvas { max-height: 260px; }
    </style>
</head>
<body>
<div class="container">
    <header>
        <h1>PPG 자율신경계 스트레스 반응 시뮬레이터</h1>
        <p>자율신경계(교감신경 활성화) 변화에 따른 광용적맥파(PPG)의 형태학적 및 시간적 변화를 직접 조절하며 관찰할 수 있는 도구입니다.</p>
    </header>
    <motion class="control-panel">
        <motion class="btn-group">
            <button class="btn-normal" onclick="loadPreset('normal')">안정 상태 프리셋</button>
            <button class="btn-stress" onclick="loadPreset('stress')">스트레스 프리셋</button>
        </motion>
        <div class="slider-group">
            <motion class="slider-label-container">
                <label for="hr">심박수 (Heart Rate)</label>
                <span class="slider-val" id="hr-val">65 BPM</span>
            </motion>
            <input type="range" id="hr" min="50" max="150" value="65" oninput="updateSimulation()">
        </motion>
        <div class="slider-group">
            <motion class="slider-label-container">
                <label for="vaso">말초 혈관 수축 (Vasoconstriction)</label>
                <span class="slider-val" id="vaso-val">10%</span>
            </motion>
            <input type="range" id="vaso" min="0" max="100" value="10" oninput="updateSimulation()">
        </motion>
        <div class="slider-group">
            <motion class="slider-label-container">
                <label for="stiff">혈관 경직도 (Arterial Stiffness)</label>
                <span class="slider-val" id="stiff-val">10%</span>
            </motion>
            <input type="range" id="stiff" min="0" max="100" value="10" oninput="updateSimulation()">
        </motion>
        <div class="info-box">
            <strong>형태 분석 가이드:</strong>
            <ul>
                <li><strong>교감신경 활성:</strong> 심박수가 올라가고 혈관이 수축(진폭 감소)됩니다.</li>
                <li><strong>중복패임(Notch) 상태:</strong> <span id="notch-text" class="notch-status">안정적인 패임 관찰됨</span></li>
            </ul>
        </motion>
    </motion>
    <div class="visual-panel">
        <motion class="card">
            <h2 id="title-continuous">5초 연속 PPG 파형 (Continuous Waveform)</h2>
            <canvas id="continuousChart"></canvas>
        </motion>
        <motion class="card">
            <h2 id="title-single">단일 맥파 형태 분석 (Single Pulse Morphology)</h2>
            <canvas id="singleChart"></canvas>
        </motion>
    </motion>
</motion>
<script>
    let continuousChart = null;
    let singleChart = null;
    window.onload = function() { initCharts(); updateSimulation(); };
    function initCharts() {
        const ctx1 = document.getElementById('continuousChart').getContext('2d');
        continuousChart = new Chart(ctx1, {
            type: 'line',
            data: {
                labels: Array.from({length: 500}, (_, i) => (i/100).toFixed(2)),
                datasets: [{ label: 'PPG 신호 (AC)', data: [], borderColor: '#3182ce', borderWidth: 2.5, pointRadius: 0, fill: false, tension: 0.2 }]
            },
            options: {
                responsive: true, maintainAspectRatio: false, animation: false,
                scales: {
                    x: { title: { display: true, text: '시간 (초)', font: { size: 11 } }, grid: { alpha: 0.1 } },
                    y: { min: -0.6, max: 1.4, title: { display: true, text: '진폭 (a.u.)', font: { size: 11 } } }
                },
                plugins: { legend: { display: false } }
            }
        });
        const ctx2 = document.getElementById('singleChart').getContext('2d');
        singleChart = new Chart(ctx2, {
            type: 'line',
            data: {
                labels: Array.from({length: 80}, (_, i) => (i/100).toFixed(2)),
                datasets: [{ label: '맥파 프로파일', data: [], borderColor: '#3182ce', borderWidth: 3.5, pointRadius: 0, fill: false, tension: 0.2 }]
            },
            options: {
                responsive: true, maintainAspectRatio: false, animation: false,
                scales: {
                    x: { title: { display: true, text: '정규화된 시간', font: { size: 11 } } },
                    y: { min: 0, max: 1.4, title: { display: true, text: '진폭', font: { size: 11 } } }
                },
                plugins: { legend: { display: false } }
            }
        });
    }
    function loadPreset(type) {
        if (type === 'normal') { document.getElementById('hr').value = 65; document.getElementById('vaso').value = 10; document.getElementById('stiff').value = 10; }
        else if (type === 'stress') { document.getElementById('hr').value = 95; document.getElementById('vaso').value = 75; document.getElementById('stiff').value = 80; }
        updateSimulation();
    }
    function updateSimulation() {
        const hr = parseFloat(document.getElementById('hr').value);
        const vaso = parseFloat(document.getElementById('vaso').value);
        const stiff = parseFloat(document.getElementById('stiff').value);
        document.getElementById('hr-val').innerText = hr + ' BPM';
        document.getElementById('vaso-val').innerText = vaso + '%';
        document.getElementById('stiff-val').innerText = stiff + '%';
        const stressFactor = Math.max(vaso, stiff) / 100;
        const currentPrimaryColor = blendColors('#3182ce', '#e53e3e', stressFactor);
        document.documentElement.style.setProperty('--primary', currentPrimaryColor);
        document.getElementById('hr-val').style.color = currentPrimaryColor;
        document.getElementById('vaso-val').style.color = currentPrimaryColor;
        document.getElementById('stiff-val').style.color = currentPrimaryColor;
        document.getElementById('title-continuous').style.borderColor = currentPrimaryColor;
        document.getElementById('title-single').style.borderColor = currentPrimaryColor;
        const notchStatusText = document.getElementById('notch-text');
        if (stiff < 30) {
            notchStatusText.innerText = "뚜렷한 중복패임(Dicrotic Notch) 관찰됨";
            notchStatusText.style.backgroundColor = "#e6fffa";
            notchStatusText.style.color = "#234e52";
        } else if (stiff < 70) {
            notchStatusText.innerText = "중복패임 뭉툭해짐 (경직도 증가)";
            notchStatusText.style.backgroundColor = "#fffaf0";
            notchStatusText.style.color = "#7b341e";
        } else {
            notchStatusText.innerText = "중복패임 평탄화/소실 (스트레스 상태)";
            notchStatusText.style.backgroundColor = "#fff5f5";
            notchStatusText.style.color = "#9b2c2c";
        }
        const pulseInterval = 60.0 / hr;
        const amp_scale = (100 - vaso * 0.55) / 100;
        const amp_sys = 1.1 * amp_scale;
        const amp_dia = (0.48 - (stiff * 0.32 / 100)) * amp_scale;
        const notch_dist = 0.24 - (stiff * 0.08 / 100);
        const fs = 100; const duration = 5; const totalPoints = fs * duration;
        const yContinuous = new Array(totalPoints).fill(0);
        const numPulses = Math.ceil(duration / pulseInterval) + 1;
        for (let p = 0; p < numPulses; p++) {
            const pulseTime = p * pulseInterval;
            for (let i = 0; i < totalPoints; i++) {
                const t = i / fs;
                const sys = amp_sys * Math.exp(-Math.pow((t - pulseTime - 0.18 * pulseInterval) / (0.07 * pulseInterval), 2));
                const dia = amp_dia * Math.exp(-Math.pow((t - pulseTime - (0.18 + notch_dist) * pulseInterval) / (0.11 * pulseInterval), 2));
                yContinuous[i] += (sys + dia);
            }
        }
        for (let i = 0; i < totalPoints; i++) {
            const t = i / fs;
            yContinuous[i] += 0.04 * Math.sin(2 * Math.PI * 0.12 * t);
            yContinuous[i] -= (vaso * 0.002);
        }
        const ySingle = [];
        for (let i = 0; i < 80; i++) {
            const normT = i / 100;
            const sys = amp_sys * Math.exp(-Math.pow((normT - 0.16) / 0.07, 2));
            const dia = amp_dia * Math.exp(-Math.pow((normT - (0.16 + notch_dist)) / 0.11, 2));
            ySingle.push(sys + dia);
        }
        continuousChart.data.datasets[0].data = yContinuous;
        continuousChart.data.datasets[0].borderColor = currentPrimaryColor;
        continuousChart.update();
        singleChart.data.datasets[0].data = ySingle;
        singleChart.data.datasets[0].borderColor = currentPrimaryColor;
        singleChart.update();
    }
    function blendColors(color1, color2, percentage) {
        const c1 = parseInt(color1.replace('#', ''), 16);
        const c2 = parseInt(color2.replace('#', ''), 16);
        const r1 = (c1 >> 16) & 255, g1 = (c1 >> 8) & 255, b1 = c1 & 255;
        const r2 = (c2 >> 16) & 255, g2 = (c2 >> 8) & 255, b2 = c2 & 255;
        const r = Math.round(r1 + (r2 - r1) * percentage);
        const g = Math.round(g1 + (g2 - g1) * percentage);
        const b = Math.round(b1 + (b2 - b1) * percentage);
        return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
    }
</script>
</body>
</html>"""

HTML = HTML.replace("<motion", "<motion").replace("</motion>", "</motion>")
HTML = HTML.replace("<motion", "<div").replace("</motion>", "</div>")

if __name__ == "__main__":
    paths = [
        Path(__file__).resolve().parents[1] / "assets" / "ppg_stress_simulator.html",
        Path(r"C:/Users/ghkdt/Downloads/ppg_stress_simulator.html"),
    ]
    for p in paths:
        p.write_text(HTML, encoding="utf-8")
        assert "스트레스" in p.read_text(encoding="utf-8"), p
        print("written", p)
