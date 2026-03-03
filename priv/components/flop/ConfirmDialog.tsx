/**
 * NbFlop Confirm Dialog
 *
 * A styled confirmation dialog that replaces window.confirm().
 * Renders the full Confirmation struct from the backend DSL including
 * custom title, message, button labels, variant, and icon.
 */

import * as React from 'react';
import { cn } from '@/lib/utils';
import type { TableConfirmation } from './tableTypes';

export interface ConfirmDialogProps {
  confirmation: TableConfirmation;
  open: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

const variantStyles: Record<string, { icon: string; button: string; bg: string }> = {
  default: {
    icon: 'text-muted-foreground',
    button: 'bg-primary text-primary-foreground hover:bg-primary/90',
    bg: 'bg-muted',
  },
  danger: {
    icon: 'text-red-600 dark:text-red-400',
    button: 'bg-red-600 text-white hover:bg-red-700',
    bg: 'bg-red-100 dark:bg-red-900/20',
  },
  warning: {
    icon: 'text-yellow-600 dark:text-yellow-400',
    button: 'bg-yellow-600 text-white hover:bg-yellow-700',
    bg: 'bg-yellow-100 dark:bg-yellow-900/20',
  },
  success: {
    icon: 'text-green-600 dark:text-green-400',
    button: 'bg-green-600 text-white hover:bg-green-700',
    bg: 'bg-green-100 dark:bg-green-900/20',
  },
};

function VariantIcon({ variant }: { variant: string }) {
  const styles = variantStyles[variant] || variantStyles.default;

  if (variant === 'danger') {
    return (
      <div className={cn('mx-auto flex h-12 w-12 items-center justify-center rounded-full', styles.bg)}>
        <svg className={cn('h-6 w-6', styles.icon)} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
        </svg>
      </div>
    );
  }

  if (variant === 'warning') {
    return (
      <div className={cn('mx-auto flex h-12 w-12 items-center justify-center rounded-full', styles.bg)}>
        <svg className={cn('h-6 w-6', styles.icon)} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
        </svg>
      </div>
    );
  }

  return null;
}

export function ConfirmDialog({ confirmation, open, onConfirm, onCancel }: ConfirmDialogProps) {
  const variant = confirmation.variant || 'default';
  const styles = variantStyles[variant] || variantStyles.default;

  // Close on Escape
  React.useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel();
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [open, onCancel]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/50 transition-opacity"
        onClick={onCancel}
      />

      {/* Dialog */}
      <div className="relative z-10 w-full max-w-md rounded-lg border border-border bg-card p-6 shadow-lg">
        <div className="text-center sm:text-left">
          <VariantIcon variant={variant} />

          <h3 className={cn('mt-4 text-lg font-semibold leading-6', variant !== 'default' && 'text-center')}>
            {confirmation.title}
          </h3>

          {confirmation.message && (
            <p className={cn('mt-2 text-sm text-muted-foreground', variant !== 'default' && 'text-center')}>
              {confirmation.message}
            </p>
          )}
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button
            type="button"
            onClick={onCancel}
            className="rounded-md border border-border bg-card px-4 py-2 text-sm font-medium text-foreground hover:bg-muted"
          >
            {confirmation.cancelButton || 'Cancel'}
          </button>
          <button
            type="button"
            onClick={onConfirm}
            className={cn('rounded-md px-4 py-2 text-sm font-medium', styles.button)}
            autoFocus
          >
            {confirmation.confirmButton || 'Confirm'}
          </button>
        </div>
      </div>
    </div>
  );
}

/**
 * Hook for managing confirmation dialog state.
 *
 * Returns a stable `confirm` function that shows the dialog and returns
 * a promise resolving to true (confirmed) or false (cancelled).
 */
export function useConfirmDialog() {
  const [state, setState] = React.useState<{
    confirmation: TableConfirmation;
    resolve: (value: boolean) => void;
  } | null>(null);

  const confirm = React.useRef((confirmation: TableConfirmation): Promise<boolean> => {
    return new Promise((resolve) => {
      setState({ confirmation, resolve });
    });
  }).current;

  const handleConfirm = () => {
    state?.resolve(true);
    setState(null);
  };

  const handleCancel = () => {
    state?.resolve(false);
    setState(null);
  };

  const dialogProps = state
    ? {
        confirmation: state.confirmation,
        open: true,
        onConfirm: handleConfirm,
        onCancel: handleCancel,
      }
    : null;

  return { confirm, dialogProps };
}

export default ConfirmDialog;
