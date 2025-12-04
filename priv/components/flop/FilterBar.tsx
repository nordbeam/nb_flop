/**
 * FilterBar - Main container for Linear-style filter chips
 *
 * Works with TableFilter from nb_flop DSL and TableFlopFilter for active filters
 */

import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import type { TableFilter, TableFlopFilter, FilterClause } from './tableTypes';
import { FilterChip } from './FilterChip';
import { AddFilterButton } from './AddFilterButton';
import {
  clauseToFlopOp,
  flopOpToClause,
  transformFilterValue,
} from './filterUtils';

export interface FilterBarProps {
  /** Filter definitions from DSL (resource.filters) */
  filters: TableFilter[];
  /** Active filter values (resource.state.filters) */
  activeFilters: TableFlopFilter[];
  /** Callback when a filter is added or changed */
  onFilterChange: (field: string, op: string, value: unknown) => void;
  /** Callback when a filter is removed */
  onFilterRemove: (field: string, op?: string) => void;
  /** Callback to clear all filters */
  onClearFilters: () => void;
  /** Additional CSS class */
  className?: string;
}

/**
 * Represents a filter chip with its definition and current value
 */
interface ActiveFilterWithDefinition {
  definition: TableFilter;
  clause: FilterClause;
  value: unknown;
  flopOp: string;
}

export function FilterBar({
  filters,
  activeFilters,
  onFilterChange,
  onFilterRemove,
  onClearFilters,
  className = '',
}: FilterBarProps) {
  // Match active filters with their definitions
  const activeFiltersWithDefs: ActiveFilterWithDefinition[] = [];

  activeFilters.forEach((af) => {
    const definition = filters.find((f) => f.field === af.field);
    if (definition) {
      activeFiltersWithDefs.push({
        definition,
        clause: flopOpToClause(af.op),
        value: af.value,
        flopOp: af.op,
      });
    }
  });

  const hasActiveFilters = activeFiltersWithDefs.length > 0;

  // Get filters that can still be added (not already active, or allow multiple)
  const availableFilters = filters.filter((f) => {
    // For set filters, only allow one active at a time
    if (f.type === 'set') {
      return !activeFiltersWithDefs.some((af) => af.definition.field === f.field);
    }
    // For other types, allow multiple (e.g., different clauses)
    return true;
  });

  const handleClauseChange = (filter: ActiveFilterWithDefinition, newClause: FilterClause) => {
    // Convert clause to Flop operator
    const newOp = clauseToFlopOp(newClause);
    // Transform value if needed (e.g., for contains → add wildcards)
    const newValue = transformFilterValue(newClause, filter.value);

    // Remove old filter and add new one
    onFilterRemove(filter.definition.field, filter.flopOp);
    onFilterChange(filter.definition.field, newOp, newValue);
  };

  const handleValueChange = (filter: ActiveFilterWithDefinition, newValue: unknown) => {
    // Transform value based on clause type
    const transformedValue = transformFilterValue(filter.clause, newValue);
    onFilterChange(filter.definition.field, filter.flopOp, transformedValue);
  };

  const handleRemove = (filter: ActiveFilterWithDefinition) => {
    onFilterRemove(filter.definition.field, filter.flopOp);
  };

  const handleAddFilter = (field: string, clause: FilterClause, value: unknown) => {
    const op = clauseToFlopOp(clause);
    const transformedValue = transformFilterValue(clause, value);
    onFilterChange(field, op, transformedValue);
  };

  return (
    <div
      className={`flex flex-wrap items-center gap-2 ${className}`}
      role="group"
      aria-label="Active filters"
    >
      {/* Active filter chips */}
      {activeFiltersWithDefs.map((af, index) => (
        <FilterChip
          key={`${af.definition.field}-${af.flopOp}-${index}`}
          filter={af.definition}
          clause={af.clause}
          value={af.value}
          onClauseChange={(clause) => handleClauseChange(af, clause)}
          onValueChange={(value) => handleValueChange(af, value)}
          onRemove={() => handleRemove(af)}
        />
      ))}

      {/* Add filter button */}
      {availableFilters.length > 0 && (
        <AddFilterButton
          filters={availableFilters}
          onAddFilter={handleAddFilter}
        />
      )}

      {/* Clear all button */}
      {hasActiveFilters && (
        <Button
          variant="ghost"
          size="sm"
          className="h-7 text-xs text-muted-foreground hover:text-destructive"
          onClick={onClearFilters}
        >
          <X className="h-3 w-3 mr-1" />
          Clear
        </Button>
      )}
    </div>
  );
}

export default FilterBar;
