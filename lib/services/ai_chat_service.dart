class AiChatService {
  // ── Knowledge base ────────────────────────────────────────────────────────
  static const Map<String, String> _kb = {
    'start': '''
🚀 Getting Started with AppForge:

1. Tap "New App" on the Home screen
2. Pick a template (or start blank)
3. Give your app a name and tap "Create App"
4. You'll land in the Builder with a phone canvas
5. Drag widgets from the left panel onto the canvas
6. Tap any widget to edit its properties on the right
7. Use the Backend tab to set up your database
8. Hit Preview to see how it looks live
9. When ready, tap Publish to go live!
''',

    'template': '''
📱 Using Templates:

AppForge has 7 ready-made templates:
• 🛒 E-Commerce — products, cart, checkout, orders
• 🏫 School — attendance, grades, timetable, notices
• 🍔 Food Delivery — menu, ordering, live tracking
• 💼 Business CRM — contacts, leads, tasks, reports
• 💪 Fitness — workouts, nutrition, progress tracking
• 📰 Blog — articles, categories, comments
• ✨ Blank — start from scratch

Each template comes with pre-built screens and a
Firebase database already configured. You can
customise everything after selecting a template.
''',

    'widget': '''
🧩 Adding Widgets:

1. Open the Builder for your project
2. In the left sidebar, tap the "Widgets" tab (grid icon)
3. Browse by category: Basic, Forms, Layout, Media
4. Tap a widget to add it to the canvas
5. Or drag it directly onto the phone screen
6. Tap the placed widget to select it
7. Edit its properties in the right panel

Available widgets:
• Basic: Text, Button, Image, Icon, Divider
• Forms: Text Field, Dropdown, Checkbox, Switch, Form
• Layout: Card, List, Grid, Nav Bar, App Bar, Tabs
• Media: Chart, Map, Video, Carousel
''',

    'propert': '''
🎨 Customising Widget Properties:

1. Tap any widget on the canvas to select it
2. The Properties panel opens on the right
3. Edit text, colors, font sizes, border radius, etc.
4. Changes apply instantly to the canvas preview
5. Use the color picker for background & text colors
6. Sliders control sizes and spacing
7. Dropdowns let you set widget type/action

You can also:
• Tap "Duplicate" to copy a widget
• Tap "Delete" to remove it
• Tap "Bind to Database" to connect live data
''',

    'backend': '''
🗄️ Setting Up Your Database:

1. In the Builder, tap the "Backend" tab (database icon)
2. Tap "Create Table" to add a Firestore collection
3. Enter the table name (e.g. "Products")
4. List fields separated by commas (e.g. name, price, image)
5. id and created_at are added automatically
6. Toggle Auth methods: Email, Google, Phone OTP
7. Security rules are auto-generated to protect your data

Your database runs on Firebase Firestore which:
✅ Scales to millions of users automatically
✅ Supports real-time sync across devices
✅ Has military-grade security rules
✅ Is owned entirely by YOU — no vendor lock-in
''',

    'security': '''
🔒 Security & Data Ownership:

AppForge gives you full control:

1. Your own Firebase project — data belongs to you
2. Auto-generated Firestore security rules
3. Each user can only access their own data
4. All traffic is encrypted via HTTPS
5. Data encrypted at rest on Google's servers
6. You can export all Firestore data anytime as JSON
7. Migrate to any backend (AWS, Supabase, self-hosted)

Security rules example:
  match /users/{uid} {
    allow read, write: if request.auth.uid == uid;
  }
''',

    'bind': '''
🔗 Binding Data to UI Widgets:

1. Select a widget on the canvas
2. In the Properties panel, tap "Bind to Database"
3. Choose a Firestore collection (table)
4. Choose the field to display
5. Tap "Bind Data" to confirm

At runtime, the widget automatically shows live
data from Firestore. For example:
• A Text widget can show the product "name" field
• An Image widget can show the product "image" URL
• A List widget can show all items in a collection

Changes in Firestore update the UI in real-time!
''',

    'publish': '''
🚀 Publishing Your App:

1. Tap "Preview" to test your app first
2. If it looks good, tap "Publish"
3. Choose your platform:
   • 📱 Android APK — install on any Android device
   • 🍎 iOS App — deploy to App Store (Mac needed)
   • 🌐 Web App — live on Firebase Hosting instantly
   • 📦 Flutter Source — full Dart code to edit freely
4. Tap "Build & Publish App"
5. Wait ~1 minute for the build to complete
6. Share your live app URL with anyone!

✅ No vendor lock-in — you own 100% of the code
✅ Firebase Hosting is free for most apps
''',
  };

  // ── Public method: getResponse ────────────────────────────────────────────
  String getResponse(String userMessage) {
    final input = userMessage.toLowerCase();

    if (_matches(input, ['start', 'begin', 'how', 'first', 'new', 'create'])) {
      return _kb['start']!;
    }
    if (_matches(input, ['template', 'ecommerce', 'school', 'food', 'crm', 'fitness', 'blog', 'blank'])) {
      return _kb['template']!;
    }
    if (_matches(input, ['widget', 'component', 'add', 'drag', 'button', 'text', 'image', 'input'])) {
      return _kb['widget']!;
    }
    if (_matches(input, ['propert', 'custom', 'color', 'font', 'size', 'style', 'edit', 'change'])) {
      return _kb['propert']!;
    }
    if (_matches(input, ['backend', 'database', 'firestore', 'table', 'collection', 'field', 'auth'])) {
      return _kb['backend']!;
    }
    if (_matches(input, ['security', 'rule', 'safe', 'protect', 'own', 'data', 'privacy'])) {
      return _kb['security']!;
    }
    if (_matches(input, ['bind', 'connect', 'link', 'live data', 'dynamic', 'real-time'])) {
      return _kb['bind']!;
    }
    if (_matches(input, ['publish', 'deploy', 'launch', 'export', 'apk', 'ios', 'web', 'release'])) {
      return _kb['publish']!;
    }

    // Fallback
    return '''
🤖 I'm not sure about that specific topic, but here's what I can help with:

• 🚀 Getting started & creating your first app
• 📱 Choosing and using templates
• 🧩 Adding and configuring widgets
• 🎨 Customising widget properties & colors
• 🗄️ Setting up your Firebase database
• 🔒 Security rules & data ownership
• 🔗 Binding live data to UI elements
• 🌐 Publishing to Android, iOS, or Web

Try asking about any of these topics!
''';
  }

  // ── Helper: check if input contains any of the keywords ──────────────────
  bool _matches(String input, List<String> keywords) {
    return keywords.any((k) => input.contains(k));
  }
}