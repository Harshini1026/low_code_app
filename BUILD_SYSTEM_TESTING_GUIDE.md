# Build System Testing Guide

## Complete End-to-End Testing Procedures

This guide walks you through testing every component of the APK build system.

---

## Phase 1: Backend Startup & Health Check

### Step 1.1: Start the Backend Server

```bash
cd c:\Users\nithe\low_code_app\backend
npm install
npm start
```

**Expected Output:**
```
Backend API server running on port 3001
Health check endpoint available at http://localhost:3001/health
```

### Step 1.2: Verify Health Endpoint

**Option A: Using Browser**
- Open: `http://localhost:3001/health`
- Expected: Shows `{status: ok}`

**Option B: Using PowerShell**
```powershell
Invoke-WebRequest http://localhost:3001/health
# Should return status 200 with body: {"status":"ok"}
```

**Option C: Using cURL (if installed)**
```bash
curl http://localhost:3001/health
```

✅ **Pass Criteria:** Returns HTTP 200 and `{"status":"ok"}`

---

## Phase 2: Backend API Testing

### Step 2.1: Test Build Submission

**Using PowerShell:**
```powershell
$body = @{
    id = "test-build-001"
    name = "HelloApp"
    description = "Test application"
    screens = @(
        @{
            id = "screen-1"
            name = "Home"
            widgets = @()
        }
    )
} | ConvertTo-Json

$response = Invoke-WebRequest `
    -Uri "http://localhost:3001/api/build/submit" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body

Write-Output $response.Content
```

**Expected Response:**
```json
{
  "buildId": "abc-123-xyz",
  "status": "queued",
  "message": "Build request accepted"
}
```

✅ **Pass Criteria:** 
- Status code 200
- `buildId` is a valid UUID
- Status is "queued"

### Step 2.2: Monitor Build Status

Extract `buildId` from previous response and use it here:

```powershell
$buildId = "abc-123-xyz"
$response = Invoke-WebRequest `
    -Uri "http://localhost:3001/api/build/status/$buildId" `
    -Method Get

$data = $response.Content | ConvertFrom-Json
Write-Output $data | Format-List

# Repeat every few seconds to see progress
Start-Sleep -Seconds 5
```

**Expected Response (In Progress):**
```json
{
  "buildId": "abc-123-xyz",
  "status": "building",
  "progress": 0.45,
  "logs": [
    "✅ Flutter project generated",
    "✅ Dependencies installing...",
    "⏳ Compiling source code"
  ],
  "downloadUrl": null,
  "error": null
}
```

**Expected Response (Completed):**
```json
{
  "buildId": "abc-123-xyz",
  "status": "completed",
  "progress": 1.0,
  "logs": [
    "✅ Flutter project generated",
    "✅ Dependencies installed",
    "✅ APK compiled successfully",
    "📥 Ready for download"
  ],
  "downloadUrl": "http://localhost:3001/api/build/download/abc-123-xyz",
  "error": null
}
```

✅ **Pass Criteria:**
- Progress increases over time
- Status transitions: queued → building → completed
- Logs are populated with real build steps
- `downloadUrl` provided when complete

### Step 2.3: Verify Build Logs

```powershell
$buildId = "abc-123-xyz"
$response = Invoke-WebRequest `
    -Uri "http://localhost:3001/api/build/logs/$buildId" `
    -Method Get

$data = $response.Content | ConvertFrom-Json
$data.logs | ForEach-Object { Write-Output $_ }
```

✅ **Pass Criteria:**
- Returns array of log strings
- Contains project generation messages
- Contains compilation messages
- Contains completion message

### Step 2.4: Download APK

```powershell
$buildId = "abc-123-xyz"
$downloadUrl = "http://localhost:3001/api/build/download/$buildId"

Invoke-WebRequest `
    -Uri $downloadUrl `
    -OutFile "TestApp-$buildId.apk"

# Verify file was created
Get-Item "TestApp-$buildId.apk"
```

✅ **Pass Criteria:**
- File downloads successfully
- File size > 20 MB (release APK)
- File has .apk extension
- File is binary (not text)

### Step 2.5: Cancel Build (Optional Test)

```powershell
$buildId = "abc-123-xyz"
$response = Invoke-WebRequest `
    -Uri "http://localhost:3001/api/build/cancel/$buildId" `
    -Method Post

$response.Content | ConvertFrom-Json
```

✅ **Pass Criteria:**
- Returns 200 status
- Contains success message

---

## Phase 3: Frontend Integration Testing

### Step 3.1: Update Backend URL (Local Testing)

File: `lib/services/build_service.dart`

**Current:**
```dart
static const String _baseUrl = 'http://localhost:3001';
```

✅ Leave as-is for local testing

### Step 3.2: Run Flutter App

```bash
cd c:\Users\nithe\low_code_app

# Run with your favorite device/emulator
flutter run -d chrome   # Chrome for web testing
flutter run             # Default device

# Or in VS Code: Press F5
```

### Step 3.3: Test Build Process via UI

1. **Create a test project:**
   - Click "New Project"
   - Add a simple screen with a button
   - Add some widgets (Button, Text, etc.)

2. **Navigate to Publish screen:**
   - Click menu button (top-right)
   - Click "Publish"

3. **Submit build:**
   - Select "Android APK" platform
   - Click "Build & Publish App"
   - You should see:
     - Loading spinner appears
     - "Building your app..." message
     - Real-time build logs

4. **Monitor progress:**
   - Watch progress bar increase
   - Read actual build steps in log area
   - Wait for "completed" status (3-6 minutes typical)

5. **Verify success screen:**
   - See download URL
   - Button to "Download APK"
   - Button to "Share Link"
   - Log history visible

✅ **Pass Criteria:**
- Progress bar shows activity
- Logs populate in real-time
- No errors displayed
- Download URL appears after completion
- URL is not a fake hardcoded value

### Step 3.4: Test Download Feature

1. **Click "Download APK" button**
   - Should show snackbar: "Download link copied to clipboard"
   - Should prompt browser to download file

2. **Verify file:**
   - File named like: `app-release.apk`
   - File size 30-50 MB typical
   - File is actually an APK (binary)

### Step 3.5: Test Share Feature

1. **Click "Share Link" button**
   - Should open native share dialog
   - Can share via email, messaging, etc.
   - Link is valid for 30 days

2. **Test shared link:**
   - Copy link to another device/browser
   - Visit link: `http://localhost:3001/api/build/download/{buildId}`
   - APK downloads on that device too

✅ **Pass Criteria:**
- Share dialog appears
- Download works from shared link
- Link is valid and accessible

---

## Phase 4: Backend Directory Verification

After tests complete, verify file structure:

```powershell
# Check build directories created
Get-Item c:\Users\nithe\low_code_app\backend\builds
Get-Item c:\Users\nithe\low_code_app\backend\projects
Get-Item c:\Users\nithe\low_code_app\backend\apks
Get-Item c:\Users\nithe\low_code_app\backend\temp

# Count files
(Get-ChildItem -Path c:\Users\nithe\low_code_app\backend\builds -Recurse).Count
(Get-ChildItem -Path c:\Users\nithe\low_code_app\backend\apks -File).Count

# Check APK size
Get-Item c:\Users\nithe\low_code_app\backend\apks\*.apk | ForEach-Object { 
    Write-Output "$($_.Name) - $($_.Length / 1MB)MB"
}
```

✅ **Pass Criteria:**
- `/builds/{buildId}` directories exist
- `/apks/*.apk` files created
- APK files are 30-50 MB each
- Generated Flutter projects have valid structure

---

## Phase 5: Error Scenario Testing

### Test 5.1: Invalid Project Config

```powershell
# Submit empty config
$response = Invoke-WebRequest `
    -Uri "http://localhost:3001/api/build/submit" `
    -Method Post `
    -ContentType "application/json" `
    -Body "{}"

Write-Output $response.Content
```

✅ **Expected:** Error handling without crashing

### Test 5.2: Status Check for Invalid Build ID

```powershell
$response = Invoke-WebRequest `
    -Uri "http://localhost:3001/api/build/status/invalid-id" `
    -Method Get `
    -ErrorAction SilentlyContinue

Write-Output "Status: $($response.StatusCode)"
```

✅ **Expected:** 404 or appropriate error response

### Test 5.3: Network Connection Loss

```powershell
# Stop backend
# In backend terminal: Press Ctrl+C

# Try to submit build in Flutter app
# Expected: Error message about connection failure
# Expected: Graceful error handling (not crash)

# Restart backend
# npm start
```

✅ **Expected:** App shows error, no crashes

### Test 5.4: Build Timeout Simulation

```powershell
# Edit backend build-server.js
# Change timeout to very short (e.g., 10 seconds)
timeout: 10 * 1000  # 10 seconds

# Restart backend
# Submit build - should timeout and return error

# Change back to proper timeout
timeout: 15 * 60 * 1000  # 15 minutes
```

✅ **Expected:** Build fails gracefully with error message

---

## Phase 6: Performance Testing

### Test 6.1: Build Speed Baseline

```powershell
# Record start time
$start = Get-Date

# Submit build and wait for completion
# Monitor status until "completed"

$end = Get-Date
$duration = $end - $start

Write-Output "Total build time: $($duration.TotalSeconds) seconds"
```

✅ **Expected:** 
- 180-360 seconds (3-6 minutes) for typical build
- First build slower (downloads dependencies)
- Subsequent builds faster (cached dependencies)

### Test 6.2: Concurrent Builds

```powershell
# Submit multiple builds simultaneously
for ($i = 1; $i -le 3; $i++) {
    $body = @{
        id = "concurrent-$i"
        name = "TestApp$i"
        screens = @(@{ id = "s1"; name = "Home"; widgets = @() })
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest `
        -Uri "http://localhost:3001/api/build/submit" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body
    
    $response.Content | ConvertFrom-Json | Select-Object buildId
}

# Monitor all builds
# All should build independently without blocking each other
```

✅ **Expected:** Multiple builds process concurrently

---

## Phase 7: Real Device Testing

### Test 7.1: Install APK on Android Device

```bash
# Connect Android device
adb devices

# Install downloaded APK
adb install path\to\app-release.apk

# Launch app
adb shell am start -n com.example.app/.MainActivity

# Check logs
adb logcat
```

✅ **Pass Criteria:**
- APK installs successfully
- App launches
- No runtime crashes
- App displays generated content

### Test 7.2: Test App Functionality

1. **Launch installed app**
2. **Verify:**
   - Screens display correctly
   - Buttons are clickable
   - Navigation works
   - Widgets render properly
   - No performance issues

---

## Checklist: All Tests Passed ✅

- [ ] Backend starts without errors
- [ ] Health endpoint responds
- [ ] Build submission accepted
- [ ] Build status updates in real-time
- [ ] Build logs populated with real steps
- [ ] APK generated and downloadable
- [ ] Frontend integration works
- [ ] Progress bar shows activity
- [ ] Download feature works
- [ ] Share feature works
- [ ] APK file valid (30-50 MB)
- [ ] APK installs on device
- [ ] App runs on device
- [ ] Error handling works
- [ ] Concurrent builds possible
- [ ] Build takes 3-6 minutes

---

## Troubleshooting During Testing

| Issue | Solution |
|-------|----------|
| Backend won't start | Check Node.js version (16+), check port 3001 not in use |
| Flutter not found | Add Flutter SDK to PATH, run `flutter doctor` |
| APK generation fails | Check Android SDK, run `flutter doctor` |
| Download returns 404 | Wait for build to complete, check buildId |
| App crashes on device | Check Android version (API 21+), check logs |
| Slow builds | First build is slower, cache dependency files |
| Port already in use | Kill existing process on 3001 |

---

## Next Steps After Testing

1. ✅ All tests pass → Ready for production deployment
2. 🚀 Deploy backend to cloud server
3. 📝 Update BuildService URL to production endpoint
4. 🔒 Configure SSL/HTTPS
5. 📊 Set up monitoring and logging
6. 🛡️ Implement rate limiting and auth
7. 📱 Test with multiple app configurations

---

## Additional Test Cases

### Advanced: Large Configuration
```json
{
  "id": "large-app",
  "name": "ComplexApp",
  "screens": [
    // 50+ screens with complex widgets
  ],
  "assets": {
    // 100+ images, videos
  }
}
```

Test large builds handle correctly without timeouts.

### Advanced: Special Characters
```json
{
  "name": "Üñíçödé Åpp 🚀",
  "widgets": [{
    "label": "Special: 你好世界 مرحبا",
    "description": "Test UTF-8 handling"
  }]
}
```

Test internationalization support.

### Advanced: Rapid Submissions
Submit 10 builds in quick succession. Verify all complete successfully without losing data.

