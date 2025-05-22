// Model analyzer for relationships
// This file provides utilities to analyze models and extract relationship metadata
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Enum representing the type of relationship
enum RelationType {
  /// A one-to-many relationship
  oneToMany,

  /// A many-to-one relationship
  manyToOne,

  /// A one-to-one relationship
  oneToOne,

  /// A many-to-many relationship
  manyToMany
}

/// Information about a relationship extracted from annotations
class RelationshipInfo {
  /// The type of relationship
  final RelationType relationType;

  /// The type of the related entity
  final String relatedType;

  /// The foreign key field
  final String foreignKey;

  /// For many-to-many, the join table
  final String? joinTable;

  /// For many-to-many, the source key in the join table (same as foreignKey)
  final String? sourceKey;

  /// For many-to-many, the target key in the join table
  final String? targetKey;

  /// For many-to-many, the related key (same as targetKey)
  final String? relatedKey;

  /// Whether to load the relationship eagerly
  final bool eager;

  /// Optional where clause
  final String? where;

  RelationshipInfo({
    required this.relationType,
    required this.relatedType,
    required this.foreignKey,
    this.joinTable,
    this.sourceKey,
    this.targetKey,
    this.relatedKey,
    this.eager = false,
    this.where,
  });
}

/// Utility class for analyzing models and extracting relationship information
class RelationshipAnalyzer {
  /// Extracts relationship information from a class element
  ///
  /// [classElement] is the class element to analyze
  /// Returns a Map of field names to relationship information
  static Map<String, RelationshipInfo> extractRelationships(
      ClassElement classElement) {
    final relationshipFields = <String, RelationshipInfo>{};

    // Process all fields in the class
    for (final field in classElement.fields) {
      // Skip static fields
      if (field.isStatic) continue;

      // Process annotations
      for (final annotation in field.metadata) {
        final annotationType =
            annotation.computeConstantValue()?.type?.toString() ?? '';

        if (annotationType.contains('BelongsTo')) {
          final foreignKeyObj =
              annotation.computeConstantValue()?.getField('foreignKey');
          final foreignKey = foreignKeyObj?.toStringValue() ?? '';
          final eagerObj = annotation.computeConstantValue()?.getField('eager');
          final eager = eagerObj?.toBoolValue() ?? false;
          final whereObj = annotation.computeConstantValue()?.getField('where');
          final where = whereObj?.toStringValue();

          relationshipFields[field.name] = RelationshipInfo(
            relationType: RelationType.manyToOne,
            relatedType: _extractRelatedTypeName(field.type),
            foreignKey: foreignKey,
            eager: eager,
            where: where,
          );
          break;
        } else if (annotationType.contains('HasMany')) {
          final foreignKeyObj =
              annotation.computeConstantValue()?.getField('foreignKey');
          final foreignKey = foreignKeyObj?.toStringValue() ?? '';
          final eagerObj = annotation.computeConstantValue()?.getField('eager');
          final eager = eagerObj?.toBoolValue() ?? false;
          final whereObj = annotation.computeConstantValue()?.getField('where');
          final where = whereObj?.toStringValue();

          relationshipFields[field.name] = RelationshipInfo(
            relationType: RelationType.oneToMany,
            relatedType: _extractTypeFromList(field.type),
            foreignKey: foreignKey,
            eager: eager,
            where: where,
          );
          break;
        } else if (annotationType.contains('HasOne')) {
          final foreignKeyObj =
              annotation.computeConstantValue()?.getField('foreignKey');
          final foreignKey = foreignKeyObj?.toStringValue() ?? '';
          final eagerObj = annotation.computeConstantValue()?.getField('eager');
          final eager = eagerObj?.toBoolValue() ?? false;
          final whereObj = annotation.computeConstantValue()?.getField('where');
          final where = whereObj?.toStringValue();

          relationshipFields[field.name] = RelationshipInfo(
            relationType: RelationType.oneToOne,
            relatedType: _extractRelatedTypeName(field.type),
            foreignKey: foreignKey,
            eager: eager,
            where: where,
          );
          break;
        } else if (annotationType.contains('ManyToMany')) {
          final foreignKeyObj =
              annotation.computeConstantValue()?.getField('foreignKey');
          final foreignKey = foreignKeyObj?.toStringValue() ?? '';
          final relatedKeyObj =
              annotation.computeConstantValue()?.getField('relatedKey');
          final relatedKey = relatedKeyObj?.toStringValue() ?? '';
          final eagerObj = annotation.computeConstantValue()?.getField('eager');
          final eager = eagerObj?.toBoolValue() ?? false;
          final whereObj = annotation.computeConstantValue()?.getField('where');
          final where = whereObj?.toStringValue();
          final pivotTableObj =
              annotation.computeConstantValue()?.getField('pivotTable');
          final pivotTable = pivotTableObj?.toStringValue() ?? '';

          relationshipFields[field.name] = RelationshipInfo(
            relationType: RelationType.manyToMany,
            relatedType: _extractTypeFromList(field.type),
            foreignKey: foreignKey,
            joinTable: pivotTable,
            sourceKey: foreignKey, // Set sourceKey to the foreignKey value
            targetKey: relatedKey, // Set targetKey to the relatedKey value
            relatedKey: relatedKey, // Explicitly set relatedKey
            eager: eager,
            where: where,
          );
          break;
        }
      }
    }

    return relationshipFields;
  }

  /// Extracts the name of the related type from a DartType
  static String _extractRelatedTypeName(DartType type) {
    if (type is InterfaceType) {
      return type.element.name;
    }
    return type.toString();
  }

  /// Extracts the type parameter from a List<T>
  static String _extractTypeFromList(DartType type) {
    if (type is InterfaceType &&
        type.element.name == 'List' &&
        type.typeArguments.isNotEmpty) {
      return _extractRelatedTypeName(type.typeArguments.first);
    }
    return 'dynamic';
  }
}
