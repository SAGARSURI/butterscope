import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mark at [frame], at 120 Hz, timed as if frames ran 8333 µs apart.
FrameMark at(int frame) {
  return FrameMark(
    frameNumber: frame,
    declaredRefreshRate: 120,
    micros: frame * 8333,
  );
}

Activity input(int from, int to) =>
    Activity(ActivityKind.input, at(from), at(to));

Activity animation(int from, int to) {
  return Activity(ActivityKind.animation, at(from), at(to));
}

/// A test from frame 0 to frame 200, 1.67 s at 120 Hz.
final test200 = MarkedPart(PartKind.test, 'Feed scrolls', at(0), at(200));

/// The start and end frames of each of [episodes].
List<(int, int)> framesOf(List<MarkedPart> episodes) {
  return [
    for (final episode in episodes)
      (episode.start.frameNumber, episode.end.frameNumber),
  ];
}

void main() {
  group('splitEpisodes', () {
    test('keeps a test with no activity as one episode', () {
      final episodes = splitEpisodes(test200, activities: [], pages: []);

      expect(framesOf(episodes), [(0, 200)]);
      expect(episodes.single.kind, PartKind.episode);
      expect(episodes.single.name, 'episode 1');
      expect(episodes.single.test, 'Feed scrolls');
    });

    test('starts an episode at input after 300 ms of quiet', () {
      // Input ends at frame 20 and starts again at frame 56: 36 frames of
      // 8333 µs is 299 988 µs, short of 300 ms, so frame 56 does not cut.
      // From frame 56's end at 60 to frame 97 is 41 frames, 341 653 µs.
      final episodes = splitEpisodes(
        test200,
        activities: [input(10, 20), input(56, 60), input(96 + 1, 100)],
        pages: [],
      );

      expect(framesOf(episodes), [(0, 97), (97, 200)]);
      expect([for (final e in episodes) e.name], ['episode 1', 'episode 2']);
    });

    test('starts an episode at the first input after a quiet start', () {
      // The test starts at frame 0 and its first input comes at frame 50:
      // 50 frames is 416 650 µs, so the frames before it, such as the
      // app's launch, are an episode of their own.
      final episodes = splitEpisodes(
        test200,
        activities: [input(50, 51)],
        pages: [],
      );

      expect(framesOf(episodes), [(0, 50), (50, 200)]);
    });

    test('keeps the quiet after activity with the episode it follows', () {
      final episodes = splitEpisodes(
        test200,
        activities: [input(5, 6), input(150, 151)],
        pages: [],
      );

      // Frames 7 to 150 are quiet and stay with the first episode.
      expect(framesOf(episodes), [(0, 150), (150, 200)]);
    });

    test('counts animation under rule A and not under rule B, the default', () {
      // An animation from frame 50 to 60 after input ends at frame 10:
      // 40 frames is 333 320 µs of quiet.
      final activities = [input(5, 10), animation(50, 60)];

      final ruleA = splitEpisodes(
        test200,
        activities: activities,
        pages: [],
        rule: EpisodeRule.inputOrAnimation,
      );
      final ruleB = splitEpisodes(test200, activities: activities, pages: []);

      expect(framesOf(ruleA), [(0, 50), (50, 200)]);
      expect(framesOf(ruleB), [(0, 200)]);
    });

    test('joins activity that overlaps, however long it runs', () {
      // Under rule A the animation runs from frame 12 to 120, so the input
      // at frame 115 follows no quiet.
      final episodes = splitEpisodes(
        test200,
        activities: [input(10, 12), animation(12, 120), input(115, 116)],
        pages: [],
        rule: EpisodeRule.inputOrAnimation,
      );

      expect(framesOf(episodes), [(0, 200)]);
    });

    test('takes the quiet stretch from the rule', () {
      const halfSecond = EpisodeRule(
        countsAnimation: true,
        quiet: Duration(milliseconds: 500),
      );
      final activities = [input(5, 10), input(60, 61)];

      // 50 frames is 416 650 µs: over 300 ms, under 500 ms.
      expect(
        framesOf(splitEpisodes(test200, activities: activities, pages: [])),
        [(0, 60), (60, 200)],
      );
      expect(
        framesOf(
          splitEpisodes(
            test200,
            activities: activities,
            pages: [],
            rule: halfSecond,
          ),
        ),
        [(0, 200)],
      );
    });

    test('ignores activity outside the test', () {
      final later = MarkedPart(PartKind.test, 'Search', at(300), at(400));

      final episodes = splitEpisodes(
        later,
        activities: [input(100, 110), input(200, 210), input(310, 320)],
        pages: [],
      );

      expect(framesOf(episodes), [(300, 400)]);
    });

    test('starts an episode when the page changes', () {
      // The page changes at frame 100, in the middle of an animation, so
      // no quiet stretch would cut there.
      final episodes = splitEpisodes(
        test200,
        activities: [animation(10, 180)],
        pages: [
          PageChange(at(2), '/', cuts: false),
          PageChange(at(100), 'detail', cuts: true),
        ],
      );

      expect(framesOf(episodes), [(0, 100), (100, 200)]);
      expect([for (final e in episodes) e.page], ['/', 'detail']);
    });

    test('keeps a tap and the page it opens in one episode', () {
      // The tap at frame 120 starts an episode; the page changes 2 frames
      // (16.7 ms) later, under 300 ms after that start.
      final episodes = splitEpisodes(
        test200,
        activities: [input(5, 10), input(120, 120), animation(122, 160)],
        pages: [PageChange(at(122), 'detail', cuts: true)],
      );

      expect(framesOf(episodes), [(0, 120), (120, 200)]);
      expect([for (final e in episodes) e.page], [null, 'detail']);
    });

    test('keeps a page with the input just before it', () {
      // A drag from frame 10 to 100, then a tap at 110 that opens a page at
      // 111. The tap is 10 frames after the drag, so it starts no episode.
      // The episode started at frame 0, 111 frames (924 963 µs) before the
      // page, but the tap came 1 frame before it, so the page joins the
      // drag's episode.
      final episodes = splitEpisodes(
        test200,
        activities: [input(10, 100), input(110, 110)],
        pages: [PageChange(at(111), 'detail', cuts: true)],
      );

      expect(framesOf(episodes), [(0, 200)]);
      expect(episodes.single.page, 'detail');
    });

    test('does not cut at the first page an app shows', () {
      final episodes = splitEpisodes(
        test200,
        activities: [],
        pages: [PageChange(at(80), '/', cuts: false)],
      );

      expect(framesOf(episodes), [(0, 200)]);
      expect(episodes.single.page, '/');
    });
  });
}
