import * as THREE from 'three';
import { soundEngine } from './audio.js';

/**
 * 3. Şahıs Karakter ve Prosedürel Animasyon Sistemi
 * Detaylı öğrenci avatarı, eklemli iskelet hiyerarşisi, yürüme/koşma/oturma animasyonları ve takip kamerası.
 */

export class ThirdPersonPlayer {
  constructor(scene, camera) {
    this.scene = scene;
    this.camera = camera;

    // Fizik ve Hareket Değerleri
    this.position = new THREE.Vector3(0, 0, 8); // Okul bahçesi/giriş başlangıç noktası
    this.velocity = new THREE.Vector3(0, 0, 0);
    this.rotation = Math.PI; // Okula doğru bakış
    this.targetRotation = Math.PI;

    this.walkSpeed = 4.8;
    this.runSpeed = 8.5;
    this.jumpForce = 7.2;
    this.gravity = 18.0;

    this.isGrounded = true;
    this.isSitting = false;
    this.sitTarget = null;
    this.isCheering = false;
    this.cheerTimer = 0;

    // Animasyon Durum Değişkenleri
    this.animTime = 0;
    this.currentState = 'idle'; // 'idle', 'walk', 'run', 'jump', 'sit', 'cheer'
    this.footstepTimer = 0;

    // Renk Ayarları (Varsayılan Lacivert Üniforma & Turkuaz Çanta)
    this.blazerColor = 0x1e3a8a;
    this.backpackColor = 0x06b6d4;

    this.initCharacterModel();
  }

  initCharacterModel() {
    this.group = new THREE.Group();
    this.group.position.copy(this.position);

    // Malzemeler
    this.skinMat = new THREE.MeshStandardMaterial({ color: 0xffdbac, roughness: 0.6, metalness: 0.05 });
    this.hairMat = new THREE.MeshStandardMaterial({ color: 0x3b2219, roughness: 0.8 });
    this.blazerMat = new THREE.MeshStandardMaterial({ color: this.blazerColor, roughness: 0.5 });
    this.shirtMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 });
    this.tieMat = new THREE.MeshStandardMaterial({ color: 0xdc2626, roughness: 0.4 });
    this.pantsMat = new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.6 });
    this.shoesMat = new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.3 });
    this.backpackMat = new THREE.MeshStandardMaterial({ color: this.backpackColor, roughness: 0.5 });
    this.detailMat = new THREE.MeshStandardMaterial({ color: 0xf59e0b, roughness: 0.3, metalness: 0.6 });

    // 1. Kök & Kalça (Pelvis)
    this.pelvis = new THREE.Group();
    this.pelvis.position.y = 0.95;
    this.group.add(this.pelvis);

    // 2. Gövde (Torso & Üniforma Ceket)
    this.torsoGroup = new THREE.Group();
    this.pelvis.add(this.torsoGroup);

    const torsoGeo = new THREE.BoxGeometry(0.55, 0.65, 0.32);
    const torsoMesh = new THREE.Mesh(torsoGeo, this.blazerMat);
    torsoMesh.position.y = 0.35;
    torsoMesh.castShadow = true;
    torsoMesh.receiveShadow = true;
    this.torsoGroup.add(torsoMesh);

    // Beyaz gömlek yaka üçgeni & Kırmızı kravat
    const shirtGeo = new THREE.BufferGeometry();
    const shirtVertices = new Float32Array([
      -0.12, 0.67, 0.165,
       0.12, 0.67, 0.165,
       0.0,  0.42, 0.165
    ]);
    shirtGeo.setAttribute('position', new THREE.BufferAttribute(shirtVertices, 3));
    shirtGeo.computeVertexNormals();
    const shirtMesh = new THREE.Mesh(shirtGeo, this.shirtMat);
    this.torsoGroup.add(shirtMesh);

    const tieGeo = new THREE.BoxGeometry(0.06, 0.26, 0.02);
    const tieMesh = new THREE.Mesh(tieGeo, this.tieMat);
    tieMesh.position.set(0, 0.5, 0.175);
    this.torsoGroup.add(tieMesh);

    // Sırt Çantası (Backpack)
    this.backpackMesh = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.48, 0.22), this.backpackMat);
    this.backpackMesh.position.set(0, 0.32, -0.22);
    this.backpackMesh.castShadow = true;
    this.torsoGroup.add(this.backpackMesh);

    const pocketMesh = new THREE.Mesh(new THREE.BoxGeometry(0.32, 0.22, 0.08), this.detailMat);
    pocketMesh.position.set(0, 0.24, -0.34);
    this.torsoGroup.add(pocketMesh);

    // 3. Boyun & Kafa (Head)
    this.neckGroup = new THREE.Group();
    this.neckGroup.position.y = 0.68;
    this.torsoGroup.add(this.neckGroup);

    const headGeo = new THREE.BoxGeometry(0.36, 0.38, 0.34);
    const headMesh = new THREE.Mesh(headGeo, this.skinMat);
    headMesh.position.y = 0.22;
    headMesh.castShadow = true;
    this.neckGroup.add(headMesh);

    // Saçlar (Stylized Modern Saç)
    const hairGeo = new THREE.BoxGeometry(0.4, 0.18, 0.38);
    const hairMesh = new THREE.Mesh(hairGeo, this.hairMat);
    hairMesh.position.set(0, 0.36, 0);
    hairMesh.castShadow = true;
    this.neckGroup.add(hairMesh);

    const hairFringe = new THREE.Mesh(new THREE.BoxGeometry(0.38, 0.12, 0.1), this.hairMat);
    hairFringe.position.set(0, 0.28, 0.18);
    this.neckGroup.add(hairFringe);

    // Gözler
    const eyeGeo = new THREE.BoxGeometry(0.06, 0.06, 0.02);
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0x1e293b });
    const leftEye = new THREE.Mesh(eyeGeo, eyeMat);
    leftEye.position.set(-0.09, 0.22, 0.175);
    const rightEye = new THREE.Mesh(eyeGeo, eyeMat);
    rightEye.position.set(0.09, 0.22, 0.175);
    this.neckGroup.add(leftEye, rightEye);

    // 4. Kollar (Sol ve Sağ Üst/Alt Kol)
    // Sol Kol
    this.leftShoulder = new THREE.Group();
    this.leftShoulder.position.set(-0.35, 0.58, 0);
    this.torsoGroup.add(this.leftShoulder);

    const armGeo = new THREE.BoxGeometry(0.14, 0.34, 0.14);
    const leftUpperArm = new THREE.Mesh(armGeo, this.blazerMat);
    leftUpperArm.position.y = -0.17;
    leftUpperArm.castShadow = true;
    this.leftShoulder.add(leftUpperArm);

    this.leftElbow = new THREE.Group();
    this.leftElbow.position.y = -0.34;
    this.leftShoulder.add(this.leftElbow);

    const forearmGeo = new THREE.BoxGeometry(0.12, 0.32, 0.12);
    const leftForearm = new THREE.Mesh(forearmGeo, this.skinMat);
    leftForearm.position.y = -0.16;
    leftForearm.castShadow = true;
    this.leftElbow.add(leftForearm);

    // Sağ Kol
    this.rightShoulder = new THREE.Group();
    this.rightShoulder.position.set(0.35, 0.58, 0);
    this.torsoGroup.add(this.rightShoulder);

    const rightUpperArm = new THREE.Mesh(armGeo, this.blazerMat);
    rightUpperArm.position.y = -0.17;
    rightUpperArm.castShadow = true;
    this.rightShoulder.add(rightUpperArm);

    this.rightElbow = new THREE.Group();
    this.rightElbow.position.y = -0.34;
    this.rightShoulder.add(this.rightElbow);

    const rightForearm = new THREE.Mesh(forearmGeo, this.skinMat);
    rightForearm.position.y = -0.16;
    rightForearm.castShadow = true;
    this.rightElbow.add(rightForearm);

    // 5. Bacaklar (Sol ve Sağ Kalça/Diz)
    const legGeo = new THREE.BoxGeometry(0.18, 0.44, 0.18);
    const shoeGeo = new THREE.BoxGeometry(0.19, 0.12, 0.26);

    // Sol Bacak
    this.leftHip = new THREE.Group();
    this.leftHip.position.set(-0.16, 0, 0);
    this.pelvis.add(this.leftHip);

    const leftThigh = new THREE.Mesh(legGeo, this.pantsMat);
    leftThigh.position.y = -0.22;
    leftThigh.castShadow = true;
    this.leftHip.add(leftThigh);

    this.leftKnee = new THREE.Group();
    this.leftKnee.position.y = -0.44;
    this.leftHip.add(this.leftKnee);

    const leftCalf = new THREE.Mesh(legGeo, this.pantsMat);
    leftCalf.position.y = -0.22;
    leftCalf.castShadow = true;
    this.leftKnee.add(leftCalf);

    const leftShoe = new THREE.Mesh(shoeGeo, this.shoesMat);
    leftShoe.position.set(0, -0.46, 0.04);
    leftShoe.castShadow = true;
    this.leftKnee.add(leftShoe);

    // Sağ Bacak
    this.rightHip = new THREE.Group();
    this.rightHip.position.set(0.16, 0, 0);
    this.pelvis.add(this.rightHip);

    const rightThigh = new THREE.Mesh(legGeo, this.pantsMat);
    rightThigh.position.y = -0.22;
    rightThigh.castShadow = true;
    this.rightHip.add(rightThigh);

    this.rightKnee = new THREE.Group();
    this.rightKnee.position.y = -0.44;
    this.rightHip.add(this.rightKnee);

    const rightCalf = new THREE.Mesh(legGeo, this.pantsMat);
    rightCalf.position.y = -0.22;
    rightCalf.castShadow = true;
    this.rightKnee.add(rightCalf);

    const rightShoe = new THREE.Mesh(shoeGeo, this.shoesMat);
    rightShoe.position.set(0, -0.46, 0.04);
    rightShoe.castShadow = true;
    this.rightKnee.add(rightShoe);

    this.scene.add(this.group);
  }

  setBlazerColor(hexColor) {
    this.blazerColor = hexColor;
    this.blazerMat.color.set(hexColor);
  }

  setBackpackColor(hexColor) {
    this.backpackColor = hexColor;
    this.backpackMat.color.set(hexColor);
  }

  triggerCheer() {
    this.isCheering = true;
    this.cheerTimer = 2.2;
    soundEngine.playCorrect();
  }

  sitDown(chairPosition, chairRotation) {
    this.isSitting = true;
    this.sitTarget = {
      pos: chairPosition.clone(),
      rot: chairRotation
    };
    this.group.position.copy(chairPosition);
    this.rotation = chairRotation;
    this.group.rotation.y = chairRotation;
    this.velocity.set(0, 0, 0);
  }

  standUp() {
    if (!this.isSitting) return;
    this.isSitting = false;
    this.sitTarget = null;
    // Sandalyeden hafif öne çık
    this.position.z += Math.cos(this.rotation) * 0.8;
    this.position.x += Math.sin(this.rotation) * 0.8;
  }

  update(delta, controls, colliders = []) {
    this.animTime += delta;

    // Sevinç animasyon sayacı
    if (this.isCheering) {
      this.cheerTimer -= delta;
      if (this.cheerTimer <= 0) {
        this.isCheering = false;
      }
    }

    // Sandalyede oturuyorsa hareketleri devre dışı bırak
    if (this.isSitting) {
      if (controls.sitRequested || controls.inputVector.x !== 0 || controls.inputVector.y !== 0) {
        this.standUp();
        controls.sitRequested = false;
      } else {
        this.animateSitting(delta);
        this.updateCamera(controls);
        return;
      }
    }

    // 1. Zıplama Kontrolü
    if (controls.jumpRequested && this.isGrounded) {
      this.velocity.y = this.jumpForce;
      this.isGrounded = false;
      controls.jumpRequested = false;
      soundEngine.playJump();
    }

    // 2. Yatay Hareket Hesaplama
    const inputX = controls.inputVector.x;
    const inputY = controls.inputVector.y;
    const isMoving = Math.hypot(inputX, inputY) > 0.05;

    let targetSpeed = 0;
    if (isMoving) {
      targetSpeed = controls.isSprinting ? this.runSpeed : this.walkSpeed;
      this.currentState = controls.isSprinting ? 'run' : 'walk';

      // Kamera açısına göre hareket vektörünü dönüştür
      const camYaw = controls.cameraYaw;
      const moveAngle = Math.atan2(inputX, -inputY) + camYaw;
      this.targetRotation = moveAngle;

      // Yumuşak dönüş rotasyonu (Slerp-like lerp)
      let diff = this.targetRotation - this.rotation;
      while (diff < -Math.PI) diff += Math.PI * 2;
      while (diff > Math.PI) diff -= Math.PI * 2;
      this.rotation += diff * Math.min(1.0, delta * 12);

      // İlerleme hızını uygula
      const forwardX = Math.sin(this.rotation) * targetSpeed;
      const forwardZ = Math.cos(this.rotation) * targetSpeed;
      this.velocity.x = forwardX;
      this.velocity.z = forwardZ;

      // Adım sesi çalma
      soundEngine.playFootstep(controls.isSprinting);
    } else {
      this.velocity.x = 0;
      this.velocity.z = 0;
      this.currentState = 'idle';
    }

    if (!this.isGrounded) {
      this.currentState = 'jump';
    } else if (this.isCheering) {
      this.currentState = 'cheer';
    }

    // 3. Yerçekimi ve Düşey Hareket
    this.velocity.y -= this.gravity * delta;
    this.position.y += this.velocity.y * delta;

    // Zemin seviyesi (y = 0)
    if (this.position.y <= 0) {
      if (!this.isGrounded && this.velocity.y < -3.0) {
        soundEngine.playLand();
      }
      this.position.y = 0;
      this.velocity.y = 0;
      this.isGrounded = true;
    }

    // 4. Çarpışma Kontrolü (Duvarlar ve Sınırlar)
    const proposedX = this.position.x + this.velocity.x * delta;
    const proposedZ = this.position.z + this.velocity.z * delta;

    let blockedX = false;
    let blockedZ = false;

    // Okul sınırları ve oda duvarları ile çarpışma testi
    for (const col of colliders) {
      if (col.isBox) {
        const charRadius = 0.45;
        // X ekseni kontrolü
        if (proposedX + charRadius > col.min.x && proposedX - charRadius < col.max.x &&
            this.position.z + charRadius > col.min.z && this.position.z - charRadius < col.max.z) {
          blockedX = true;
        }
        // Z ekseni kontrolü
        if (this.position.x + charRadius > col.min.x && this.position.x - charRadius < col.max.x &&
            proposedZ + charRadius > col.min.z && proposedZ - charRadius < col.max.z) {
          blockedZ = true;
        }
      }
    }

    if (!blockedX) this.position.x = proposedX;
    if (!blockedZ) this.position.z = proposedZ;

    // Grup pozisyon ve rotasyonunu güncelle
    this.group.position.copy(this.position);
    this.group.rotation.y = this.rotation;

    // 5. Prosedürel İskelet Animasyonlarını Oynat
    this.updateProceduralAnimations(delta);

    // 6. 3. Şahıs Takip Kamerasını Güncelle
    this.updateCamera(controls);
  }

  updateProceduralAnimations(delta) {
    const t = this.animTime;

    if (this.currentState === 'idle') {
      // Doğal nefes alma ve hafif sallanma
      const breath = Math.sin(t * 2.2) * 0.02;
      this.pelvis.position.y = 0.95 + breath;
      this.torsoGroup.rotation.x = breath * 0.5;
      this.neckGroup.rotation.y = Math.sin(t * 0.8) * 0.08;

      // Kollar serbest dinlenme
      this.leftShoulder.rotation.x = Math.sin(t * 1.5) * 0.04;
      this.leftShoulder.rotation.z = -0.05;
      this.rightShoulder.rotation.x = -Math.sin(t * 1.5) * 0.04;
      this.rightShoulder.rotation.z = 0.05;

      this.leftElbow.rotation.x = -0.1;
      this.rightElbow.rotation.x = -0.1;

      // Bacaklar düz
      this.leftHip.rotation.x = 0;
      this.leftKnee.rotation.x = 0;
      this.rightHip.rotation.x = 0;
      this.rightKnee.rotation.x = 0;

    } else if (this.currentState === 'walk' || this.currentState === 'run') {
      const isRunning = this.currentState === 'run';
      const strideFreq = isRunning ? 15.0 : 8.5;
      const strideAngle = isRunning ? 0.95 : 0.55;
      const armSwing = isRunning ? 1.05 : 0.6;

      const stride = Math.sin(t * strideFreq);

      // Gövde öne eğilme & adım yaylanması
      const bounce = Math.abs(Math.sin(t * strideFreq)) * (isRunning ? 0.12 : 0.06);
      this.pelvis.position.y = 0.95 + bounce;
      this.torsoGroup.rotation.x = isRunning ? 0.24 : 0.08; // Koşuda öne eğilme
      this.torsoGroup.rotation.y = Math.sin(t * strideFreq) * 0.08;

      // Bacaklar
      this.leftHip.rotation.x = stride * strideAngle;
      this.rightHip.rotation.x = -stride * strideAngle;

      // Diz bükülmeleri (Arkaya savrulurken bükülür)
      this.leftKnee.rotation.x = Math.max(0, -stride * (isRunning ? 1.4 : 0.8));
      this.rightKnee.rotation.x = Math.max(0, stride * (isRunning ? 1.4 : 0.8));

      // Kollar (Bacakların ters yönünde salınım)
      this.leftShoulder.rotation.x = -stride * armSwing;
      this.rightShoulder.rotation.x = stride * armSwing;

      this.leftShoulder.rotation.z = -0.1;
      this.rightShoulder.rotation.z = 0.1;

      this.leftElbow.rotation.x = isRunning ? -0.9 : -0.25;
      this.rightElbow.rotation.x = isRunning ? -0.9 : -0.25;

    } else if (this.currentState === 'jump') {
      this.pelvis.position.y = 0.95;
      this.torsoGroup.rotation.x = -0.1;
      // Bacaklar havada hafif bükülü
      this.leftHip.rotation.x = -0.4;
      this.leftKnee.rotation.x = 0.7;
      this.rightHip.rotation.x = -0.4;
      this.rightKnee.rotation.x = 0.7;

      // Kollar hafifçe havaya kalkık
      this.leftShoulder.rotation.x = -0.8;
      this.rightShoulder.rotation.x = -0.8;
      this.leftShoulder.rotation.z = -0.4;
      this.rightShoulder.rotation.z = 0.4;

    } else if (this.currentState === 'cheer') {
      // İki el havada sevinç hareketi
      const cheerWave = Math.sin(t * 12) * 0.25;
      this.leftShoulder.rotation.x = -2.6 + cheerWave;
      this.rightShoulder.rotation.x = -2.6 - cheerWave;
      this.leftShoulder.rotation.z = -0.5;
      this.rightShoulder.rotation.z = 0.5;

      this.leftElbow.rotation.x = -0.3;
      this.rightElbow.rotation.x = -0.3;
      this.neckGroup.rotation.x = -0.3; // Baş yukarıda
    }
  }

  animateSitting(delta) {
    // Oturma Pozisyonu
    this.pelvis.position.y = 0.65; // Sandalye yüksekliğine in
    this.torsoGroup.rotation.x = 0;
    this.torsoGroup.rotation.y = 0;

    // Uyluklar 90 derece öne
    this.leftHip.rotation.x = -Math.PI / 2;
    this.rightHip.rotation.x = -Math.PI / 2;

    // Dizler 90 derece aşağı
    this.leftKnee.rotation.x = Math.PI / 2;
    this.rightKnee.rotation.x = Math.PI / 2;

    // Kollar masaya veya dizlere rahatça koyulmuş
    this.leftShoulder.rotation.x = -0.7;
    this.leftShoulder.rotation.z = -0.1;
    this.leftElbow.rotation.x = -0.8;

    this.rightShoulder.rotation.x = -0.7;
    this.rightShoulder.rotation.z = 0.1;
    this.rightElbow.rotation.x = -0.8;

    // Hafif oturma nefesi
    this.neckGroup.rotation.y = Math.sin(this.animTime * 1.2) * 0.05;
  }

  updateCamera(controls) {
    // Karakterin göğüs/baş seviyesi hedef noktası
    const targetY = this.position.y + 1.45;
    const targetPos = new THREE.Vector3(this.position.x, targetY, this.position.z);

    // Küresel koordinatlardan kamera ofseti hesaplama
    const yaw = controls.cameraYaw;
    const pitch = controls.cameraPitch;
    const dist = controls.cameraDistance;

    const camX = targetPos.x + Math.sin(yaw) * Math.cos(pitch) * dist;
    const camY = Math.max(0.6, targetPos.y + Math.sin(pitch) * dist);
    const camZ = targetPos.z + Math.cos(yaw) * Math.cos(pitch) * dist;

    const desiredCamPos = new THREE.Vector3(camX, camY, camZ);

    // Yumuşak kamera sönümlemesi (Lerp)
    this.camera.position.lerp(desiredCamPos, 0.15);
    this.camera.lookAt(targetPos);
  }
}
