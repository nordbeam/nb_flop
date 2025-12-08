/**
 * NbFlop useFlopParams Hook
 *
 * A UI-agnostic hook for managing Flop pagination, sorting, and filtering state.
 * Works with both nb_routes and plain URL handling.
 *
 * @example Basic usage with Inertia
 * ```tsx
 * import { useFlopParams, flopToQueryParams } from '@/components/flop';
 * import { router } from '@/lib/inertia';
 * import { posts_path } from '@/routes';
 *
 * function PostsIndex({ posts, meta }: PostsIndexProps) {
 *   const flop = useFlopParams(meta, {
 *     onParamsChange: (params) => {
 *       router.visit(posts_path({ query: flopToQueryParams(params) }), {
 *         preserveState: true,
 *         preserveScroll: true,
 *       });
 *     },
 *   });
 *
 *   return (
 *     <div>
 *       <Pagination meta={meta} onPageChange={flop.setPage} />
 *     </div>
 *   );
 * }
 * ```
 */

import { useState, useCallback, useMemo } from 'react';
import type {
  FlopParams,
  FlopMeta,
  FlopOperator,
  SortDirection,
  PaginationMode,
} from './types';

export interface UseFlopParamsOptions {
  /**
   * Callback when params change - use to navigate or fetch data
   */
  onParamsChange?: (params: FlopParams) => void;

  /**
   * Initial params to use (merged with meta.flop)
   */
  initialParams?: Partial<FlopParams>;
}

export interface UseFlopParamsReturn {
  // State
  params: FlopParams;
  meta: FlopMeta | null;
  paginationMode: PaginationMode;

  // Sorting
  setSort: (field: string, direction?: SortDirection) => void;
  toggleSort: (field: string) => void;
  clearSort: () => void;
  getSortDirection: (field: string) => SortDirection;

  // Filtering
  setFilter: (field: string, op: FlopOperator, value: unknown) => void;
  removeFilter: (field: string, op?: FlopOperator) => void;
  clearFilters: () => void;
  getFilterValue: (field: string, op?: FlopOperator) => unknown;

  // Page-based pagination
  setPage: (page: number) => void;
  nextPage: () => void;
  previousPage: () => void;
  setPageSize: (size: number) => void;

  // Offset-based pagination
  setOffset: (offset: number) => void;

  // Cursor-based pagination
  goToNextCursor: () => void;
  goToPreviousCursor: () => void;

  // General
  setParams: (params: Partial<FlopParams>) => void;
  resetParams: () => void;
}

/**
 * Detect pagination mode from meta
 */
function detectPaginationMode(meta: FlopMeta | null): PaginationMode {
  if (!meta) return 'page';
  if (meta.startCursor !== null || meta.endCursor !== null) return 'cursor';
  if (meta.currentOffset !== null) return 'offset';
  return 'page';
}

export interface FlopToQueryParamsOptions {
  paginationType?: 'page' | 'offset' | 'cursor';
  /** Skip ordering params - let backend use defaults (default: false) */
  skipDefaultOrdering?: boolean;
  /** Skip page=1 since it's the default (default: true) */
  skipFirstPage?: boolean;
  /** Skip page_size if it matches this value (default: undefined = always skip) */
  defaultPageSize?: number;
}

/**
 * Convert FlopParams to URL query params format
 *
 * By default, includes ordering params when set, and skips defaults:
 * - Includes ordering when set (for sorting to work)
 * - Skips page=1 (first page is default)
 * - Skips page_size (backend has default)
 * - Always includes filters
 */
export function flopToQueryParams(
  params: FlopParams,
  options: FlopToQueryParamsOptions = {}
): Record<string, string | string[]> {
  const {
    paginationType = 'page',
    skipDefaultOrdering = false,
    skipFirstPage = true,
    defaultPageSize,
  } = options;

  const query: Record<string, string | string[]> = {};

  // Ordering - use empty bracket notation for arrays so Phoenix parses them as lists
  if (!skipDefaultOrdering && params.orderBy?.length) {
    params.orderBy.forEach((field) => {
      const key = 'order_by[]';
      if (query[key]) {
        (query[key] as string[]).push(field);
      } else {
        query[key] = [field];
      }
    });
  }
  if (!skipDefaultOrdering && params.orderDirections?.length) {
    params.orderDirections.forEach((dir) => {
      const key = 'order_directions[]';
      if (query[key]) {
        (query[key] as string[]).push(dir);
      } else {
        query[key] = [dir];
      }
    });
  }

  // Pagination - only include params for the specified type
  if (paginationType === 'page') {
    // Skip page=1 since it's the default
    if (params.page != null && !(skipFirstPage && params.page === 1)) {
      query['page'] = String(params.page);
    }
    // Skip page_size if defaultPageSize is undefined (always skip) or matches the default
    // Only include if defaultPageSize is specified AND current value differs
    if (defaultPageSize !== undefined && params.pageSize != null && params.pageSize !== defaultPageSize) {
      query['page_size'] = String(params.pageSize);
    }
  } else if (paginationType === 'offset') {
    if (params.offset != null && params.offset !== 0) {
      query['offset'] = String(params.offset);
    }
    if (params.limit != null) query['limit'] = String(params.limit);
  } else if (paginationType === 'cursor') {
    if (params.first != null) query['first'] = String(params.first);
    if (params.last != null) query['last'] = String(params.last);
    if (params.after != null) query['after'] = params.after;
    if (params.before != null) query['before'] = params.before;
  }

  // Filters - always include (these are user-specified)
  if (params.filters?.length) {
    params.filters.forEach((filter, index) => {
      query[`filters[${index}][field]`] = filter.field;
      query[`filters[${index}][op]`] = filter.op;
      // Handle array values for operators like 'in' - use bracket notation
      if (Array.isArray(filter.value)) {
        query[`filters[${index}][value][]`] = filter.value.map(String);
      } else {
        query[`filters[${index}][value]`] = String(filter.value);
      }
    });
  }

  return query;
}

/**
 * useFlopParams - Hook for managing Flop state
 */
export function useFlopParams(
  meta: FlopMeta | null,
  options: UseFlopParamsOptions = {}
): UseFlopParamsReturn {
  const { onParamsChange, initialParams = {} } = options;

  // Initialize params from meta.flop and initialParams
  const [params, setParamsState] = useState<FlopParams>(() => ({
    ...meta?.flop,
    ...initialParams,
  }));

  // Memoized pagination mode
  const paginationMode = useMemo(() => detectPaginationMode(meta), [meta]);

  // Helper to update params and trigger callback
  const updateParams = useCallback(
    (updater: (prev: FlopParams) => FlopParams) => {
      setParamsState((prev) => {
        const next = updater(prev);
        onParamsChange?.(next);
        return next;
      });
    },
    [onParamsChange]
  );

  // --- Sorting Actions ---

  const setSort = useCallback(
    (field: string, direction: SortDirection = 'asc') => {
      updateParams((prev) => ({
        ...prev,
        orderBy: direction ? [field] : null,
        orderDirections: direction ? [direction] : null,
        // Reset to first page when sorting changes
        page: paginationMode === 'page' ? 1 : prev.page,
        offset: paginationMode === 'offset' ? 0 : prev.offset,
        after: null,
        before: null,
      }));
    },
    [updateParams, paginationMode]
  );

  const toggleSort = useCallback(
    (field: string) => {
      const currentField = params.orderBy?.[0];
      const currentDirection = params.orderDirections?.[0];

      let newDirection: SortDirection;
      if (currentField !== field) {
        newDirection = 'asc';
      } else if (currentDirection === 'asc') {
        newDirection = 'desc';
      } else {
        newDirection = null;
      }

      setSort(field, newDirection);
    },
    [params.orderBy, params.orderDirections, setSort]
  );

  const clearSort = useCallback(() => {
    updateParams((prev) => ({
      ...prev,
      orderBy: null,
      orderDirections: null,
    }));
  }, [updateParams]);

  const getSortDirection = useCallback(
    (field: string): SortDirection => {
      const index = params.orderBy?.indexOf(field) ?? -1;
      if (index === -1) return null;
      const dir = params.orderDirections?.[index];
      // Normalize extended directions to simple asc/desc
      if (dir?.startsWith('asc')) return 'asc';
      if (dir?.startsWith('desc')) return 'desc';
      return null;
    },
    [params.orderBy, params.orderDirections]
  );

  // --- Filtering Actions ---

  const setFilter = useCallback(
    (field: string, op: FlopOperator, value: unknown) => {
      updateParams((prev) => {
        const filters =
          prev.filters?.filter((f) => !(f.field === field && f.op === op)) ??
          [];

        return {
          ...prev,
          filters: [...filters, { field, op, value }],
          // Reset pagination when filters change
          page: paginationMode === 'page' ? 1 : prev.page,
          offset: paginationMode === 'offset' ? 0 : prev.offset,
          after: null,
          before: null,
        };
      });
    },
    [updateParams, paginationMode]
  );

  const removeFilter = useCallback(
    (field: string, op?: FlopOperator) => {
      updateParams((prev) => ({
        ...prev,
        filters: prev.filters?.filter(
          (f) => f.field !== field || (op !== undefined && f.op !== op)
        ),
        // Reset pagination when filters change
        page: paginationMode === 'page' ? 1 : prev.page,
        offset: paginationMode === 'offset' ? 0 : prev.offset,
        after: null,
        before: null,
      }));
    },
    [updateParams, paginationMode]
  );

  const clearFilters = useCallback(() => {
    updateParams((prev) => ({
      ...prev,
      filters: [],
      page: paginationMode === 'page' ? 1 : prev.page,
      offset: paginationMode === 'offset' ? 0 : prev.offset,
      after: null,
      before: null,
    }));
  }, [updateParams, paginationMode]);

  const getFilterValue = useCallback(
    (field: string, op?: FlopOperator): unknown => {
      const filter = params.filters?.find(
        (f) => f.field === field && (op === undefined || f.op === op)
      );
      return filter?.value;
    },
    [params.filters]
  );

  // --- Page-based Pagination Actions ---

  const setPage = useCallback(
    (page: number) => {
      updateParams((prev) => ({ ...prev, page }));
    },
    [updateParams]
  );

  const nextPage = useCallback(() => {
    if (meta?.hasNextPage && meta.nextPage) {
      setPage(meta.nextPage);
    }
  }, [meta, setPage]);

  const previousPage = useCallback(() => {
    if (meta?.hasPreviousPage && meta.previousPage) {
      setPage(meta.previousPage);
    }
  }, [meta, setPage]);

  const setPageSize = useCallback(
    (size: number) => {
      updateParams((prev) => ({
        ...prev,
        pageSize: size,
        page: 1, // Reset to first page
      }));
    },
    [updateParams]
  );

  // --- Offset-based Pagination Actions ---

  const setOffset = useCallback(
    (offset: number) => {
      updateParams((prev) => ({ ...prev, offset }));
    },
    [updateParams]
  );

  // --- Cursor-based Pagination Actions ---

  const goToNextCursor = useCallback(() => {
    if (meta?.hasNextPage && meta.endCursor) {
      updateParams((prev) => ({
        ...prev,
        after: meta.endCursor,
        before: null,
      }));
    }
  }, [meta, updateParams]);

  const goToPreviousCursor = useCallback(() => {
    if (meta?.hasPreviousPage && meta.startCursor) {
      updateParams((prev) => ({
        ...prev,
        before: meta.startCursor,
        after: null,
      }));
    }
  }, [meta, updateParams]);

  // --- General Actions ---

  const setParams = useCallback(
    (newParams: Partial<FlopParams>) => {
      updateParams((prev) => ({ ...prev, ...newParams }));
    },
    [updateParams]
  );

  const resetParams = useCallback(() => {
    updateParams(() => ({ ...meta?.flop, ...initialParams }));
  }, [updateParams, meta, initialParams]);

  return {
    // State
    params,
    meta,
    paginationMode,

    // Sorting
    setSort,
    toggleSort,
    clearSort,
    getSortDirection,

    // Filtering
    setFilter,
    removeFilter,
    clearFilters,
    getFilterValue,

    // Page-based pagination
    setPage,
    nextPage,
    previousPage,
    setPageSize,

    // Offset-based pagination
    setOffset,

    // Cursor-based pagination
    goToNextCursor,
    goToPreviousCursor,

    // General
    setParams,
    resetParams,
  };
}

export default useFlopParams;
