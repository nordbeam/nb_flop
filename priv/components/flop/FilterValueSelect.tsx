/**
 * FilterValueSelect - Searchable select for set filter values
 *
 * Supports color badges from DSL colors configuration
 */

import { Check } from 'lucide-react';
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';
import { cn } from '@/lib/utils';
import type { TableFilterOption, FilterColorVariant } from './tableTypes';

export interface FilterValueSelectProps {
  /** Available options */
  options: TableFilterOption[];
  /** Currently selected value */
  value?: unknown;
  /** Callback when option is selected */
  onSelect: (value: string) => void;
  /** Placeholder text for search */
  placeholder?: string;
  /** Optional color mapping for badge display */
  colors?: Record<string, FilterColorVariant> | null;
}

/**
 * Get Tailwind classes for a color variant
 */
function getColorClasses(variant: FilterColorVariant): string {
  switch (variant) {
    case 'primary':
      return 'bg-primary/20 text-primary';
    case 'success':
      return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400';
    case 'warning':
      return 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400';
    case 'danger':
      return 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400';
    case 'muted':
      return 'bg-muted text-muted-foreground';
    default:
      return 'bg-secondary text-secondary-foreground';
  }
}

export function FilterValueSelect({
  options,
  value,
  onSelect,
  placeholder = 'Search...',
  colors,
}: FilterValueSelectProps) {
  return (
    <Command className="rounded-lg border shadow-md">
      <CommandInput placeholder={placeholder} />
      <CommandList>
        <CommandEmpty>No results found.</CommandEmpty>
        <CommandGroup>
          {options.map((option) => {
            const isSelected = String(option.value) === String(value);
            const colorVariant = colors?.[option.value] || colors?.[option.value.toLowerCase()];

            return (
              <CommandItem
                key={String(option.value)}
                value={option.label}
                onSelect={() => onSelect(option.value)}
                className={cn(
                  'flex items-center gap-2',
                  isSelected && 'bg-accent'
                )}
              >
                {/* Color badge if colors provided */}
                {colorVariant && (
                  <span
                    className={cn(
                      'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
                      getColorClasses(colorVariant)
                    )}
                  >
                    {option.label}
                  </span>
                )}

                {/* Plain label if no colors */}
                {!colorVariant && <span>{option.label}</span>}

                {/* Check mark for selected item */}
                {isSelected && (
                  <Check className="ml-auto h-4 w-4 text-primary" />
                )}
              </CommandItem>
            );
          })}
        </CommandGroup>
      </CommandList>
    </Command>
  );
}

export default FilterValueSelect;
