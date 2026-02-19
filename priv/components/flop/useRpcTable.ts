/**
 * useRpcTable — Hook for using NbFlop tables with NbRpc.
 *
 * Combines TanStack Query (useQuery/useMutation) with Flop params state
 * management to provide a complete table data layer over RPC.
 *
 * Usage:
 * ```tsx
 * const table = useRpcTable(
 *   (params) => rpc.users.table.queryOptions(params),
 *   {
 *     actionMutation: () => rpc.users.tableAction.mutationOptions(),
 *   }
 * );
 *
 * return <Table resource={table.resource!} {...table.tableProps} />;
 * ```
 */

import { useState, useCallback } from "react";
import {
  useQuery,
  useMutation,
  useQueryClient,
  type UseQueryOptions,
  type UseMutationOptions,
} from "@tanstack/react-query";
import type {
  TableResource,
  TableFlopFilter,
  Selection,
} from "./tableTypes";

// ---- Types ----

/** Input params sent to the RPC table query procedure. */
export interface RpcTableParams {
  page?: number;
  pageSize?: number;
  orderBy?: string[];
  orderDirections?: string[];
  filters?: TableFlopFilter[];
  search?: string;
}

/** Action result returned by the server. */
export interface ActionResult {
  success: boolean;
  message?: string;
  redirect?: string;
  count?: number;
}

/** Options for useRpcTable. */
export interface UseRpcTableOptions {
  /** Mutation options factory for row actions. */
  actionMutation?: () => UseMutationOptions<ActionResult, Error, { action: string; id: string | number }>;
  /** Mutation options factory for bulk actions. */
  bulkActionMutation?: () => UseMutationOptions<ActionResult, Error, { action: string; mode: string; ids?: (string | number)[]; filters?: TableFlopFilter[] }>;
}

/** Return type of useRpcTable. */
export interface UseRpcTableReturn<T = Record<string, unknown>> {
  /** The current table resource (undefined while loading). */
  resource: TableResource<T> | undefined;
  /** Whether the initial load is in progress. */
  isLoading: boolean;
  /** Whether any fetch (including refetch) is in progress. */
  isFetching: boolean;
  /** Query error, if any. */
  error: Error | null;

  // -- Pagination --
  /** Navigate to a specific page. */
  setPage: (page: number) => void;
  /** Change items per page. */
  setPageSize: (size: number) => void;

  // -- Sorting --
  /** Set sort field and direction. */
  setSort: (field: string, direction?: "asc" | "desc") => void;
  /** Toggle sort direction for a field. */
  toggleSort: (field: string) => void;

  // -- Filtering --
  /** Set or update a filter. */
  setFilter: (field: string, op: string, value: unknown) => void;
  /** Remove a filter. */
  removeFilter: (field: string, op?: string) => void;
  /** Clear all filters. */
  clearFilters: () => void;

  // -- Search --
  /** Set the search query. */
  setSearch: (search: string) => void;

  // -- Actions --
  /** Execute a row action. */
  executeAction: (name: string, id: string | number) => Promise<ActionResult>;
  /** Execute a bulk action. */
  executeBulkAction: (name: string, selection: Selection) => Promise<ActionResult>;
  /** Whether an action is currently executing. */
  actionPending: boolean;

  // -- Table component integration --
  /** Props to spread onto the Table component for RPC transport. */
  tableProps: {
    onNavigate: (params: Record<string, string>) => void;
    onAction: (actionName: string, rowId: string | number) => Promise<ActionResult>;
    onBulkAction: (actionName: string, selection: Selection) => Promise<ActionResult>;
    onRefresh: () => void;
  };

  /** Refetch the current data. */
  refetch: () => void;
}

// ---- Hook ----

export function useRpcTable<TRow = Record<string, unknown>>(
  queryOptionsFn: (params: RpcTableParams) => UseQueryOptions<TableResource<TRow>>,
  opts?: UseRpcTableOptions,
): UseRpcTableReturn<TRow> {
  const queryClient = useQueryClient();
  const [params, setParams] = useState<RpcTableParams>({});

  // Build query options from current params
  const queryOptions = queryOptionsFn(params);
  const { data: resource, isLoading, isFetching, error, refetch } = useQuery(queryOptions);

  // -- Pagination --

  const setPage = useCallback((page: number) => {
    setParams((prev) => ({ ...prev, page }));
  }, []);

  const setPageSize = useCallback((pageSize: number) => {
    setParams((prev) => ({ ...prev, pageSize, page: 1 }));
  }, []);

  // -- Sorting --

  const setSort = useCallback((field: string, direction: "asc" | "desc" = "asc") => {
    setParams((prev) => ({
      ...prev,
      orderBy: [field],
      orderDirections: [direction],
      page: 1,
    }));
  }, []);

  const toggleSort = useCallback((field: string) => {
    setParams((prev) => {
      const currentField = prev.orderBy?.[0];
      const currentDir = prev.orderDirections?.[0];

      let newDir: "asc" | "desc";
      if (currentField === field) {
        newDir = currentDir === "asc" ? "desc" : "asc";
      } else {
        newDir = "asc";
      }

      return {
        ...prev,
        orderBy: [field],
        orderDirections: [newDir],
        page: 1,
      };
    });
  }, []);

  // -- Filtering --

  const setFilter = useCallback((field: string, op: string, value: unknown) => {
    setParams((prev) => {
      const existing = prev.filters || [];
      const idx = existing.findIndex((f) => f.field === field && f.op === op);
      const newFilter = { field, op, value };

      const filters =
        idx >= 0
          ? existing.map((f, i) => (i === idx ? newFilter : f))
          : [...existing, newFilter];

      return { ...prev, filters, page: 1 };
    });
  }, []);

  const removeFilter = useCallback((field: string, op?: string) => {
    setParams((prev) => {
      const filters = (prev.filters || []).filter(
        (f) => !(f.field === field && (op === undefined || f.op === op)),
      );
      return { ...prev, filters, page: 1 };
    });
  }, []);

  const clearFilters = useCallback(() => {
    setParams((prev) => ({ ...prev, filters: [], search: undefined, page: 1 }));
  }, []);

  // -- Search --

  const setSearch = useCallback((search: string) => {
    setParams((prev) => ({
      ...prev,
      search: search || undefined,
      page: 1,
    }));
  }, []);

  // -- Actions --

  const actionMutationOpts = opts?.actionMutation?.();
  const actionMutation = useMutation({
    ...actionMutationOpts,
    onSuccess: (data, variables, context) => {
      // Invalidate table query after successful action
      if (queryOptions.queryKey) {
        queryClient.invalidateQueries({ queryKey: [queryOptions.queryKey[0]] });
      }
      actionMutationOpts?.onSuccess?.(data, variables, context);
    },
  });

  const bulkActionMutationOpts = opts?.bulkActionMutation?.();
  const bulkActionMutation = useMutation({
    ...bulkActionMutationOpts,
    onSuccess: (data, variables, context) => {
      if (queryOptions.queryKey) {
        queryClient.invalidateQueries({ queryKey: [queryOptions.queryKey[0]] });
      }
      bulkActionMutationOpts?.onSuccess?.(data, variables, context);
    },
  });

  const executeAction = useCallback(
    async (name: string, id: string | number): Promise<ActionResult> => {
      return actionMutation.mutateAsync({ action: name, id });
    },
    [actionMutation],
  );

  const executeBulkAction = useCallback(
    async (name: string, selection: Selection): Promise<ActionResult> => {
      return bulkActionMutation.mutateAsync({
        action: name,
        mode: selection.mode,
        ids: selection.ids,
        filters: params.filters,
      });
    },
    [bulkActionMutation, params.filters],
  );

  // -- Table component integration --
  // onNavigate receives the query params from the Table component's internal
  // navigation logic and converts them back to RpcTableParams.

  const onNavigate = useCallback((navParams: Record<string, string>) => {
    setParams((prev) => {
      const next: RpcTableParams = { ...prev };

      if (navParams.page) next.page = Number(navParams.page);
      if (navParams.per_page) next.pageSize = Number(navParams.per_page);
      if (navParams.search !== undefined) next.search = navParams.search || undefined;

      if (navParams.sort) {
        const [field, dir] = navParams.sort.split(":");
        next.orderBy = [field];
        next.orderDirections = [(dir as "asc" | "desc") || "asc"];
      }

      return next;
    });
  }, []);

  const onRefresh = useCallback(() => {
    refetch();
  }, [refetch]);

  return {
    resource: resource as TableResource<TRow> | undefined,
    isLoading,
    isFetching,
    error: error as Error | null,
    setPage,
    setPageSize,
    setSort,
    toggleSort,
    setFilter,
    removeFilter,
    clearFilters,
    setSearch,
    executeAction,
    executeBulkAction,
    actionPending: actionMutation.isPending || bulkActionMutation.isPending,
    tableProps: {
      onNavigate,
      onAction: executeAction,
      onBulkAction: executeBulkAction,
      onRefresh,
    },
    refetch: onRefresh,
  };
}
