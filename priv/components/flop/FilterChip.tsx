/**
 * FilterChip - Individual filter display with inline editing
 *
 * Works with TableFilter from nb_flop DSL
 */

import { X } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';
import type { TableFilter, FilterClause } from './tableTypes';
import {
  getClauseLabel,
  formatFilterValue,
  clauseRequiresValue,
  getInputTypeForFilterType,
} from './filterUtils';
import { FilterValueSelect } from './FilterValueSelect';
import { FilterValueInput } from './FilterValueInput';

export interface FilterChipProps {
  /** Filter definition from DSL */
  filter: TableFilter;
  /** Current clause (operator) */
  clause: FilterClause;
  /** Current filter value */
  value: unknown;
  /** Callback when clause changes */
  onClauseChange: (clause: FilterClause) => void;
  /** Callback when value changes */
  onValueChange: (value: unknown) => void;
  /** Callback to remove filter */
  onRemove: () => void;
}

export function FilterChip({
  filter,
  clause,
  value,
  onClauseChange,
  onValueChange,
  onRemove,
}: FilterChipProps) {
  const clauseLabel = getClauseLabel(clause);
  const valueLabel = formatFilterValue(value, filter.options);
  const hasMultipleClauses = filter.clauses.length > 1;
  const isSetType = filter.type === 'set';
  const showValueInput = clauseRequiresValue(clause);
  const inputType = getInputTypeForFilterType(filter.type);

  return (
    <Badge
      variant="secondary"
      className="flex items-center gap-1 px-2 py-1 h-7 text-sm font-normal"
    >
      {/* Filter label */}
      <span className="text-muted-foreground">{filter.label || filter.field}</span>

      {/* Clause selector */}
      {hasMultipleClauses ? (
        <Popover>
          <PopoverTrigger asChild>
            <button
              type="button"
              className="px-1 hover:bg-muted rounded text-xs text-muted-foreground hover:text-foreground transition-colors"
            >
              {clauseLabel}
            </button>
          </PopoverTrigger>
          <PopoverContent className="w-44 p-1" align="start">
            <div className="flex flex-col gap-0.5">
              {filter.clauses.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => onClauseChange(c)}
                  className={`text-left px-2 py-1.5 text-sm rounded hover:bg-muted transition-colors ${
                    c === clause ? 'bg-muted font-medium' : ''
                  }`}
                >
                  {getClauseLabel(c)}
                </button>
              ))}
            </div>
          </PopoverContent>
        </Popover>
      ) : (
        <span className="text-xs text-muted-foreground">{clauseLabel}</span>
      )}

      {/* Value editor */}
      {showValueInput && (
        <Popover>
          <PopoverTrigger asChild>
            <button
              type="button"
              className="px-1.5 py-0.5 bg-background border rounded text-xs font-medium hover:bg-muted transition-colors max-w-[120px] truncate"
            >
              {valueLabel}
            </button>
          </PopoverTrigger>
          <PopoverContent className="w-56 p-2" align="start">
            {isSetType && filter.options.length > 0 ? (
              <FilterValueSelect
                options={filter.options}
                value={value}
                onSelect={onValueChange}
                placeholder={filter.placeholder || `Select ${filter.label || filter.field}...`}
                colors={filter.colors}
              />
            ) : (
              <FilterValueInput
                value={String(value ?? '')}
                onChange={onValueChange}
                placeholder={filter.placeholder ?? undefined}
                type={inputType}
                min={filter.min as number | undefined}
                max={filter.max as number | undefined}
              />
            )}
          </PopoverContent>
        </Popover>
      )}

      {/* Remove button */}
      <Button
        variant="ghost"
        size="sm"
        className="h-4 w-4 p-0 ml-1 hover:bg-destructive/20 hover:text-destructive"
        onClick={onRemove}
      >
        <X className="h-3 w-3" />
        <span className="sr-only">Remove filter</span>
      </Button>
    </Badge>
  );
}

export default FilterChip;
