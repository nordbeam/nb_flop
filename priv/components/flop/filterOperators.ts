/**
 * Filter operator labels and utilities
 */

import type { FlopOperator, FilterFieldType } from './types';

export const OPERATOR_LABELS: Record<string, string> = {
  '==': 'is',
  '!=': 'is not',
  'ilike': 'contains',
  'not_ilike': 'does not contain',
  'like': 'contains (case-sensitive)',
  'not_like': 'does not contain (case-sensitive)',
  'empty': 'is empty',
  'not_empty': 'is not empty',
  '>': 'greater than',
  '<': 'less than',
  '>=': 'at least',
  '<=': 'at most',
  'in': 'is any of',
  'not_in': 'is none of',
  '=~': 'matches',
};

export function getOperatorLabel(op: FlopOperator | string): string {
  return OPERATOR_LABELS[op] || op;
}

export function getDefaultOperator(type: FilterFieldType): FlopOperator {
  switch (type) {
    case 'string':
      return 'ilike';
    case 'boolean':
      return '==';
    case 'enum':
      return '==';
    case 'relation':
      return '==';
    case 'number':
      return '==';
    case 'date':
      return '==';
    default:
      return '==';
  }
}

export function getOperatorsForType(type: FilterFieldType): FlopOperator[] {
  switch (type) {
    case 'string':
      return ['ilike', 'not_ilike', '==', '!=', 'empty', 'not_empty'];
    case 'boolean':
      return ['=='];
    case 'enum':
      return ['==', '!='];
    case 'relation':
      return ['==', '!='];
    case 'number':
      return ['==', '!=', '>', '<', '>=', '<='];
    case 'date':
      return ['==', '!=', '>', '<', '>=', '<='];
    default:
      return ['==', '!='];
  }
}

/**
 * Format a filter value for display
 */
export function formatFilterValue(
  value: unknown,
  options?: { value: string | number; label: string }[]
): string {
  if (value === null || value === undefined || value === '') {
    return '(empty)';
  }

  // Check if value matches an option
  if (options) {
    const option = options.find((o) => o.value === value);
    if (option) {
      return option.label;
    }
  }

  if (typeof value === 'boolean') {
    return value ? 'Yes' : 'No';
  }

  return String(value);
}
