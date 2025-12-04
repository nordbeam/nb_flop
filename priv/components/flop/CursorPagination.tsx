/**
 * NbFlop Cursor Pagination Component
 *
 * A pagination component for cursor-based pagination with Flop.
 * Does not show page numbers (not available in cursor pagination).
 *
 * @example
 * ```tsx
 * <CursorPagination
 *   meta={meta}
 *   onNext={() => flop.goToNextCursor()}
 *   onPrevious={() => flop.goToPreviousCursor()}
 * />
 * ```
 */

import type { CursorPaginationProps } from './types';

export function CursorPagination({
  meta,
  onNext,
  onPrevious,
  className = '',
  loadingNext = false,
  loadingPrevious = false,
  labels = {},
}: CursorPaginationProps) {
  const {
    previous = 'Previous',
    next = 'Next',
    loadingPrevious: loadingPrevLabel = 'Loading...',
    loadingNext: loadingNextLabel = 'Loading...',
  } = labels;

  return (
    <nav
      className={`flop-cursor-pagination ${className}`}
      aria-label="Pagination"
      role="navigation"
    >
      {/* Previous Button */}
      <button
        type="button"
        onClick={onPrevious}
        disabled={!meta.hasPreviousPage || loadingPrevious}
        aria-label={previous}
        className="flop-cursor-pagination-prev"
      >
        {loadingPrevious ? loadingPrevLabel : previous}
      </button>

      {/* Next Button */}
      <button
        type="button"
        onClick={onNext}
        disabled={!meta.hasNextPage || loadingNext}
        aria-label={next}
        className="flop-cursor-pagination-next"
      >
        {loadingNext ? loadingNextLabel : next}
      </button>
    </nav>
  );
}

export default CursorPagination;
