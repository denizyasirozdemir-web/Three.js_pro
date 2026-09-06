import * as THREE from 'three';

/**
 * 3D Okul Kampüsü ve Sınıf Ortamları
 * Matematik, Fen Labı, Bilişim Labı, Tarih Sınıfı, Koridor, Kantin ve Bahçe (Basketbol Sahası).
 */

export class SchoolCampus {
  constructor(scene) {
    this.scene = scene;
    this.colliders = []; // Karakter çarpışma kutuları
    this.interactiveZones = []; // Etkileşim noktaları
    this.animatedObjects = []; // Güncellenecek animasyonlu objeler (ekranlar, alevler, bayrak)

    this.initProceduralTextures();
    this.initCampus();
  }

  initProceduralTextures() {
    // 1. Koridor Zemin Fayans Dokusu
    const tileCanvas = document.createElement('canvas');
    tileCanvas.width = 512;
    tileCanvas.height = 512;
    const tileCtx = tileCanvas.getContext('2d');
    tileCtx.fillStyle = '#1e293b';
    tileCtx.fillRect(0, 0, 512, 512);
    tileCtx.strokeStyle = '#334155';
    tileCtx.lineWidth = 4;
    for (let i = 0; i <= 512; i += 64) {
      tileCtx.beginPath();
      tileCtx.moveTo(i, 0); tileCtx.lineTo(i, 512);
      tileCtx.moveTo(0, i); tileCtx.lineTo(512, i);
      tileCtx.stroke();
    }
    this.tileTexture = new THREE.CanvasTexture(tileCanvas);
    this.tileTexture.wrapS = THREE.RepeatWrapping;
    this.tileTexture.wrapT = THREE.RepeatWrapping;

    // 2. Matematik Yazı Tahtası Dokusu
    const boardCanvas = document.createElement('canvas');
    boardCanvas.width = 1024;
    boardCanvas.height = 512;
    const bCtx = boardCanvas.getContext('2d');
    bCtx.fillStyle = '#064e3b'; // Koyu yeşil klasik okul tahtası
    bCtx.fillRect(0, 0, 1024, 512);
    bCtx.strokeStyle = '#047857';
    bCtx.lineWidth = 6;
    bCtx.strokeRect(6, 6, 1012, 500);

    bCtx.fillStyle = '#f0fdf4';
    bCtx.font = 'bold 36px sans-serif';
    bCtx.fillText('MATEMATİK VE GEOMETRİ', 60, 70);

    bCtx.font = '28px monospace';
    bCtx.fillStyle = '#e2e8f0';
    bCtx.fillText('1) f(x) = ax² + bx + c  =>  Δ = b² - 4ac', 60, 140);
    bCtx.fillText('2) Euler: e^(iπ) + 1 = 0', 60, 200);
    bCtx.fillText('3) Trigonometri: sin²(θ) + cos²(θ) = 1', 60, 260);
    bCtx.fillText('4) İntegral: ∫ 2x dx = x² + C', 60, 320);
    bCtx.fillText('5) Hipotenüs: c = √(a² + b²)', 60, 380);

    // Tahtaya üçgen çizimi
    bCtx.strokeStyle = '#fef08a';
    bCtx.lineWidth = 3;
    bCtx.beginPath();
    bCtx.moveTo(820, 340);
    bCtx.lineTo(950, 340);
    bCtx.lineTo(820, 200);
    bCtx.closePath();
    bCtx.stroke();
    bCtx.fillStyle = '#fef08a';
    bCtx.font = '20px sans-serif';
    bCtx.fillText('90° Dik Üçgen', 810, 370);

    this.boardTexture = new THREE.CanvasTexture(boardCanvas);

    // 3. Bilgisayar Terminal Ekran Dokusu
    const codeCanvas = document.createElement('canvas');
    codeCanvas.width = 512;
    codeCanvas.height = 256;
    const cCtx = codeCanvas.getContext('2d');
    cCtx.fillStyle = '#090d16';
    cCtx.fillRect(0, 0, 512, 256);
    cCtx.fillStyle = '#10b981';
    cCtx.font = '16px monospace';
    cCtx.fillText('// PYTHON & JAVASCRIPT WORKSPACE', 20, 35);
    cCtx.fillStyle = '#38bdf8';
    cCtx.fillText('const academy = new SchoolSimulation();', 20, 70);
    cCtx.fillText('academy.startLesson("Coding");', 20, 100);
    cCtx.fillStyle = '#f59e0b';
    cCtx.fillText('for (let student of students) {', 20, 135);
    cCtx.fillText('   student.learn(Knowledge.INFINITY);', 40, 165);
    cCtx.fillText('}', 20, 195);
    cCtx.fillStyle = '#a855f7';
    cCtx.fillText('console.log("Ders Başarıyla Tamamlandı!");', 20, 230);
    this.codeTexture = new THREE.CanvasTexture(codeCanvas);

    // 4. Periyodik Tablo / Fen Posteri Dokusu
    const sciCanvas = document.createElement('canvas');
    sciCanvas.width = 512;
    sciCanvas.height = 256;
    const sCtx = sciCanvas.getContext('2d');
    sCtx.fillStyle = '#0f172a';
    sCtx.fillRect(0, 0, 512, 256);
    sCtx.fillStyle = '#38bdf8';
    sCtx.font = 'bold 24px sans-serif';
    sCtx.fillText('PERİYODİK TABLO & FİZİK', 40, 45);
    // Element kutuları
    const elements = [
      { s: 'H', n: 1, c: '#38bdf8' }, { s: 'He', n: 2, c: '#a855f7' },
      { s: 'Li', n: 3, c: '#ef4444' }, { s: 'C', n: 6, c: '#10b981' },
      { s: 'N', n: 7, c: '#f59e0b' }, { s: 'O', n: 8, c: '#06b6d4' },
      { s: 'Na', n: 11, c: '#ec4899' }, { s: 'Au', n: 79, c: '#eab308' }
    ];
    elements.forEach((el, idx) => {
      const col = idx % 4;
      const row = Math.floor(idx / 4);
      const x = 40 + col * 110;
      const y = 70 + row * 80;
      sCtx.fillStyle = 'rgba(255,255,255,0.06)';
      sCtx.fillRect(x, y, 90, 70);
      sCtx.strokeStyle = el.c;
      sCtx.strokeRect(x, y, 90, 70);
      sCtx.fillStyle = el.c;
      sCtx.font = 'bold 26px sans-serif';
      sCtx.fillText(el.s, x + 25, y + 42);
      sCtx.font = '12px sans-serif';
      sCtx.fillText('No: ' + el.n, x + 25, y + 60);
    });
    this.scienceTexture = new THREE.CanvasTexture(sciCanvas);

    // 5. Dünya Haritası / Tarih Dokusu
    const mapCanvas = document.createElement('canvas');
    mapCanvas.width = 512;
    mapCanvas.height = 256;
    const mCtx = mapCanvas.getContext('2d');
    mCtx.fillStyle = '#0284c7';
    mCtx.fillRect(0, 0, 512, 256);
    mCtx.fillStyle = '#15803d';
    // Kıtalar (Basitleştirilmiş stilize kıtalar)
    mCtx.beginPath();
    mCtx.ellipse(130, 90, 60, 45, 0, 0, Math.PI * 2);
    mCtx.ellipse(170, 170, 45, 60, 0.2, 0, Math.PI * 2);
    mCtx.ellipse(320, 80, 80, 45, 0, 0, Math.PI * 2);
    mCtx.ellipse(340, 160, 50, 50, 0, 0, Math.PI * 2);
    mCtx.fill();
    mCtx.fillStyle = '#ffffff';
    mCtx.font = 'bold 20px sans-serif';
    mCtx.fillText('TARİH VE DÜNYA COĞRAFYASI', 110, 30);
    this.mapTexture = new THREE.CanvasTexture(mapCanvas);
  }

  initCampus() {
    this.materials = {
      wall: new THREE.MeshStandardMaterial({ color: 0xf1f5f9, roughness: 0.8 }),
      wallAccent: new THREE.MeshStandardMaterial({ color: 0x3b82f6, roughness: 0.6 }),
      classroomFloor: new THREE.MeshStandardMaterial({ color: 0x94a3b8, roughness: 0.7 }),
      wood: new THREE.MeshStandardMaterial({ color: 0x78350f, roughness: 0.5 }),
      metal: new THREE.MeshStandardMaterial({ color: 0x64748b, roughness: 0.3, metalness: 0.7 }),
      glass: new THREE.MeshPhysicalMaterial({ color: 0xffffff, transparent: true, opacity: 0.35, roughness: 0.1, transmission: 0.9 }),
      grass: new THREE.MeshStandardMaterial({ color: 0x15803d, roughness: 0.9 }),
      concrete: new THREE.MeshStandardMaterial({ color: 0x64748b, roughness: 0.8 }),
      asphalt: new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.85 }),
      locker: new THREE.MeshStandardMaterial({ color: 0x2563eb, roughness: 0.4, metalness: 0.5 }),
      redLocker: new THREE.MeshStandardMaterial({ color: 0xd97706, roughness: 0.4, metalness: 0.5 }),
      gold: new THREE.MeshStandardMaterial({ color: 0xf59e0b, metalness: 0.8, roughness: 0.2 }),
      tieMat: new THREE.MeshStandardMaterial({ color: 0xdc2626, roughness: 0.4 }),
      pantsMat: new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.6 }),
      shoesMat: new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.3 })
    };

    // 1. Zemin ve Bahçe
    this.createCourtyard();

    // 2. Ana Koridor
    this.createMainHallway();

    // 3. Sınıf 101: Matematik
    this.createMathClass();

    // 4. Sınıf 102: Fen & Fizik Labı
    this.createScienceLab();

    // 5. Sınıf 103: Bilişim Labı
    this.createComputerLab();

    // 6. Sınıf 104: Tarih & Edebiyat
    this.createHistoryClass();

    // 7. Kantin & Dinlenme Alanı
    this.createCafeteria();

    // 8. NPC'ler (Öğretmen ve Öğrenci)
    this.createNPCs();
  }

  addCollider(minX, maxX, minZ, maxZ) {
    this.colliders.push({
      isBox: true,
      min: new THREE.Vector3(minX, 0, minZ),
      max: new THREE.Vector3(maxX, 10, maxZ)
    });
  }

  registerInteractiveZone(id, position, radius, title, desc, actionCallback) {
    this.interactiveZones.push({
      id,
      position: position.clone(),
      radius,
      title,
      desc,
      action: actionCallback
    });

    // Zemin üzerine hafif parıldayan etkileşim halkası
    const ringGeo = new THREE.RingGeometry(radius * 0.4, radius * 0.5, 32);
    const ringMat = new THREE.MeshBasicMaterial({
      color: 0x06b6d4,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: 0.45
    });
    const ringMesh = new THREE.Mesh(ringGeo, ringMat);
    ringMesh.rotation.x = -Math.PI / 2;
    ringMesh.position.set(position.x, 0.05, position.z);
    this.scene.add(ringMesh);

    this.animatedObjects.push({
      mesh: ringMesh,
      type: 'ring',
      baseScale: 1
    });
  }

  /**
   * OKUL BAHÇESİ (COURTYARD & BASKETBOL SAHASI)
   */
  createCourtyard() {
    // Çim Zemin
    const yardGeo = new THREE.PlaneGeometry(80, 50);
    const yardMesh = new THREE.Mesh(yardGeo, this.materials.grass);
    yardMesh.rotation.x = -Math.PI / 2;
    yardMesh.position.set(0, -0.02, 28);
    yardMesh.receiveShadow = true;
    this.scene.add(yardMesh);

    // Giriş Taş Yolu
    const pathGeo = new THREE.PlaneGeometry(8, 24);
    const pathMesh = new THREE.Mesh(pathGeo, this.materials.concrete);
    pathMesh.rotation.x = -Math.PI / 2;
    pathMesh.position.set(0, 0.01, 16);
    pathMesh.receiveShadow = true;
    this.scene.add(pathMesh);

    // Bahçe Ağaçları
    const treePositions = [
      [-16, 22], [-22, 32], [-28, 20],
      [16, 22], [22, 32], [28, 20]
    ];
    treePositions.forEach(([tx, tz]) => {
      this.createTree(tx, tz);
    });

    // Bahçe Bankları
    this.createBench(-10, 18, Math.PI / 2);
    this.createBench(10, 18, -Math.PI / 2);

    // Okul Bayrak Direği
    this.createFlagpole(0, 30);

    // Basketbol Sahası (Bahçenin Sağ Tarafı)
    this.createBasketballCourt(20, 32);

    // Bahçe Sınır Duvarları (Karakterin sonsuza gitmesini engeller)
    this.addCollider(-40, -38, 0, 50);
    this.addCollider(38, 40, 0, 50);
    this.addCollider(-40, 40, 48, 50);
  }

  createTree(x, z) {
    const trunk = new THREE.Mesh(
      new THREE.CylinderGeometry(0.3, 0.45, 3.5, 8),
      this.materials.wood
    );
    trunk.position.set(x, 1.75, z);
    trunk.castShadow = true;
    this.scene.add(trunk);

    const foliage = new THREE.Mesh(
      new THREE.DodecahedronGeometry(2.2, 1),
      new THREE.MeshStandardMaterial({ color: 0x166534, roughness: 0.9 })
    );
    foliage.position.set(x, 4.5, z);
    foliage.castShadow = true;
    this.scene.add(foliage);

    this.addCollider(x - 0.6, x + 0.6, z - 0.6, z + 0.6);
  }

  createBench(x, z, rotY) {
    const benchGroup = new THREE.Group();
    benchGroup.position.set(x, 0, z);
    benchGroup.rotation.y = rotY;

    // Ahşap oturak
    const seat = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.1, 0.6), this.materials.wood);
    seat.position.y = 0.5;
    seat.castShadow = true;
    benchGroup.add(seat);

    // Sırtlık
    const back = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.5, 0.08), this.materials.wood);
    back.position.set(0, 0.85, -0.28);
    back.castShadow = true;
    benchGroup.add(back);

    // Metal ayaklar
    const leg1 = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.5, 0.55), this.materials.metal);
    leg1.position.set(-0.9, 0.25, 0);
    const leg2 = leg1.clone();
    leg2.position.x = 0.9;
    benchGroup.add(leg1, leg2);

    this.scene.add(benchGroup);
    this.addCollider(x - 1.2, x + 1.2, z - 0.5, z + 0.5);
  }

  createFlagpole(x, z) {
    const pole = new THREE.Mesh(
      new THREE.CylinderGeometry(0.08, 0.12, 10, 16),
      this.materials.metal
    );
    pole.position.set(x, 5, z);
    pole.castShadow = true;
    this.scene.add(pole);

    // Kırmızı Türk Bayrağı
    const flagGeo = new THREE.PlaneGeometry(1.8, 1.2, 8, 4);
    const flagMat = new THREE.MeshStandardMaterial({
      color: 0xe11d48,
      side: THREE.DoubleSide,
      roughness: 0.6
    });
    const flagMesh = new THREE.Mesh(flagGeo, flagMat);
    flagMesh.position.set(x + 0.95, 9.2, z);
    this.scene.add(flagMesh);

    this.animatedObjects.push({
      mesh: flagMesh,
      type: 'flag'
    });

    this.addCollider(x - 0.4, x + 0.4, z - 0.4, z + 0.4);
  }

  createBasketballCourt(x, z) {
    const court = new THREE.Mesh(
      new THREE.PlaneGeometry(16, 12),
      this.materials.asphalt
    );
    court.rotation.x = -Math.PI / 2;
    court.position.set(x, 0.01, z);
    court.receiveShadow = true;
    this.scene.add(court);

    // Pota Direği
    const hoopPost = new THREE.Mesh(
      new THREE.CylinderGeometry(0.1, 0.1, 4.2, 12),
      this.materials.metal
    );
    hoopPost.position.set(x + 7.5, 2.1, z);
    hoopPost.castShadow = true;
    this.scene.add(hoopPost);

    // Pota Panyası
    const board = new THREE.Mesh(
      new THREE.BoxGeometry(0.08, 1.2, 1.8),
      this.materials.wall
    );
    board.position.set(x + 7.4, 3.8, z);
    this.scene.add(board);

    // Çember
    const rim = new THREE.Mesh(
      new THREE.TorusGeometry(0.35, 0.03, 8, 24),
      new THREE.MeshStandardMaterial({ color: 0xe11d48, roughness: 0.3 })
    );
    rim.rotation.x = Math.PI / 2;
    rim.position.set(x + 7.0, 3.5, z);
    this.scene.add(rim);

    // İnteraktif Basketbol Topu
    const ball = new THREE.Mesh(
      new THREE.SphereGeometry(0.24, 16, 16),
      new THREE.MeshStandardMaterial({ color: 0xea580c, roughness: 0.7 })
    );
    ball.position.set(x, 0.24, z);
    ball.castShadow = true;
    this.scene.add(ball);

    // Basket Atma Etkileşim Alanı
    this.registerInteractiveZone(
      'basketball',
      new THREE.Vector3(x, 0, z),
      2.5,
      'Basketbol Sahası',
      'Şut Atmak için [E] Tuşuna Bas',
      () => {
        window.gameplayManager?.shootBasketball(ball, new THREE.Vector3(x + 7.0, 3.5, z));
      }
    );
  }

  /**
   * ANA KORİDOR (MAIN HALLWAY)
   */
  createMainHallway() {
    // Koridor Zemin Döşemesi (40m x 8m)
    const floorGeo = new THREE.PlaneGeometry(8, 40);
    this.tileTexture.repeat.set(4, 20);
    const floorMat = new THREE.MeshStandardMaterial({
      map: this.tileTexture,
      roughness: 0.4
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(0, 0.01, -16);
    floor.receiveShadow = true;
    this.scene.add(floor);

    // Tavan
    const ceilingGeo = new THREE.PlaneGeometry(8, 40);
    const ceiling = new THREE.Mesh(ceilingGeo, this.materials.wall);
    ceiling.rotation.x = Math.PI / 2;
    ceiling.position.set(0, 5.0, -16);
    this.scene.add(ceiling);

    // Tavan Işıkları (LED Paneller)
    for (let z = -32; z <= 0; z += 8) {
      const panel = new THREE.Mesh(
        new THREE.BoxGeometry(2.5, 0.08, 1.2),
        new THREE.MeshBasicMaterial({ color: 0xffffff })
      );
      panel.position.set(0, 4.95, z);
      this.scene.add(panel);

      const light = new THREE.PointLight(0xfff8ed, 0.8, 12);
      light.position.set(0, 4.5, z);
      this.scene.add(light);
    }

    // Koridor Dolapları (Lockers - Sol Duvar Boyunca)
    this.createLockers(-3.7, -18);

    // Otomat (Vending Machine - Koridorun Sağ Tarafı)
    this.createVendingMachine(3.6, -10);

    // Su Sebili (Water Cooler - Sağ Taraf)
    this.createWaterCooler(3.6, -14);

    // Okul Zili (Duvarda Işıklı Zil)
    this.createSchoolBell(0, 4.3, -35.8);

    // Koridor Arka Duvarı (Z = -36)
    const backWall = new THREE.Mesh(new THREE.BoxGeometry(8, 5, 0.4), this.materials.wall);
    backWall.position.set(0, 2.5, -36);
    backWall.castShadow = true;
    this.scene.add(backWall);
    this.addCollider(-4, 4, -36.4, -35.6);

    // Giriş Kapısı Çerçevesi (Z = 4)
    this.createEntranceDoors(0, 4);
  }

  createEntranceDoors(x, z) {
    const leftWall = new THREE.Mesh(new THREE.BoxGeometry(2.5, 5, 0.4), this.materials.wall);
    leftWall.position.set(x - 2.75, 2.5, z);
    const rightWall = new THREE.Mesh(new THREE.BoxGeometry(2.5, 5, 0.4), this.materials.wall);
    rightWall.position.set(x + 2.75, 2.5, z);
    this.scene.add(leftWall, rightWall);

    this.addCollider(x - 4, x - 1.5, z - 0.2, z + 0.2);
    this.addCollider(x + 1.5, x + 4, z - 0.2, z + 0.2);

    // Cam Kapılar
    const door1 = new THREE.Mesh(new THREE.BoxGeometry(1.4, 3.2, 0.1), this.materials.glass);
    door1.position.set(x - 0.7, 1.6, z);
    const door2 = door1.clone();
    door2.position.x = x + 0.7;
    this.scene.add(door1, door2);
  }

  createSchoolBell(x, y, z) {
    const bellGroup = new THREE.Group();
    bellGroup.position.set(x, y, z);

    const base = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.6, 0.15), this.materials.metal);
    const dome = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.3, 0.2, 16), this.materials.gold);
    dome.rotation.x = Math.PI / 2;
    dome.position.z = 0.15;
    bellGroup.add(base, dome);

    this.scene.add(bellGroup);
  }

  createLockers(x, z) {
    const lockerRow = new THREE.Group();
    lockerRow.position.set(x, 0, z);

    for (let i = 0; i < 6; i++) {
      const isPlayerLocker = (i === 2);
      const locker = new THREE.Mesh(
        new THREE.BoxGeometry(0.65, 2.4, 0.7),
        isPlayerLocker ? this.materials.redLocker : this.materials.locker
      );
      locker.position.set(0, 1.2, i * 0.75);
      locker.castShadow = true;
      lockerRow.add(locker);

      // Kulp ve Numara Plakası
      const handle = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.2, 0.08), this.materials.metal);
      handle.position.set(0.35, 1.2, i * 0.75 + 0.2);
      lockerRow.add(handle);
    }
    this.scene.add(lockerRow);

    this.addCollider(x - 0.4, x + 0.4, z - 0.5, z + 5.0);

    // Kişisel Dolap Etkileşimi (Kıyafet ve Çanta Renk Seçici)
    this.registerInteractiveZone(
      'locker',
      new THREE.Vector3(x + 1.2, 0, z + 1.5),
      1.8,
      'Öğrenci Dolabı (Senin Dolabın)',
      'Kıyafet/Çanta Rengini Değiştir [E]',
      () => {
        window.gameplayManager?.openLockerCustomizer();
      }
    );
  }

  createVendingMachine(x, z) {
    const vm = new THREE.Group();
    vm.position.set(x, 0, z);

    const body = new THREE.Mesh(
      new THREE.BoxGeometry(1.2, 2.5, 0.9),
      new THREE.MeshStandardMaterial({ color: 0x0284c7, roughness: 0.3, metalness: 0.4 })
    );
    body.position.y = 1.25;
    body.castShadow = true;
    vm.add(body);

    // Cam içecek bölmesi
    const windowMesh = new THREE.Mesh(
      new THREE.BoxGeometry(0.9, 1.2, 0.05),
      new THREE.MeshBasicMaterial({ color: 0x38bdf8 })
    );
    windowMesh.position.set(-0.1, 1.6, 0.46);
    vm.add(windowMesh);

    this.scene.add(vm);
    this.addCollider(x - 0.7, x + 0.7, z - 0.6, z + 0.6);

    // Otomat Etkileşimi
    this.registerInteractiveZone(
      'vending',
      new THREE.Vector3(x - 1.2, 0, z),
      1.8,
      'Kantin Otomatı',
      'Enerji İçeceği & Tost Al [E]',
      () => {
        window.gameplayManager?.buySnack();
      }
    );
  }

  createWaterCooler(x, z) {
    const cooler = new THREE.Group();
    cooler.position.set(x, 0, z);

    const base = new THREE.Mesh(new THREE.BoxGeometry(0.6, 1.2, 0.6), this.materials.wall);
    base.position.y = 0.6;
    base.castShadow = true;

    const bottle = new THREE.Mesh(
      new THREE.CylinderGeometry(0.24, 0.24, 0.7, 16),
      new THREE.MeshPhysicalMaterial({ color: 0x06b6d4, transparent: true, opacity: 0.7 })
    );
    bottle.position.y = 1.55;

    cooler.add(base, bottle);
    this.scene.add(cooler);
    this.addCollider(x - 0.4, x + 0.4, z - 0.4, z + 0.4);

    // Su Sebili Etkileşimi
    this.registerInteractiveZone(
      'water',
      new THREE.Vector3(x - 1.0, 0, z),
      1.6,
      'Soğuk Su Sebili',
      'Su İçip Ferahla [E]',
      () => {
        window.gameplayManager?.drinkWater();
      }
    );
  }

  /**
   * SINIF 101: MATEMATİK SINIFI (MATH CLASS)
   */
  createMathClass() {
    const originX = -12;
    const originZ = -8;
    const roomWidth = 14;
    const roomLength = 12;

    this.createRoomEnclosure(originX, originZ, roomWidth, roomLength, 'MATEMATİK SINIFI (101)', true);

    // Büyük Yeşil Matematik Tahtası
    const board = new THREE.Mesh(
      new THREE.BoxGeometry(6.5, 2.6, 0.1),
      new THREE.MeshStandardMaterial({ map: this.boardTexture, roughness: 0.6 })
    );
    board.position.set(originX, 2.5, originZ - roomLength / 2 + 0.15);
    this.scene.add(board);

    // Öğretmen Kürsüsü
    this.createTeacherPodium(originX, originZ - roomLength / 2 + 2.4);

    // Öğrenci Sıraları (2 sıra x 3 sütun)
    for (let r = 0; r < 2; r++) {
      for (let c = -1; c <= 1; c++) {
        const dx = originX + c * 3.5;
        const dz = originZ + 0.5 + r * 3.2;
        const isInteractiveDesk = (r === 0 && c === 0);
        this.createStudentDesk(dx, dz, isInteractiveDesk, 'math');
      }
    }
  }

  /**
   * SINIF 102: FEN & FİZİK LABORATUVARI (SCIENCE LAB)
   */
  createScienceLab() {
    const originX = 12;
    const originZ = -8;
    const roomWidth = 14;
    const roomLength = 12;

    this.createRoomEnclosure(originX, originZ, roomWidth, roomLength, 'FEN & FİZİK LABI (102)', false);

    // Periyodik Tablo Posteri
    const poster = new THREE.Mesh(
      new THREE.BoxGeometry(5.5, 2.5, 0.08),
      new THREE.MeshStandardMaterial({ map: this.scienceTexture, roughness: 0.4 })
    );
    poster.position.set(originX, 2.6, originZ - roomLength / 2 + 0.15);
    this.scene.add(poster);

    // Laboratuvar Tezgahları (Siyah yüzeyli, musluklu)
    for (let r = 0; r < 2; r++) {
      for (let c = -1; c <= 1; c += 2) {
        const lx = originX + c * 3.6;
        const lz = originZ + r * 4.0;
        this.createLabBench(lx, lz, (r === 0 && c === -1));
      }
    }
  }

  /**
   * SINIF 103: BİLİŞİM & KODLAMA LABORATUVARI (COMPUTER LAB)
   */
  createComputerLab() {
    const originX = -12;
    const originZ = -24;
    const roomWidth = 14;
    const roomLength = 12;

    this.createRoomEnclosure(originX, originZ, roomWidth, roomLength, 'BİLİŞİM LABI (103)', true);

    // Sunucu Kabini (Köşede Parıldayan LED'ler)
    this.createServerRack(originX - 5.5, originZ - 4.5);

    // Bilgisayar Çalışma Masaları
    for (let r = 0; r < 2; r++) {
      for (let c = -1; c <= 1; c++) {
        const cx = originX + c * 3.4;
        const cz = originZ - 1.0 + r * 3.4;
        const isInteractive = (r === 0 && c === 0);
        this.createComputerWorkstation(cx, cz, isInteractive);
      }
    }
  }

  /**
   * SINIF 104: TARİH & EDEBİYAT SINIFI (HISTORY CLASS)
   */
  createHistoryClass() {
    const originX = 12;
    const originZ = -24;
    const roomWidth = 14;
    const roomLength = 12;

    this.createRoomEnclosure(originX, originZ, roomWidth, roomLength, 'TARİH & EDEBİYAT (104)', false);

    // Büyük Dünya Haritası
    const map = new THREE.Mesh(
      new THREE.BoxGeometry(6.0, 2.8, 0.08),
      new THREE.MeshStandardMaterial({ map: this.mapTexture, roughness: 0.5 })
    );
    map.position.set(originX, 2.6, originZ - roomLength / 2 + 0.15);
    this.scene.add(map);

    // Yan Duvar Kitaplıkları
    this.createBookshelf(originX + 6.3, originZ);

    // Tarih Sıraları
    for (let r = 0; r < 2; r++) {
      for (let c = -1; c <= 1; c++) {
        const hx = originX + c * 3.5;
        const hz = originZ + 0.5 + r * 3.2;
        const isInteractive = (r === 0 && c === 0);
        this.createStudentDesk(hx, hz, isInteractive, 'history');
      }
    }
  }

  /**
   * KANTİN & DİNLENME ALANI (CAFETERIA)
   */
  createCafeteria() {
    const originX = 0;
    const originZ = -44;
    const roomWidth = 20;
    const roomLength = 14;

    // Kantin Zemin & Duvarları
    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(roomWidth, roomLength),
      new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6 })
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(originX, 0.01, originZ);
    floor.receiveShadow = true;
    this.scene.add(floor);

    // Kantin Yemek Masaları (Yuvarlak masalar ve sandalyeler)
    this.createCafeteriaTable(originX - 4.5, originZ - 2);
    this.createCafeteriaTable(originX + 4.5, originZ - 2);
    this.createCafeteriaTable(originX, originZ + 2.5);

    // Kantin Servis Tezgahı
    const counter = new THREE.Mesh(
      new THREE.BoxGeometry(10, 1.2, 1.2),
      this.materials.wood
    );
    counter.position.set(originX, 0.6, originZ - 5.5);
    counter.castShadow = true;
    this.scene.add(counter);
    this.addCollider(originX - 5.2, originX + 5.2, originZ - 6.2, originZ - 4.8);

    // Kantin Etkileşimi
    this.registerInteractiveZone(
      'cafeteria',
      new THREE.Vector3(originX, 0, originZ - 3.8),
      2.5,
      'Kantin Servis Tezgahı',
      'Öğle Yemeği & Tost Al [E]',
      () => {
        window.gameplayManager?.buySnack('lunch');
      }
    );
  }

  createCafeteriaTable(x, z) {
    const tableGroup = new THREE.Group();
    tableGroup.position.set(x, 0, z);

    // Yuvarlak Masa
    const top = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, 0.08, 24), this.materials.wall);
    top.position.y = 0.8;
    top.castShadow = true;

    const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.8, 12), this.materials.metal);
    leg.position.y = 0.4;
    tableGroup.add(top, leg);

    // 4 Sandalye
    const angles = [0, Math.PI / 2, Math.PI, Math.PI * 1.5];
    angles.forEach(a => {
      const chair = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.45, 0.4), this.materials.wood);
      chair.position.set(Math.cos(a) * 1.5, 0.25, Math.sin(a) * 1.5);
      tableGroup.add(chair);
    });

    this.scene.add(tableGroup);
    this.addCollider(x - 1.6, x + 1.6, z - 1.6, z + 1.6);
  }

  /**
   * ODA DUVARLARI VE KAPISI
   */
  createRoomEnclosure(x, z, width, length, title, isLeft) {
    // Sınıf Zemin
    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(width, length),
      this.materials.classroomFloor
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(x, 0.01, z);
    floor.receiveShadow = true;
    this.scene.add(floor);

    // Dış ve Ara Duvarlar
    const wallHeight = 5.0;
    const halfW = width / 2;
    const halfL = length / 2;

    // Arka Duvar (Z min)
    const backWall = new THREE.Mesh(new THREE.BoxGeometry(width, wallHeight, 0.3), this.materials.wall);
    backWall.position.set(x, wallHeight / 2, z - halfL);
    this.scene.add(backWall);
    this.addCollider(x - halfW, x + halfW, z - halfL - 0.2, z - halfL + 0.2);

    // Ön Duvar (Z max)
    const frontWall = new THREE.Mesh(new THREE.BoxGeometry(width, wallHeight, 0.3), this.materials.wall);
    frontWall.position.set(x, wallHeight / 2, z + halfL);
    this.scene.add(frontWall);
    this.addCollider(x - halfW, x + halfW, z + halfL - 0.2, z + halfL + 0.2);

    // Dış Yan Duvar
    const outerWallX = isLeft ? x - halfW : x + halfW;
    const outerWall = new THREE.Mesh(new THREE.BoxGeometry(0.3, wallHeight, length), this.materials.wall);
    outerWall.position.set(outerWallX, wallHeight / 2, z);
    this.scene.add(outerWall);
    this.addCollider(outerWallX - 0.2, outerWallX + 0.2, z - halfL, z + halfL);

    // Koridora Bakan İç Duvar (Kapı Boşluklu)
    const innerWallX = isLeft ? x + halfW : x - halfW;
    const wallPart1 = new THREE.Mesh(new THREE.BoxGeometry(0.3, wallHeight, length * 0.38), this.materials.wall);
    wallPart1.position.set(innerWallX, wallHeight / 2, z - halfL * 0.55);

    const wallPart2 = new THREE.Mesh(new THREE.BoxGeometry(0.3, wallHeight, length * 0.38), this.materials.wall);
    wallPart2.position.set(innerWallX, wallHeight / 2, z + halfL * 0.55);

    // Kapı Üst Kiriş
    const doorLintel = new THREE.Mesh(new THREE.BoxGeometry(0.3, 1.8, 2.2), this.materials.wall);
    doorLintel.position.set(innerWallX, 4.1, z);

    this.scene.add(wallPart1, wallPart2, doorLintel);
    this.addCollider(innerWallX - 0.2, innerWallX + 0.2, z - halfL, z - 1.2);
    this.addCollider(innerWallX - 0.2, innerWallX + 0.2, z + 1.2, z + halfL);

    // Kapı Tabelası
    this.createDoorSign(innerWallX + (isLeft ? -0.2 : 0.2), 3.0, z, title, isLeft);
  }

  createDoorSign(x, y, z, text, isLeft) {
    const sign = new THREE.Mesh(
      new THREE.BoxGeometry(0.08, 0.5, 1.8),
      new THREE.MeshStandardMaterial({ color: 0x1e3a8a, roughness: 0.3 })
    );
    sign.position.set(x, y, z);
    this.scene.add(sign);
  }

  createTeacherPodium(x, z) {
    const desk = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.9, 1.1), this.materials.wood);
    desk.position.set(x, 0.45, z);
    desk.castShadow = true;

    // Kürsü üstü kitap ve lamba
    const book = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.08, 0.5), this.materials.tieMat);
    book.position.set(x - 0.5, 0.94, z);

    this.scene.add(desk, book);
    this.addCollider(x - 1.3, x + 1.3, z - 0.6, z + 0.6);
  }

  createStudentDesk(x, z, isInteractive, subjectType) {
    const deskGroup = new THREE.Group();
    deskGroup.position.set(x, 0, z);

    // Masa
    const deskTop = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.08, 0.8), this.materials.wood);
    deskTop.position.set(0, 0.76, 0);
    deskTop.castShadow = true;

    const legs = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.72, 0.6), this.materials.metal);
    legs.position.set(0, 0.36, 0);
    deskGroup.add(deskTop, legs);

    // Defter & Kalemlik
    const notebook = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.04, 0.45), this.materials.wall);
    notebook.position.set(-0.35, 0.82, 0);
    deskGroup.add(notebook);

    // Sandalye (Masanın arkasında, Z + 0.75)
    const chairSeat = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.08, 0.5), this.materials.wood);
    chairSeat.position.set(0, 0.45, 0.75);
    chairSeat.castShadow = true;

    const chairBack = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.45, 0.06), this.materials.wood);
    chairBack.position.set(0, 0.7, 0.98);

    const chairLegs = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.42, 0.4), this.materials.metal);
    chairLegs.position.set(0, 0.22, 0.75);
    deskGroup.add(chairSeat, chairBack, chairLegs);

    this.scene.add(deskGroup);
    this.addCollider(x - 0.9, x + 0.9, z - 0.5, z + 1.1);

    if (isInteractive) {
      const subjectTitles = {
        math: { title: 'Matematik Dersi (Sıra 1)', desc: 'Derse Katılmak & Soru Çözmek için [E]' },
        history: { title: 'Tarih & Edebiyat Dersi', desc: 'Tarih Sınavına Başla [E]' }
      };
      const info = subjectTitles[subjectType] || { title: 'Ders Sırası', desc: 'Derse Katıl [E]' };

      this.registerInteractiveZone(
        `desk_${subjectType}`,
        new THREE.Vector3(x, 0, z + 0.75),
        1.8,
        info.title,
        info.desc,
        () => {
          // Oyuncuyu sandalyeye oturt ve ders modalını aç
          window.player?.sitDown(new THREE.Vector3(x, 0.45, z + 0.75), 0);
          window.gameplayManager?.startLesson(subjectType);
        }
      );
    }
  }

  createLabBench(x, z, isInteractive) {
    const bench = new THREE.Group();
    bench.position.set(x, 0, z);

    // Siyah Asit Dayanıklı Tezgah
    const top = new THREE.Mesh(
      new THREE.BoxGeometry(2.4, 0.1, 1.2),
      new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.2 })
    );
    top.position.y = 0.85;
    top.castShadow = true;

    const base = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.8, 1.0), this.materials.wall);
    base.position.y = 0.4;
    bench.add(top, base);

    // Mikroskop ve Deney Tüpleri
    const tubeRack = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.25, 0.15), this.materials.wood);
    tubeRack.position.set(0.6, 1.0, 0);

    const tube1 = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.3, 8), new THREE.MeshBasicMaterial({ color: 0xef4444 }));
    tube1.position.set(0.52, 1.05, 0);
    const tube2 = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.3, 8), new THREE.MeshBasicMaterial({ color: 0x06b6d4 }));
    tube2.position.set(0.68, 1.05, 0);
    bench.add(tubeRack, tube1, tube2);

    // Bunsen Beki Alevi
    const burner = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 0.2, 12), this.materials.metal);
    burner.position.set(-0.5, 1.0, 0);
    const flame = new THREE.Mesh(
      new THREE.ConeGeometry(0.06, 0.2, 8),
      new THREE.MeshBasicMaterial({ color: 0x38bdf8 })
    );
    flame.position.set(-0.5, 1.2, 0);
    bench.add(burner, flame);

    this.animatedObjects.push({ mesh: flame, type: 'flame' });

    this.scene.add(bench);
    this.addCollider(x - 1.3, x + 1.3, z - 0.7, z + 0.7);

    if (isInteractive) {
      this.registerInteractiveZone(
        'science_lab',
        new THREE.Vector3(x, 0, z + 1.2),
        1.8,
        'Fen & Kimya Deney Masası',
        'Kimya Deneyi Yap & Derse Katıl [E]',
        () => {
          window.player?.sitDown(new THREE.Vector3(x, 0.45, z + 1.2), 0);
          window.gameplayManager?.startLesson('science');
        }
      );
    }
  }

  createComputerWorkstation(x, z, isInteractive) {
    const ws = new THREE.Group();
    ws.position.set(x, 0, z);

    // Modern Masa
    const desk = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.08, 0.9), this.materials.wall);
    desk.position.set(0, 0.75, 0);
    desk.castShadow = true;

    const legs = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.72, 0.7), this.materials.metal);
    legs.position.set(0, 0.36, 0);
    ws.add(desk, legs);

    // Geniş Kavisli Monitör
    const monitor = new THREE.Mesh(
      new THREE.BoxGeometry(1.0, 0.55, 0.05),
      new THREE.MeshStandardMaterial({ map: this.codeTexture, roughness: 0.2 })
    );
    monitor.position.set(0, 1.15, -0.2);
    monitor.castShadow = true;

    const stand = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.08, 0.35, 12), this.materials.metal);
    stand.position.set(0, 0.92, -0.2);

    // Klavye ve Fare
    const keyboard = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.03, 0.2), this.materials.shoesMat);
    keyboard.position.set(0, 0.8, 0.1);

    // RGB Kasa
    const pcCase = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.5, 0.5), new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.3 }));
    pcCase.position.set(0.65, 0.35, 0);

    ws.add(monitor, stand, keyboard, pcCase);

    // Ofis Sandalyesi
    const chair = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.5, 0.5), this.materials.shoesMat);
    chair.position.set(0, 0.35, 0.75);
    ws.add(chair);

    this.scene.add(ws);
    this.addCollider(x - 1.0, x + 1.0, z - 0.5, z + 1.1);

    if (isInteractive) {
      this.registerInteractiveZone(
        'coding_lab',
        new THREE.Vector3(x, 0, z + 0.75),
        1.8,
        'Yazılım & Kodlama İstasyonu',
        'Kodlama Egzersizine Başla [E]',
        () => {
          window.player?.sitDown(new THREE.Vector3(x, 0.45, z + 0.75), 0);
          window.gameplayManager?.startLesson('coding');
        }
      );
    }
  }

  createServerRack(x, z) {
    const rack = new THREE.Mesh(
      new THREE.BoxGeometry(1.4, 3.8, 1.0),
      new THREE.MeshStandardMaterial({ color: 0x090d16, roughness: 0.3, metalness: 0.8 })
    );
    rack.position.set(x, 1.9, z);
    rack.castShadow = true;
    this.scene.add(rack);
    this.addCollider(x - 0.8, x + 0.8, z - 0.6, z + 0.6);
  }

  createBookshelf(x, z) {
    const shelf = new THREE.Mesh(
      new THREE.BoxGeometry(0.6, 3.6, 3.8),
      this.materials.wood
    );
    shelf.position.set(x, 1.8, z);
    shelf.castShadow = true;
    this.scene.add(shelf);
    this.addCollider(x - 0.4, x + 0.4, z - 2.0, z + 2.0);
  }

  /**
   * NPC ÖĞRETMEN VE ÖĞRENCİLER
   */
  createNPCs() {
    // Matematik Öğretmeni (Sınıf 101'de Kürsü Yanında)
    this.createNPC(-12, 1.0, -11, 0x1e3a8a, 'Ahmet Hoca (Matematik)', 'Hoş geldin! Sıraya oturup matematik dersine başlayabilirsin.');

    // Fen Öğretmeni (Sınıf 102'de)
    this.createNPC(12, 1.0, -11, 0x059669, 'Selin Hoca (Fen Bilimleri)', 'Deney masasına geç ve kimyasal bileşimleri keşfet!');

    // Koridorda Konuşan Öğrenci Arkadaş
    this.createNPC(2.0, 1.0, -20, 0xd97706, 'Can (Sınıf Arkadaşın)', 'Zil çalmak üzere! Not ortalamanı yüksek tutmayı unutma.');
  }

  createNPC(x, y, z, coatColor, name, speech) {
    const npcGroup = new THREE.Group();
    npcGroup.position.set(x, y - 1.0, z);

    // Gövde
    const body = new THREE.Mesh(
      new THREE.BoxGeometry(0.5, 0.7, 0.3),
      new THREE.MeshStandardMaterial({ color: coatColor, roughness: 0.5 })
    );
    body.position.y = 0.95;
    body.castShadow = true;

    // Kafa
    const head = new THREE.Mesh(
      new THREE.BoxGeometry(0.35, 0.35, 0.3),
      new THREE.MeshStandardMaterial({ color: 0xffdbac, roughness: 0.6 })
    );
    head.position.y = 1.55;
    head.castShadow = true;

    // Bacaklar
    const legs = new THREE.Mesh(
      new THREE.BoxGeometry(0.4, 0.6, 0.25),
      this.materials.pantsMat
    );
    legs.position.y = 0.3;
    legs.castShadow = true;

    npcGroup.add(body, head, legs);
    this.scene.add(npcGroup);
    this.addCollider(x - 0.4, x + 0.4, z - 0.4, z + 0.4);

    // NPC Etkileşim Alanı
    this.registerInteractiveZone(
      `npc_${name}`,
      new THREE.Vector3(x, 0, z),
      2.0,
      name,
      'Sohbet Et [E]',
      () => {
        window.gameplayManager?.showNPCDialog(name, speech);
      }
    );
  }

  update(delta, time) {
    // Animasyonlu objeleri güncelle (parıldayan halkalar, alevler, bayrak)
    this.animatedObjects.forEach(item => {
      if (item.type === 'ring') {
        const pulse = 1.0 + Math.sin(time * 3.5) * 0.12;
        item.mesh.scale.set(pulse, pulse, 1);
      } else if (item.type === 'flame') {
        item.mesh.scale.y = 1.0 + Math.sin(time * 15) * 0.2;
        item.mesh.scale.x = 1.0 + Math.cos(time * 12) * 0.15;
      } else if (item.type === 'flag') {
        // Bayrak dalgalanma efekti
        item.mesh.rotation.y = Math.sin(time * 4) * 0.2;
      }
    });
  }
}
