/**
 * FilterValueInput - Type-aware input for filter values
 *
 * Supports text, number, date, and datetime inputs with min/max constraints
 */

import { useState, useEffect, useRef } from 'react';
import { Input } from '@/components/ui/input';

export interface FilterValueInputProps {
  /** Current value */
  value?: string;
  /** Callback when value changes */
  onChange: (value: string) => void;
  /** Placeholder text */
  placeholder?: string;
  /** Input type */
  type?: 'text' | 'number' | 'date' | 'datetime-local';
  /** Minimum value (for number/date) */
  min?: number | string;
  /** Maximum value (for number/date) */
  max?: number | string;
  /** Debounce delay in ms */
  debounceMs?: number;
}

export function FilterValueInput({
  value = '',
  onChange,
  placeholder = 'Enter value...',
  type = 'text',
  min,
  max,
  debounceMs = 300,
}: FilterValueInputProps) {
  const [localValue, setLocalValue] = useState(value);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Sync local value when prop changes (e.g., from URL)
  useEffect(() => {
    setLocalValue(value);
  }, [value]);

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = e.target.value;
    setLocalValue(newValue);

    // Clear previous timeout
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }

    // Set new debounced timeout
    timeoutRef.current = setTimeout(() => {
      onChange(newValue);
    }, debounceMs);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      // Clear pending timeout and submit immediately
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      onChange(localValue);
    }
  };

  const handleBlur = () => {
    // Submit on blur if value differs
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    if (localValue !== value) {
      onChange(localValue);
    }
  };

  // Build input props with constraints
  const inputProps: React.InputHTMLAttributes<HTMLInputElement> = {
    type,
    value: localValue,
    onChange: handleChange,
    onKeyDown: handleKeyDown,
    onBlur: handleBlur,
    placeholder,
    className: 'h-8',
  };

  // Add min/max for numeric and date types
  if (type === 'number') {
    if (min !== undefined) inputProps.min = min;
    if (max !== undefined) inputProps.max = max;
    inputProps.step = 'any'; // Allow decimals
  } else if (type === 'date' || type === 'datetime-local') {
    if (min !== undefined) inputProps.min = String(min);
    if (max !== undefined) inputProps.max = String(max);
  }

  return <Input {...inputProps} />;
}

export default FilterValueInput;
