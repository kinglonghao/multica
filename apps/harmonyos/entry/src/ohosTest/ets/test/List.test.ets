/**
 * Test runner. Aggregates the test files into a single suite the
 * `hypium` runner can execute. The list order is irrelevant —
 * hypium reports each `describe` block separately — but we keep
 * them grouped by domain.
 */
import inboxDisplayTest from './inbox-display.test';
import utilsTest from './utils.test';
import issueStatusTest from './issue-status.test';
import cacheTest from './cache.test';

export default function testsuite(): void {
  inboxDisplayTest();
  utilsTest();
  issueStatusTest();
  cacheTest();
}
