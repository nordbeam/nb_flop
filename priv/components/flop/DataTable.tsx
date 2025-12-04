/**
 * NbFlop DataTable Component - Linear-inspired design
 *
 * A TanStack Table wrapper that integrates with Flop for server-side
 * pagination, sorting, and filtering.
 */

import * as React from 'react';
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
  type ColumnDef,
  type Row,
  type Table as TanStackTable,
} from '@tanstack/react-table';
import type { FlopMeta, SortDirection } from './types';
import { cn } from '@/lib/utils';

export type { ColumnDef } from '@tanstack/react-table';

export interface DataTableProps<TData, TValue> {
  columns: ColumnDef<TData, TValue>[];
  data: TData[];
  meta?: FlopMeta | null;
  onSortChange?: (field: string, direction: SortDirection) => void;
  getSortDirection?: (field: string) => SortDirection;
  emptyState?: React.ReactNode;
  className?: string;
  rowClassName?: string | ((row: Row<TData>) => string);
  onRowClick?: (row: Row<TData>) => void;
  footer?: (table: TanStackTable<TData>) => React.ReactNode;
}

export interface DataTableContextValue {
  onSortChange?: (field: string, direction: SortDirection) => void;
  getSortDirection?: (field: string) => SortDirection;
}

export const DataTableContext = React.createContext<DataTableContextValue>({});

export function useDataTableContext() {
  return React.useContext(DataTableContext);
}

export function DataTable<TData, TValue>({
  columns,
  data,
  meta,
  onSortChange,
  getSortDirection,
  emptyState,
  className,
  rowClassName,
  onRowClick,
  footer,
}: DataTableProps<TData, TValue>) {
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    manualPagination: true,
    manualSorting: true,
    pageCount: meta?.totalPages ?? -1,
  });

  const contextValue = React.useMemo(
    () => ({ onSortChange, getSortDirection }),
    [onSortChange, getSortDirection]
  );

  const getRowClassName = (row: Row<TData>) => {
    if (typeof rowClassName === 'function') {
      return rowClassName(row);
    }
    return rowClassName ?? '';
  };

  return (
    <DataTableContext.Provider value={contextValue}>
      <div className={cn("overflow-hidden", className)}>
        <table className="w-full text-sm">
          {/* Header */}
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr
                key={headerGroup.id}
                className="border-b border-border"
              >
                {headerGroup.headers.map((header) => (
                  <th
                    key={header.id}
                    className="h-10 px-4 text-left align-middle text-xs font-medium uppercase tracking-wider text-muted-foreground"
                  >
                    {header.isPlaceholder
                      ? null
                      : flexRender(
                          header.column.columnDef.header,
                          header.getContext()
                        )}
                  </th>
                ))}
              </tr>
            ))}
          </thead>

          {/* Body */}
          <tbody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row, index) => (
                <tr
                  key={row.id}
                  data-state={row.getIsSelected() && 'selected'}
                  className={cn(
                    "transition-colors",
                    "hover:bg-accent/50",
                    "data-[state=selected]:bg-accent",
                    index !== table.getRowModel().rows.length - 1 && "border-b border-border",
                    onRowClick && "cursor-pointer",
                    getRowClassName(row)
                  )}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                >
                  {row.getVisibleCells().map((cell) => (
                    <td
                      key={cell.id}
                      className="px-4 py-3 align-middle text-foreground"
                    >
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
                    </td>
                  ))}
                </tr>
              ))
            ) : (
              <tr>
                <td
                  colSpan={columns.length}
                  className="px-4 py-12 text-center"
                >
                  <div className="flex flex-col items-center gap-2">
                    <EmptyIcon className="h-8 w-8 text-muted-foreground/50" />
                    <p className="text-sm text-muted-foreground">
                      {emptyState ?? 'No results found.'}
                    </p>
                  </div>
                </td>
              </tr>
            )}
          </tbody>

          {/* Footer */}
          {footer && (
            <tfoot className="border-t border-border bg-muted/30">
              {footer(table)}
            </tfoot>
          )}
        </table>
      </div>
    </DataTableContext.Provider>
  );
}

// Empty state icon
function EmptyIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
      />
    </svg>
  );
}

export default DataTable;
