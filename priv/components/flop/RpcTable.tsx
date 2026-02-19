/**
 * RpcTable — Convenience wrapper combining useRpcTable with Table.
 *
 * Usage:
 * ```tsx
 * import { RpcTable } from '@/components/flop';
 *
 * function UsersPage() {
 *   return (
 *     <RpcTable
 *       queryOptions={(params) => rpc.users.table.queryOptions(params)}
 *       actionMutation={() => rpc.users.tableAction.mutationOptions()}
 *       bulkActionMutation={() => rpc.users.tableBulkAction.mutationOptions()}
 *     />
 *   );
 * }
 * ```
 */

import * as React from 'react';
import type { UseQueryOptions, UseMutationOptions } from '@tanstack/react-query';
import type { TableResource } from './tableTypes';
import { Table, type TableProps, type ActionResult } from './Table';
import {
  useRpcTable,
  type RpcTableParams,
  type UseRpcTableOptions,
} from './useRpcTable';

export interface RpcTableProps<T = Record<string, unknown>>
  extends Omit<TableProps<T>, 'resource' | 'onNavigate' | 'onAction' | 'onBulkAction' | 'onRefresh'> {
  /** Query options factory — receives Flop params, returns TanStack Query options. */
  queryOptions: (params: RpcTableParams) => UseQueryOptions<TableResource<T>>;
  /** Mutation options factory for row actions. */
  actionMutation?: UseRpcTableOptions['actionMutation'];
  /** Mutation options factory for bulk actions. */
  bulkActionMutation?: UseRpcTableOptions['bulkActionMutation'];
  /** Loading placeholder (shown during initial load). */
  loading?: React.ReactNode;
  /** Error renderer. */
  renderError?: (error: Error) => React.ReactNode;
}

export function RpcTable<T extends Record<string, unknown> = Record<string, unknown>>({
  queryOptions,
  actionMutation,
  bulkActionMutation,
  loading,
  renderError,
  ...tableProps
}: RpcTableProps<T>) {
  const table = useRpcTable<T>(queryOptions, {
    actionMutation,
    bulkActionMutation,
  });

  if (table.isLoading || !table.resource) {
    return (loading as React.ReactElement) ?? (
      <div className="flex items-center justify-center py-12">
        <div className="text-sm text-muted-foreground">Loading...</div>
      </div>
    );
  }

  if (table.error) {
    return renderError ? (
      renderError(table.error) as React.ReactElement
    ) : (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4">
        <p className="text-sm text-red-600">
          Failed to load table: {table.error.message}
        </p>
      </div>
    );
  }

  return (
    <Table<T>
      resource={table.resource}
      {...table.tableProps}
      {...tableProps}
    />
  );
}

export default RpcTable;
