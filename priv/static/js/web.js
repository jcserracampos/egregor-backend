// Egrégor Web — LiveView + custom hooks
// Depends on: phoenix.js, phoenix_live_view.js (loaded before this script)

// ── Hooks ─────────────────────────────────────────────────────────────────

const FloatingBalls = {
  mounted() {
    this.canvas = this.el.querySelector("#balls-canvas");
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext("2d");
    this.balls = [];
    this.handleEvent("update-balls", ({ categories }) => {
      this.initBalls(categories);
    });
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(this.el);
    this.resize();
    this.raf = requestAnimationFrame(() => this.tick());
  },

  destroyed() {
    cancelAnimationFrame(this.raf);
    if (this.resizeObserver) this.resizeObserver.disconnect();
  },

  resize() {
    const w = this.el.offsetWidth;
    const h = this.el.offsetHeight;
    this.canvas.width = w;
    this.canvas.height = h;
    this.W = w;
    this.H = h;
    this.balls.forEach(b => {
      b.x = Math.max(b.r, Math.min(w - b.r, b.x));
      b.y = Math.max(b.r, Math.min(h - b.r, b.y));
    });
  },

  initBalls(categories) {
    const W = this.W || this.canvas.width;
    const H = this.H || this.canvas.height;
    const maxCount = Math.max(...categories.map(c => c.entry_count), 1);

    this.balls = categories.map((cat, i) => {
      const norm = cat.entry_count / maxCount;
      const r = 28 + norm * 52;
      const existing = this.balls.find(b => b.id === cat.id);
      return {
        id: cat.id,
        name: cat.name,
        color: cat.color,
        glowColor: cat.glow_color,
        count: cat.entry_count,
        r,
        x: existing ? existing.x : W * 0.15 + Math.random() * W * 0.7,
        y: existing ? existing.y : H * 0.15 + Math.random() * H * 0.7,
        vx: existing ? existing.vx : (Math.random() - 0.5) * 0.4,
        vy: existing ? existing.vy : (Math.random() - 0.5) * 0.4,
      };
    });
  },

  tick() {
    const ctx = this.ctx;
    const W = this.W || 0;
    const H = this.H || 0;

    ctx.clearRect(0, 0, W, H);

    // Brownian motion nudge
    this.balls.forEach(b => {
      b.vx += (Math.random() - 0.5) * 0.05;
      b.vy += (Math.random() - 0.5) * 0.05;
      const speed = Math.sqrt(b.vx * b.vx + b.vy * b.vy);
      const maxSpeed = 0.8;
      if (speed > maxSpeed) { b.vx *= maxSpeed / speed; b.vy *= maxSpeed / speed; }
      b.x += b.vx;
      b.y += b.vy;
      if (b.x - b.r < 0) { b.x = b.r; b.vx *= -0.9; }
      if (b.x + b.r > W) { b.x = W - b.r; b.vx *= -0.9; }
      if (b.y - b.r < 0) { b.y = b.r; b.vy *= -0.9; }
      if (b.y + b.r > H) { b.y = H - b.r; b.vy *= -0.9; }
    });

    // Elastic collisions
    for (let i = 0; i < this.balls.length; i++) {
      for (let j = i + 1; j < this.balls.length; j++) {
        const a = this.balls[i], b = this.balls[j];
        const dx = b.x - a.x, dy = b.y - a.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const minDist = a.r + b.r + 4;
        if (dist < minDist && dist > 0) {
          const nx = dx / dist, ny = dy / dist;
          const overlap = (minDist - dist) / 2;
          a.x -= nx * overlap; a.y -= ny * overlap;
          b.x += nx * overlap; b.y += ny * overlap;
          const relVx = b.vx - a.vx, relVy = b.vy - a.vy;
          const dot = relVx * nx + relVy * ny;
          if (dot < 0) {
            const impulse = dot * 0.85;
            a.vx += impulse * nx; a.vy += impulse * ny;
            b.vx -= impulse * nx; b.vy -= impulse * ny;
          }
        }
      }
    }

    // Draw
    this.balls.forEach(b => {
      // Glow
      const grd = ctx.createRadialGradient(b.x, b.y, b.r * 0.3, b.x, b.y, b.r * 1.4);
      grd.addColorStop(0, hexAlpha(b.glowColor || b.color, 0.18));
      grd.addColorStop(1, "transparent");
      ctx.fillStyle = grd;
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.r * 1.4, 0, Math.PI * 2);
      ctx.fill();

      // Ball
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2);
      ctx.fillStyle = hexAlpha(b.color, 0.25);
      ctx.fill();
      ctx.strokeStyle = hexAlpha(b.color, 0.5);
      ctx.lineWidth = 1;
      ctx.stroke();

      // Label
      ctx.fillStyle = hexAlpha(b.color, 0.9);
      ctx.font = `300 ${Math.max(9, b.r * 0.28)}px "Cormorant Garamond", serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(b.name, b.x, b.y - 4);
      ctx.font = `300 ${Math.max(8, b.r * 0.22)}px Inter, sans-serif`;
      ctx.fillStyle = hexAlpha(b.color, 0.5);
      ctx.fillText(b.count, b.x, b.y + Math.max(10, b.r * 0.3));
    });

    this.raf = requestAnimationFrame(() => this.tick());
  }
};

function hexAlpha(hex, alpha) {
  if (!hex || !hex.startsWith("#")) return `rgba(201,170,130,${alpha})`;
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}

// ── Audio recorder hook ────────────────────────────────────────────────────

const AudioRecorder = {
  mounted() {
    this.mediaRecorder = null;
    this.chunks = [];
    this.timerInterval = null;
    this.seconds = 0;

    this.handleEvent("start-recording", () => this.startRecording());
    this.handleEvent("stop-recording", () => this.stopRecording());
  },

  destroyed() {
    this.stopRecording();
  },

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.chunks = [];
      this.seconds = 0;
      this.mediaRecorder = new MediaRecorder(stream, { mimeType: "audio/webm" });
      this.mediaRecorder.ondataavailable = e => {
        if (e.data.size > 0) this.chunks.push(e.data);
      };
      this.mediaRecorder.onstop = () => this.uploadAudio(stream);
      this.mediaRecorder.start(200);

      this.timerInterval = setInterval(() => {
        this.seconds++;
        this.pushEvent("recording-tick", { seconds: this.seconds });
      }, 1000);

      this.pushEvent("recording-started", {});
    } catch (err) {
      this.pushEvent("recording-error", { reason: err.message });
    }
  },

  stopRecording() {
    if (this.timerInterval) { clearInterval(this.timerInterval); this.timerInterval = null; }
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop();
    }
  },

  uploadAudio(stream) {
    stream.getTracks().forEach(t => t.stop());
    const blob = new Blob(this.chunks, { type: "audio/webm" });
    const form = new FormData();
    form.append("entry[audio]", blob, "recording.webm");

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

    fetch("/api/entries/audio", {
      method: "POST",
      headers: { "x-csrf-token": csrfToken },
      body: form,
    })
      .then(r => r.json())
      .then(data => this.pushEvent("audio-uploaded", { entry: data.data }))
      .catch(err => this.pushEvent("audio-error", { reason: err.message }));
  }
};

// ── Oracle chat scroll ─────────────────────────────────────────────────────

const OracleScroll = {
  mounted() { this.scrollBottom(); },
  updated() { this.scrollBottom(); },
  scrollBottom() { this.el.scrollTop = this.el.scrollHeight; }
};

// ── Auto-resize textarea ───────────────────────────────────────────────────

const AutoResize = {
  mounted() { this.resize(); this.el.addEventListener("input", () => this.resize()); },
  resize() {
    this.el.style.height = "auto";
    this.el.style.height = this.el.scrollHeight + "px";
  }
};

// ── Ritual mode ───────────────────────────────────────────────────────────

const RitualMode = {
  mounted() {
    if (this.el.dataset.ritual === "true") {
      document.querySelector(".layout")?.classList.add("layout--ritual");
    }
  }
};

// ── Logout via DELETE ─────────────────────────────────────────────────────

document.addEventListener("click", (e) => {
  const link = e.target.closest("[data-method='delete']");
  if (!link) return;
  e.preventDefault();
  const csrf = document.querySelector("meta[name='csrf-token']")?.content;
  const form = document.createElement("form");
  form.method = "POST";
  form.action = link.href;
  const m = document.createElement("input");
  m.type = "hidden"; m.name = "_method"; m.value = "DELETE";
  const c = document.createElement("input");
  c.type = "hidden"; c.name = "_csrf_token"; c.value = csrf;
  form.appendChild(m); form.appendChild(c);
  document.body.appendChild(form);
  form.submit();
});

// ── LiveSocket setup ───────────────────────────────────────────────────────

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");

const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  params: { _csrf_token: csrfToken },
  hooks: {
    FloatingBalls,
    AudioRecorder,
    OracleScroll,
    AutoResize,
    RitualMode,
  }
});

liveSocket.connect();
window.liveSocket = liveSocket;
