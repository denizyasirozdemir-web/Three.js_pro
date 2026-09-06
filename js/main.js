import * as THREE from 'three';
import { SchoolCampus } from './school.js';
import { ThirdPersonPlayer } from './player.js';
import { ControlsManager } from './controls.js';
import { GameplayManager } from './gameplay.js';
import { soundEngine } from './audio.js';

/**
 * 3D Okul Simülasyonu - Ana Giriş Noktası
 */

class SchoolApp {
  constructor() {
    this.container = document.getElementById('canvas-container');
    this.clock = new THREE.Clock();

    this.initScene();
    this.initLights();
    this.initObjects();
    this.setupEventListeners();

    // Başlangıç karşılama bildirimi
    setTimeout(() => {
      window.gameplayManager?.showToast('🏫 Atatürk Anadolu Lisesi Simülasyonuna Hoş Geldin!');
    }, 800);

    this.animate = this.animate.bind(this);
    requestAnimationFrame(this.animate);
  }

  initScene() {
    // 1. Sahne ve Sis
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x0b1120);
    this.scene.fog = new THREE.FogExp2(0x0b1120, 0.012);

    // 2. Kamera (Third-Person için 60 derece FOV)
    this.camera = new THREE.PerspectiveCamera(
      60,
      window.innerWidth / window.innerHeight,
      0.1,
      250
    );
    this.camera.position.set(0, 3, 14);

    // 3. WebGL Renderer
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      powerPreference: 'high-performance'
    });
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.15;
    this.container.appendChild(this.renderer.domElement);
  }

  initLights() {
    // Ortam Işığı (Gökyüzü ve Zemin Yumuşak Aydınlatması)
    const hemiLight = new THREE.HemisphereLight(0xe0f2fe, 0x1e293b, 0.85);
    hemiLight.position.set(0, 30, 0);
    this.scene.add(hemiLight);

    // Ana Güneş Işığı (Gölgeli)
    this.sunLight = new THREE.DirectionalLight(0xfffbeb, 1.4);
    this.sunLight.position.set(25, 45, 30);
    this.sunLight.castShadow = true;
    this.sunLight.shadow.mapSize.width = 2048;
    this.sunLight.shadow.mapSize.height = 2048;
    this.sunLight.shadow.camera.near = 0.5;
    this.sunLight.shadow.camera.far = 120;

    const d = 40;
    this.sunLight.shadow.camera.left = -d;
    this.sunLight.shadow.camera.right = d;
    this.sunLight.shadow.camera.top = d;
    this.sunLight.shadow.camera.bottom = -d;
    this.sunLight.shadow.bias = -0.0005;

    this.scene.add(this.sunLight);
  }

  initObjects() {
    // 1. Okul Kampüsü ve Sınıflar
    this.school = new SchoolCampus(this.scene);

    // 2. 3. Şahıs Karakter
    this.player = new ThirdPersonPlayer(this.scene, this.camera);
    window.player = this.player;

    // 3. Kontrol Yöneticisi
    this.controls = new ControlsManager(this.renderer.domElement);
    window.controlsManager = this.controls;

    // 4. Oyun Mekaniği ve Dersler
    this.gameplay = new GameplayManager(this.school, this.player);
    window.gameplayManager = this.gameplay;
  }

  setupEventListeners() {
    // Ekran Yeniden Boyutlandırma
    window.addEventListener('resize', () => {
      this.camera.aspect = window.innerWidth / window.innerHeight;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(window.innerWidth, window.innerHeight);
      this.controls.checkDeviceType();
    });

    // Ses Context başlatma (Kullanıcı ilk tıkladığında)
    const unlockAudio = () => {
      soundEngine.resume();
      window.removeEventListener('click', unlockAudio);
      window.removeEventListener('touchstart', unlockAudio);
    };
    window.addEventListener('click', unlockAudio);
    window.addEventListener('touchstart', unlockAudio);
  }

  animate() {
    requestAnimationFrame(this.animate);

    const delta = Math.min(this.clock.getDelta(), 0.1);
    const elapsedTime = this.clock.getElapsedTime();

    // 1. Karakter ve Kamera Güncellemesi (Duvar çarpışmaları ile)
    this.player.update(delta, this.controls, this.school.colliders);

    // 2. Okul Animasyonlu Nesneleri Güncelle
    this.school.update(delta, elapsedTime);

    // 3. Oyun Mekaniği & Minimap Güncellemesi
    this.gameplay.update(delta);

    // 4. Sahneyi Çiz
    this.renderer.render(this.scene, this.camera);
  }
}

// Uygulamayı Başlat
window.addEventListener('DOMContentLoaded', () => {
  new SchoolApp();
});
