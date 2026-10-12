/// The lines a Butterscope report is printed as on the phone, and how the
/// host reads them back (`docs/DESIGN.md` section 8).
library;

export 'src/collected_run.dart';
export 'src/crc32.dart';
export 'src/line_format.dart' hide checkAtLeastOne;
export 'src/line_reader.dart';
export 'src/line_writer.dart';
