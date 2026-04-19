# Quick Start: Real APK Build System

## TL;DR - Get Running in 5 Minutes

### Backend Setup (One-time)

```bash
# 1. Go to backend directory
cd c:\Users\nithe\low_code_app\backend

# 2. Install dependencies
npm install

# 3. Start server
npm start
# or: npm run dev (with auto-reload)
```

✅ Server running on `http://localhost:3001`

### Frontend Configuration (Already Done)

- ✅ `BuildService` created: `lib/services/build_service.dart`
- ✅ `PublishScreen` updated: `lib/screens/publish/publish_screen.dart`
- ✅ Uses real build backend automatically

### How to Use

1. Open Flutter app and create/edit a project
2. Click **"Publish"** button in top-right
3. Select **"Android APK"** platform
4. Click **"Build & Publish App"**
5. Wait for build to complete (shows real progress)
6. Download or share the APK link

---

## Backend Directory Structure

```
backend/
├── build-server.js      ← Main Node.js server
├── package.json         ← Dependencies
├── builds/              ← Build working directories
├── projects/            ← Generated Flutter projects
├── apks/                ← Finished APK files
└── temp/                ← Temporary files
```

---

## What Gets Generated

Each build creates a **complete, standalone Flutter project**:

```
builds/{buildId}/flutter_app/
├── lib/
│   └── main.dart               ← App entry point
├── android/
│   ├── app/
│   │   ├── build.gradle.kts
│   │   └── src/main/
│   │       └── AndroidManifest.xml
│   └── settings.gradle.kts
├── pubspec.yaml                ← Dependencies
├── pubspec.lock                ← Locked versions
└── build/
    └── app/outputs/apk/release/
        └── app-release.apk     ← Final APK
```

---

## API Response Flow

### 1. Submit Build
```json
POST /api/build/submit
{
  "id": "proj-123",
  "name": "MyApp",
  "screens": [...]
}

Response:
{
  "buildId": "abc-123-def",
  "status": "queued"
}
```

### 2. Poll Status (Every 5 seconds)
```json
GET /api/build/status/abc-123-def

Response:
{
  "status": "building",
  "progress": 0.45,
  "logs": ["✅ Dependencies installed", "⏳ Compiling..."],
  "downloadUrl": null
}
```

### 3. Build Complete
```json
Response:
{
  "status": "completed",
  "progress": 1.0,
  "downloadUrl": "http://localhost:3001/api/build/download/abc-123-def",
  "logs": [
    "✅ Flutter project generated",
    "✅ Dependencies installed",
    "✅ APK compilation completed",
    "📥 Ready for download"
  ]
}
```

### 4. Download APK
```
GET /api/build/download/abc-123-def
→ Returns binary APK file
→ User saves: MyApp.apk
```

---

## Expected Build Times

| Task | Duration |
|------|----------|
| Project generation | ~5s |
| Flutter pub get | ~15-30s |
| APK compilation | ~2-5 min |
| **Total** | **~3-6 min** |

---

## Real-World Workflow

### For App Developers

```
User Design:
  Drag & drop widgets
  Configure properties
  ↓
User Publishes:
  Click "Publish" button
  Select Android
  Wait 3-6 minutes
  ↓
Downloads APK:
  Click "Download" button
  or "Share Link"
  ↓
Installs on Phone:
  Open APK file on Android device
  Grant permissions
  App runs! 🎉
```

### For Sharing

```
User gets download link:
  https://yourdomain.com/api/build/download/abc-123-def
  ↓
User shares via:
  - Email
  - WhatsApp
  - Facebook
  - QR Code
  ↓
Recipient downloads APK:
  Installs and uses the app
  ↓
App owner can get feedback!
```

---

## Environment Variables (Optional)

Create `.env` file in backend directory:

```env
# Server configuration
SERVER_HOST=localhost:3001
SERVER_PORT=3001
NODE_ENV=production

# Build configuration
BUILD_TIMEOUT=900000
MAX_BUILD_QUEUE=10
MAX_CONCURRENT_BUILDS=3

# Storage configuration
BUILDS_DIR=./builds
APKS_DIR=./apks
TEMP_DIR=./temp
```

---

## Common Issues & Fixes

### ❌ Error: "Port 3001 already in use"
```bash
# Kill process using port 3001
# Windows
netstat -ano | findstr :3001
taskkill /PID <PID> /F

# Mac/Linux
lsof -i :3001
kill -9 <PID>
```

### ❌ Error: "Flutter not found"
```bash
# Add Flutter to PATH
# Windows: Add to PATH environment variable
C:\path\to\flutter\bin

# Mac/Linux
export PATH="$PATH:$(pwd)/flutter/bin"
```

### ❌ Error: "Build timed out"
```bash
# Increase timeout in build-server.js
timeout: 20 * 60 * 1000  // 20 minutes instead of 15
```

### ❌ APK Download Fails
```bash
# Check APK file exists
ls -la ./apks/

# Check permissions
chmod 644 ./apks/*.apk
```

---

## Production Checklist

- [ ] Backend deployed to cloud server
- [ ] SSL certificate configured
- [ ] BuildService URL updated to production endpoint
- [ ] Build timeout tuned for your server specs
- [ ] APK storage configured (local/S3/Firebase)
- [ ] Download links tested for external access
- [ ] Monitoring/logging set up
- [ ] Rate limiting enabled
- [ ] File upload validation in place
- [ ] Error notifications configured

---

## File Sizes Reference

| Item | Size |
|------|------|
| Generated Flutter project | ~150-200 MB |
| Generated APK | ~30-50 MB |
| Compiled build artifacts | ~500 MB - 1 GB |
| All builds (30 days) | ~2-5 GB |

*Tip: Set up automatic cleanup to remove builds older than 30 days*

---

## Test Your Build

### Command Line Test

```bash
# 1. Start backend
npm start

# 2. Submit test build
curl -X POST http://localhost:3001/api/build/submit \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-1",
    "name": "TestApp",
    "description": "Test",
    "screens": [{
      "id": "s1",
      "name": "Home",
      "widgets": []
    }]
  }'

# 3. Check status
curl http://localhost:3001/api/build/status/{buildId}

# 4. Download when complete
curl http://localhost:3001/api/build/download/{buildId} \
  -o TestApp.apk
```

---

## Next: Go Production! 🚀

See `REAL_BUILD_SYSTEM_GUIDE.md` for:
- Docker deployment
- AWS/GCP/DigitalOcean setup
- SSL configuration
- Monitoring & logging
- Performance optimization
- Security best practices

