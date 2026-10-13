/// The lines a Butterscope report is printed as on the phone, how the host
/// reads them back (`docs/DESIGN.md` section 8), and the schema the report
/// they carry follows (`docs/report-schema.md`).
library;

export 'src/collected_run.dart';
export 'src/crc32.dart';
export 'src/line_format.dart' hide checkAtLeastOne;
export 'src/line_reader.dart';
export 'src/line_writer.dart';
export 'src/report_schema.dart';
