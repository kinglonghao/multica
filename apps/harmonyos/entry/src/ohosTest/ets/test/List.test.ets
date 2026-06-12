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
import wsClientTest from './ws-client.test';
import mutationsTest from './mutations.test';
import wsValidateTest from './ws-validate.test';
import realtimeHooksTest from './realtime-hooks.test';
import pinMutationsTest from './pin-mutations.test';
import parseResponseTest from './parse-response.test';
import realtimeContractTest from './realtime-contract.test';
import formatUtilsTest from './format-utils.test';
import issueMutationsTest from './issue-mutations.test';
import optimisticTest from './optimistic.test';
import markdownTest from './markdown.test';
import storageAdapterTest from './storage-adapter.test';

export default function testsuite(): void {
  inboxDisplayTest();
  utilsTest();
  issueStatusTest();
  cacheTest();
  wsClientTest();
  mutationsTest();
  wsValidateTest();
  realtimeHooksTest();
  pinMutationsTest();
  parseResponseTest();
  realtimeContractTest();
  formatUtilsTest();
  issueMutationsTest();
  optimisticTest();
  markdownTest();
  storageAdapterTest();
}
