/**
 * FilterModeToggle - Toggle between AND/OR filter logic
 */

import { Button } from '@/components/ui/button';
import type { FilterModeToggleProps } from './types';

export function FilterModeToggle({ mode, onChange }: FilterModeToggleProps) {
  const handleToggle = () => {
    onChange(mode === 'all' ? 'any' : 'all');
  };

  return (
    <Button
      variant="ghost"
      size="sm"
      className="h-7 text-xs text-muted-foreground hover:text-foreground"
      onClick={handleToggle}
    >
      {mode === 'all' ? 'Match all filters' : 'Match any filter'}
    </Button>
  );
}

export default FilterModeToggle;
