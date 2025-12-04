/**
 * AddFilterButton - Dropdown to add filters from available TableFilter definitions
 *
 * Shows clause/operator selection when a filter has multiple clauses
 */

import { useState } from 'react';
import { Filter } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';
import type { TableFilter, FilterClause } from './tableTypes';
import { getInputTypeForFilterType, getClauseLabel } from './filterUtils';

export interface AddFilterButtonProps {
  /** Available filter definitions from DSL */
  filters: TableFilter[];
  /** Callback when a filter is added */
  onAddFilter: (field: string, clause: FilterClause, value: unknown) => void;
}

export function AddFilterButton({
  filters,
  onAddFilter,
}: AddFilterButtonProps) {
  const [inputValues, setInputValues] = useState<Record<string, string>>({});
  const [open, setOpen] = useState(false);

  const handleAddFilter = (
    filter: TableFilter,
    clause: FilterClause,
    value: unknown
  ) => {
    onAddFilter(filter.field, clause, value);
    setOpen(false);
    // Clear input values after adding
    setInputValues({});
  };

  const handleInputKeyDown = (
    e: React.KeyboardEvent<HTMLInputElement>,
    filter: TableFilter,
    clause: FilterClause
  ) => {
    if (e.key === 'Enter') {
      const value = inputValues[filter.field]?.trim();
      if (value) {
        handleAddFilter(filter, clause, value);
      }
    }
  };

  if (filters.length === 0) {
    return null;
  }

  return (
    <DropdownMenu open={open} onOpenChange={setOpen}>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="h-7 gap-1">
          <Filter className="h-3.5 w-3.5" />
          <span>Filter</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-48">
        {filters.map((filter) => {
          const inputType = getInputTypeForFilterType(filter.type);
          const hasMultipleClauses = filter.clauses.length > 1;

          // For set filters with options, show nested menu with searchable list
          if (filter.type === 'set' && filter.options.length > 0) {
            return (
              <DropdownMenuSub key={filter.field}>
                <DropdownMenuSubTrigger className="gap-2">
                  <span>{filter.label || filter.field}</span>
                </DropdownMenuSubTrigger>
                <DropdownMenuSubContent className="p-0">
                  <Command>
                    <CommandInput
                      placeholder={filter.placeholder || `Search ${(filter.label || filter.field).toLowerCase()}...`}
                    />
                    <CommandList>
                      <CommandEmpty>No results found.</CommandEmpty>
                      <CommandGroup>
                        {filter.options.map((option) => (
                          <CommandItem
                            key={String(option.value)}
                            value={option.label}
                            onSelect={() => handleAddFilter(filter, 'equals', option.value)}
                          >
                            <span>{option.label}</span>
                          </CommandItem>
                        ))}
                      </CommandGroup>
                    </CommandList>
                  </Command>
                </DropdownMenuSubContent>
              </DropdownMenuSub>
            );
          }

          // For boolean filters, add true/false options
          if (filter.type === 'boolean') {
            return (
              <DropdownMenuSub key={filter.field}>
                <DropdownMenuSubTrigger className="gap-2">
                  <span>{filter.label || filter.field}</span>
                </DropdownMenuSubTrigger>
                <DropdownMenuSubContent className="p-1 w-32">
                  <Command>
                    <CommandList>
                      <CommandGroup>
                        <CommandItem onSelect={() => handleAddFilter(filter, filter.defaultClause, true)}>
                          Yes
                        </CommandItem>
                        <CommandItem onSelect={() => handleAddFilter(filter, filter.defaultClause, false)}>
                          No
                        </CommandItem>
                        {filter.nullable && (
                          <CommandItem onSelect={() => handleAddFilter(filter, filter.defaultClause, null)}>
                            Not set
                          </CommandItem>
                        )}
                      </CommandGroup>
                    </CommandList>
                  </Command>
                </DropdownMenuSubContent>
              </DropdownMenuSub>
            );
          }

          // For text/numeric/date fields with multiple clauses, show clause selector first
          if (hasMultipleClauses) {
            return (
              <DropdownMenuSub key={filter.field}>
                <DropdownMenuSubTrigger className="gap-2">
                  <span>{filter.label || filter.field}</span>
                </DropdownMenuSubTrigger>
                <DropdownMenuSubContent className="p-1 w-44">
                  {filter.clauses.map((clause) => (
                    <DropdownMenuSub key={clause}>
                      <DropdownMenuSubTrigger className="text-sm">
                        <span>{getClauseLabel(clause)}</span>
                      </DropdownMenuSubTrigger>
                      <DropdownMenuSubContent className="p-2 w-48">
                        <Input
                          type={inputType}
                          placeholder={filter.placeholder || `Enter value...`}
                          value={inputValues[`${filter.field}-${clause}`] || ''}
                          onChange={(e) =>
                            setInputValues((prev) => ({
                              ...prev,
                              [`${filter.field}-${clause}`]: e.target.value,
                            }))
                          }
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              const value = inputValues[`${filter.field}-${clause}`]?.trim();
                              if (value) {
                                handleAddFilter(filter, clause, value);
                              }
                            }
                          }}
                          min={filter.min as number | undefined}
                          max={filter.max as number | undefined}
                          autoFocus
                          className="h-8"
                        />
                        <p className="text-xs text-muted-foreground mt-1">
                          Press Enter to add
                        </p>
                      </DropdownMenuSubContent>
                    </DropdownMenuSub>
                  ))}
                </DropdownMenuSubContent>
              </DropdownMenuSub>
            );
          }

          // For fields with single clause, show input directly
          return (
            <DropdownMenuSub key={filter.field}>
              <DropdownMenuSubTrigger className="gap-2">
                <span>{filter.label || filter.field}</span>
              </DropdownMenuSubTrigger>
              <DropdownMenuSubContent className="p-2 w-48">
                <Input
                  type={inputType}
                  placeholder={filter.placeholder || `Enter ${(filter.label || filter.field).toLowerCase()}...`}
                  value={inputValues[filter.field] || ''}
                  onChange={(e) =>
                    setInputValues((prev) => ({
                      ...prev,
                      [filter.field]: e.target.value,
                    }))
                  }
                  onKeyDown={(e) => handleInputKeyDown(e, filter, filter.defaultClause)}
                  min={filter.min as number | undefined}
                  max={filter.max as number | undefined}
                  autoFocus
                  className="h-8"
                />
                <p className="text-xs text-muted-foreground mt-1">
                  Press Enter to add filter
                </p>
              </DropdownMenuSubContent>
            </DropdownMenuSub>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

export default AddFilterButton;
