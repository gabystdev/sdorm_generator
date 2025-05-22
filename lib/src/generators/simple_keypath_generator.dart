// Simple KeyPath generator implementation
import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:supabase_dart_client/supabase_dart_client.dart';

/// Generator for simplified KeyPaths
///
/// This generator processes all classes and generates
/// simple KeyPath classes for use in query building.
class SimpleKeyPathGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();

    // For each class annotated with @Table
    for (var element in library.classes) {
      final tableAnnotation = _getTableAnnotation(element);

      // Skip if not a Table or if KeyPath generation is disabled
      if (tableAnnotation == null || !tableAnnotation.generateKeyPaths) {
        continue;
      }

      buffer.writeln(_generateSimpleKeyPath(element));
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Generates a simple KeyPath class for the given element
  String _generateSimpleKeyPath(ClassElement element) {
    final className = element.name;
    final tableName = _getTableName(element);
    final keyPathClassName = '${className}_';

    final buffer = StringBuffer();

    // Generated code header
    buffer.writeln('// SimpleKeyPathGenerator');
    buffer.writeln('// Simple KeyPath for $className');

    // Add table static constant
    buffer.writeln('\nclass $keyPathClassName {');
    buffer.writeln('  /// The name of the database table');
    buffer.writeln('  static const String table = \'$tableName\';');
    buffer.writeln();

    // Add private constructor to prevent instantiation
    buffer.writeln('  // Private constructor to prevent instantiation');
    buffer.writeln('  const $keyPathClassName._();');
    buffer.writeln();

    // Add factory constructor
    buffer.writeln('  /// Factory constructor for static access');
    buffer.writeln('  factory $keyPathClassName() = $keyPathClassName._;');
    buffer.writeln();

    // Add fields for each model property
    for (final field in element.fields) {
      // Skip static fields
      if (field.isStatic) continue;

      // Skip fields with relationship annotations
      if (_hasRelationshipAnnotation(field)) continue;

      final fieldName = field.name;
      final fieldType = field.type.getDisplayString(withNullability: true);
      final columnName = _getColumnName(field) ?? _toSnakeCase(fieldName);

      buffer.writeln('  /// KeyPath for `$fieldName` property');
      buffer.writeln(
          '  final SimpleKeyPath<$className, $fieldType> $fieldName =');
      buffer.writeln(
          '      const SimpleKeyPath<$className, $fieldType>(\'$columnName\');');
      buffer.writeln();
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Get the column name from a field's Column annotation
  String? _getColumnName(FieldElement field) {
    final columnChecker = const TypeChecker.fromRuntime(Column);
    final annotation = columnChecker.firstAnnotationOf(field);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    if (reader.peek('name') != null && !reader.read('name').isNull) {
      return reader.read('name').stringValue;
    }

    return null;
  }

  /// Check if a field has a relationship annotation
  bool _hasRelationshipAnnotation(FieldElement field) {
    const hasOneChecker = TypeChecker.fromRuntime(HasOne);
    if (hasOneChecker.hasAnnotationOf(field)) return true;

    const hasManyChecker = TypeChecker.fromRuntime(HasMany);
    if (hasManyChecker.hasAnnotationOf(field)) return true;

    const belongsToChecker = TypeChecker.fromRuntime(BelongsTo);
    if (belongsToChecker.hasAnnotationOf(field)) return true;

    const manyToManyChecker = TypeChecker.fromRuntime(ManyToMany);
    if (manyToManyChecker.hasAnnotationOf(field)) return true;

    return false;
  }

  /// Gets the table name from the Table annotation
  String _getTableName(ClassElement element) {
    final tableAnnotation = _getTableAnnotation(element);
    return tableAnnotation?.name ?? _toSnakeCase(element.name);
  }

  /// Gets the Table annotation from a class element
  Table? _getTableAnnotation(ClassElement element) {
    final tableChecker = const TypeChecker.fromRuntime(Table);
    final annotation = tableChecker.firstAnnotationOf(element);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    return Table(
      reader.read('name').stringValue,
      generateDAO: reader.read('generateDAO').boolValue,
      generateKeyPaths: reader.read('generateKeyPaths').boolValue,
    );
  }

  /// Converts a camelCase string to snake_case
  String _toSnakeCase(String str) {
    return str.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)?.toLowerCase()}',
    );
  }
}
