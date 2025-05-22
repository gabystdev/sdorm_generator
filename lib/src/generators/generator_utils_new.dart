// Generator utilities for analyzing Dart models
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:source_gen/source_gen.dart';
import 'package:supabase_dart_client/src/annotations/annotations.dart';
// import 'package:supabase_dart_client/src/annotations/table_annotations.dart';
// import 'package:supabase_dart_client/src/annotations/relationship_annotations.dart';

/// Information about a model field
class FieldInfo {
  /// The name of the field
  final String name;

  /// The type of the field
  final String type;

  /// The column name in the database
  final String? columnName;

  /// Whether the field is nullable
  final bool isNullable;

  /// Whether the field is a primary key
  final bool isPrimaryKey;

  /// Whether the field is a computed field
  final bool isComputedField;

  /// Whether to exclude the field from insert operations
  final bool excludeFromInsert;

  /// Whether to exclude the field from update operations
  final bool excludeFromUpdate;

  /// Description of the field's purpose
  final String? description;

  FieldInfo({
    required this.name,
    required this.type,
    this.columnName,
    this.isNullable = false,
    this.isPrimaryKey = false,
    this.isComputedField = false,
    this.excludeFromInsert = false,
    this.excludeFromUpdate = false,
    this.description,
  });
}

/// Information about a relationship
class RelationshipInfo {
  /// The name of the field representing the relationship
  final String name;

  /// The type of entity referred in this relationship
  final String type;

  /// Optional description
  final String? description;

  RelationshipInfo({
    required this.name,
    required this.type,
    this.description,
  });
}

/// Extract field information from a class
List<FieldInfo> getModelFields(ClassElement classElement) {
  final fields = <FieldInfo>[];

  for (final field in classElement.fields) {
    // Skip static fields
    if (field.isStatic) continue;

    // Look for field annotations
    FieldInfo? fieldInfo = _processFieldAnnotations(field);

    if (fieldInfo != null) {
      fields.add(fieldInfo);
    }
  }

  return fields;
}

/// Process field annotations to extract field information
FieldInfo? _processFieldAnnotations(FieldElement field) {
  // Get field type
  final type = field.type;
  final typeName = _getTypeName(type);
  final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

  // Default field info
  var columnName = _toSnakeCase(field.name);
  var isPrimaryKey = false;
  var isComputedField = false;
  var excludeFromInsert = false;
  var excludeFromUpdate = false;
  String? description;

  // Look for Column annotation
  final columnAnnotation = _getColumnAnnotation(field);
  if (columnAnnotation != null) {
    final reader = ConstantReader(columnAnnotation);

    // Get column name if specified
    if (reader.peek('name') != null && !reader.read('name').isNull) {
      columnName = reader.read('name').stringValue;
    }

    // Get excludeFromInsert if specified
    if (reader.peek('excludeFromInsert') != null) {
      excludeFromInsert = reader.read('excludeFromInsert').boolValue;
    }

    // Get excludeFromUpdate if specified
    if (reader.peek('excludeFromUpdate') != null) {
      excludeFromUpdate = reader.read('excludeFromUpdate').boolValue;
    }

    // Get description if specified
    if (reader.peek('description') != null &&
        !reader.read('description').isNull) {
      description = reader.read('description').stringValue;
    }
  }

  // Look for PrimaryKey annotation
  final primaryKeyAnnotation = _getPrimaryKeyAnnotation(field);
  if (primaryKeyAnnotation != null) {
    isPrimaryKey = true;
  }

  // Look for ComputedField annotation
  final computedFieldAnnotation = _getComputedFieldAnnotation(field);
  if (computedFieldAnnotation != null) {
    isComputedField = true;
    excludeFromInsert = true;
    excludeFromUpdate = true;
  }

  // Skip if the field has a relationship annotation - these are handled separately
  if (_hasRelationshipAnnotation(field)) {
    return null;
  }

  return FieldInfo(
    name: field.name,
    type: typeName,
    columnName: columnName,
    isNullable: isNullable,
    isPrimaryKey: isPrimaryKey,
    isComputedField: isComputedField,
    excludeFromInsert: excludeFromInsert || isComputedField || isPrimaryKey,
    excludeFromUpdate: excludeFromUpdate || isComputedField || isPrimaryKey,
    description: description,
  );
}

/// Get the primary key field from a class
FieldInfo? getPrimaryKeyField(ClassElement classElement) {
  for (final field in classElement.fields) {
    if (field.isStatic) continue;

    final primaryKeyAnnotation = _getPrimaryKeyAnnotation(field);
    if (primaryKeyAnnotation != null) {
      final type = field.type;
      final typeName = _getTypeName(type);
      final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

      // Get column name from Column annotation if present
      var columnName = _toSnakeCase(field.name);
      final columnAnnotation = _getColumnAnnotation(field);
      if (columnAnnotation != null) {
        final reader = ConstantReader(columnAnnotation);
        if (reader.peek('name') != null && !reader.read('name').isNull) {
          columnName = reader.read('name').stringValue;
        }
      }

      return FieldInfo(
        name: field.name,
        type: typeName,
        columnName: columnName,
        isNullable: isNullable,
        isPrimaryKey: true,
      );
    }
  }

  return null;
}

/// Extract relationship fields from a class
List<RelationshipInfo> getRelationships(ClassElement classElement) {
  final relationships = <RelationshipInfo>[];

  for (final field in classElement.fields) {
    // Skip static fields
    if (field.isStatic) continue;

    // Get relationship type if this field has a relationship annotation
    final relationshipType = _getRelationshipType(field);
    if (relationshipType != null) {
      // Extract type of related entity
      final type = field.type;
      final relatedTypeName = _getRelatedTypeName(type, relationshipType);

      if (relatedTypeName != null) {
        String? description;

        // Get description from Column annotation if present
        final columnAnnotation = _getColumnAnnotation(field);
        if (columnAnnotation != null) {
          final reader = ConstantReader(columnAnnotation);
          if (reader.peek('description') != null &&
              !reader.read('description').isNull) {
            description = reader.read('description').stringValue;
          }
        }

        relationships.add(RelationshipInfo(
          name: field.name,
          type: relatedTypeName,
          description: description,
        ));
      }
    }
  }

  return relationships;
}

/// Get the Column annotation from a field
DartObject? _getColumnAnnotation(FieldElement field) {
  final columnChecker = const TypeChecker.fromRuntime(Column);
  return columnChecker.firstAnnotationOf(field);
}

/// Get the PrimaryKey annotation from a field
DartObject? _getPrimaryKeyAnnotation(FieldElement field) {
  final primaryKeyChecker = const TypeChecker.fromRuntime(PrimaryKey);
  return primaryKeyChecker.firstAnnotationOf(field);
}

/// Get the ComputedField annotation from a field
DartObject? _getComputedFieldAnnotation(FieldElement field) {
  final computedFieldChecker = const TypeChecker.fromRuntime(ComputedField);
  return computedFieldChecker.firstAnnotationOf(field);
}

/// Check if a field has any relationship annotation
bool _hasRelationshipAnnotation(FieldElement field) {
  return _getRelationshipType(field) != null;
}

/// Get the type of relationship for a field
String? _getRelationshipType(FieldElement field) {
  final hasOneChecker = const TypeChecker.fromRuntime(HasOne);
  if (hasOneChecker.hasAnnotationOf(field)) {
    return 'HasOne';
  }

  final hasManyChecker = const TypeChecker.fromRuntime(HasMany);
  if (hasManyChecker.hasAnnotationOf(field)) {
    return 'HasMany';
  }

  final belongsToChecker = const TypeChecker.fromRuntime(BelongsTo);
  if (belongsToChecker.hasAnnotationOf(field)) {
    return 'BelongsTo';
  }

  final manyToManyChecker = const TypeChecker.fromRuntime(ManyToMany);
  if (manyToManyChecker.hasAnnotationOf(field)) {
    return 'ManyToMany';
  }

  return null;
}

/// Get the type name for a field, handling generics
String _getTypeName(DartType type) {
  if (type is InterfaceType && type.typeArguments.isNotEmpty) {
    // Handle generic types like List<T>, Future<T>, etc.
    final typeArgs = type.typeArguments.map(_getTypeName).join(', ');
    return '${type.element.name}<$typeArgs>';
  }
  return type.element?.name ?? type.toString();
}

/// Get the related type name from a relationship field
String? _getRelatedTypeName(DartType type, String relationshipType) {
  if (relationshipType == 'HasMany' || relationshipType == 'ManyToMany') {
    // For HasMany and ManyToMany, the type should be List<T>
    if (type is InterfaceType &&
        type.element.name == 'List' &&
        type.typeArguments.isNotEmpty) {
      return _getTypeName(type.typeArguments.first);
    }
  } else {
    // For HasOne and BelongsTo, the type should be directly the entity type
    return _getTypeName(type);
  }
  return null;
}

/// Converts a camelCase string to snake_case
String _toSnakeCase(String str) {
  return str.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)?.toLowerCase()}',
  );
}
