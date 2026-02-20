# Sistema intel·ligent de recomanació de rutes de senderisme

**Treball de Fi de Grau – Enginyeria Informàtica de Gestió i Sistemes d’Informació**

**Autor:** Sergio Benages Millan
**Tutora:** Immaculada Moreno Carré
**Curs:** 2025–2026

---

## Descripció del projecte

Aquest projecte consisteix en el desenvolupament d’un sistema complet (app mòbil + backend API) orientat a la planificació, navegació i recomanació intel·ligent de rutes de senderisme.

L’aplicació està desenvolupada amb **Flutter i Dart** i el backend amb **Flask (Python)**. Forma part del Treball de Fi de Grau i actualment permet:

* Registre i autenticació d’usuaris (JWT)
* Visualització de rutes i detall complet de cada ruta
* Recomanació de rutes segons preferències i perfil físic
* Navegació guiada sobre mapa amb geolocalització en temps real
* Detecció de desviació de la ruta i finalització automàtica/manual
* Integració d’elements culturals associats a les rutes
* Importació de rutes GPX
* Sistema social: likes, valoracions i comentaris
* Favorits per usuari
* Seguiment de rutes completades i estadístiques personals
* Adaptació progressiva de preferències segons l’activitat real de l’usuari

El projecte s’ha desenvolupat amb una arquitectura modular, separant clarament capa mòbil, serveis d’API i persistència de dades, amb enfocament iteratiu i escalable.

---

## Tecnologies utilitzades

* Flutter
* Dart
* Python
* Flask
* PostgreSQL
* JWT (autenticació)
* Android SDK
* Android Emulator (AVD)
* Git i GitHub
* Visual Studio Code

---

## Estructura del projecte

```
tfg-rutes-senderisme/
 ├─ app/                    # Aplicació Flutter
 │   ├─ lib/
 │   │   ├─ config/         # Configuració de connexió API
 │   │   ├─ models/         # Models de dades
 │   │   ├─ services/       # Serveis HTTP i lògica client
 │   │   ├─ screens/        # Pantalles de l’aplicació
 │   │   ├─ widgets/        # Components reutilitzables
 │   │   └─ main.dart       # Punt d’entrada
 │   └─ test/               # Tests Flutter
 ├─ backend/                # API Flask
 │   ├─ routes/             # Endpoints (auth, rutes, social, preferències...)
 │   ├─ services/           # Lògica de domini
 │   ├─ utils/              # Utilitats
 │   ├─ db.py               # Connexió base de dades
 │   ├─ app.py              # Arrencada del servidor Flask
 │   └─ requirements.txt    # Dependències Python
 └─ README.md
```

---

## Requisits previs

Abans d’executar el projecte cal tenir instal·lat:

* Git
* Flutter SDK
* Python 3.11+ (recomanat)
* PostgreSQL
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

### 3️⃣ Configurar i executar el backend

Entrar a la carpeta del backend i instal·lar dependències:

```bash
cd backend
pip install -r requirements.txt
```

Configurar variables d’entorn (fitxer `.env` dins `backend/`):

```env
APP_ENV=development
DATABASE_URL=postgresql://usuari:password@host:5432/nom_bd
JWT_SECRET_KEY=clau_secreta_segura_amb_minim_32_caracters
JWT_ACCESS_TOKEN_EXPIRES=3600
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
```

Notes de seguretat:

* En producció (`APP_ENV=production`), `JWT_SECRET_KEY` és obligatori i ha de ser robust.
* En producció, `ALLOWED_ORIGINS` és obligatori (no s’admet wildcard `*`).
* Hi ha una plantilla recomanada a `backend/.env.example`.

Executar servidor Flask:

```bash
python app.py
```

El backend quedarà disponible (per defecte) a `http://localhost:5000`.

---

### 4️⃣ Configurar i executar l’app Flutter

Entrar a la carpeta de l’app i instal·lar dependències:

```bash
cd app
flutter pub get
```

Comprovar que la URL base de l’API és correcta a:

* `app/lib/config/api_config.dart`

---

### 5️⃣ Crear un dispositiu Android virtual

1. Obrir **Android Studio**
2. Anar a **Tools → Device Manager**
3. Crear un nou dispositiu virtual
4. Seleccionar un dispositiu (per exemple, Pixel 5)
5. Instal·lar una imatge Android (recomanat Android 13 o superior)

---

### 6️⃣ Executar l’aplicació

Amb l’emulador obert:

```bash
flutter run
```

L’aplicació s’executarà automàticament a l’emulador Android.

---

## Estat del projecte

✅ Versió funcional avançada (pre-release TFG)

Funcionalitats implementades fins al moment:

* Autenticació i perfil d’usuari
* Llistat i detall de rutes
* Recomanació personalitzada amb perfil inicial
* Adaptació de preferències segons rutes completades
* Navegació en temps real al mapa
* Control de desviació i finalització de ruta
* Elements culturals i rutes associades
* Importació de rutes GPX
* Likes, comentaris i valoracions
* Favorits per usuari
* Marcatge de rutes completades
* Pantalla d’estadístiques personals
* Gestió d’errors HTTP i respostes no JSON amb tolerància a fallades

El projecte es troba en fase de consolidació final, amb enfocament en estabilitat, validació i documentació per a la versió final del TFG.

---

## Autor

**Sergio Benages Millan**
Treball de Fi de Grau – Enginyeria Informàtica de Gestió i Sistemes d’Informació
