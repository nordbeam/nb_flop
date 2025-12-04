/**
 * NbFlop FilterForm Component
 *
 * A container component for filter inputs. Users build their own
 * filter inputs using the render prop - this just provides structure.
 *
 * @example
 * ```tsx
 * <FilterForm
 *   filterableFields={meta.filterableFields}
 *   filters={flop.params.filters ?? []}
 *   onFilterChange={(field, op, value) => flop.setFilter(field, op, value)}
 *   onFilterRemove={(field, op) => flop.removeFilter(field, op)}
 *   onClearFilters={() => flop.clearFilters()}
 * >
 *   {({ fields, activeFilters, setFilter, removeFilter, clearFilters }) => (
 *     <>
 *       <input
 *         type="text"
 *         placeholder="Search..."
 *         onChange={(e) => setFilter('title', 'ilike', `%${e.target.value}%`)}
 *       />
 *
 *       <select onChange={(e) => setFilter('status', '==', e.target.value)}>
 *         <option value="">All</option>
 *         <option value="published">Published</option>
 *         <option value="draft">Draft</option>
 *       </select>
 *
 *       {activeFilters.length > 0 && (
 *         <button onClick={clearFilters}>Clear all</button>
 *       )}
 *     </>
 *   )}
 * </FilterForm>
 * ```
 */

import React from 'react';
import type { FilterFormProps, FilterFormRenderProps } from './types';

export function FilterForm({
  filterableFields = [],
  filters = [],
  onFilterChange,
  onFilterRemove,
  onClearFilters,
  className = '',
  children,
}: FilterFormProps) {
  const renderProps: FilterFormRenderProps = {
    fields: filterableFields,
    activeFilters: filters,
    setFilter: onFilterChange,
    removeFilter: onFilterRemove,
    clearFilters: onClearFilters,
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
  };

  return (
    <form
      onSubmit={handleSubmit}
      className={`flop-filter-form ${className}`}
      role="search"
    >
      {children ? children(renderProps) : null}
    </form>
  );
}

export default FilterForm;
