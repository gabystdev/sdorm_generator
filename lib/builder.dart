import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generators/dao_generator.dart';

/// Creates the DAO builder
Builder daoBuilder(BuilderOptions options) => SharedPartBuilder(
      [DAOGenerator()],
      'dao_builder',
    );
