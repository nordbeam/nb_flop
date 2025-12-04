/**
 * Filter utilities for nb_flop DSL integration
 *
 * Handles conversion between DSL clauses (equals, contains) and Flop operators (==, ilike)
 */

import type { FlopOperator } from './types';
import type { FilterClause, FilterType, TableFilterOption } from './tableTypes';

/**
 * Human-readable labels for filter clauses
 */
export const CLAUSE_LABELS: Record<FilterClause, string> = {
  equals: 'is',
  not_equals: 'is not',
  contains: 'contains',
  starts_with: 'starts with',
  ends_with: 'ends with',
  gt: 'greater than',
  gte: 'at least',
  lt: 'less than',
  lte: 'at most',
  between: 'between',
  in: 'is any of',
  not_in: 'is none of',
  empty: 'is empty',
  not_empty: 'is not empty',
};

/**
 * Get human-readable label for a clause
 */
export function getClauseLabel(clause: FilterClause | string): string {
  return CLAUSE_LABELS[clause as FilterClause] || clause;
}

/**
 * Convert a DSL clause to a Flop operator
 * Matches NbFlop.Filter.clause_to_flop_op/1
 */
export function clauseToFlopOp(clause: FilterClause): FlopOperator {
  switch (clause) {
    case 'equals':
      return '==';
    case 'not_equals':
      return '!=';
    case 'contains':
      return 'ilike';
    case 'starts_with':
      return 'ilike'; // Value will be prefixed with %
    case 'ends_with':
      return 'ilike'; // Value will be suffixed with %
    case 'gt':
      return '>';
    case 'gte':
      return '>=';
    case 'lt':
      return '<';
    case 'lte':
      return '<=';
    case 'in':
      return 'in';
    case 'not_in':
      return 'not_in';
    case 'empty':
      return 'empty';
    case 'not_empty':
      return 'not_empty';
    case 'between':
      // Between is special - handled separately
      return '>=';
    default:
      return '==' as FlopOperator;
  }
}

/**
 * Convert a Flop operator to a DSL clause
 * Matches NbFlop.Filter.flop_op_to_clause/1
 */
export function flopOpToClause(op: FlopOperator | string): FilterClause {
  switch (op) {
    case '==':
      return 'equals';
    case '!=':
      return 'not_equals';
    case 'ilike':
    case 'like':
    case '=~':
      return 'contains';
    case '>':
      return 'gt';
    case '>=':
      return 'gte';
    case '<':
      return 'lt';
    case '<=':
      return 'lte';
    case 'in':
      return 'in';
    case 'not_in':
      return 'not_in';
    case 'empty':
      return 'empty';
    case 'not_empty':
      return 'not_empty';
    default:
      return 'equals';
  }
}

/**
 * Transform filter value based on clause type
 * Note: Flop automatically adds wildcards for ilike operator,
 * so we don't need to add them here.
 */
export function transformFilterValue(_clause: FilterClause, value: unknown): unknown {
  // Flop handles wildcard addition for ilike operator automatically
  // Just return the value as-is
  return value;
}

/**
 * Get default clauses for a filter type
 */
export function getDefaultClausesForType(type: FilterType): FilterClause[] {
  switch (type) {
    case 'text':
      return ['equals', 'not_equals', 'contains', 'starts_with', 'ends_with', 'empty', 'not_empty'];
    case 'numeric':
      return ['equals', 'not_equals', 'gt', 'gte', 'lt', 'lte', 'between', 'empty', 'not_empty'];
    case 'set':
      return ['in', 'not_in'];
    case 'date':
    case 'datetime':
      return ['equals', 'not_equals', 'gt', 'gte', 'lt', 'lte', 'between', 'empty', 'not_empty'];
    case 'boolean':
      return ['equals'];
    default:
      return ['equals', 'not_equals'];
  }
}

/**
 * Get the default clause for a filter type
 */
export function getDefaultClauseForType(type: FilterType): FilterClause {
  switch (type) {
    case 'text':
      return 'contains';
    case 'numeric':
      return 'equals';
    case 'set':
      return 'in';
    case 'date':
    case 'datetime':
      return 'equals';
    case 'boolean':
      return 'equals';
    default:
      return 'equals';
  }
}

/**
 * Format a filter value for display
 */
export function formatFilterValue(
  value: unknown,
  options?: TableFilterOption[]
): string {
  if (value === null || value === undefined || value === '') {
    return '(empty)';
  }

  // Check if value matches an option
  if (options && options.length > 0) {
    const option = options.find((o) => o.value === String(value));
    if (option) {
      return option.label;
    }
  }

  if (typeof value === 'boolean') {
    return value ? 'Yes' : 'No';
  }

  // Strip wildcards for display
  let displayValue = String(value);
  if (displayValue.startsWith('%')) {
    displayValue = displayValue.slice(1);
  }
  if (displayValue.endsWith('%')) {
    displayValue = displayValue.slice(0, -1);
  }

  return displayValue;
}

/**
 * Get input type for a filter type
 */
export function getInputTypeForFilterType(type: FilterType): 'text' | 'number' | 'date' | 'datetime-local' {
  switch (type) {
    case 'numeric':
      return 'number';
    case 'date':
      return 'date';
    case 'datetime':
      return 'datetime-local';
    default:
      return 'text';
  }
}

/**
 * Check if a clause requires a value input
 */
export function clauseRequiresValue(clause: FilterClause): boolean {
  return clause !== 'empty' && clause !== 'not_empty';
}

/**
 * Check if a clause is for set/multi-select filters
 */
export function clauseIsSetBased(clause: FilterClause): boolean {
  return clause === 'in' || clause === 'not_in';
}
