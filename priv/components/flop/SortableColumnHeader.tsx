/**
 * NbFlop SortableColumnHeader Component - Linear-inspired design
 *
 * A column header component for TanStack Table that integrates with Flop
 * for server-side sorting.
 */

import * as React from 'react';
import { useDataTableContext } from './DataTable';
import type { SortDirection } from './types';
import { ArrowUp, ArrowDown, ArrowUpDown } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface SortableColumnHeaderProps {
  field: string;
  children: React.ReactNode;
  className?: string;
}

export function SortableColumnHeader({
  field,
  children,
  className = '',
}: SortableColumnHeaderProps) {
  const { onSortChange, getSortDirection } = useDataTableContext();

  const direction = getSortDirection?.(field) ?? null;
  const isActive = direction !== null;

  const handleClick = () => {
    if (!onSortChange) return;

    let newDirection: SortDirection;
    if (!isActive) {
      newDirection = 'asc';
    } else if (direction === 'asc') {
      newDirection = 'desc';
    } else {
      newDirection = null;
    }

    onSortChange(field, newDirection);
  };

  // If no sort handler, render as plain text
  if (!onSortChange) {
    return <span className="text-xs font-medium uppercase tracking-wider">{children}</span>;
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      className={cn(
        "inline-flex items-center gap-1.5 text-xs font-medium uppercase tracking-wider transition-colors",
        "hover:text-foreground focus:outline-none focus-visible:text-foreground",
        isActive ? "text-foreground" : "text-muted-foreground",
        className
      )}
      aria-sort={
        direction === 'asc'
          ? 'ascending'
          : direction === 'desc'
            ? 'descending'
            : 'none'
      }
    >
      <span>{children}</span>
      {direction === 'asc' ? (
        <ArrowUp className="h-3.5 w-3.5" />
      ) : direction === 'desc' ? (
        <ArrowDown className="h-3.5 w-3.5" />
      ) : (
        <ArrowUpDown className="h-3.5 w-3.5 opacity-40" />
      )}
    </button>
  );
}

export default SortableColumnHeader;
