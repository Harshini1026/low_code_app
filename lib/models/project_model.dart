import 'package:cloud_firestore/cloud_firestore.dart';
import 'screen_model.dart';

class ProjectModel {
  final String id, name, userId, templateId, templateName;
  final List<AppScreen> screens;
  final ProjectTheme theme;
  final BackendConfig backendConfig;
  final DateTime createdAt, updatedAt;
  final String status;
  final String? publishedUrl;

  ProjectModel({
    required this.id, required this.name, required this.userId,
    required this.templateId, required this.templateName,
    required this.screens, required this.theme, required this.backendConfig,
    required this.createdAt, required this.updatedAt,
    this.status = 'draft', this.publishedUrl,
  });

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      id: doc.id, name: d['name'] ?? '', userId: d['userId'] ?? '',
      templateId: d['templateId'] ?? 'blank', templateName: d['templateName'] ?? '',
      screens: (d['screens'] as List? ?? []).map((s) => AppScreen.fromMap(s)).toList(),
      theme: ProjectTheme.fromMap(d['theme'] ?? {}),
      backendConfig: BackendConfig.fromMap(d['backendConfig'] ?? {}),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] ?? 'draft', publishedUrl: d['publishedUrl'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name, 'userId': userId, 'templateId': templateId,
    'templateName': templateName, 'screens': screens.map((s) => s.toMap()).toList(),
    'theme': theme.toMap(), 'backendConfig': backendConfig.toMap(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'status': status, 'publishedUrl': publishedUrl,
  };

  ProjectModel copyWith({String? name, List<AppScreen>? screens,
      ProjectTheme? theme, BackendConfig? backendConfig, String? status}) =>
    ProjectModel(
      id: id, userId: userId, templateId: templateId, templateName: templateName,
      createdAt: createdAt, updatedAt: DateTime.now(),
      name: name ?? this.name, screens: screens ?? this.screens,
      theme: theme ?? this.theme, backendConfig: backendConfig ?? this.backendConfig,
      status: status ?? this.status,
    );
}

class ProjectTheme {
  final String primaryColor, secondaryColor, backgroundColor, fontFamily;
  final double borderRadius;
  final bool isDarkMode;
  const ProjectTheme({
    this.primaryColor = '#00C896', this.secondaryColor = '#6C63FF',
    this.backgroundColor = '#FFFFFF', this.fontFamily = 'Poppins',
    this.borderRadius = 12.0, this.isDarkMode = false,
  });
  factory ProjectTheme.fromMap(Map<String, dynamic> m) => ProjectTheme(
    primaryColor: m['primaryColor'] ?? '#00C896',
    secondaryColor: m['secondaryColor'] ?? '#6C63FF',
    backgroundColor: m['backgroundColor'] ?? '#FFFFFF',
    fontFamily: m['fontFamily'] ?? 'Poppins',
    borderRadius: (m['borderRadius'] as num?)?.toDouble() ?? 12.0,
    isDarkMode: m['isDarkMode'] ?? false,
  );
  Map<String, dynamic> toMap() => {
    'primaryColor': primaryColor, 'secondaryColor': secondaryColor,
    'backgroundColor': backgroundColor, 'fontFamily': fontFamily,
    'borderRadius': borderRadius, 'isDarkMode': isDarkMode,
  };
}

class BackendConfig {
  final List<DatabaseTable> tables;
  final bool emailAuth, googleAuth, phoneAuth;
  const BackendConfig({this.tables = const [], this.emailAuth = true,
      this.googleAuth = false, this.phoneAuth = false});
  factory BackendConfig.fromMap(Map<String, dynamic> m) => BackendConfig(
    tables: (m['tables'] as List? ?? []).map((t) => DatabaseTable.fromMap(t)).toList(),
    emailAuth: m['emailAuth'] ?? true,
    googleAuth: m['googleAuth'] ?? false,
    phoneAuth: m['phoneAuth'] ?? false,
  );
  Map<String, dynamic> toMap() => {
    'tables': tables.map((t) => t.toMap()).toList(),
    'emailAuth': emailAuth, 'googleAuth': googleAuth, 'phoneAuth': phoneAuth,
  };
}

class DatabaseTable {
  final String id, name;
  final List<String> fields;
  const DatabaseTable({required this.id, required this.name, required this.fields});
  factory DatabaseTable.fromMap(Map<String, dynamic> m) => DatabaseTable(
    id: m['id'], name: m['name'], fields: List<String>.from(m['fields'] ?? []),
  );
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'fields': fields};
}