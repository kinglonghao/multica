import { IssueStatus, IssuePriority } from '../models/types';
import { THEME, ColorScheme } from './theme';

/**
 * Issue status / priority display + color mapping. Mirrors
 * apps/mobile/components/ui/status-icon.tsx and priority-icon.tsx.
 *
 * Why a separate file: the same mapping is needed by the inbox row, the
 * issue detail header, the new-issue picker, and the chat "agent set
 * status" line. Centralising the lookup avoids drift between them — the
 * bug "Inbox shows `In Review` as blue but Project card shows it as
 * orange" is exactly the sort of inconsistency this file prevents.
 */

const STATUS_LABELS: Record<string, string> = {
  backlog: 'Backlog',
  todo: 'Todo',
  in_progress: 'In Progress',
  in_review: 'In Review',
  done: 'Done',
  cancelled: 'Cancelled'
};

const PRIORITY_LABELS: Record<string, string> = {
  no_priority: 'No priority',
  urgent: 'Urgent',
  high: 'High',
  medium: 'Medium',
  low: 'Low'
};

export function statusLabel(status: IssueStatus | string | null | undefined): string {
  if (!status) return 'Unknown';
  return STATUS_LABELS[status] ?? status;
}

export function priorityLabel(priority: IssuePriority | string | null | undefined): string {
  if (!priority) return 'No priority';
  return PRIORITY_LABELS[priority] ?? priority;
}

export function statusColor(status: IssueStatus | string | null | undefined, scheme: ColorScheme): string {
  const t = THEME[scheme];
  switch (status) {
    case 'backlog': return String(t.statusBacklog);
    case 'todo': return String(t.statusTodo);
    case 'in_progress': return String(t.statusInProgress);
    case 'in_review': return String(t.statusInReview);
    case 'done': return String(t.statusDone);
    case 'cancelled': return String(t.statusCancelled);
    default: return String(t.mutedForeground);
  }
}

export function priorityColor(priority: IssuePriority | string | null | undefined, scheme: ColorScheme): string {
  const t = THEME[scheme];
  switch (priority) {
    case 'urgent': return String(t.priorityUrgent);
    case 'high': return String(t.priorityHigh);
    case 'medium': return String(t.priorityMedium);
    case 'low': return String(t.priorityLow);
    case 'no_priority':
    default: return String(t.priorityNone);
  }
}
