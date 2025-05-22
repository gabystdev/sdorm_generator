// DAO Generator implementation
import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
// import 'package:supabase_dart_client/src/annotations/table_annotations.dart';
// import 'package:supabase_dart_client/src/annotations/relationship_annotations.dart';
import 'package:supabase_dart_client/supabase_dart_client.dart';
import 'generator_utils.dart';
import 'relationship_analyzer.dart';

/// Generator for Data Access Objects (DAOs)
///
/// This generator processes classes annotated with @Table and generates
/// corresponding DAO implementations.
class DAOGenerator extends GeneratorForAnnotation<Table> {
  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Make sure the annotated element is a class
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'The @Table annotation can only be applied to classes.',
        element: element,
      );
    }

    // Extract information from the annotation
    final tableName = annotation.read('name').stringValue;
    final generateDAO = annotation.read('generateDAO').boolValue;

    // Skip generation if generateDAO is false
    if (!generateDAO) {
      return '';
    }

    // Extract class information
    final className = element.name;
    final fields = getModelFields(element);
    final primaryKeyField = getPrimaryKeyField(element);

    if (primaryKeyField == null) {
      throw InvalidGenerationSourceError(
        'Class $className must have a field annotated with @PrimaryKey.',
        element: element,
      );
    }

    // Generate the DAO class
    return _generateDAOClass(
      className,
      tableName,
      fields,
      primaryKeyField,
      element,
    );
  }

  /// Generate the DAO class implementation
  String _generateDAOClass(
    String className,
    String tableName,
    List<FieldInfo> fields,
    FieldInfo primaryKeyField,
    ClassElement element,
  ) {
    final daoClassName = '${className}DAO';
    final buffer = StringBuffer();

    // Extract relationship information
    final relationships = RelationshipAnalyzer.extractRelationships(element);

    // Begin DAO class
    buffer.writeln('/// Data Access Object for $className entities');
    buffer.writeln('class $daoClassName extends BaseDAO<$className> {');

    // Constructor
    buffer.writeln(
        '  /// Create a new $daoClassName with the given Supabase client');

    if (relationships.isEmpty) {
      // Simple constructor if no relationships
      buffer.writeln(
          '  $daoClassName(SupabaseClient client) : super(client, \'$tableName\');');
    } else {
      // Constructor with relationship registration
      buffer.writeln(
          '  $daoClassName(SupabaseClient client) : super(client, \'$tableName\') {');
      buffer.writeln('    // Register relationships');

      // Register each relationship
      for (final entry in relationships.entries) {
        final relationshipName = entry.key;
        final relationshipInfo = entry.value;

        if (relationshipInfo.relationType == RelationType.oneToMany) {
          // One-to-many relationship
          buffer.writeln('    registerRelationship(');
          buffer.writeln('      RelationshipMetadata(');
          buffer.writeln('        type: \'HasMany\',');
          buffer.writeln('        fieldName: \'$relationshipName\',');
          buffer.writeln(
              '        relatedClass: ${relationshipInfo.relatedType},');
          buffer.writeln(
              '        foreignKey: \'${relationshipInfo.foreignKey}\',');
          buffer.writeln('      ),');
          buffer.writeln('    );');
        } else if (relationshipInfo.relationType == RelationType.manyToOne) {
          // Many-to-one relationship
          buffer.writeln('    registerRelationship(');
          buffer.writeln('      RelationshipMetadata(');
          buffer.writeln('        type: \'BelongsTo\',');
          buffer.writeln('        fieldName: \'$relationshipName\',');
          buffer.writeln(
              '        relatedClass: ${relationshipInfo.relatedType},');
          buffer.writeln(
              '        foreignKey: \'${relationshipInfo.foreignKey}\',');
          buffer.writeln('      ),');
          buffer.writeln('    );');
        } else if (relationshipInfo.relationType == RelationType.manyToMany) {
          // Many-to-many relationship
          buffer.writeln('    registerRelationship(');
          buffer.writeln('      RelationshipMetadata(');
          buffer.writeln('        type: \'ManyToMany\',');
          buffer.writeln('        fieldName: \'$relationshipName\',');
          buffer.writeln(
              '        relatedClass: ${relationshipInfo.relatedType},');
          buffer.writeln(
              '        foreignKey: \'${relationshipInfo.foreignKey}\',');
          buffer.writeln(
              '        pivotTable: \'${relationshipInfo.joinTable}\',');
          buffer.writeln(
              '        relatedKey: \'${relationshipInfo.relatedKey}\',');
          buffer.writeln('      ),');
          buffer.writeln('    );');
        }
      }
      buffer.writeln('  }');
    }
    buffer.writeln();

    // Generate fromJson method
    buffer.writeln('  @override');
    buffer.writeln('  $className fromJson(Map<String, dynamic> json) {');

    // Check if the class has a named constructor 'fromJson'
    ConstructorElement? fromJsonConstructor;
    try {
      fromJsonConstructor = element.constructors.firstWhere(
        (constructor) => constructor.name == 'fromJson',
      );
    } catch (e) {
      // No fromJson constructor found
      fromJsonConstructor = null;
    }

    if (fromJsonConstructor != null) {
      // If there's a fromJson constructor, use it
      buffer.writeln('    return $className.fromJson(json);');
    } else {
      // Otherwise, we need to manually create the object
      // Start with finding the default constructor
      ConstructorElement? defaultConstructor;
      try {
        defaultConstructor = element.constructors.firstWhere(
          (constructor) => constructor.name.isEmpty,
        );
      } catch (e) {
        // No default constructor found
        defaultConstructor = null;
      }

      if (defaultConstructor == null) {
        throw InvalidGenerationSourceError(
          'Class $className must have a default constructor or fromJson constructor.',
          element: element,
        );
      }

      // Create object using the default constructor
      buffer.writeln('    return $className(');
      for (final field in fields) {
        final fieldName = field.name;
        final columnName = field.columnName ?? _toSnakeCase(fieldName);
        buffer.writeln(
            '      $fieldName: json[\'$columnName\'] as ${field.type},');
      }
      buffer.writeln('    );');
    }
    buffer.writeln('  }');
    buffer.writeln();

    // Generate toJson method
    buffer.writeln('  @override');
    buffer.writeln('  Map<String, dynamic> toJson($className entity) {');

    // Check if the entity has a toJson method
    MethodElement? toJsonMethod;
    try {
      toJsonMethod = element.methods.firstWhere(
        (method) => method.name == 'toJson',
      );
    } catch (e) {
      // No toJson method found
      toJsonMethod = null;
    }

    if (toJsonMethod != null) {
      // If there's a toJson method, use it
      buffer.writeln('    // Use the entity\'s toJson method');
      buffer.writeln('    return entity.toJson();');
    } else {
      // Otherwise, we need to manually create the map
      buffer.writeln('    final map = <String, dynamic>{');
      for (final field in fields) {
        final fieldName = field.name;
        final columnName = field.columnName ?? _toSnakeCase(fieldName);
        buffer.writeln('      \'$columnName\': entity.$fieldName,');
      }
      buffer.writeln('    };');
      buffer.writeln();
      buffer.writeln('    // Remove null values');
      buffer.writeln(
          '    return Map<String, dynamic>.from(map..removeWhere((k, v) => v == null));');
    }

    buffer.writeln('  }');
    buffer.writeln();

    // Generate getPrimaryKey method
    buffer.writeln('  @override');
    buffer.writeln('  int getPrimaryKey($className entity) {');
    buffer.writeln('    return entity.${primaryKeyField.name};');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate getFieldValue method
    buffer.writeln('  @override');
    buffer.writeln(
        '  dynamic getFieldValue($className entity, String fieldName) {');
    buffer.writeln('    switch (fieldName) {');

    // Add a case for each field
    for (final field in fields) {
      buffer.writeln('      case \'${field.name}\':');
      buffer.writeln('        return entity.${field.name};');
    }

    // Add cases for relationship fields if needed
    if (relationships.isNotEmpty) {
      for (final entry in relationships.entries) {
        buffer.writeln('      case \'${entry.key}\':');
        buffer.writeln('        return entity.${entry.key};');
      }
    }

    buffer.writeln('      default:');
    buffer.writeln('        return null;');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate setFieldValue method
    buffer.writeln('  @override');
    buffer.writeln(
        '  void setFieldValue($className entity, String fieldName, dynamic value) {');
    buffer.writeln('    switch (fieldName) {');

    // For now, we'll just handle relationship fields since most model fields are final
    if (relationships.isNotEmpty) {
      for (final entry in relationships.entries) {
        buffer.writeln('      case \'${entry.key}\':');

        // We need to use a different approach since we can't directly set final fields
        // Here we'll assume that the field is not final, which is typical for relationship fields
        buffer.writeln('        entity.${entry.key} = value;');
        buffer.writeln('        break;');
      }
    }

    buffer.writeln('      default:');
    buffer.writeln(
        '        throw UnimplementedError(\'Cannot set field \$fieldName on $className\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate getter for the table name
    buffer.writeln('  @override');
    buffer.writeln('  String get tableName => \'$tableName\';');

    buffer.writeln('}');

    return buffer.toString();
  }
}

/// Converts a camelCase string to snake_case
String _toSnakeCase(String str) {
  return str.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)?.toLowerCase()}',
  );
}
