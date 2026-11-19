# Interface language validation

This is an acceptance record for the implementation that was uncommitted when
measured, based on
`8c22db796284b1d9d414d1d181fa6a73b8936eb7`. It is not a release sign-off.
Measurements below were taken on 2026-11-19 on arm64, macOS 27.2.1 (26B131),
Xcode 27.2. Baseline and candidate were built on the same machine with release
`-Osize`, and the app bundles were ad-hoc signed.

The later settings-localization follow-up passed 27 focused language and
settings-index tests and a debug build on the same host. An isolated visible
probe verified the search-suggestion description and expanded explanation,
both custom-engine selectors, and the Proxy and Shortcuts group headings in
Chinese; switching to English restored the English text. Each settings page
was inspected, including information panels that could be opened through
accessibility. Some offscreen information buttons could not be opened; their
catalog resources were checked by the focused test. The full suite below was
not rerun after this follow-up.

## Functional checks

- The language, window-title and address-command Swift tests passed: 23 tests.
- `SEARCH_BENCH_APP=/path/to/Search.app python3 Tests/i18n_switch.py` against
  the candidate app passed 24 checks. At 20 and
  200 tabs it compared two windows, a split view and a sleeping background tab
  across English → Simplified Chinese → English switches. Tab IDs, WebView
  identities and built/asleep state matched; the test page retained its form
  value, DOM focus and scroll position.
- A separate probe preselected `zh-Hans` in its isolated profile, launched the
  candidate twice and confirmed the preference persisted and both `下载` and
  `Downloads` found the downloads settings. This does not exercise selecting
  the language through the visible settings UI.
- `Tests/check-localization.py`, `plutil -lint` on the six localization files,
  Python lint and syntax checks, and `git diff --check` passed. The merge-review
  scan against `HEAD` emitted 59 review items; it is heuristic and needs a
  human review of the complete diff.
- `python3 Tests/run-ci-tests.py` ran 1,054 main-suite tests with 14 skipped
  and 11 failed assertions across seven cases. Six cases also failed on the
  untouched baseline or its corresponding test group. The remaining
  `PinStuckTests.testASquareCalledOffMidCarryIsPutDown` passed in isolation on
  both versions and in the candidate with all `LanguageTests` in the same
  process, but its full-suite failure is unexplained. All 16 isolated WebKit
  download cases passed. The suite therefore did not pass.

## Performance checks

- Three interleaved release `SpeedBenchTests` runs passed all 13 tests in each
  run. Typing measurements, in milliseconds, were baseline
  `5.925 / 5.145 / 6.051` and candidate `4.814 / 6.936 / 5.401`.
- `Tests/bookmark_redraws.py` passed on the baseline and candidate. Each tested
  60 edits at both 20 and 200 tabs; sidebar row rebuilds per edit were zero.
- Two interleaved runs of `Tests/address_at_rest.py` retained the original
  median assertion. In the enabled mode, 66 key samples per run gave baseline
  p50 `2.599 / 2.334 ms`, p95 `16.553 / 16.740 ms`, and candidate p50
  `1.019 / 1.300 ms`, p95 `14.807 / 15.342 ms`. These are small samples and do
  not establish a release-wide latency bound. The baseline runs each had two
  other failed assertions, and one candidate run had one failure; they involved
  external pages and the same class of intermittent failures appeared in both
  versions. The other candidate run passed all 28 assertions.
- Binary size increased from 10,787,552 to 11,004,480 bytes (+216,928;
  2.01%). The sum of app bundle file sizes increased from 12,022,292 to
  12,294,236 bytes (+271,944; 2.26%).

## Outstanding acceptance

- Diagnose the full-suite failures, including the one without a matching
  full-suite baseline reproduction, and repeat the suite to a clean result.
- Measure startup to the first visible window and language-switch completion
  p50/p95 against repeated baseline runs. The typing measurements alone are not
  a full performance sign-off.
- On an unlocked display, verify two visible windows, settings scroll position,
  light/dark appearance, a real Chinese input method, VoiceOver and restoring an
  older session. Repeat the required scenarios on macOS 14. The available test
  machine was locked and macOS 14 was unavailable.
- The catalogs currently include 804 English-source strings used as resource
  keys. They are shared between languages and the merge-review tool reports
  resource additions and removals, but changing one of those English strings
  changes its key. Migrate these remaining entries to stable semantic keys and
  revalidate before claiming the plan's stable-key requirement is complete.

## Integration check on 2026-11-19

Unless noted, the following checks used code commit
`8d4eea441b6b30ec895d4f390aa88292aecf8388`, after integrating `chaslui-dev`
at `1fb52363744f6fed88311018757ae7dae029882a`. The host was arm64,
macOS 27.2.1 (26B131), with Xcode 27.2. These results do not replace the
outstanding acceptance above.

- `swift build` passed before the final test-only commit; application sources
  were unchanged by that commit. The localization checker and `plutil -lint`
  for all six language resource files passed. The selected language, settings,
  commands, tab-drag, tab-group and split tests passed: 73 tests.
- The 20/200-tab language test had left its session for later tests. It now
  saves and restores the previous session; the original failing sequence
  passed after that change.
- `python3 Tests/run-ci-tests.py` ran 1,063 main-suite tests, with 18 skipped
  and 15 failed assertions across nine cases. Seven cases had also failed on
  the prior baseline or its corresponding test group. The favicon-cache and
  sidebar pin-selection cases failed in the full run but both passed in a
  focused two-case rerun; their full-run failures remain unexplained.
- Of 16 isolated WebKit download cases, nine passed and seven timed out
  waiting for download state. One failed again with the default timeout and
  passed with `CI=true`; the other six were not rerun with that setting.
- Three interleaved release `-Osize` runs of `SpeedBenchTests` passed all 17
  tests for both revisions in each run. For grouped 200-tab selection, the
  medians of the three p50/p95 measurements were 30.02/35.04 ms on the target
  and 30.82/37.20 ms on the candidate. In separate-process 20-tab selection
  runs they were 9.26/13.40 ms and 8.64/14.10 ms respectively. For 20-tab
  resize, the three p95 values were 8.39/6.04/6.90 ms and 7.37/14.97/13.34 ms.
  The tail varied; startup and visible language-switch timing were not
  measured, so this is not a full performance sign-off.
