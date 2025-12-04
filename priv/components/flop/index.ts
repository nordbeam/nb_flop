/**
 * NbFlop React Components
 *
 * Export all Flop components and hooks for pagination, sorting, and filtering.
 */

// Types
export type {
  FlopOperator,
  FlopFilter,
  FlopParams,
  FilterableField,
  FlopMeta,
  PaginationMode,
  SortDirection,
  OrderDirection,
  PaginationProps,
  CursorPaginationProps,
  SortableHeaderProps,
  FilterFormProps,
  FilterFormRenderProps,
  // Linear-style filter types
  FilterFieldType,
  FilterOption,
  FilterConfig,
  FilterMode,
  ActiveFilter,
  FilterBarProps,
  FilterChipProps,
  AddFilterButtonProps,
  FilterValueSelectProps,
  FilterValueInputProps,
  FilterModeToggleProps,
  // TanStack Table types
  SortableColumnHeaderProps,
} from './types';

// Hook
export { useFlopParams, flopToQueryParams } from './useFlopParams';
export type {
  UseFlopParamsOptions,
  UseFlopParamsReturn,
  FlopToQueryParamsOptions,
} from './useFlopParams';

// Components
export { Pagination } from './Pagination';
export { CursorPagination } from './CursorPagination';
export { SortableHeader } from './SortableHeader';
export { FilterForm } from './FilterForm';

// Linear-style filter components
export { FilterBar } from './FilterBar';
export { FilterChip } from './FilterChip';
export { AddFilterButton } from './AddFilterButton';
export { FilterValueSelect } from './FilterValueSelect';
export { FilterValueInput } from './FilterValueInput';
export { FilterModeToggle } from './FilterModeToggle';

// Filter utilities (legacy)
export {
  OPERATOR_LABELS,
  getOperatorLabel,
  getDefaultOperator,
  getOperatorsForType,
  formatFilterValue,
} from './filterOperators';

// Filter utilities (DSL-based)
export {
  clauseToFlopOp,
  flopOpToClause,
  transformFilterValue,
  getClauseLabel,
  getInputTypeForFilterType,
  clauseRequiresValue,
  formatFilterValue as formatDslFilterValue,
} from './filterUtils';

// TanStack Table components
export { DataTable, DataTableContext, useDataTableContext } from './DataTable';
export type { DataTableProps, DataTableContextValue, ColumnDef } from './DataTable';
export { SortableColumnHeader } from './SortableColumnHeader';

// Table Resource component and types
export { Table } from './Table';
export type { TableProps } from './Table';
export type {
  TableResource,
  TableColumn,
  TableAction,
  TableBulkAction,
  TableFilter,
  TableMeta,
  TableState,
  TableEmptyState,
  TableExport,
  TableViews,
  Selection,
} from './tableTypes';
