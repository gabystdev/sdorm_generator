# Supabase Dart Generators

Generadores de código para el paquete supabase-dart-client que proporciona generación automática de DAOs (Data Access Objects).

## 🌟 Características

- ✅ **Generación de DAOs**: Genera automáticamente clases de acceso a datos para tus modelos anotados
- ✅ **Soporte para relaciones**: Maneja relaciones 1:1, 1:N, N:1 y N:M
- ✅ **Mapeo automático**: Maneja la conversión entre objetos Dart y datos JSON
- ✅ **Validación en tiempo de compilación**: Detecta errores en tus modelos durante la compilación

## 📋 Requisitos

- Dart SDK: >=2.19.0 <4.0.0
- build_runner: ^2.4.6

## 🚀 Instalación

```yaml
dev_dependencies:
  supabase_dart_generators: ^0.2.0
```

## 📖 Uso

1. Asegúrate de tener el paquete supabase_dart_client configurado correctamente.

2. Crea o modifica tu archivo `build.yaml` en la raíz del proyecto:

```yaml
targets:
  $default:
    builders:
      # Configuración para generación de DAOs
      supabase_dart_generators|dao_builder:
        enabled: true
        generate_for:
          - lib/models/**.dart
```

3. Ejecuta build_runner para generar el código:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 🔧 Generadores disponibles

### DAOGenerator

Genera clases DAO para los modelos anotados con `@Table`. Cada DAO generado incluye:

- Operaciones CRUD básicas (findById, findAll, insert, update, delete)
- Métodos para navegar relaciones
- Mapeo automático entre objetos y JSON

## 📝 Configuración avanzada

Puedes personalizar el comportamiento de los generadores en tu archivo `build.yaml`:

```yaml
targets:
  $default:
    builders:
      supabase_dart_generators|dao_builder:
        options:
          # Opciones específicas para el generador de DAOs
          include_comments: true
          validate_models: true
```

## ⚡ Rendimiento

Los generadores están optimizados para:

- Generar código eficiente y reutilizable
- Minimizar la cantidad de código generado
- Procesar rápidamente los archivos fuente

## 📚 Referencias

- [supabase-dart-client](../supabase-dart-client/README.md)
- [Dart Build System](https://github.com/dart-lang/build)
- [Source Gen](https://pub.dev/packages/source_gen)
