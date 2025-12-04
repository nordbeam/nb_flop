/**
 * NbFlop Table Component
 *
 * A comprehensive table component that renders from the TableResource
 * returned by the backend Table DSL. Backend is the single source of truth
 * for columns, actions, filters, and behavior.
 */

import * as React from 'react';
import { useState, useMemo, useCallback } from 'react';
import { router } from '@/lib/inertia';
import { cn } from '@/lib/utils';
import type {
  TableResource,
  TableColumn,
  TableAction,
  TableBulkAction,
  TableFlopFilter,
  Selection,
} from './tableTypes';
import { Pagination } from './Pagination';
import { SearchInput } from '@/components/SearchInput';
import { FilterBar } from './FilterBar';

export interface TableProps<T = Record<string, unknown>> {
  /** The table resource from backend */
  resource: TableResource<T>;
  /** Base URL for navigation (e.g., "/users") */
  baseUrl: string;
  /** Custom row renderer (optional - uses columns from resource by default) */
  renderRow?: (row: T, columns: TableColumn[]) => React.ReactNode;
  /** Custom cell renderer for specific column types */
  renderCell?: (column: TableColumn, value: unknown, row: T) => React.ReactNode;
  /** Custom action button renderer */
  renderAction?: (action: TableAction, row: T) => React.ReactNode;
  /** Row class name or function */
  rowClassName?: string | ((row: T) => string);
  /** Callback when row is clicked */
  onRowClick?: (row: T) => void;
  /** Additional query params to preserve */
  preserveQuery?: Record<string, unknown>;
  /** Custom header content */
  header?: React.ReactNode;
  /** Custom footer content */
  footer?: React.ReactNode;
  /** Class name for wrapper */
  className?: string;
}

export function Table<T extends Record<string, unknown> = Record<string, unknown>>({
  resource,
  baseUrl,
  renderRow,
  renderCell,
  renderAction,
  rowClassName,
  onRowClick,
  preserveQuery = {},
  header,
  footer,
  className,
}: TableProps<T>) {
  const [search, setSearch] = useState(resource.state.search || '');
  const [selectedIds, setSelectedIds] = useState<Set<string | number>>(new Set());
  const [selectionMode, setSelectionMode] = useState<'explicit' | 'all' | 'all_except'>('explicit');

  // Build query params for navigation
  const buildQuery = useCallback(
    (overrides: Record<string, unknown> = {}) => {
      const query: Record<string, unknown> = {
        ...preserveQuery,
      };

      // Page
      if (resource.state.page > 1 || overrides.page) {
        query.page = overrides.page ?? resource.state.page;
      }

      // Per page - preserve current value or use override
      const perPage = overrides.per_page ?? resource.state.perPage;
      if (perPage && perPage !== resource.perPageOptions?.[0]) {
        query.per_page = perPage;
      }

      // Search
      const searchValue = overrides.search !== undefined ? overrides.search : search;
      if (searchValue) {
        query.search = searchValue;
      }

      // Sort
      if (resource.state.sort || overrides.sort) {
        const sort = (overrides.sort as { field: string; direction: string }) ?? resource.state.sort;
        if (sort) {
          query.order_by = sort.field;
          query.order_direction = sort.direction;
        }
      }

      // Filters
      const filters = (overrides.filters ?? resource.state.filters) as TableFlopFilter[];
      if (filters?.length > 0) {
        filters.forEach((f, i) => {
          query[`filters[${i}][field]`] = f.field;
          query[`filters[${i}][op]`] = f.op;
          query[`filters[${i}][value]`] = f.value;
        });
      }

      // Clean undefined values
      Object.keys(query).forEach((key) => {
        if (query[key] === undefined || query[key] === null || query[key] === '') {
          delete query[key];
        }
      });

      return query;
    },
    [resource.state, search, preserveQuery]
  );

  // Navigation helper
  const navigate = useCallback(
    (query: Record<string, unknown>) => {
      router.visit(baseUrl, {
        data: query,
        preserveState: true,
        preserveScroll: true,
      });
    },
    [baseUrl]
  );

  // Handlers
  const handleSearch = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      navigate(buildQuery({ search, page: 1 }));
    },
    [navigate, buildQuery, search]
  );

  const handleSearchChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setSearch(e.target.value);
  }, []);

  const handleSort = useCallback(
    (field: string) => {
      const currentSort = resource.state.sort;
      let newDirection: 'asc' | 'desc' = 'asc';

      if (currentSort?.field === field) {
        newDirection = currentSort.direction === 'asc' ? 'desc' : 'asc';
      }

      navigate(buildQuery({ sort: { field, direction: newDirection }, page: 1 }));
    },
    [resource.state.sort, navigate, buildQuery]
  );

  const handlePageChange = useCallback(
    (page: number) => {
      navigate(buildQuery({ page }));
    },
    [navigate, buildQuery]
  );

  const handlePerPageChange = useCallback(
    (perPage: number) => {
      navigate(buildQuery({ per_page: perPage, page: 1 }));
    },
    [navigate, buildQuery]
  );

  // Filter handlers
  const handleFilterChange = useCallback(
    (field: string, op: string, value: unknown) => {
      // Get current filters
      const currentFilters = [...(resource.state.filters || [])];

      // Find existing filter with same field and op
      const existingIndex = currentFilters.findIndex(
        (f) => f.field === field && f.op === op
      );

      if (existingIndex >= 0) {
        // Update existing filter
        currentFilters[existingIndex] = { field, op, value };
      } else {
        // Add new filter
        currentFilters.push({ field, op, value });
      }

      navigate(buildQuery({ filters: currentFilters, page: 1 }));
    },
    [resource.state.filters, navigate, buildQuery]
  );

  const handleFilterRemove = useCallback(
    (field: string, op?: string) => {
      const currentFilters = [...(resource.state.filters || [])];

      // Remove filter(s) matching field (and optionally op)
      const newFilters = currentFilters.filter((f) => {
        if (op) {
          return !(f.field === field && f.op === op);
        }
        return f.field !== field;
      });

      navigate(buildQuery({ filters: newFilters, page: 1 }));
    },
    [resource.state.filters, navigate, buildQuery]
  );

  const handleClearFilters = useCallback(() => {
    navigate(buildQuery({ filters: [], page: 1 }));
  }, [navigate, buildQuery]);

  // Selection handlers
  const handleSelectRow = useCallback((id: string | number) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
    setSelectionMode('explicit');
  }, []);

  const handleSelectAll = useCallback(() => {
    if (selectionMode === 'all') {
      setSelectedIds(new Set());
      setSelectionMode('explicit');
    } else {
      setSelectionMode('all');
      setSelectedIds(new Set());
    }
  }, [selectionMode]);

  const getSelection = useCallback((): Selection => {
    return {
      mode: selectionMode,
      ids: Array.from(selectedIds),
    };
  }, [selectionMode, selectedIds]);

  const selectedCount = useMemo(() => {
    if (selectionMode === 'all') {
      return (resource.meta.totalCount ?? resource.data.length) - selectedIds.size;
    }
    return selectedIds.size;
  }, [selectionMode, selectedIds, resource.meta.totalCount, resource.data.length]);

  // Action handlers
  const handleAction = useCallback(
    async (action: TableAction, row: T) => {
      if (!resource.token) return;

      // Check for confirmation
      if (action.confirmation) {
        const confirmed = window.confirm(
          `${action.confirmation.title}\n\n${action.confirmation.message}`
        );
        if (!confirmed) return;
      }

      // Execute action via API
      const response = await fetch('/nb-flop/action', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': getCSRFToken(),
        },
        body: JSON.stringify({
          token: resource.token,
          action: action.name,
          id: row.id,
        }),
      });

      const result = await response.json();

      if (result.success) {
        if (result.redirect) {
          router.visit(result.redirect);
        } else {
          router.reload();
        }
      } else {
        alert(result.message || 'Action failed');
      }
    },
    [resource.token]
  );

  const handleBulkAction = useCallback(
    async (action: TableBulkAction) => {
      if (!resource.token || selectedCount === 0) return;

      // Check for confirmation
      if (action.confirmation) {
        const message = action.confirmation.message.replace('{count}', String(selectedCount));
        const confirmed = window.confirm(`${action.confirmation.title}\n\n${message}`);
        if (!confirmed) return;
      }

      const response = await fetch('/nb-flop/bulk-action', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': getCSRFToken(),
        },
        body: JSON.stringify({
          token: resource.token,
          action: action.name,
          selection: getSelection(),
          filters: resource.state.filters,
        }),
      });

      const result = await response.json();

      if (result.success) {
        setSelectedIds(new Set());
        setSelectionMode('explicit');
        router.reload();
      } else {
        alert(result.message || 'Bulk action failed');
      }
    },
    [resource.token, selectedCount, getSelection, resource.state.filters]
  );

  // Visible columns
  const visibleColumns = useMemo(
    () => resource.columns.filter((col) => col.visible),
    [resource.columns]
  );

  // Get row className
  const getRowClassName = (row: T) => {
    if (typeof rowClassName === 'function') {
      return rowClassName(row);
    }
    return rowClassName ?? '';
  };

  // Check if row is selected
  const isRowSelected = (row: T) => {
    const id = row.id as string | number;
    if (selectionMode === 'all') {
      return !selectedIds.has(id);
    }
    if (selectionMode === 'all_except') {
      return !selectedIds.has(id);
    }
    return selectedIds.has(id);
  };

  // Render cell based on column type
  const defaultRenderCell = (column: TableColumn, value: unknown, row: T): React.ReactNode => {
    if (renderCell) {
      const custom = renderCell(column, value, row);
      if (custom !== undefined) return custom;
    }

    switch (column.type) {
      case 'image':
        return (
          <img
            src={(value as string) || column.fallback || ''}
            alt=""
            className={cn(
              column.rounded && 'rounded-full',
              'object-cover'
            )}
            style={{
              width: column.width || 40,
              height: column.height || 40,
            }}
          />
        );

      case 'badge':
        // Use lowercase lookup since keys are lowercased by camelCase transformation
        const colorClass = column.colors?.[String(value).toLowerCase()] || 'default';
        return (
          <span
            className={cn(
              'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
              getVariantClasses(colorClass)
            )}
          >
            {String(value ?? '')}
          </span>
        );

      case 'boolean':
        return value ? (
          <span className="text-green-600">Yes</span>
        ) : (
          <span className="text-muted-foreground">No</span>
        );

      case 'numeric':
        const num = Number(value) || 0;
        let formatted = column.decimals !== null
          ? num.toFixed(column.decimals)
          : String(num);
        if (column.thousandsSeparator) {
          formatted = formatted.replace(/\B(?=(\d{3})+(?!\d))/g, column.thousandsSeparator);
        }
        return (
          <span>
            {column.prefix}
            {formatted}
            {column.suffix}
          </span>
        );

      case 'date':
      case 'datetime':
        if (!value) return null;
        const date = new Date(value as string);
        return (
          <span>
            {date.toLocaleDateString(undefined, {
              year: 'numeric',
              month: 'short',
              day: 'numeric',
              ...(column.type === 'datetime' && {
                hour: '2-digit',
                minute: '2-digit',
              }),
            })}
          </span>
        );

      case 'action':
        return (
          <div className="flex items-center justify-end gap-2">
            {resource.actions.map((action) => {
              // Check per-row action state for hidden/disabled
              const rowActionState = row.actions?.[action.name];
              if (rowActionState?.hidden) return null;

              if (renderAction) {
                return renderAction(action, row);
              }
              return (
                <button
                  key={action.name}
                  onClick={(e) => {
                    e.stopPropagation();
                    handleAction(action, row);
                  }}
                  disabled={rowActionState?.disabled}
                  className={cn(
                    'inline-flex items-center gap-1 rounded px-2 py-1 text-xs',
                    getActionClasses(action.variant),
                    rowActionState?.disabled && 'opacity-50 cursor-not-allowed'
                  )}
                  title={action.label ?? action.name}
                >
                  {action.label ?? action.name}
                </button>
              );
            })}
          </div>
        );

      default:
        return <span className={cn(column.truncate && 'truncate block max-w-xs')}>{String(value ?? '')}</span>;
    }
  };

  const hasFilters = resource.filters && resource.filters.length > 0;
  const showDefaultHeader = resource.searchable.length > 0 || resource.bulkActions.length > 0 || hasFilters;

  return (
    <div className={cn('space-y-4', className)}>
      {/* Header with search, filters, and bulk actions */}
      {header}
      {!header && showDefaultHeader && (
        <div className="space-y-3">
          {/* Top row: Search and bulk actions */}
          {(resource.searchable.length > 0 || (selectedCount > 0 && resource.bulkActions.length > 0)) && (
            <div className="flex items-center justify-between gap-4">
              {resource.searchable.length > 0 && (
                <form onSubmit={handleSearch} className="flex-1 max-w-sm">
                  <SearchInput
                    value={search}
                    onChange={handleSearchChange}
                    placeholder={resource.searchPlaceholder || 'Search...'}
                  />
                </form>
              )}

              {selectedCount > 0 && resource.bulkActions.length > 0 && (
                <div className="flex items-center gap-2">
                  <span className="text-sm text-muted-foreground">
                    {selectedCount} selected
                  </span>
                  {resource.bulkActions.map((action) => (
                    <button
                      key={action.name}
                      onClick={() => handleBulkAction(action)}
                      className={cn(
                        'inline-flex items-center gap-1 rounded px-3 py-1.5 text-sm',
                        getActionClasses(action.variant)
                      )}
                    >
                      {action.label ?? action.name}
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Filter bar */}
          {hasFilters && (
            <FilterBar
              filters={resource.filters}
              activeFilters={resource.state.filters || []}
              onFilterChange={handleFilterChange}
              onFilterRemove={handleFilterRemove}
              onClearFilters={handleClearFilters}
            />
          )}
        </div>
      )}

      {/* Table */}
      <div className="rounded-lg border border-border bg-card overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border">
              {/* Selection checkbox */}
              {resource.bulkActions.length > 0 && (
                <th className="w-10 px-4 py-3">
                  <input
                    type="checkbox"
                    checked={selectionMode === 'all'}
                    onChange={handleSelectAll}
                    className="rounded border-border"
                  />
                </th>
              )}

              {/* Column headers */}
              {visibleColumns.map((column) => (
                <th
                  key={column.key}
                  className={cn(
                    'px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground',
                    column.alignment === 'center' && 'text-center',
                    column.alignment === 'right' && 'text-right',
                    column.headerClass
                  )}
                >
                  {column.sortable ? (
                    <button
                      onClick={() => handleSort(column.key)}
                      className="inline-flex items-center gap-1 hover:text-foreground"
                    >
                      {column.label ?? column.key}
                      <SortIcon
                        direction={
                          resource.state.sort?.field === column.key
                            ? resource.state.sort.direction
                            : null
                        }
                      />
                    </button>
                  ) : (
                    column.label ?? column.key
                  )}
                </th>
              ))}
            </tr>
          </thead>

          <tbody>
            {resource.data.length > 0 ? (
              resource.data.map((row, index) => (
                <tr
                  key={(row as Record<string, unknown>).id as string | number ?? index}
                  className={cn(
                    'transition-colors hover:bg-accent/50',
                    index !== resource.data.length - 1 && 'border-b border-border',
                    onRowClick && 'cursor-pointer',
                    isRowSelected(row) && 'bg-accent/30',
                    getRowClassName(row)
                  )}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                >
                  {/* Selection checkbox */}
                  {resource.bulkActions.length > 0 && (
                    <td className="px-4 py-3">
                      <input
                        type="checkbox"
                        checked={isRowSelected(row)}
                        onChange={() => handleSelectRow((row as Record<string, unknown>).id as string | number)}
                        onClick={(e) => e.stopPropagation()}
                        className="rounded border-border"
                      />
                    </td>
                  )}

                  {/* Row cells */}
                  {renderRow ? (
                    renderRow(row, visibleColumns)
                  ) : (
                    visibleColumns.map((column) => (
                      <td
                        key={column.key}
                        className={cn(
                          'px-4 py-3',
                          column.alignment === 'center' && 'text-center',
                          column.alignment === 'right' && 'text-right',
                          column.cellClass
                        )}
                      >
                        {defaultRenderCell(column, (row as Record<string, unknown>)[column.key], row)}
                      </td>
                    ))
                  )}
                </tr>
              ))
            ) : (
              <tr>
                <td
                  colSpan={visibleColumns.length + (resource.bulkActions.length > 0 ? 1 : 0)}
                  className="px-4 py-12 text-center"
                >
                  {resource.emptyState ? (
                    <div className="flex flex-col items-center gap-2">
                      <p className="text-lg font-medium">{resource.emptyState.title}</p>
                      {resource.emptyState.message && (
                        <p className="text-sm text-muted-foreground">
                          {resource.emptyState.message}
                        </p>
                      )}
                      {resource.emptyState.action && (
                        <a
                          href={resource.emptyState.action.href}
                          className="mt-2 inline-flex items-center rounded bg-primary px-3 py-1.5 text-sm text-primary-foreground"
                        >
                          {resource.emptyState.action.label}
                        </a>
                      )}
                    </div>
                  ) : (
                    <p className="text-sm text-muted-foreground">No results found.</p>
                  )}
                </td>
              </tr>
            )}
          </tbody>
        </table>

        {/* Pagination */}
        {resource.meta.totalPages && resource.meta.totalPages > 1 && (
          <div className="border-t border-border px-4 py-3 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">
                {resource.meta.totalCount} total
              </span>
              <select
                value={resource.state.perPage}
                onChange={(e) => handlePerPageChange(Number(e.target.value))}
                className="h-8 rounded border border-border bg-background px-2 text-sm"
              >
                {resource.perPageOptions.map((opt) => (
                  <option key={opt} value={opt}>
                    {opt} per page
                  </option>
                ))}
              </select>
            </div>
            <Pagination
              meta={{
                currentPage: resource.meta.currentPage,
                totalPages: resource.meta.totalPages,
                previousPage: resource.meta.previousPage,
                nextPage: resource.meta.nextPage,
                hasPreviousPage: resource.meta.hasPreviousPage,
                hasNextPage: resource.meta.hasNextPage,
                pageSize: resource.meta.pageSize,
                totalCount: resource.meta.totalCount,
                currentOffset: null,
                previousOffset: null,
                nextOffset: null,
                startCursor: null,
                endCursor: null,
                flop: resource.meta.flop ?? { filters: [], orderBy: null, orderDirections: null, page: null, pageSize: null },
              }}
              onPageChange={handlePageChange}
              className="flex items-center gap-1"
            />
          </div>
        )}
      </div>

      {footer}
    </div>
  );
}

// Helper functions
function getCSRFToken(): string {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta?.getAttribute('content') || '';
}

function getVariantClasses(variant: string): string {
  const variants: Record<string, string> = {
    default: 'bg-muted text-muted-foreground',
    primary: 'bg-primary/10 text-primary',
    success: 'bg-green-100 text-green-700 dark:bg-green-900/20 dark:text-green-400',
    warning: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/20 dark:text-yellow-400',
    danger: 'bg-red-100 text-red-700 dark:bg-red-900/20 dark:text-red-400',
  };
  return variants[variant] || variants.default;
}

function getActionClasses(variant: string): string {
  const variants: Record<string, string> = {
    default: 'bg-muted text-muted-foreground hover:bg-muted/80',
    primary: 'bg-primary text-primary-foreground hover:bg-primary/90',
    success: 'bg-green-600 text-white hover:bg-green-700',
    warning: 'bg-yellow-600 text-white hover:bg-yellow-700',
    danger: 'bg-red-600 text-white hover:bg-red-700',
  };
  return variants[variant] || variants.default;
}

function SortIcon({ direction }: { direction: 'asc' | 'desc' | null }) {
  if (direction === 'asc') {
    return (
      <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
      </svg>
    );
  }
  if (direction === 'desc') {
    return (
      <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
      </svg>
    );
  }
  return (
    <svg className="h-4 w-4 opacity-30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
    </svg>
  );
}

export default Table;
