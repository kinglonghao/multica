/**
 * Unit tests for the issue / project status and priority label
 * + color mappers. Mirrors the iOS labels-and-color tests.
 *
 * The label mappers include a `?? status` / `?? priority` fallback
 * for unknown server values — this test pins that down. The color
 * mappers should never throw on unknown values, just render the
 * muted fallback. Both invariants are easy to break in a refactor
 * ("let's tidy up the switch statement") so we test them here.
 */
import { describe, it, expect } from '@ohos.hypium';
import {
  statusLabel,
  statusColor,
  priorityLabel,
  priorityColor
} from '../../../../main/ets/lib/issue-status';
import {
  projectStatusLabel,
  projectStatusColor,
  projectPriorityLabel,
  projectPriorityColor
} from '../../../../main/ets/lib/project-status';

export default function issueStatusTest(): void {
  describe('statusLabel', () => {
    it('renders every known status', () => {
      expect(statusLabel('backlog')).assertEqual('Backlog');
      expect(statusLabel('todo')).assertEqual('Todo');
      expect(statusLabel('in_progress')).assertEqual('In Progress');
      expect(statusLabel('in_review')).assertEqual('In Review');
      expect(statusLabel('done')).assertEqual('Done');
      expect(statusLabel('cancelled')).assertEqual('Cancelled');
    });

    it('returns "Unknown" for null / undefined', () => {
      expect(statusLabel(null)).assertEqual('Unknown');
      expect(statusLabel(undefined)).assertEqual('Unknown');
    });

    it('returns the raw string for unknown values (does NOT crash)', () => {
      expect(statusLabel('not_a_real_status')).assertEqual('not_a_real_status');
    });
  });

  describe('priorityLabel', () => {
    it('renders every known priority', () => {
      expect(priorityLabel('no_priority')).assertEqual('No priority');
      expect(priorityLabel('urgent')).assertEqual('Urgent');
      expect(priorityLabel('high')).assertEqual('High');
      expect(priorityLabel('medium')).assertEqual('Medium');
      expect(priorityLabel('low')).assertEqual('Low');
    });

    it('returns "No priority" for null / undefined', () => {
      expect(priorityLabel(null)).assertEqual('No priority');
      expect(priorityLabel(undefined)).assertEqual('No priority');
    });

    it('returns the raw string for unknown values', () => {
      expect(priorityLabel('blah')).assertEqual('blah');
    });
  });

  describe('statusColor', () => {
    it('returns a non-empty color for every known status in both schemes', () => {
      const statuses = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'];
      for (const s of statuses) {
        const light = statusColor(s, 'light');
        const dark = statusColor(s, 'dark');
        expect(light.length > 0).assertEqual(true);
        expect(dark.length > 0).assertEqual(true);
      }
    });

    it('falls back to muted foreground for unknown status', () => {
      const light = statusColor('not_a_status', 'light');
      const dark = statusColor('not_a_status', 'dark');
      // The fallback must be a non-empty hex / color string; it must
      // also not be one of the bright status colors. We don't pin the
      // exact value (it's a theme decision) — just that it's defined.
      expect(light.length > 0).assertEqual(true);
      expect(dark.length > 0).assertEqual(true);
    });
  });

  describe('priorityColor', () => {
    it('returns a non-empty color for every known priority in both schemes', () => {
      const priorities = ['no_priority', 'urgent', 'high', 'medium', 'low'];
      for (const p of priorities) {
        expect(priorityColor(p, 'light').length > 0).assertEqual(true);
        expect(priorityColor(p, 'dark').length > 0).assertEqual(true);
      }
    });
  });

  describe('project status / priority', () => {
    it('projectStatusLabel renders known values', () => {
      expect(projectStatusLabel('planned')).assertEqual('Planned');
      expect(projectStatusLabel('in_progress')).assertEqual('In Progress');
      expect(projectStatusLabel('paused')).assertEqual('Paused');
      expect(projectStatusLabel('completed')).assertEqual('Completed');
      expect(projectStatusLabel('cancelled')).assertEqual('Cancelled');
    });

    it('projectStatusLabel returns the raw string for unknown values', () => {
      expect(projectStatusLabel('frozen')).assertEqual('frozen');
    });

    it('projectStatusLabel returns "Unknown" for null / undefined', () => {
      expect(projectStatusLabel(null)).assertEqual('Unknown');
      expect(projectStatusLabel(undefined)).assertEqual('Unknown');
    });

    it('projectPriorityLabel renders known values', () => {
      expect(projectPriorityLabel('no_priority')).assertEqual('No priority');
      expect(projectPriorityLabel('urgent')).assertEqual('Urgent');
      expect(projectPriorityLabel('high')).assertEqual('High');
      expect(projectPriorityLabel('medium')).assertEqual('Medium');
      expect(projectPriorityLabel('low')).assertEqual('Low');
    });

    it('projectStatusColor returns a non-empty color in both schemes', () => {
      const statuses = ['planned', 'in_progress', 'paused', 'completed', 'cancelled'];
      for (const s of statuses) {
        expect(projectStatusColor(s, 'light').length > 0).assertEqual(true);
        expect(projectStatusColor(s, 'dark').length > 0).assertEqual(true);
      }
    });

    it('projectPriorityColor returns a non-empty color in both schemes', () => {
      const priorities = ['no_priority', 'urgent', 'high', 'medium', 'low'];
      for (const p of priorities) {
        expect(projectPriorityColor(p, 'light').length > 0).assertEqual(true);
        expect(projectPriorityColor(p, 'dark').length > 0).assertEqual(true);
      }
    });
  });
}
