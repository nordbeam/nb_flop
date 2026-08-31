import { Search } from 'lucide-react';
import type { ChangeEvent, FormEvent } from 'react';
import { Input } from '@/components/ui/input';

export interface SearchInputProps {
  value: string;
  onChange: (event: ChangeEvent<HTMLInputElement>) => void;
  onSubmit?: (event: FormEvent) => void;
  placeholder?: string;
  className?: string;
}

export function SearchInput({
  value,
  onChange,
  onSubmit,
  placeholder = 'Search...',
  className = 'max-w-sm',
}: SearchInputProps) {
  const input = (
    <div className={`relative ${className}`}>
      <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
      <Input
        type="search"
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        className="pl-9"
      />
    </div>
  );

  return onSubmit ? <form onSubmit={onSubmit}>{input}</form> : input;
}
