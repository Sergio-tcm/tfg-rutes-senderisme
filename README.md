# Sistema intel·ligent de recomanació de rutes de senderisme

**Treball de Fi de Grau – Enginyeria Informàtica de Gestió i Sistemes d’Informació**

**Autor:** Sergio Benages Millan
**Tutora:** Immaculada Moreno Carré
**Curs:** 2025–2026

---

## Descripció del projecte

Aquest projecte consisteix en el desenvolupament d’una aplicació mòbil per a Android orientada a la visualització i recomanació de rutes de senderisme.

L’aplicació està desenvolupada amb **Flutter i Dart** i forma part del Treball de Fi de Grau. El sistema permet actualment:

* Visualitzar una llista de rutes de senderisme
* Consultar el detall d’una ruta
* Filtrar rutes segons la dificultat
* Recomanar una ruta segons preferències bàsiques de l’usuari (dificultat i distància màxima)

El projecte s’ha desenvolupat seguint una arquitectura modular i escalable, preparada per a futures ampliacions com la integració de mapes, fitxers GPX o fonts de dades externes.

Aquest repositori conté el codi font de l’aplicació i s’actualitza progressivament durant el desenvolupament del projecte.

---

## Tecnologies utilitzades

* Flutter
* Dart
* Android SDK
* Android Emulator (AVD)
* Git i GitHub
* Visual Studio Code

---

## Estructura del projecte

```
lib/
 ├─ models/        # Models de dades (ex: rutes)
 ├─ services/      # Serveis i lògica de negoci
 ├─ screens/       # Pantalles de l’aplicació
 ├─ widgets/       # Widgets reutilitzables
 └─ main.dart      # Punt d’entrada de l’aplicació
```

---

## Requisits previs

Abans d’executar l’aplicació cal tenir instal·lat:

* Git
* Flutter SDK
* Android Studio (amb Android SDK i emulador)
* Visual Studio Code amb:

  * Extensió Flutter
  * Extensió Dart

Es pot comprovar l’estat de l’entorn amb:

```bash
flutter doctor
```

---

## Com executar el projecte pas a pas

### 1️⃣ Clonar el repositori

```bash
git clone https://github.com/USUARI/tfg-rutes-senderisme.git
```

O bé utilitzar **GitHub Desktop → Clone repository**.

---

### 2️⃣ Obrir el projecte

Obrir la carpeta del projecte amb **Visual Studio Code**.

---

### 3️⃣ Instal·lar dependències

A la terminal:

```bash
flutter pub get
```

---

### 4️⃣ Crear un dispositiu Android virtual

1. Obrir **Android Studio**
2. Anar a **Tools → Device Manager**
3. Crear un nou dispositiu virtual
4. Seleccionar un dispositiu (per exemple, Pixel 5)
5. Instal·lar una imatge Android (recomanat Android 13 o superior)

---

### 5️⃣ Executar l’aplicació

Amb l’emulador obert:

```bash
flutter run
```

L’aplicació s’executarà automàticament a l’emulador Android.

---

## Estat del projecte

✅ MVP funcional

Funcionalitats implementades fins al moment:

* Navegació entre pantalles
* Llista de rutes amb detall
* Filtratge per dificultat
* Recomanació bàsica de rutes
* Gestió d’estat i dades asíncrones

El projecte es desenvolupa de forma iterativa seguint la planificació definida a l’avantprojecte del TFG.

---

## Autor

**Sergio Benages Millan**
Treball de Fi de Grau – Enginyeria Informàtica de Gestió i Sistemes d’Informació
