/**
 * Web Audio API Prosedürel Ses Motoru
 * Harici dosya indirmeden gerçekçi okul zili, adımlar, etkileşimler ve melodiler üretir.
 */

class SoundEngine {
  constructor() {
    this.ctx = null;
    this.isMuted = false;
    this.lastStepTime = 0;
    this.initAudioContext();
  }

  initAudioContext() {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (AudioContext) {
      this.ctx = new AudioContext();
    }
  }

  resume() {
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  toggleMute() {
    this.isMuted = !this.isMuted;
    return this.isMuted;
  }

  /**
   * Klasik Okul Zili Sentezi (Westminster Melodisi Tınısı)
   */
  playSchoolBell() {
    if (this.isMuted || !this.ctx) return;
    this.resume();

    // Okul zili notaları: Sol4, Mi4, Do4, Sol3 melodik çanı
    const notes = [
      { freq: 659.25, time: 0.0, dur: 0.8 }, // E5
      { freq: 523.25, time: 0.5, dur: 0.8 }, // C5
      { freq: 587.33, time: 1.0, dur: 0.8 }, // D5
      { freq: 392.00, time: 1.5, dur: 1.6 }  // G4
    ];

    notes.forEach(n => {
      const startTime = this.ctx.currentTime + n.time;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(n.freq, startTime);

      // Harmonik zenginlik için hafif overtone
      const harmonic = this.ctx.createOscillator();
      const harmGain = this.ctx.createGain();
      harmonic.type = 'triangle';
      harmonic.frequency.setValueAtTime(n.freq * 2.02, startTime);

      gain.gain.setValueAtTime(0, startTime);
      gain.gain.linearRampToValueAtTime(0.25, startTime + 0.04);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + n.dur);

      harmGain.gain.setValueAtTime(0, startTime);
      harmGain.gain.linearRampToValueAtTime(0.08, startTime + 0.04);
      harmGain.gain.exponentialRampToValueAtTime(0.001, startTime + n.dur * 0.7);

      osc.connect(gain);
      harmonic.connect(harmGain);
      gain.connect(this.ctx.destination);
      harmGain.connect(this.ctx.destination);

      osc.start(startTime);
      harmonic.start(startTime);
      osc.stop(startTime + n.dur + 0.1);
      harmonic.stop(startTime + n.dur + 0.1);
    });
  }

  /**
   * Adım Sesi (Yürüme ve Koşma)
   */
  playFootstep(isRunning = false) {
    if (this.isMuted || !this.ctx) return;
    const now = performance.now();
    const interval = isRunning ? 260 : 420;

    if (now - this.lastStepTime < interval) return;
    this.lastStepTime = now;
    this.resume();

    const startTime = this.ctx.currentTime;
    const bufferSize = this.ctx.sampleRate * 0.05;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);

    for (let i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (bufferSize * 0.25));
    }

    const noise = this.ctx.createBufferSource();
    noise.buffer = buffer;

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(isRunning ? 600 : 450, startTime);

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(isRunning ? 0.12 : 0.07, startTime);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.06);

    noise.connect(filter);
    filter.connect(gain);
    gain.connect(this.ctx.destination);

    noise.start(startTime);
    noise.stop(startTime + 0.07);
  }

  /**
   * Zıplama Sesi
   */
  playJump() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    const startTime = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(140, startTime);
    osc.frequency.exponentialRampToValueAtTime(320, startTime + 0.18);

    gain.gain.setValueAtTime(0.15, startTime);
    gain.gain.linearRampToValueAtTime(0.001, startTime + 0.2);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(startTime);
    osc.stop(startTime + 0.22);
  }

  /**
   * Yere İniş Sesi
   */
  playLand() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    const startTime = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(110, startTime);
    osc.frequency.exponentialRampToValueAtTime(45, startTime + 0.15);

    gain.gain.setValueAtTime(0.2, startTime);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.16);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(startTime);
    osc.stop(startTime + 0.18);
  }

  /**
   * Etkileşim Klik Sesi
   */
  playInteract() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    const startTime = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(540, startTime);
    osc.frequency.exponentialRampToValueAtTime(980, startTime + 0.08);

    gain.gain.setValueAtTime(0.15, startTime);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.1);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(startTime);
    osc.stop(startTime + 0.12);
  }

  /**
   * Doğru Cevap / Başarı Melodisi
   */
  playCorrect() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    const chords = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    chords.forEach((freq, idx) => {
      const startTime = this.ctx.currentTime + idx * 0.07;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, startTime);

      gain.gain.setValueAtTime(0, startTime);
      gain.gain.linearRampToValueAtTime(0.2, startTime + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.4);

      osc.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start(startTime);
      osc.stop(startTime + 0.45);
    });
  }

  /**
   * Yanlış Cevap Sesi
   */
  playWrong() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    [240, 200].forEach((freq, idx) => {
      const startTime = this.ctx.currentTime + idx * 0.12;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(freq, startTime);

      gain.gain.setValueAtTime(0.12, startTime);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.15);

      osc.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start(startTime);
      osc.stop(startTime + 0.18);
    });
  }

  /**
   * Otomat / İçecek Düşme Sesi
   */
  playVending() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    const startTime = this.ctx.currentTime;
    
    // Bozuk para kliği
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1400, startTime);
    osc.frequency.setValueAtTime(1800, startTime + 0.05);
    gain.gain.setValueAtTime(0.2, startTime);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.12);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(startTime);
    osc.stop(startTime + 0.15);

    // Kutu düşüş takırtısı
    setTimeout(() => {
      if (!this.ctx) return;
      const dropTime = this.ctx.currentTime;
      const dropOsc = this.ctx.createOscillator();
      const dropGain = this.ctx.createGain();
      dropOsc.type = 'triangle';
      dropOsc.frequency.setValueAtTime(220, dropTime);
      dropOsc.frequency.exponentialRampToValueAtTime(80, dropTime + 0.2);
      dropGain.gain.setValueAtTime(0.25, dropTime);
      dropGain.gain.exponentialRampToValueAtTime(0.001, dropTime + 0.22);
      dropOsc.connect(dropGain);
      dropGain.connect(this.ctx.destination);
      dropOsc.start(dropTime);
      dropOsc.stop(dropTime + 0.25);
    }, 250);
  }

  /**
   * Su Yudumlama Sesi
   */
  playSip() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    const startTime = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(450, startTime);
    osc.frequency.exponentialRampToValueAtTime(620, startTime + 0.12);
    osc.frequency.exponentialRampToValueAtTime(320, startTime + 0.22);

    gain.gain.setValueAtTime(0.12, startTime);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.25);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(startTime);
    osc.stop(startTime + 0.27);
  }

  /**
   * Basketbol Topu Sesi
   */
  playBasketballBounce() {
    if (this.isMuted || !this.ctx) return;
    this.resume();
    const startTime = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(130, startTime);
    osc.frequency.exponentialRampToValueAtTime(50, startTime + 0.14);

    gain.gain.setValueAtTime(0.3, startTime);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.15);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(startTime);
    osc.stop(startTime + 0.17);
  }
}

export const soundEngine = new SoundEngine();
