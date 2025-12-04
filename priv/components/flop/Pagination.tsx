/**
 * NbFlop Pagination Component - Linear-inspired design
 *
 * A compact, clean pagination component for page-based pagination with Flop.
 */

import { ChevronLeft, ChevronRight, MoreHorizontal } from "lucide-react";
import type { PaginationProps } from "./types";
import { cn } from "@/lib/utils";

/**
 * Generate page numbers to display with ellipsis
 */
function getPageNumbers(
  currentPage: number,
  totalPages: number,
  maxVisible: number
): (number | "ellipsis-start" | "ellipsis-end")[] {
  if (totalPages <= maxVisible) {
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }

  const pages: (number | "ellipsis-start" | "ellipsis-end")[] = [];
  const half = Math.floor(maxVisible / 2);

  pages.push(1);

  let start = Math.max(2, currentPage - half);
  let end = Math.min(totalPages - 1, currentPage + half);

  if (currentPage <= half + 1) {
    end = Math.min(totalPages - 1, maxVisible - 1);
  } else if (currentPage >= totalPages - half) {
    start = Math.max(2, totalPages - maxVisible + 2);
  }

  if (start > 2) {
    pages.push("ellipsis-start");
  }

  for (let i = start; i <= end; i++) {
    pages.push(i);
  }

  if (end < totalPages - 1) {
    pages.push("ellipsis-end");
  }

  if (totalPages > 1) {
    pages.push(totalPages);
  }

  return pages;
}

export function Pagination({
  meta,
  onPageChange,
  className = "",
  showPageNumbers = true,
  maxVisiblePages = 7,
  labels = {},
}: PaginationProps) {
  const {
    previous = "Previous",
    next = "Next",
    page = (current, total) => `Page ${current} of ${total}`,
  } = labels;

  const currentPage = meta.currentPage ?? 1;
  const totalPages = meta.totalPages ?? 1;

  const pageNumbers = showPageNumbers
    ? getPageNumbers(currentPage, totalPages, maxVisiblePages)
    : [];

  const buttonBase = cn(
    "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors",
    "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/20",
    "disabled:pointer-events-none disabled:opacity-40"
  );

  const pageButton = cn(
    buttonBase,
    "h-8 min-w-8 px-2",
    "text-muted-foreground hover:text-foreground hover:bg-accent"
  );

  const activePageButton = cn(
    buttonBase,
    "h-8 min-w-8 px-2",
    "bg-primary text-primary-foreground"
  );

  const navButton = cn(
    buttonBase,
    "h-8 px-2 gap-1",
    "text-muted-foreground hover:text-foreground hover:bg-accent"
  );

  return (
    <nav
      className={cn("flex items-center justify-center gap-0.5", className)}
      aria-label="Pagination"
      role="navigation"
    >
      {/* Previous Button */}
      <button
        type="button"
        onClick={() => meta.previousPage && onPageChange(meta.previousPage)}
        disabled={!meta.hasPreviousPage}
        aria-label={previous}
        className={navButton}
      >
        <ChevronLeft className="h-4 w-4" />
        <span className="hidden sm:inline text-xs">{previous}</span>
      </button>

      {/* Page Numbers */}
      {showPageNumbers && (
        <div className="flex items-center gap-0.5 mx-1" role="list">
          {pageNumbers.map((pageNum) =>
            pageNum === "ellipsis-start" || pageNum === "ellipsis-end" ? (
              <span
                key={pageNum}
                className="flex h-8 w-8 items-center justify-center text-muted-foreground"
                aria-hidden="true"
              >
                <MoreHorizontal className="h-4 w-4" />
              </span>
            ) : (
              <button
                type="button"
                key={pageNum}
                onClick={() => onPageChange(pageNum)}
                aria-current={pageNum === currentPage ? "page" : undefined}
                aria-label={`Page ${pageNum}`}
                className={pageNum === currentPage ? activePageButton : pageButton}
                disabled={pageNum === currentPage}
              >
                {pageNum}
              </button>
            )
          )}
        </div>
      )}

      {/* Page Info (when not showing numbers) */}
      {!showPageNumbers && (
        <span className="px-3 text-xs text-muted-foreground tabular-nums">
          {page(currentPage, totalPages)}
        </span>
      )}

      {/* Next Button */}
      <button
        type="button"
        onClick={() => meta.nextPage && onPageChange(meta.nextPage)}
        disabled={!meta.hasNextPage}
        aria-label={next}
        className={navButton}
      >
        <span className="hidden sm:inline text-xs">{next}</span>
        <ChevronRight className="h-4 w-4" />
      </button>
    </nav>
  );
}

export default Pagination;
