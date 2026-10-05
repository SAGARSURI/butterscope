// Every screen's tests in one run, so one `flutter drive` covers the app.
// tool/m4/run_tests.sh runs it clean and once per plant.

import 'activity_test.dart' as activity;
import 'detail_test.dart' as detail;
import 'feed_test.dart' as feed;
import 'gallery_test.dart' as gallery;
import 'inbox_test.dart' as inbox;
import 'search_test.dart' as search;

void main() {
  feed.main();
  search.main();
  detail.main();
  activity.main();
  inbox.main();
  gallery.main();
}
