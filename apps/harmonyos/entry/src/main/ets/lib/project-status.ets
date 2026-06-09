import { ProjectStatus, ProjectPriority } from '../models/types';
import { THEME, ColorScheme } from './theme';

const STATUS_LABELS: Record<string, string> = {
  planned: 'Planned',
  in_progress: 'In Progress',
  paused: 'Paused',
  completed: 'Completed',
  cancelled: 'Cancelled'
};

const PRIORITY_LABELS: Record<string, string> = {
  no_priority: 'No priority',
  urgent: 'Urgent',
  high: 'High',
  medium: 'Medium',
  low: 'Low'
};

export function projectStatusLabel(status: ProjectStatus | string | null | undefined): string {
  if (!status) return 'Unknown';
  return STATUS_LABELS[status] ?? status;
}

export function projectPriorityLabel(priority: ProjectPriority | string | null | undefined): string {
  if (!priority) return 'No priority';
  return PRIORITY_LABELS[priority] ?? priority;
}

export function projectStatusColor(status: ProjectStatus | string | null | undefined, scheme: ColorScheme): string {
  const t = THEME[scheme];
  switch (status) {
    case 'planned': return String(t.statusBacklog);
    case 'in_progress': return String(t.statusInProgress);
    case 'paused': return String(t.statusInReview);
    case 'completed': return String(t.statusDone);
    case 'cancelled': return String(t.statusCancelled);
    default: return String(t.mutedForeground);
  }
}

export function projectPriorityColor(priority: ProjectPriority | string | null | undefined, scheme: ColorScheme): string {
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
