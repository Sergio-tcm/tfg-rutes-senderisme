# Sistema Intel·ligent de Recomanació de Rutes de Senderisme

**Treball de Fi de Grau – Enginyeria Informàtica de Gestió i Sistemes d’Informació**

Autor: Sergio Benages Millan
Tutora: Immaculada Moreno Carré
Curs: 2025–2026

---

## Descripció del projecte

Aquest projecte consisteix en el desenvolupament d’una aplicació mòbil per a Android orientada a la recomanació personalitzada de rutes de senderisme a Catalunya.

L’aplicació està desenvolupada amb **Flutter i Dart**, i forma part del Treball de Fi de Grau. El sistema permet:

* Visualitzar rutes sobre mapa
* Filtrar rutes segons preferències
* Importar rutes en format GPX
* Recomanar rutes segons el perfil de l’usuari

Aquest repositori conté el codi font de l’aplicació i s’actualitza progressivament durant el desenvolupament del projecte.

---

## Tecnologies utilitzades

* Flutter
* Dart
* Android SDK
* Android Emulator (AVD)

---

## Requisits previs

Abans d’executar l’aplicació cal tenir instal·lat:

* Git
* Flutter SDK
* Android Studio (amb Android SDK)
* Visual Studio Code amb:

  * Extensió Flutter
  * Extensió Dart

---

## Com executar el projecte pas a pas

### 1. Clonar el repositori

```bash
git clone https://github.com/USUARI/tfg-rutes-senderisme.git
```

O bé utilitzar **GitHub Desktop → Clone repository**.

---

### 2. Obrir el projecte

Obrir la carpeta del projecte amb **Visual Studio Code**.

---

### 3. Instal·lar dependències

A la terminal:

```bash
flutter pub get
```

---

### 4. Crear un dispositiu Android virtual

1. Obrir Android Studio
2. Tools → Device Manager
3. Create Device
4. Seleccionar un dispositiu (ex: Pixel 5)
5. Instal·lar una imatge Android (recomanat API 33 o similar)

---

### 5. Executar l’aplicació

Amb l’emulador obert:

```bash
flutter run
```

L’aplicació s’obrirà automàticament a l’emulador Android.

---

## Estat del projecte

🔧 En desenvolupament (MVP)

Aquest projecte es desenvolupa de forma iterativa segons la planificació definida a l’avantprojecte del TFG.
