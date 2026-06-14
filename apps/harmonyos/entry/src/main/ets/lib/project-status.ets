import { ProjectStatus, ProjectPriority } from '../models/types';
import { ColorScheme, themeTokens } from './theme';

export function projectStatusLabel(status: ProjectStatus | string | null | undefined): string {
  if (!status) return 'Unknown';
  switch (status) {
    case 'planned': return 'Planned';
    case 'in_progress': return 'In Progress';
    case 'paused': return 'Paused';
    case 'completed': return 'Completed';
    case 'cancelled': return 'Cancelled';
    default: return status;
  }
}

export function projectPriorityLabel(priority: ProjectPriority | string | null | undefined): string {
  if (!priority) return 'No priority';
  switch (priority) {
    case 'no_priority': return 'No priority';
    case 'urgent': return 'Urgent';
    case 'high': return 'High';
    case 'medium': return 'Medium';
    case 'low': return 'Low';
    default: return priority;
  }
}

export function projectStatusColor(status: ProjectStatus | string | null | undefined, scheme: ColorScheme): string {
  const t = themeTokens(scheme);
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
  const t = themeTokens(scheme);
  switch (priority) {
    case 'urgent': return String(t.priorityUrgent);
    case 'high': return String(t.priorityHigh);
    case 'medium': return String(t.priorityMedium);
    case 'low': return String(t.priorityLow);
    case 'no_priority':
    default: return String(t.priorityNone);
  }
}
