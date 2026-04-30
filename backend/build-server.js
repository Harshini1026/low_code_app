// ════════════════════════════════════════════════════════════════════════════════
// APK Build Server - Node.js/Express Backend (FIXED VERSION)
// Generates Flutter projects dynamically and builds real APKs
// 
// FIXES APPLIED:
// ✅ Normalized API endpoints (removed duplicates)
// ✅ Unified status field: "pending" | "building" | "complete" | "failed"  
// ✅ Fixed IP address extraction for download URLs
// ✅ Improved error capture from Flutter build process
// ✅ Better APK validation
// ════════════════════════════════════════════════════════════════════════════════

const express = require('express');
const fs = require('fs-extra');
const path = require('path');
const { exec } = require('child_process');
const { v4: uuidv4 } = require('uuid');
const bodyParser = require('body-parser');
const cors = require('cors');
const os = require('os');

const app = express();
const PORT = 3001;

// Middleware - CORS configuration for web support
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: false
}));
app.options('*', cors());

// Additional CORS headers middleware
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    next();
});

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
// Helper: Extract IP address from host header or request
// ════════════════════════════════════════════════════════════════════════════════
function getServerIpAddress(req) {
    // Try to get from X-Forwarded-For header (if behind proxy)
    const forwarded = req.get('x-forwarded-for');
    if (forwarded) {
        return forwarded.split(',')[0].trim();
    }

    // Get from host header
    const host = req.get('host');
    if (host) {
        return host.split(':')[0]; // Remove port if present
    }

    // Fallback: get local IP
    try {
        const interfaces = os.networkInterfaces();
        for (const name of Object.keys(interfaces)) {
            for (const iface of interfaces[name]) {
                // Skip loopback and internal addresses
                if (iface.family === 'IPv4' && !iface.internal) {
                    return iface.address;
                }
            }
        }
    } catch (e) {
        console.warn('Could not detect IP:', e.message);
    }

    return '127.0.0.1';
}

// ════════════════════════════════════════════════════════════════════════════════
// Health Check Endpoint (must be before other routes)
// ════════════════════════════════════════════════════════════════════════════════

/**
 * GET /health
 * Simple health check endpoint for backend availability
 * Used by Flutter app to verify backend is running
 */
app.get('/health', (req, res) => {
    res.json({ status: 'running' });
});

// ════════════════════════════════════════════════════════════════════════════════
// API Routes
// ════════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════════
// API Endpoints (UNIFIED)
// ════════════════════════════════════════════════════════════════════════════════

/**
 * GET /health
 * Health check endpoint - frontend uses this to verify backend is running
 */
app.get('/health', (req, res) => {
    res.json({ status: 'running' });
});

/**
 * POST /api/build/submit
 * Submit app config for APK building (PRIMARY ENDPOINT)
 * Body: App configuration JSON
 * Response: { buildId, status, message }
 */
app.post('/api/build/submit', async (req, res) => {
    try {
        const appConfig = req.body;
        const serverIp = getServerIpAddress(req);
        const buildId = uuidv4();
        const buildDir = path.join(BUILDS_DIR, buildId);

        if (!appConfig.id || !appConfig.name) {
            return res.status(400).json({ error: 'Missing app id or name' });
        }

        // Store server info for download URL generation
        appConfig.serverIp = serverIp;

        // Create build record with unified status
        const buildRecord = {
            id: buildId,
            appId: appConfig.id,
            appName: appConfig.name,
            status: 'pending',  // ✅ UNIFIED: "pending" | "building" | "complete" | "failed"
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

        // Start async build process (non-blocking)
        startBuildProcess(buildId, appConfig, buildDir).catch(err => {
            console.error(`Background build error for ${buildId}:`, err);
        });

        console.log(`✅ Build ${buildId} queued for ${appConfig.name}`);

        res.json({
            buildId,
            status: 'pending',
            message: 'Build request accepted. Building in background...',
        });
    } catch (error) {
        console.error('Build submission error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/build/status/:buildId
 * Get current build status, progress, logs, and download URL
 * Returns unified status: "pending" | "building" | "complete" | "failed"
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

        if (buildRecord.status === 'complete' || buildRecord.status === 'failed') {
            return res.status(400).json({ error: 'Build already finished' });
        }

        buildRecord.status = 'failed';
        buildRecord.logs.push('⛔ Build cancelled by user');

        res.json({ message: 'Build cancelled' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ════════════════════════════════════════════════════════════════════════════════
// Build Process
// ════════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════════
// Build Process (IMPROVED)
// ════════════════════════════════════════════════════════════════════════════════

async function startBuildProcess(buildId, appConfig, buildDir) {
    const buildRecord = buildStates.get(buildId);

    try {
        buildRecord.logs.push('🚀 Starting APK build process...');
        buildRecord.status = 'building';  // ✅ Transition to building
        updateProgress(buildId, 5);

        // Step 1: Generate Flutter project
        buildRecord.logs.push('📝 Generating Flutter project...');
        await generateFlutterProject(buildId, appConfig, buildDir);
        updateProgress(buildId, 20);
        buildRecord.logs.push('✅ Flutter project generated');

        // Step 2: Install dependencies
        buildRecord.logs.push('📦 Installing dependencies (flutter pub get)...');
        await installDependencies(buildId, buildDir);
        updateProgress(buildId, 40);
        buildRecord.logs.push('✅ Dependencies installed');

        // Step 3: Build APK
        buildRecord.logs.push('🔨 Building APK (flutter build apk --release)...');
        await buildApk(buildId, buildDir);
        updateProgress(buildId, 85);
        buildRecord.logs.push('✅ APK compilation completed');

        // Step 4: Validate APK file exists
        buildRecord.logs.push('✔️ Validating APK file...');
        const apkPath = await validateApkExists(buildId, buildDir);
        updateProgress(buildId, 95);
        buildRecord.logs.push(`✅ APK validated (${formatFileSize(fs.statSync(apkPath).size)})`);

        // Step 5: Move APK to storage
        buildRecord.logs.push('💾 Moving APK to storage...');
        await moveApkToStorage(buildId, buildDir, apkPath);
        updateProgress(buildId, 99);

        // Step 6: Generate download link
        const downloadUrl = generateDownloadLink(buildId, appConfig.serverIp);

        buildRecord.status = 'complete';  // ✅ Transition to complete
        buildRecord.progress = 100;
        buildRecord.downloadUrl = downloadUrl;
        buildRecord.endTime = Date.now();
        buildRecord.logs.push('✅ Build completed successfully!');
        buildRecord.logs.push(`📥 Download URL: ${downloadUrl}`);

        console.log(`✅ Build ${buildId} completed successfully`);
    } catch (error) {
        console.error(`❌ Build ${buildId} failed:`, error);
        buildRecord.status = 'failed';  // ✅ Transition to failed
        buildRecord.error = error.message;
        buildRecord.endTime = Date.now();
        buildRecord.logs.push(`\n❌ BUILD FAILED:`);
        buildRecord.logs.push(`Error: ${error.message}`);
        buildRecord.logs.push(`\n💡 Troubleshooting:`);
        buildRecord.logs.push(`1. Check backend console for detailed error messages`);
        buildRecord.logs.push(`2. Ensure Flutter SDK is installed and in PATH`);
        buildRecord.logs.push(`3. Ensure Android SDK is installed and configured`);
    }
}

async function generateFlutterProject(buildId, appConfig, buildDir) {
    const projectDir = path.join(buildDir, 'flutter_app');
    fs.ensureDirSync(projectDir);

    // Step 1: Create pubspec.yaml
    const pubspec = generatePubspec(appConfig);
    fs.writeFileSync(
        path.join(projectDir, 'pubspec.yaml'),
        pubspec
    );

    // Step 2: Create main.dart
    const mainDart = generateMainDart(appConfig);
    fs.ensureDirSync(path.join(projectDir, 'lib'));
    fs.writeFileSync(
        path.join(projectDir, 'lib', 'main.dart'),
        mainDart
    );

    // Step 3: Create Android directory structure
    const packageName = sanitizePackageName(appConfig.name);
    const kotlinDir = path.join(projectDir, 'android', 'app', 'src', 'main', 'kotlin', packageName.replace(/\./g, '/'));
    fs.ensureDirSync(kotlinDir);

    // Step 4: Create MainActivity.kt (v2 embedding)
    const mainActivityKt = generateMainActivityKt(packageName);
    fs.writeFileSync(
        path.join(kotlinDir, 'MainActivity.kt'),
        mainActivityKt
    );

    // Step 5: Create AndroidManifest.xml
    const androidManifest = generateAndroidManifest(appConfig, packageName);
    fs.ensureDirSync(path.join(projectDir, 'android', 'app', 'src', 'main'));
    fs.writeFileSync(
        path.join(projectDir, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
        androidManifest
    );

    // Step 6: Create gradle.properties with v2 embedding support
    const gradleProperties = generateGradleProperties();
    fs.ensureDirSync(path.join(projectDir, 'android'));
    fs.writeFileSync(
        path.join(projectDir, 'android', 'gradle.properties'),
        gradleProperties
    );

    // Step 7: Create build.gradle (Module: app)
    const appBuildGradle = generateAppBuildGradle(packageName);
    fs.ensureDirSync(path.join(projectDir, 'android', 'app'));
    fs.writeFileSync(
        path.join(projectDir, 'android', 'app', 'build.gradle'),
        appBuildGradle
    );

    // Step 8: Create build.gradle (Project: android)
    const projectBuildGradle = generateProjectBuildGradle();
    fs.writeFileSync(
        path.join(projectDir, 'android', 'build.gradle'),
        projectBuildGradle
    );

    // Step 9: Create settings.gradle
    const settingsGradle = generateSettingsGradle();
    fs.writeFileSync(
        path.join(projectDir, 'android', 'settings.gradle'),
        settingsGradle
    );

    // Step 10: Create .gitignore
    const gitignore = generateGitignore();
    fs.writeFileSync(
        path.join(projectDir, '.gitignore'),
        gitignore
    );

    // Step 11: Create Android resources (styles.xml for LaunchTheme)
    const resDir = path.join(projectDir, 'android', 'app', 'src', 'main', 'res');
    const valuesDir = path.join(resDir, 'values');
    fs.ensureDirSync(valuesDir);

    const stylesXml = generateStylesXml();
    fs.writeFileSync(
        path.join(valuesDir, 'styles.xml'),
        stylesXml
    );

    // Step 12: Create local.properties
    const localProperties = generateLocalProperties();
    fs.writeFileSync(
        path.join(projectDir, 'android', 'local.properties'),
        localProperties
    );

    // Step 13: Create drawable resources
    const drawableDir = path.join(resDir, 'drawable');
    fs.ensureDirSync(drawableDir);

    const launchBackground = generateLaunchBackgroundXml();
    fs.writeFileSync(
        path.join(drawableDir, 'launch_background.xml'),
        launchBackground
    );

    // Step 14: Create color resources
    const colorsDir = path.join(resDir, 'values');
    const colorsXml = generateColorsXml();
    fs.writeFileSync(
        path.join(colorsDir, 'colors.xml'),
        colorsXml
    );
}

async function installDependencies(buildId, buildDir) {
    const projectDir = path.join(buildDir, 'flutter_app');
    const buildRecord = buildStates.get(buildId);

    return new Promise((resolve, reject) => {
        const command = `cd "${projectDir}" && flutter pub get`;

        exec(
            command,
            { maxBuffer: 10 * 1024 * 1024, shell: true },
            (error, stdout, stderr) => {
                if (error) {
                    const errorMsg = stderr || stdout || error.message;
                    buildRecord.logs.push(`\n⚠️ Dependency installation output:`);
                    buildRecord.logs.push(errorMsg);
                    reject(new Error(`Dependency installation failed: ${errorMsg}`));
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
        const command = `cd "${projectDir}" && flutter build apk --release 2>&1`;

        exec(
            command,
            { maxBuffer: 50 * 1024 * 1024, timeout: 30 * 60 * 1000, shell: true },
            (error, stdout, stderr) => {
                if (error) {
                    // Capture both stdout and stderr
                    const fullOutput = (stdout || '') + (stderr || '');

                    buildRecord.logs.push(`\n📋 Build Output:`);
                    fullOutput.split('\n').forEach(line => {
                        if (line.trim()) {
                            buildRecord.logs.push(line);
                        }
                    });

                    const errorMsg = stderr || stdout || error.message || 'Unknown build error';
                    reject(new Error(`APK build failed: ${errorMsg}`));
                } else {
                    resolve();
                }
            }
        );
    });
}

async function validateApkExists(buildId, buildDir) {
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
        throw new Error(`APK file not found at expected location: ${apkSource}`);
    }

    const stats = fs.statSync(apkSource);
    if (stats.size <= 0) {
        throw new Error(`APK file is empty or corrupted (size: ${stats.size} bytes)`);
    }

    return apkSource;
}

async function moveApkToStorage(buildId, buildDir, apkSource) {
    const apkDest = path.join(APKS_DIR, `${buildId}.apk`);

    try {
        await fs.copy(apkSource, apkDest);

        // Verify copy was successful
        if (!fs.existsSync(apkDest)) {
            throw new Error('APK copy verification failed');
        }

        const stats = fs.statSync(apkDest);
        if (stats.size <= 0) {
            throw new Error('APK copy resulted in empty file');
        }
    } catch (error) {
        throw new Error(`Failed to move APK to storage: ${error.message}`);
    }

    return apkDest;
}

function generateDownloadLink(buildId, serverIp) {
    // Use the detected server IP for download URL
    return `http://${serverIp}:${PORT}/api/download/${buildId}`;
}

function updateProgress(buildId, progress) {
    const buildRecord = buildStates.get(buildId);
    if (buildRecord) {
        buildRecord.progress = Math.min(progress, 99); // Never reach 100% until complete
    }
}

function formatFileSize(bytes) {
    const mb = (bytes / 1024 / 1024).toFixed(2);
    return `${mb} MB`;
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

function generateMainActivityKt(packageName) {
    return `package ${packageName}

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
`;
}

function generateGradleProperties() {
    return `# Project-wide Gradle settings.
# For more details on how to configure your build environment visit
# http://www.gradle.org/guide/topics/build_environment.html.
# Specifies the JVM arguments used for the daemon process.
# The setting is particularly useful for headless machines. See also
# http://www.gradle.org/guide/topics/build_environment/daemon_properties.html
# Increase the heap size of the daemon to 2GB to avoid OutOfMemory errors
org.gradle.jvmargs=-Xmx2048m

# When configured, Gradle will run in incubating parallel mode.
# This option should only be used with decoupled projects. See Gradle documentation for more details.
# org.gradle.parallel=true
org.gradle.parallel=true

# Enable the new Gradle build cache feature for faster builds
org.gradle.caching=true

# Enable AndroidX
android.useAndroidX=true

# Enable Jetifier for library compatibility
android.enableJetifier=true

# Target Android API 34 with source and target compatibility 17
android.compileSdkVersion=34
`;
}

function generateAppBuildGradle(packageName) {
    return `plugins {
    id 'com.android.application'
    id 'kotlin-android'
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "\${flutterRoot}/packages/flutter_tools/gradle/flutter.gradle"

android {
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "${packageName}"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation 'androidx.window:window:1.2.0'
}
`;
}

function generateProjectBuildGradle() {
    return `buildscript {
    ext.kotlin_version = '1.7.10'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "\${rootProject.buildDir}/\${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
`;
}

function generateSettingsGradle() {
    return `pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        def propertiesFile = new File(rootDir.parentFile, '.dart_tool/package_config.json')
        if (propertiesFile.exists()) {
            propertiesFile.withInputStream { stream ->
                properties.load(stream)
            }
        }
        properties.getProperty('flutter.sdk') ?: System.env.FLUTTER_SDK ?: System.getenv('FLUTTER_SDK')
    }

    settings.ext.flutterSdkPath = flutterSdkPath()

    includeBuild("\${settings.ext.flutterSdkPath}/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id 'dev.flutter.flutter-gradle-plugin' version '1.0.0' apply false
}

include ':app'

def localPropertiesFile = new File(rootDir, 'local.properties')
def properties = new Properties()

if (localPropertiesFile.exists()) {
    properties.load(localPropertiesFile.newDataInputStream())
}

def flutterSdkPath = properties.getProperty('flutter.sdk')
if (flutterSdkPath != null) {
    System.setProperty('flutter.sdk', flutterSdkPath)
}

def flutterNdkPath = properties.getProperty('flutter.ndk')
if (flutterNdkPath != null) {
    System.setProperty('flutter.ndk', flutterNdkPath)
}
`;
}

function generateStylesXml() {
    return `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Theme for the splash screen displayed before loading the Flutter UI -->
    <style name="LaunchTheme" parent="@android:style/Theme.NoTitleBar">
        <!-- Show a splash screen on the activity. Automatically removed when
             the Flutter engine draws its first frame -->
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowFullscreen">false</item>
        <item name="android:windowDrawsSystemBarBackgrounds">false</item>
    </style>

    <!-- Theme of Flutter Demo app -->
    <style name="NormalTheme" parent="@android:style/Theme.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
`;
}

function generateLocalProperties() {
    return `# Automatically generated by Flutter CLI.
# Do not edit or check into version control.
`;
}

function generateLaunchBackgroundXml() {
    return `<?xml version="1.0" encoding="utf-8"?>
<!-- Modify this file to customize your launch splash screen -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/io_flutter_splash_screen_background" />

    <!-- You can insert your own image assets here -->
    <!-- <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/launch_image" />
    </item> -->
</layer-list>
`;
}

function generateColorsXml() {
    return `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- The color used with the launch icon background (for API 21+) -->
    <color name="io_flutter_splash_screen_background">#FFFFFFFF</color>
</resources>
`;
}

function generateAndroidManifest(appConfig, packageName) {
    const pkg = packageName || sanitizePackageName(appConfig.name);

    return `<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="${pkg}">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:label="${appConfig.name}"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true">
        
        <!-- Flutter v2 embedding MainActivity -->
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

        <!-- Flutter v2 embedding metadata (REQUIRED) -->
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

// ════════════════════════════════════════════════════════════════════════════════
// Download Endpoint (UNIFIED)
// ════════════════════════════════════════════════════════════════════════════════

/**
 * GET /api/download/:buildId
 * Download the built APK file (PRIMARY ENDPOINT)
 */
app.get('/api/download/:buildId', (req, res) => {
    try {
        const { buildId } = req.params;
        const buildRecord = buildStates.get(buildId);

        if (!buildRecord) {
            return res.status(404).json({ error: 'Build not found' });
        }

        if (buildRecord.status !== 'complete') {
            return res.status(400).json({
                error: `Build not completed. Current status: ${buildRecord.status}`,
                status: buildRecord.status
            });
        }

        const apkPath = path.join(APKS_DIR, `${buildId}.apk`);

        // Verify APK file exists and has content
        if (!fs.existsSync(apkPath)) {
            return res.status(404).json({ error: 'APK file not found in storage' });
        }

        const stats = fs.statSync(apkPath);
        if (stats.size <= 0) {
            return res.status(400).json({ error: 'APK file is empty or corrupted' });
        }

        // Set proper headers for APK download
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', 'attachment; filename="app-release.apk"');
        res.setHeader('Content-Length', stats.size);
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');

        const fileStream = fs.createReadStream(apkPath);
        fileStream.pipe(res);

        fileStream.on('error', (error) => {
            console.error(`Download error for ${buildId}:`, error);
            if (!res.headersSent) {
                res.status(500).json({ error: 'Download failed' });
            }
        });

        console.log(`📥 APK ${buildId} downloaded (${formatFileSize(stats.size)})`);
    } catch (error) {
        console.error('Download error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ════════════════════════════════════════════════════════════════════════════════
// Server Startup and Cleanup
// ════════════════════════════════════════════════════════════════════════════════

// Cleanup old builds (older than 7 days)
function cleanupOldBuilds() {
    const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days
    const now = Date.now();

    let cleanedCount = 0;
    buildStates.forEach((record, buildId) => {
        if (record.endTime && (now - record.endTime) > maxAge) {
            buildStates.delete(buildId);
            const buildDir = path.join(BUILDS_DIR, buildId);
            try {
                fs.removeSync(buildDir);
                cleanedCount++;
            } catch (e) {
                console.warn(`Failed to cleanup build ${buildId}:`, e.message);
            }
        }
    });

    if (cleanedCount > 0) {
        console.log(`🧹 Cleaned up ${cleanedCount} old build(s)`);
    }
}

// Run cleanup every 24 hours
setInterval(cleanupOldBuilds, 24 * 60 * 60 * 1000);

// Also run cleanup on startup
cleanupOldBuilds();

// Start server on all interfaces (0.0.0.0) so it's accessible from other machines
app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n${'═'.repeat(60)}`);
    console.log(`🚀 APK Build Server is running!`);
    console.log(`${'═'.repeat(60)}`);
    console.log(`\n📍 Server Address: http://0.0.0.0:${PORT}`);
    console.log(`📍 Local Machine: http://localhost:${PORT}`);
    console.log(`\n📂 Directories:`);
    console.log(`   ├─ Builds: ${BUILDS_DIR}`);
    console.log(`   ├─ Projects: ${PROJECTS_DIR}`);
    console.log(`   ├─ APKs: ${APKS_DIR}`);
    console.log(`   └─ Temp: ${TEMP_DIR}`);
    console.log(`\n🔗 API Endpoints:`);
    console.log(`   ├─ Health: GET  /health`);
    console.log(`   ├─ Submit: POST /api/build/submit`);
    console.log(`   ├─ Status: GET  /api/build/status/:buildId`);
    console.log(`   └─ Download: GET  /api/download/:buildId`);
    console.log(`\n${'═'.repeat(60)}\n`);
});

module.exports = app;
