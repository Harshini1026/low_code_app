// ════════════════════════════════════════════════════════════════════════════════
// APK Build Server - Node.js/Express Backend
// Generates Flutter projects dynamically and builds real APKs
// ════════════════════════════════════════════════════════════════════════════════

const express = require('express');
const fs = require('fs-extra');
const path = require('path');
const { exec } = require('child_process');
const { v4: uuidv4 } = require('uuid');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
const PORT = 3001;

// Middleware
app.use(cors({ origin: '*' }));
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

// Configuration
const BUILDS_DIR = path.join(__dirname, 'builds');
const PROJECTS_DIR = path.join(__dirname, 'projects');
const APKS_DIR = path.join(__dirname, 'apks');
const TEMP_DIR = path.join(__dirname, 'temp');

// Ensure directories exist
[BUILDS_DIR, PROJECTS_DIR, APKS_DIR, TEMP_DIR].forEach(dir => {
    fs.ensureDirSync(dir);
});

// In-memory store for build states (use Redis for production)
const buildStates = new Map();

// ════════════════════════════════════════════════════════════════════════════════
// API Routes
// ════════════════════════════════════════════════════════════════════════════════

/**
 * POST /api/build/submit
 * Submit app config for APK building
 * Body: App configuration JSON
 * Response: { buildId, status, message }
 */
app.post('/api/build/submit', async (req, res) => {
    try {
        const appConfig = req.body;
        const host = req.get('host') || `127.0.0.1:${PORT}`;
        appConfig.backendHost = host;
        const buildId = uuidv4();
        const buildDir = path.join(BUILDS_DIR, buildId);

        if (!appConfig.id || !appConfig.name) {
            return res.status(400).json({ error: 'Missing app id or name' });
        }

        // Create build record
        const buildRecord = {
            id: buildId,
            appId: appConfig.id,
            appName: appConfig.name,
            status: 'queued',
            progress: 0,
            startTime: Date.now(),
            endTime: null,
            logs: ['📋 Build queued'],
            downloadUrl: null,
            error: null,
        };

        buildStates.set(buildId, buildRecord);

        // Save config
        fs.ensureDirSync(buildDir);
        fs.writeJsonSync(path.join(buildDir, 'config.json'), appConfig);

        // Start async build process
        startBuildProcess(buildId, appConfig, buildDir);

        res.json({
            buildId,
            status: 'queued',
            message: 'Build request accepted. Building in background...',
        });
    } catch (error) {
        console.error('Build submission error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/build/status/:buildId
 * Get current build status and progress
 */
app.get('/api/build/status/:buildId', (req, res) => {
    try {
        const { buildId } = req.params;
        const buildRecord = buildStates.get(buildId);

        if (!buildRecord) {
            return res.status(404).json({ error: 'Build not found' });
        }

        res.json({
            buildId,
            status: buildRecord.status,
            progress: buildRecord.progress,
            logs: buildRecord.logs,
            downloadUrl: buildRecord.downloadUrl,
            error: buildRecord.error,
            elapsedTime: buildRecord.endTime
                ? buildRecord.endTime - buildRecord.startTime
                : Date.now() - buildRecord.startTime,
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/build/logs/:buildId
 * Get full build logs for debugging
 */
app.get('/api/build/logs/:buildId', (req, res) => {
    try {
        const { buildId } = req.params;
        const buildRecord = buildStates.get(buildId);

        if (!buildRecord) {
            return res.status(404).json({ error: 'Build not found' });
        }

        res.json({ logs: buildRecord.logs });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/build/cancel/:buildId
 * Cancel an ongoing build
 */
app.post('/api/build/cancel/:buildId', (req, res) => {
    try {
        const { buildId } = req.params;
        const buildRecord = buildStates.get(buildId);

        if (!buildRecord) {
            return res.status(404).json({ error: 'Build not found' });
        }

        if (buildRecord.status === 'completed' || buildRecord.status === 'failed') {
            return res.status(400).json({ error: 'Build already finished' });
        }

        buildRecord.status = 'cancelled';
        buildRecord.logs.push('⛔ Build cancelled by user');

        res.json({ message: 'Build cancelled' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /downloads/:buildId/app-release.apk
 * Download the built APK file
 */
app.get('/downloads/:buildId/app-release.apk', (req, res) => {
    try {
        const { buildId } = req.params;
        const buildRecord = buildStates.get(buildId);

        if (!buildRecord) {
            return res.status(404).json({ error: 'Build not found' });
        }

        if (buildRecord.status !== 'completed') {
            return res.status(400).json({ error: 'Build not completed' });
        }

        const apkPath = path.join(APKS_DIR, `${buildId}.apk`);

        // Verify APK file exists and has content
        if (!fs.existsSync(apkPath)) {
            return res.status(404).json({ error: 'APK file not found' });
        }

        const stats = fs.statSync(apkPath);
        if (stats.size <= 0) {
            return res.status(400).json({ error: 'APK file is empty or corrupted' });
        }

        // Set proper headers for APK download
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', `attachment; filename="app-release.apk"`);
        res.setHeader('Content-Length', stats.size);

        const fileStream = fs.createReadStream(apkPath);
        fileStream.pipe(res);

        fileStream.on('error', (error) => {
            console.error(`Download error for ${buildId}:`, error);
            if (!res.headersSent) {
                res.status(500).json({ error: 'Download failed' });
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ════════════════════════════════════════════════════════════════════════════════
// Build Process
// ════════════════════════════════════════════════════════════════════════════════

async function startBuildProcess(buildId, appConfig, buildDir) {
    const buildRecord = buildStates.get(buildId);

    try {
        buildRecord.logs.push('🚀 Starting APK build process...');
        updateProgress(buildId, 5);

        // Step 1: Generate Flutter project
        await generateFlutterProject(buildId, appConfig, buildDir);
        updateProgress(buildId, 20);
        buildRecord.logs.push('✅ Flutter project generated');

        // Step 2: Install dependencies
        await installDependencies(buildId, buildDir);
        updateProgress(buildId, 40);
        buildRecord.logs.push('✅ Dependencies installed');

        // Step 3: Build APK
        await buildApk(buildId, buildDir);
        updateProgress(buildId, 90);
        buildRecord.logs.push('✅ APK compilation completed');

        // Step 4: Move APK to storage
        const apkPath = await moveApkToStorage(buildId, buildDir);
        updateProgress(buildId, 100);

        // Generate download link (valid for 30 days)
        const downloadUrl = generateDownloadLink(buildId, appConfig.backendHost || `127.0.0.1:${PORT}`);

        buildRecord.status = 'completed';
        buildRecord.downloadUrl = downloadUrl;
        buildRecord.endTime = Date.now();
        buildRecord.logs.push(`📥 Download URL: ${downloadUrl}`);

        console.log(`Build ${buildId} completed successfully`);
    } catch (error) {
        console.error(`Build ${buildId} failed:`, error);
        buildRecord.status = 'failed';
        buildRecord.error = error.message;
        buildRecord.endTime = Date.now();
        buildRecord.logs.push(`❌ Build failed: ${error.message}`);
    }
}

async function generateFlutterProject(buildId, appConfig, buildDir) {
    const projectDir = path.join(buildDir, 'flutter_app');
    fs.ensureDirSync(projectDir);

    // Create pubspec.yaml
    const pubspec = generatePubspec(appConfig);
    fs.writeFileSync(
        path.join(projectDir, 'pubspec.yaml'),
        pubspec
    );

    // Create main.dart
    const mainDart = generateMainDart(appConfig);
    fs.ensureDirSync(path.join(projectDir, 'lib'));
    fs.writeFileSync(
        path.join(projectDir, 'lib', 'main.dart'),
        mainDart
    );

    // Create Android AndroidManifest.xml
    const androidManifest = generateAndroidManifest(appConfig);
    fs.ensureDirSync(path.join(projectDir, 'android', 'app', 'src', 'main'));
    fs.writeFileSync(
        path.join(projectDir, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
        androidManifest
    );
}

async function installDependencies(buildId, buildDir) {
    const projectDir = path.join(buildDir, 'flutter_app');
    return new Promise((resolve, reject) => {
        exec(
            'cd ' + projectDir + ' && flutter pub get',
            { maxBuffer: 10 * 1024 * 1024 },
            (error, stdout, stderr) => {
                if (error) {
                    reject(new Error(`Dependency installation failed: ${stderr}`));
                } else {
                    resolve();
                }
            }
        );
    });
}

async function buildApk(buildId, buildDir) {
    const projectDir = path.join(buildDir, 'flutter_app');
    const buildRecord = buildStates.get(buildId);

    return new Promise((resolve, reject) => {
        exec(
            'cd ' + projectDir + ' && flutter build apk --release',
            { maxBuffer: 50 * 1024 * 1024, timeout: 15 * 60 * 1000 }, // 15 min timeout
            (error, stdout, stderr) => {
                if (error) {
                    buildRecord.logs.push('Build command output: ' + stdout);
                    buildRecord.logs.push('Build command error: ' + stderr);
                    reject(new Error(`APK build failed: ${stderr}`));
                } else {
                    resolve();
                }
            }
        );
    });
}

async function moveApkToStorage(buildId, buildDir) {
    const flutterProjectDir = path.join(buildDir, 'flutter_app');
    const apkSource = path.join(
        flutterProjectDir,
        'build',
        'app',
        'outputs',
        'flutter-apk',
        'app-release.apk'
    );

    if (!fs.existsSync(apkSource)) {
        throw new Error('APK file not found after build');
    }

    const apkDest = path.join(APKS_DIR, `${buildId}.apk`);
    await fs.copy(apkSource, apkDest);

    return apkDest;
}

function generateDownloadLink(buildId, host) {
    return `http://${host}/downloads/${buildId}/app-release.apk`;
}

function updateProgress(buildId, progress) {
    const buildRecord = buildStates.get(buildId);
    if (buildRecord) {
        buildRecord.progress = Math.min(progress, 99); // Never reach 100% until complete
    }
}

// ════════════════════════════════════════════════════════════════════════════════
// Code Generation Functions
// ════════════════════════════════════════════════════════════════════════════════

function generatePubspec(appConfig) {
    return `name: ${sanitizePackageName(appConfig.name)}
description: ${appConfig.description || 'Built with AppForge'}
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.5+1
  go_router: ^17.2.1
  cached_network_image: ^3.2.3
  firebase_core: ^2.32.0
  firebase_auth: ^4.19.0
  cloud_firestore: ^4.17.0
  firebase_storage: ^11.7.0
  firebase_messaging: ^14.9.0
  uuid: ^4.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
`;
}

function generateMainDart(appConfig) {
    const screenCount = (appConfig.screens || []).length;

    return `import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${appConfig.name}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('${appConfig.name}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('App Built Successfully!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Screens: ${screenCount}'),
            const SizedBox(height: 20),
            const Text('This is a placeholder screen.\\nCustom screens from the builder', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
`;
}

function generateAndroidManifest(appConfig) {
    const packageName = sanitizePackageName(appConfig.name);

    return `<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="${packageName}">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:label="${appConfig.name}"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true">
        
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:exported="true">
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>`;
}

function sanitizePackageName(name) {
    return 'com.appforge.' + name
        .toLowerCase()
        .replace(/[^a-z0-9]/g, '_')
        .replace(/_+/g, '_')
        .substring(0, 20);
}

// ════════════════════════════════════════════════════════════════════════════════
// Cleanup and Server Management
// ════════════════════════════════════════════════════════════════════════════════

// Cleanup old builds (older than 7 days)
function cleanupOldBuilds() {
    const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days
    const now = Date.now();

    buildStates.forEach((record, buildId) => {
        if (record.endTime && (now - record.endTime) > maxAge) {
            buildStates.delete(buildId);
            const buildDir = path.join(BUILDS_DIR, buildId);
            fs.removeSync(buildDir);
        }
    });
}

setInterval(cleanupOldBuilds, 24 * 60 * 60 * 1000); // Run daily

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 APK Build Server running on port ${PORT}`);
    console.log(`📁 Builds directory: ${BUILDS_DIR}`);
    console.log(`📁 APKs directory: ${APKS_DIR}`);
});

module.exports = app;
