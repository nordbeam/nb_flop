/**
 * NbFlop Table Resource Types
 *
 * Types for the Table DSL resource structure returned by `Table.make/3`.
 * These types match the serializers in nb_flop/lib/nb_flop/serializers/.
 */

// Re-export flop types for convenience
export type { FlopOperator, FlopFilter, SortDirection } from './types';

// Filter types matching nb_flop DSL
export type FilterType = 'text' | 'numeric' | 'set' | 'date' | 'datetime' | 'boolean';

// Filter clauses matching nb_flop DSL
export type FilterClause =
  | 'equals'
  | 'not_equals'
  | 'contains'
  | 'starts_with'
  | 'ends_with'
  | 'gt'
  | 'gte'
  | 'lt'
  | 'lte'
  | 'between'
  | 'in'
  | 'not_in'
  | 'empty'
  | 'not_empty';

// Color variants for filter options (badges)
export type FilterColorVariant = 'default' | 'primary' | 'success' | 'warning' | 'danger' | 'muted';

// Filter option for set filters
export interface TableFilterOption {
  value: string;
  label: string;
}

// Filter definition (matches nb_flop Filter struct + UI hints)
export interface TableFilter {
  field: string;
  type: FilterType;
  label: string | null;
  clauses: FilterClause[];
  defaultClause: FilterClause;
  nullable: boolean;
  min: unknown | null;
  max: unknown | null;
  options: TableFilterOption[];
  // UI hints from DSL
  icon: string | null;
  placeholder: string | null;
  colors: Record<string, FilterColorVariant> | null;
}

// Flop filter (active filter)
export interface TableFlopFilter {
  field: string;
  op: string;
  value: unknown;
}

// Sort state
export interface TableSortState {
  field: string;
  direction: 'asc' | 'desc';
}

// Table state (current sort, filters, page, etc.)
export interface TableState {
  page: number;
  perPage: number;
  search: string | null;
  columns: string[];
  sort: TableSortState | null;
  filters: TableFlopFilter[];
}

// Flop params in meta
export interface TableFlop {
  orderBy: string[] | null;
  orderDirections: string[] | null;
  page: number | null;
  pageSize: number | null;
  filters: TableFlopFilter[];
}

// Pagination metadata
export interface TableMeta {
  currentPage: number | null;
  totalPages: number | null;
  totalCount: number | null;
  pageSize: number | null;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
  nextPage: number | null;
  previousPage: number | null;
  startCursor: string | null;
  endCursor: string | null;
  flop: TableFlop | null;
}

// Column definition
export interface TableColumn {
  key: string;
  type: 'text' | 'badge' | 'numeric' | 'date' | 'datetime' | 'boolean' | 'image' | 'action';
  label: string | null;
  sortable: boolean;
  searchable: boolean;
  toggleable: boolean;
  visible: boolean;
  stickable: boolean;
  alignment: 'left' | 'center' | 'right';
  wrap: boolean;
  truncate: boolean;
  headerClass: string | null;
  cellClass: string | null;
  // Type-specific options
  colors: Record<string, string> | null;
  prefix: string | null;
  suffix: string | null;
  decimals: number | null;
  thousandsSeparator: string | null;
  format: string | null;
  width: number | null;
  height: number | null;
  rounded: boolean | null;
  fallback: string | null;
}

// Confirmation dialog
export interface TableConfirmation {
  title: string;
  message: string;
  confirmButton: string | null;
  cancelButton: string | null;
  variant: string;
  icon: string | null;
}

// Row action definition
export interface TableAction {
  name: string;
  label: string | null;
  variant: 'default' | 'primary' | 'danger' | 'success' | 'warning';
  icon: string | null;
  frontend: boolean;
  confirmation: TableConfirmation | null;
}

// Bulk action definition
export interface TableBulkAction {
  name: string;
  label: string | null;
  variant: 'default' | 'primary' | 'danger' | 'success' | 'warning';
  icon: string | null;
  frontend: boolean;
  confirmation: TableConfirmation | null;
}

// Export definition
export interface TableExport {
  name: string;
  label: string | null;
  format: 'csv' | 'excel' | 'pdf';
}

// Empty state configuration
export interface TableEmptyState {
  title: string;
  message: string | null;
  icon: string | null;
  action: {
    label: string;
    href: string;
  } | null;
}

// Saved view
export interface TableView {
  id: string | number;
  name: string;
  isPublic: boolean;
  isDefault: boolean;
  filters: Record<string, unknown>;
  sort: Record<string, unknown>;
  columns: string[];
  perPage: number | null;
}

// Views configuration
export interface TableViews {
  enabled: boolean;
  list: TableView[];
  current: TableView | null;
}

// Main table resource
export interface TableResource<T = Record<string, unknown>> {
  name: string;
  token: string | null;
  data: T[];
  perPageOptions: number[];
  stickyHeader: boolean;
  searchable: string[];
  searchPlaceholder: string | null;
  error: unknown | null;
  meta: TableMeta;
  state: TableState;
  emptyState: TableEmptyState | null;
  views: TableViews;
  columns: TableColumn[];
  filters: TableFilter[];
  actions: TableAction[];
  bulkActions: TableBulkAction[];
  exports: TableExport[];
}

// Selection state for bulk actions
export type SelectionMode = 'explicit' | 'all' | 'all_except';

export interface Selection {
  mode: SelectionMode;
  ids: (string | number)[];
}

// Action execution params
export interface ActionParams {
  token: string;
  action: string;
  id: string | number;
}

export interface BulkActionParams {
  token: string;
  action: string;
  selection: Selection;
  filters?: TableFlopFilter[];
}
