/**
 * Kontrol Yöneticisi (Controls Manager)
 * Masaüstü (Klavye & Fare) ve Mobil (Sanal Dokunmatik Joystick & Aksiyon Butonları) desteği.
 */

export class ControlsManager {
  constructor(domElement) {
    this.domElement = domElement;

    // Hareket Girdi Durumları
    this.moveForward = false;
    this.moveBackward = false;
    this.moveLeft = false;
    this.moveRight = false;
    this.isSprinting = false;
    this.jumpRequested = false;
    this.interactRequested = false;
    this.sitRequested = false;

    // Normalize edilmiş yön vektörü (-1 ile 1 arası x ve y)
    this.inputVector = { x: 0, y: 0 };

    // Kamera Dönüş Açıları (Radyan cinsinden)
    this.cameraYaw = 0;
    this.cameraPitch = 0.35; // Hafif yukarıdan bakış açısı
    this.cameraDistance = 4.2;
    this.minDistance = 2.0;
    this.maxDistance = 8.0;

    // Fare sürükleme durumları
    this.isMouseDown = false;
    this.lastMouseX = 0;
    this.lastMouseY = 0;

    // Dokunmatik (Mobil) durumları
    this.isMobile = false;
    this.touchJoystickId = null;
    this.touchCameraId = null;
    this.joystickOrigin = { x: 0, y: 0 };
    this.lastTouchCamX = 0;
    this.lastTouchCamY = 0;

    // DOM referansları
    this.joystickZone = document.getElementById('joystick-zone');
    this.joystickStick = document.querySelector('.joystick-stick');
    this.mobileControlsWrap = document.getElementById('mobile-controls');

    this.checkDeviceType();
    this.setupKeyboardListeners();
    this.setupMouseListeners();
    this.setupTouchListeners();
    this.setupMobileActionButtons();
  }

  checkDeviceType() {
    const isTouch = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0);
    const isSmallScreen = window.innerWidth <= 850;
    this.isMobile = isTouch || isSmallScreen;

    if (this.mobileControlsWrap) {
      if (this.isMobile) {
        this.mobileControlsWrap.style.display = 'block';
      }
    }
  }

  toggleMobileControls(forcedState = null) {
    this.isMobile = forcedState !== null ? forcedState : !this.isMobile;
    if (this.mobileControlsWrap) {
      this.mobileControlsWrap.style.display = this.isMobile ? 'block' : 'none';
    }
    return this.isMobile;
  }

  setupKeyboardListeners() {
    window.addEventListener('keydown', (e) => {
      // Eğer bir modal veya input açıksa kontrolleri durdur
      if (document.querySelector('.modal-overlay.active')) return;

      switch (e.code) {
        case 'KeyW':
        case 'ArrowUp':
          this.moveForward = true;
          break;
        case 'KeyS':
        case 'ArrowDown':
          this.moveBackward = true;
          break;
        case 'KeyA':
        case 'ArrowLeft':
          this.moveLeft = true;
          break;
        case 'KeyD':
        case 'ArrowRight':
          this.moveRight = true;
          break;
        case 'ShiftLeft':
        case 'ShiftRight':
          this.isSprinting = true;
          break;
        case 'Space':
          this.jumpRequested = true;
          e.preventDefault();
          break;
        case 'KeyE':
          this.interactRequested = true;
          break;
        case 'KeyC':
          this.sitRequested = true;
          break;
      }
      this.updateInputVectorFromKeyboard();
    });

    window.addEventListener('keyup', (e) => {
      switch (e.code) {
        case 'KeyW':
        case 'ArrowUp':
          this.moveForward = false;
          break;
        case 'KeyS':
        case 'ArrowDown':
          this.moveBackward = false;
          break;
        case 'KeyA':
        case 'ArrowLeft':
          this.moveLeft = false;
          break;
        case 'KeyD':
        case 'ArrowRight':
          this.moveRight = false;
          break;
        case 'ShiftLeft':
        case 'ShiftRight':
          this.isSprinting = false;
          break;
        case 'KeyE':
          this.interactRequested = false;
          break;
        case 'KeyC':
          this.sitRequested = false;
          break;
      }
      this.updateInputVectorFromKeyboard();
    });
  }

  updateInputVectorFromKeyboard() {
    // Sadece dokunmatik joystick aktif değilken klavyeden güncelle
    if (this.touchJoystickId !== null) return;

    let x = 0;
    let y = 0;
    if (this.moveForward) y += 1;
    if (this.moveBackward) y -= 1;
    if (this.moveRight) x += 1;
    if (this.moveLeft) x -= 1;

    const len = Math.hypot(x, y);
    if (len > 0) {
      this.inputVector.x = x / len;
      this.inputVector.y = y / len;
    } else {
      this.inputVector.x = 0;
      this.inputVector.y = 0;
    }
  }

  setupMouseListeners() {
    this.domElement.addEventListener('mousedown', (e) => {
      // Sol veya Sağ tık ile kamera çevirme
      this.isMouseDown = true;
      this.lastMouseX = e.clientX;
      this.lastMouseY = e.clientY;
    });

    window.addEventListener('mousemove', (e) => {
      if (!this.isMouseDown) return;

      const deltaX = e.clientX - this.lastMouseX;
      const deltaY = e.clientY - this.lastMouseY;
      this.lastMouseX = e.clientX;
      this.lastMouseY = e.clientY;

      const sens = 0.005;
      this.cameraYaw -= deltaX * sens;
      this.cameraPitch = Math.max(-0.2, Math.min(1.2, this.cameraPitch + deltaY * sens));
    });

    window.addEventListener('mouseup', () => {
      this.isMouseDown = false;
    });

    // Yakınlaşma - Uzaklaşma (Scroll Wheel)
    this.domElement.addEventListener('wheel', (e) => {
      this.cameraDistance = Math.max(this.minDistance, Math.min(this.maxDistance, this.cameraDistance + e.deltaY * 0.005));
    }, { passive: true });
  }

  setupTouchListeners() {
    const handleTouchStart = (e) => {
      if (document.querySelector('.modal-overlay.active')) return;

      for (let i = 0; i < e.changedTouches.length; i++) {
        const touch = e.changedTouches[i];
        const halfWidth = window.innerWidth * 0.48;

        // Ekranın sol yarısı: Joystick
        if (touch.clientX < halfWidth && this.touchJoystickId === null) {
          this.touchJoystickId = touch.identifier;
          this.joystickOrigin.x = touch.clientX;
          this.joystickOrigin.y = touch.clientY;
          this.updateJoystick(touch.clientX, touch.clientY);
        }
        // Ekranın sağ yarısı: Kamera çevirme
        else if (touch.clientX >= halfWidth && this.touchCameraId === null) {
          this.touchCameraId = touch.identifier;
          this.lastTouchCamX = touch.clientX;
          this.lastTouchCamY = touch.clientY;
        }
      }
    };

    const handleTouchMove = (e) => {
      for (let i = 0; i < e.changedTouches.length; i++) {
        const touch = e.changedTouches[i];

        if (touch.identifier === this.touchJoystickId) {
          this.updateJoystick(touch.clientX, touch.clientY);
        } else if (touch.identifier === this.touchCameraId) {
          const deltaX = touch.clientX - this.lastTouchCamX;
          const deltaY = touch.clientY - this.lastTouchCamY;
          this.lastTouchCamX = touch.clientX;
          this.lastTouchCamY = touch.clientY;

          const sens = 0.007;
          this.cameraYaw -= deltaX * sens;
          this.cameraPitch = Math.max(-0.2, Math.min(1.2, this.cameraPitch + deltaY * sens));
        }
      }
    };

    const handleTouchEnd = (e) => {
      for (let i = 0; i < e.changedTouches.length; i++) {
        const touch = e.changedTouches[i];

        if (touch.identifier === this.touchJoystickId) {
          this.touchJoystickId = null;
          this.resetJoystick();
        } else if (touch.identifier === this.touchCameraId) {
          this.touchCameraId = null;
        }
      }
    };

    window.addEventListener('touchstart', handleTouchStart, { passive: false });
    window.addEventListener('touchmove', handleTouchMove, { passive: false });
    window.addEventListener('touchend', handleTouchEnd, { passive: false });
    window.addEventListener('touchcancel', handleTouchEnd, { passive: false });
  }

  updateJoystick(clientX, clientY) {
    const maxRadius = 50; // Piksel cinsinden çekme mesafesi
    const deltaX = clientX - this.joystickOrigin.x;
    const deltaY = clientY - this.joystickOrigin.y;
    const dist = Math.hypot(deltaX, deltaY);

    const clampedDist = Math.min(dist, maxRadius);
    const angle = Math.atan2(deltaY, deltaX);

    const stickX = Math.cos(angle) * clampedDist;
    const stickY = Math.sin(angle) * clampedDist;

    if (this.joystickStick) {
      this.joystickStick.style.transform = `translate(${stickX}px, ${stickY}px)`;
    }

    const intensity = clampedDist / maxRadius;
    this.inputVector.x = Math.cos(angle) * intensity;
    this.inputVector.y = -Math.sin(angle) * intensity; // 2D ekrandan 3D ileri yönüne ters çevrilir

    // Çok çekilirse koşu moduna geç
    if (intensity > 0.85) {
      this.isSprinting = true;
    } else {
      this.isSprinting = false;
    }
  }

  resetJoystick() {
    if (this.joystickStick) {
      this.joystickStick.style.transform = `translate(0px, 0px)`;
    }
    this.inputVector.x = 0;
    this.inputVector.y = 0;
    this.isSprinting = false;
  }

  setupMobileActionButtons() {
    const btnSprint = document.getElementById('btn-sprint');
    const btnSit = document.getElementById('btn-sit');
    const btnJump = document.getElementById('btn-jump');
    const btnInteract = document.getElementById('btn-interact');

    if (btnSprint) {
      const toggleSprint = () => {
        this.isSprinting = !this.isSprinting;
        btnSprint.classList.toggle('pressed', this.isSprinting);
      };
      btnSprint.addEventListener('click', toggleSprint);
      btnSprint.addEventListener('touchstart', (e) => { e.stopPropagation(); toggleSprint(); });
    }

    if (btnSit) {
      const triggerSit = () => {
        this.sitRequested = true;
      };
      btnSit.addEventListener('click', triggerSit);
      btnSit.addEventListener('touchstart', (e) => { e.stopPropagation(); triggerSit(); });
    }

    if (btnJump) {
      const triggerJump = () => {
        this.jumpRequested = true;
      };
      btnJump.addEventListener('click', triggerJump);
      btnJump.addEventListener('touchstart', (e) => { e.stopPropagation(); triggerJump(); });
    }

    if (btnInteract) {
      const triggerInteract = () => {
        this.interactRequested = true;
      };
      btnInteract.addEventListener('click', triggerInteract);
      btnInteract.addEventListener('touchstart', (e) => { e.stopPropagation(); triggerInteract(); });
    }
  }
}
