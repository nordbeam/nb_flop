/**
 * NbFlop SortableHeader Component
 *
 * A table header component that enables sorting.
 * Unstyled - use CSS classes for styling.
 *
 * @example
 * ```tsx
 * <table>
 *   <thead>
 *     <tr>
 *       <SortableHeader
 *         field="title"
 *         currentSort={flop.params.orderBy?.[0]}
 *         currentDirection={flop.getSortDirection('title')}
 *         onSort={(field, direction) => flop.setSort(field, direction)}
 *       >
 *         Title
 *       </SortableHeader>
 *     </tr>
 *   </thead>
 * </table>
 * ```
 */

import type { SortableHeaderProps, SortDirection } from './types';

export function SortableHeader({
  field,
  children,
  currentSort,
  currentDirection,
  onSort,
  className = '',
  ascIcon = '↑',
  descIcon = '↓',
  unsortedIcon = '↕',
}: SortableHeaderProps) {
  const isActive = currentSort === field;
  const direction = isActive ? currentDirection : null;

  const handleClick = () => {
    let newDirection: SortDirection;

    if (!isActive) {
      newDirection = 'asc';
    } else if (direction === 'asc') {
      newDirection = 'desc';
    } else {
      newDirection = null;
    }

    onSort(field, newDirection);
  };

  const getIcon = () => {
    if (!isActive) return unsortedIcon;
    if (direction === 'asc') return ascIcon;
    if (direction === 'desc') return descIcon;
    return unsortedIcon;
  };

  return (
    <th
      className={`flop-sortable-header ${
        isActive ? 'flop-sortable-header-active' : ''
      } ${className}`}
    >
      <button
        type="button"
        onClick={handleClick}
        className="flop-sortable-header-button"
        aria-sort={
          isActive && direction === 'asc'
            ? 'ascending'
            : isActive && direction === 'desc'
              ? 'descending'
              : 'none'
        }
      >
        <span className="flop-sortable-header-label">{children}</span>
        <span className="flop-sortable-header-icon" aria-hidden="true">
          {getIcon()}
        </span>
      </button>
    </th>
  );
}

export default SortableHeader;
