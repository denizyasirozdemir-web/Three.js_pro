import { soundEngine } from './audio.js';

/**
 * Oyun Mekanikleri, Dersler, Karne ve Etkileşim Yöneticisi
 */

export class GameplayManager {
  constructor(school, player) {
    this.school = school;
    this.player = player;

    // Öğrenci Durumu & Karne Verileri
    this.studentData = {
      name: 'Deniz Yılmaz',
      number: '1042',
      class: '11-A',
      energy: 100,
      grades: {
        math: null,
        science: null,
        coding: null,
        history: null
      }
    };

    // Okul Zamanı ve Ders Takvimi
    this.periods = [
      { time: '09:00', name: '1. Ders: Matematik (Oda 101)', quest: 'Matematik sınıfına (101) git ve derse katıl', type: 'math' },
      { time: '10:15', name: '2. Ders: Fen & Fizik Labı (Oda 102)', quest: 'Fen Laboratuvarına (102) geç ve deneye başla', type: 'science' },
      { time: '11:30', name: 'Teneffüs: Kantin & Bahçe', quest: 'Kantinden atıştırmalık al veya bahçede basket at', type: 'recess' },
      { time: '12:45', name: '3. Ders: Bilişim & Kodlama (Oda 103)', quest: 'Bilişim Laboratuvarına (103) git ve kod yaz', type: 'coding' },
      { time: '14:00', name: '4. Ders: Tarih & Edebiyat (Oda 104)', quest: 'Tarih sınıfına (104) geç ve sınava katıl', type: 'history' },
      { time: '15:15', name: 'Günün Sonu: Serbest Zaman', quest: 'Karne butonuna basarak notlarını incele!', type: 'free' }
    ];
    this.currentPeriodIndex = 0;

    // Ders Soruları Havuzu
    this.quizQuestions = {
      math: [
        {
          q: 'Bir dik üçgende dik kenarlar 6 cm ve 8 cm ise hipotenüs uzunluğu kaç cm\'dir?',
          opts: ['9 cm', '10 cm', '12 cm', '14 cm'],
          ans: 1,
          exp: 'Pisagor teoremine göre: √(6² + 8²) = √(36 + 64) = √100 = 10 cm!'
        },
        {
          q: '2x + 14 = 30 denkleminde x kaçtır?',
          opts: ['6', '8', '10', '12'],
          ans: 1,
          exp: '2x = 30 - 14 = 16 => x = 8.'
        },
        {
          q: 'Yarıçapı r = 5 olan bir dairenin çevresi nedir? (π = 3 alınız)',
          opts: ['15', '25', '30', '75'],
          ans: 2,
          exp: 'Dairenin çevresi 2 * π * r = 2 * 3 * 5 = 30.'
        }
      ],
      science: [
        {
          q: 'Suyun kimyasal formülü ve moleküler yapısı hangisidir?',
          opts: ['CO₂ (Karbondioksit)', 'H₂O (İki Hidrojen, Bir Oksijen)', 'NaCl (Sodyum Klorür)', 'CH₄ (Metan)'],
          ans: 1,
          exp: 'Su molekülü iki hidrojen ve bir oksijen atomunun kovalent bağıyla (H₂O) oluşur.'
        },
        {
          q: 'Dünya yüzeyindeki ortalama yerçekimi ivmesi (g) yaklaşık kaç m/s²\'dir?',
          opts: ['5.2 m/s²', '9.8 m/s²', '12.4 m/s²', '15.0 m/s²'],
          ans: 1,
          exp: 'Dünya\'da standart yerçekimi ivmesi yaklaşık 9.80665 m/s² olarak kabul edilir.'
        },
        {
          q: 'Bitkilerin güneş ışığı ve klorofil yardımıyla besin üretmesi sürecine ne denir?',
          opts: ['Fermantasyon', 'Oksidasyon', 'Fotosentez', 'Süblimleşme'],
          ans: 2,
          exp: 'Fotosentez sayesinde bitkiler su ve karbondioksiti glikoz ve oksijene dönüştürür.'
        }
      ],
      coding: [
        {
          q: 'Programlamada hangisi döngü (loop) yapısı oluşturmak için kullanılır?',
          opts: ['if / else', 'for / while', 'return', 'const'],
          ans: 1,
          exp: 'Bir kod bloğunu birden fazla kez tekrarlamak için for ve while döngüleri kullanılır.'
        },
        {
          q: 'Aşağıdakilerden hangisi bir web sayfasının stil ve tasarımını tanımlar?',
          opts: ['HTML', 'SQL', 'CSS (Cascading Style Sheets)', 'Python'],
          ans: 2,
          exp: 'CSS, HTML elemanlarının renk, konum, animasyon ve görsel düzenini belirler.'
        },
        {
          q: 'İkili (Binary) sayı sisteminde 101 sayısı onluk tabanda kaça eşittir?',
          opts: ['3', '5', '6', '7'],
          ans: 1,
          exp: '(1 * 2²) + (0 * 2¹) + (1 * 2⁰) = 4 + 0 + 1 = 5.'
        }
      ],
      history: [
        {
          q: 'Türkiye Cumhuriyeti hangi yılda ilan edilmiştir?',
          opts: ['1919', '1920', '1923', '1938'],
          ans: 2,
          exp: '29 Ekim 1923 tarihinde Cumhuriyet resmen ilan edilmiştir.'
        },
        {
          q: 'Matbaayı hareketli harflerle modern hale getiren ve basım devrimini başlatan mucit kimdir?',
          opts: ['Johannes Gutenberg', 'Isaac Newton', 'Galileo Galilei', 'Leonardo da Vinci'],
          ans: 0,
          exp: 'Johannes Gutenberg 1440 yılında hareketli tipo baskı makinesini icat etmiştir.'
        },
        {
          q: 'Dünyanın yedi harikasından biri olan Keops Piramidi hangi ülkededir?',
          opts: ['Yunanistan', 'Mısır', 'İtalya', 'Irak'],
          ans: 1,
          exp: 'Gize Piramitleri ve Keops Piramidi Mısır\'ın Kahire kenti yakınlarında yer alır.'
        }
      ]
    };

    // Aktif Quiz Durumu
    this.activeQuiz = null;
    this.currentQuestionIdx = 0;
    this.quizScore = 0;

    this.initDOM();
    this.updateHUD();
    this.initMinimap();
  }

  initDOM() {
    this.promptEl = document.getElementById('interaction-prompt');
    this.promptTitle = document.getElementById('prompt-title');
    this.promptDesc = document.getElementById('prompt-desc');

    this.schoolPeriodEl = document.getElementById('school-period');
    this.questTextEl = document.getElementById('quest-text');
    this.statGradeEl = document.getElementById('stat-grade');
    this.energyFillEl = document.getElementById('energy-fill');

    // Buton Dinleyicileri
    document.getElementById('btn-report')?.addEventListener('click', () => this.openReportCard());
    document.getElementById('btn-bell')?.addEventListener('click', () => this.ringBellManually());
    document.getElementById('btn-sound')?.addEventListener('click', (e) => {
      const muted = soundEngine.toggleMute();
      e.currentTarget.classList.toggle('active', !muted);
      e.currentTarget.innerHTML = muted ? '🔇 Ses: Kapalı' : '🔊 Ses: Açık';
    });

    document.getElementById('btn-mobile-toggle')?.addEventListener('click', () => {
      const isMob = window.controlsManager?.toggleMobileControls();
      document.getElementById('btn-mobile-toggle').classList.toggle('active', isMob);
    });

    // Modal Kapatma Butonları
    document.querySelectorAll('.modal-close-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.modal-overlay').forEach(m => m.classList.remove('active'));
      });
    });

    // İpucu tıklandığında etkileşimi çalıştır
    this.promptEl?.addEventListener('click', () => {
      if (this.currentActiveZone) {
        this.currentActiveZone.action();
      }
    });

    this.initLockerSwatches();
  }

  initLockerSwatches() {
    // Ceket Renkleri
    const blazerColors = [
      { hex: 0x1e3a8a, bg: '#1e3a8a', name: 'Klasik Lacivert' },
      { hex: 0xb91c1c, bg: '#b91c1c', name: 'Bordo Kırmızı' },
      { hex: 0x065f46, bg: '#065f46', name: 'Zümrüt Yeşil' },
      { hex: 0x0f172a, bg: '#0f172a', name: 'Gece Siyahı' },
      { hex: 0xd97706, bg: '#d97706', name: 'Hardal Sarısı' }
    ];

    const blazerContainer = document.getElementById('blazer-swatches');
    if (blazerContainer) {
      blazerContainer.innerHTML = '';
      blazerColors.forEach((col, idx) => {
        const swatch = document.createElement('div');
        swatch.className = `color-swatch ${idx === 0 ? 'selected' : ''}`;
        swatch.style.backgroundColor = col.bg;
        swatch.title = col.name;
        swatch.onclick = () => {
          blazerContainer.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
          swatch.classList.add('selected');
          this.player.setBlazerColor(col.hex);
          soundEngine.playInteract();
          this.showToast(`Ceket rengi değiştirildi: ${col.name}`);
        };
        blazerContainer.appendChild(swatch);
      });
    }

    // Çanta Renkleri
    const backpackColors = [
      { hex: 0x06b6d4, bg: '#06b6d4', name: 'Turkuaz Mavi' },
      { hex: 0xa855f7, bg: '#a855f7', name: 'Mor Neon' },
      { hex: 0xef4444, bg: '#ef4444', name: 'Alev Kırmızı' },
      { hex: 0x10b981, bg: '#10b981', name: 'Nane Yeşili' },
      { hex: 0x1e293b, bg: '#1e293b', name: 'Koyu Gri' }
    ];

    const backpackContainer = document.getElementById('backpack-swatches');
    if (backpackContainer) {
      backpackContainer.innerHTML = '';
      backpackColors.forEach((col, idx) => {
        const swatch = document.createElement('div');
        swatch.className = `color-swatch ${idx === 0 ? 'selected' : ''}`;
        swatch.style.backgroundColor = col.bg;
        swatch.title = col.name;
        swatch.onclick = () => {
          backpackContainer.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
          swatch.classList.add('selected');
          this.player.setBackpackColor(col.hex);
          soundEngine.playInteract();
          this.showToast(`Çanta rengi değiştirildi: ${col.name}`);
        };
        backpackContainer.appendChild(swatch);
      });
    }
  }

  update(delta) {
    // 1. Etkileşim Alanlarını Kontrol Et
    this.checkInteractiveZones();

    // 2. Enerji Tüketimi (Koşarken hafif azalır)
    if (this.player.currentState === 'run' && this.studentData.energy > 5) {
      this.studentData.energy = Math.max(0, this.studentData.energy - delta * 2.5);
      if (this.energyFillEl) {
        this.energyFillEl.style.width = `${this.studentData.energy}%`;
      }
    }

    // 3. Mini Haritayı Güncelle
    this.renderMinimap();
  }

  checkInteractiveZones() {
    const playerPos = this.player.position;
    let closestZone = null;
    let minDist = Infinity;

    for (const zone of this.school.interactiveZones) {
      const dist = playerPos.distanceTo(zone.position);
      if (dist <= zone.radius) {
        if (dist < minDist) {
          minDist = dist;
          closestZone = zone;
        }
      }
    }

    if (closestZone) {
      this.currentActiveZone = closestZone;
      if (this.promptEl) {
        this.promptTitle.textContent = closestZone.title;
        this.promptDesc.textContent = closestZone.desc;
        this.promptEl.classList.add('visible');
      }

      // [E] tuşuna veya mobil etkileşim butonuna basıldıysa
      if (window.controlsManager?.interactRequested) {
        window.controlsManager.interactRequested = false;
        closestZone.action();
      }
    } else {
      this.currentActiveZone = null;
      if (this.promptEl) {
        this.promptEl.classList.remove('visible');
      }
    }
  }

  startLesson(subjectType) {
    const questions = this.quizQuestions[subjectType];
    if (!questions) return;

    soundEngine.playInteract();
    this.activeQuiz = {
      subject: subjectType,
      questions: questions
    };
    this.currentQuestionIdx = 0;
    this.quizScore = 0;

    const modal = document.getElementById('lesson-modal');
    const titleEl = document.getElementById('lesson-modal-title');
    const subtitleEl = document.getElementById('lesson-modal-subtitle');
    const iconEl = document.getElementById('lesson-modal-icon');

    const subjectTitles = {
      math: { title: 'Matematik Dersi (101)', subtitle: 'Kürsü & Soru Çözümü', icon: '📐' },
      science: { title: 'Fen Bilimleri & Fizik Labı (102)', subtitle: 'Deney & Teori Sınavı', icon: '🧪' },
      coding: { title: 'Bilişim & Kodlama Labı (103)', subtitle: 'Algoritma & Programlama', icon: '💻' },
      history: { title: 'Tarih & Edebiyat Dersi (104)', subtitle: 'Genel Kültür & Tarih', icon: '📜' }
    };

    const sInfo = subjectTitles[subjectType];
    if (titleEl) titleEl.textContent = sInfo.title;
    if (subtitleEl) subtitleEl.textContent = sInfo.subtitle;
    if (iconEl) iconEl.textContent = sInfo.icon;

    document.getElementById('quiz-result-banner').style.display = 'none';
    document.getElementById('quiz-content').style.display = 'block';

    modal.classList.add('active');
    this.renderCurrentQuestion();
  }

  renderCurrentQuestion() {
    const qData = this.activeQuiz.questions[this.currentQuestionIdx];
    const totalQ = this.activeQuiz.questions.length;

    document.getElementById('quiz-q-num').textContent = `SORU ${this.currentQuestionIdx + 1} / ${totalQ}`;
    document.getElementById('quiz-q-text').textContent = qData.q;
    document.getElementById('quiz-progress-fill').style.width = `${((this.currentQuestionIdx + 1) / totalQ) * 100}%`;

    const optionsList = document.getElementById('quiz-options-list');
    optionsList.innerHTML = '';

    const letters = ['A', 'B', 'C', 'D'];
    qData.opts.forEach((optText, idx) => {
      const btn = document.createElement('button');
      btn.className = 'quiz-option-btn';
      btn.innerHTML = `
        <span class="quiz-option-letter">${letters[idx]}</span>
        <span>${optText}</span>
      `;

      btn.onclick = () => {
        // Seçenek butonlarını kitle
        optionsList.querySelectorAll('.quiz-option-btn').forEach(b => b.disabled = true);

        if (idx === qData.ans) {
          btn.classList.add('correct');
          this.quizScore++;
          soundEngine.playCorrect();
          this.showToast('Tebrikler! Doğru cevap.');
        } else {
          btn.classList.add('wrong');
          optionsList.children[qData.ans].classList.add('correct');
          soundEngine.playWrong();
          this.showToast(`Yanlış! Doğru cevap: ${letters[qData.ans]}`);
        }

        // Sonraki soruya geç veya sonucu göster
        setTimeout(() => {
          this.currentQuestionIdx++;
          if (this.currentQuestionIdx < totalQ) {
            this.renderCurrentQuestion();
          } else {
            this.finishQuiz();
          }
        }, 1200);
      };

      optionsList.appendChild(btn);
    });
  }

  finishQuiz() {
    document.getElementById('quiz-content').style.display = 'none';
    const resultBanner = document.getElementById('quiz-result-banner');
    resultBanner.style.display = 'flex';

    const totalQ = this.activeQuiz.questions.length;
    const scorePct = Math.round((this.quizScore / totalQ) * 100);

    let letterGrade = 'C';
    if (scorePct >= 90) letterGrade = 'A+';
    else if (scorePct >= 70) letterGrade = 'A';
    else if (scorePct >= 50) letterGrade = 'B';

    this.studentData.grades[this.activeQuiz.subject] = {
      score: scorePct,
      grade: letterGrade
    };

    document.getElementById('quiz-score-badge').textContent = `${scorePct} PUAN (${letterGrade})`;
    document.getElementById('quiz-summary-text').textContent =
      `Dersi başarıyla tamamladın! Notun karnene işlendi. (${this.quizScore}/${totalQ} Doğru)`;

    this.player.triggerCheer();
    this.updateHUD();

    // Bir sonraki derse geç
    this.advancePeriod();
  }

  advancePeriod() {
    this.currentPeriodIndex = (this.currentPeriodIndex + 1) % this.periods.length;
    soundEngine.playSchoolBell();
    this.updateHUD();
    const period = this.periods[this.currentPeriodIndex];
    this.showToast(`🔔 Okul Zili Çaldı! Yeni Ders: ${period.name}`);
  }

  ringBellManually() {
    soundEngine.playSchoolBell();
    this.showToast('🔔 Okul zili manuel olarak çalındı!');
  }

  openReportCard() {
    soundEngine.playInteract();
    const modal = document.getElementById('report-modal');

    // Notları Tabloya Doldur
    const tbody = document.getElementById('report-grades-body');
    if (tbody) {
      tbody.innerHTML = '';
      const subjects = [
        { key: 'math', name: 'Matematik ve Geometri' },
        { key: 'science', name: 'Fen Bilimleri ve Fizik' },
        { key: 'coding', name: 'Bilişim ve Yazılım' },
        { key: 'history', name: 'Tarih ve Edebiyat' }
      ];

      let totalScore = 0;
      let gradedCount = 0;

      subjects.forEach(sub => {
        const gradeInfo = this.studentData.grades[sub.key];
        const tr = document.createElement('tr');
        if (gradeInfo) {
          totalScore += gradeInfo.score;
          gradedCount++;
          tr.innerHTML = `
            <td>${sub.name}</td>
            <td>%${gradeInfo.score}</td>
            <td><span class="grade-badge grade-A">${gradeInfo.grade}</span></td>
          `;
        } else {
          tr.innerHTML = `
            <td>${sub.name}</td>
            <td>Henüz Katılınmadı</td>
            <td><span class="grade-badge grade-None">-</span></td>
          `;
        }
        tbody.appendChild(tr);
      });

      const avg = gradedCount > 0 ? Math.round(totalScore / gradedCount) : 0;
      document.getElementById('report-gpa-val').textContent = avg > 0 ? `${avg} / 100` : 'Not Bekleniyor';
    }

    modal.classList.add('active');
  }

  openLockerCustomizer() {
    soundEngine.playInteract();
    const modal = document.getElementById('locker-modal');
    modal.classList.add('active');
  }

  buySnack(type = 'vending') {
    soundEngine.playVending();
    this.studentData.energy = 100;
    if (this.energyFillEl) this.energyFillEl.style.width = '100%';
    this.showToast(type === 'lunch' ? '🍔 Kantin tostu yendi! Enerjin %100 oldu.' : '🥤 Enerji içeceği alındı! Enerjin yenilendi.');
  }

  drinkWater() {
    soundEngine.playSip();
    this.studentData.energy = Math.min(100, this.studentData.energy + 25);
    if (this.energyFillEl) this.energyFillEl.style.width = `${this.studentData.energy}%`;
    this.showToast('💧 Soğuk su içtin, ferahladın! Enerji +%25');
  }

  shootBasketball(ballMesh, hoopPos) {
    soundEngine.playBasketballBounce();
    this.showToast('🏀 Şut çekildi! Harika bir üçlük!');
    this.player.triggerCheer();

    // Topun potaya kavisli uçuş animasyonu
    const startPos = ballMesh.position.clone();
    let progress = 0;

    const animateShot = () => {
      progress += 0.04;
      if (progress <= 1.0) {
        ballMesh.position.x = THREE.MathUtils.lerp(startPos.x, hoopPos.x, progress);
        ballMesh.position.z = THREE.MathUtils.lerp(startPos.z, hoopPos.z, progress);
        // Parabolik atış yüksekliği
        ballMesh.position.y = startPos.y + Math.sin(progress * Math.PI) * 4.2;
        requestAnimationFrame(animateShot);
      } else {
        // Çemberden geçip yere sekme
        soundEngine.playBasketballBounce();
        ballMesh.position.set(hoopPos.x, 0.24, hoopPos.z);
        setTimeout(() => {
          ballMesh.position.copy(startPos);
        }, 2000);
      }
    };
    animateShot();
  }

  showNPCDialog(name, speech) {
    soundEngine.playInteract();
    const modal = document.getElementById('npc-modal');
    document.getElementById('npc-modal-title').textContent = name;
    document.getElementById('npc-modal-speech').textContent = speech;
    modal.classList.add('active');
  }

  updateHUD() {
    const period = this.periods[this.currentPeriodIndex];
    if (this.schoolPeriodEl) this.schoolPeriodEl.textContent = `${period.time} - ${period.name}`;
    if (this.questTextEl) this.questTextEl.textContent = period.quest;

    // Karne GPA Özeti
    const grades = Object.values(this.studentData.grades).filter(g => g !== null);
    if (grades.length > 0) {
      const avg = Math.round(grades.reduce((a, b) => a + b.score, 0) / grades.length);
      if (this.statGradeEl) this.statGradeEl.textContent = `${avg}`;
    } else {
      if (this.statGradeEl) this.statGradeEl.textContent = '100';
    }
  }

  showToast(message) {
    const container = document.getElementById('toast-container');
    if (!container) return;
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(-10px)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 2800);
  }

  /**
   * MİNİ HARİTA (MINIMAP) ÇİZİCİ
   */
  initMinimap() {
    this.mmCanvas = document.getElementById('minimap-canvas');
    if (!this.mmCanvas) return;
    this.mmCtx = this.mmCanvas.getContext('2d');
  }

  renderMinimap() {
    if (!this.mmCtx || !this.mmCanvas) return;
    const ctx = this.mmCtx;
    const w = this.mmCanvas.width;
    const h = this.mmCanvas.height;

    ctx.clearRect(0, 0, w, h);

    // Harita Arka Planı
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, w, h);

    // Koordinat Dönüşümü: Dünya (X: -30..30, Z: -50..40) -> 2D Canvas
    const scaleX = w / 60;
    const scaleZ = h / 90;
    const toMapX = (wx) => (wx + 30) * scaleX;
    const toMapY = (wz) => (wz + 50) * scaleZ;

    // 1. Okul Binası ve Odaları
    // Koridor
    ctx.fillStyle = 'rgba(79, 70, 229, 0.25)';
    ctx.fillRect(toMapX(-4), toMapY(-36), 8 * scaleX, 40 * scaleZ);

    // Sınıflar
    const rooms = [
      { name: '101', x: -19, z: -14, w: 14, l: 12, col: 'rgba(59, 130, 246, 0.4)' },
      { name: '102', x: 5, z: -14, w: 14, l: 12, col: 'rgba(16, 185, 129, 0.4)' },
      { name: '103', x: -19, z: -30, w: 14, l: 12, col: 'rgba(6, 182, 212, 0.4)' },
      { name: '104', x: 5, z: -30, w: 14, l: 12, col: 'rgba(245, 158, 11, 0.4)' },
      { name: 'Kantin', x: -10, z: -50, w: 20, l: 14, col: 'rgba(239, 68, 68, 0.4)' },
      { name: 'Bahçe', x: -25, z: 5, w: 50, l: 35, col: 'rgba(34, 197, 94, 0.2)' }
    ];

    rooms.forEach(r => {
      ctx.fillStyle = r.col;
      ctx.fillRect(toMapX(r.x), toMapY(r.z), r.w * scaleX, r.l * scaleZ);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
      ctx.strokeRect(toMapX(r.x), toMapY(r.z), r.w * scaleX, r.l * scaleZ);

      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 9px sans-serif';
      ctx.fillText(r.name, toMapX(r.x + 1), toMapY(r.z + 4));
    });

    // 2. Oyuncu Pozisyonu ve Yön Oku
    const pX = toMapX(this.player.position.x);
    const pY = toMapY(this.player.position.z);

    ctx.save();
    ctx.translate(pX, pY);
    ctx.rotate(-this.player.rotation);

    // Görüş üçgeni / yön oku
    ctx.fillStyle = '#38bdf8';
    ctx.beginPath();
    ctx.moveTo(0, 7);
    ctx.lineTo(-4, -5);
    ctx.lineTo(4, -5);
    ctx.closePath();
    ctx.fill();

    // Oyuncu parlak noktası
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(0, 0, 3.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  }
}
