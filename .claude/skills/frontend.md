# Frontend Skill — React + Next.js App Router + Tailwind CSS

## Folder Structure (Next.js App Router)

```
src/
├── app/
│   ├── layout.tsx              # Root layout with providers
│   ├── page.tsx                # Home page
│   ├── (auth)/
│   │   ├── login/page.tsx
│   │   └── register/page.tsx
│   └── dashboard/
│       ├── layout.tsx          # Dashboard layout (auth guard)
│       ├── page.tsx
│       └── users/
│           ├── page.tsx
│           └── [id]/page.tsx
├── components/
│   ├── ui/                     # Primitive, reusable components
│   │   ├── Button/
│   │   │   ├── Button.tsx
│   │   │   ├── Button.types.ts
│   │   │   ├── useButton.ts    # Only if logic is complex
│   │   │   └── index.ts        # export { Button } from './Button'
│   │   └── Input/
│   └── features/               # Domain-specific components
│       └── UserCard/
├── hooks/                      # Shared custom hooks
│   ├── useDebounce.ts
│   └── useLocalStorage.ts
├── lib/
│   ├── api.ts                  # Axios/fetch instance + interceptors
│   ├── query-client.ts         # React Query client config
│   └── utils.ts                # cn() and other utils
├── stores/                     # Zustand stores
│   ├── auth.store.ts
│   └── ui.store.ts
├── types/
│   └── api.types.ts
└── services/                   # React Query hooks (not raw fetches)
    ├── user.service.ts
    └── auth.service.ts
```

## Component File Structure Pattern

```tsx
// components/ui/Button/Button.types.ts
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
}

// components/ui/Button/Button.tsx
import { forwardRef } from 'react';
import { cn } from '@/lib/utils';
import type { ButtonProps } from './Button.types';

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = 'primary', size = 'md', isLoading, className, children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        disabled={isLoading || props.disabled}
        className={cn(
          // Base
          'inline-flex items-center justify-center font-medium rounded-md transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
          'disabled:pointer-events-none disabled:opacity-50',
          // Size
          size === 'sm' && 'h-8 px-3 text-sm',
          size === 'md' && 'h-10 px-4 text-sm',
          size === 'lg' && 'h-12 px-6 text-base',
          // Variant
          variant === 'primary' && 'bg-blue-600 text-white hover:bg-blue-700',
          variant === 'secondary' && 'bg-gray-100 text-gray-900 hover:bg-gray-200',
          variant === 'ghost' && 'hover:bg-gray-100 text-gray-700',
          variant === 'danger' && 'bg-red-600 text-white hover:bg-red-700',
          className
        )}
        {...props}
      >
        {isLoading && <span className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />}
        {children}
      </button>
    );
  }
);
Button.displayName = 'Button';

// components/ui/Button/index.ts
export { Button } from './Button';
export type { ButtonProps } from './Button.types';
```

## cn() Utility

```ts
// lib/utils.ts
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
```

## Zustand Store Pattern

```ts
// stores/auth.store.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface User { id: string; name: string; email: string; role: string; }
interface AuthState {
  user: User | null;
  accessToken: string | null;
  setAuth: (user: User, token: string) => void;
  clearAuth: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      accessToken: null,
      setAuth: (user, accessToken) => set({ user, accessToken }),
      clearAuth: () => set({ user: null, accessToken: null }),
    }),
    { name: 'auth-storage', partialize: (s) => ({ user: s.user }) } // don't persist token
  )
);
```

## React Query Patterns

```ts
// services/user.service.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

// Query keys factory — always use this pattern, never inline strings
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: Record<string, unknown>) => [...userKeys.lists(), filters] as const,
  detail: (id: string) => [...userKeys.all, 'detail', id] as const,
};

// useQuery
export function useUsers(page: number, search?: string) {
  return useQuery({
    queryKey: userKeys.list({ page, search }),
    queryFn: () => api.get<User[]>('/users', { params: { page, search } }),
    staleTime: 30_000,
    placeholderData: (prev) => prev, // keeps previous data while fetching
  });
}

// useMutation with optimistic update
export function useUpdateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<User> }) =>
      api.patch<User>(`/users/${id}`, data),
    onMutate: async ({ id, data }) => {
      await queryClient.cancelQueries({ queryKey: userKeys.detail(id) });
      const previous = queryClient.getQueryData<User>(userKeys.detail(id));
      queryClient.setQueryData(userKeys.detail(id), (old: User) => ({ ...old, ...data }));
      return { previous };
    },
    onError: (_err, { id }, context) => {
      queryClient.setQueryData(userKeys.detail(id), context?.previous);
    },
    onSettled: (_data, _err, { id }) => {
      queryClient.invalidateQueries({ queryKey: userKeys.detail(id) });
    },
  });
}
```

## Form Handling: React Hook Form + Zod

```tsx
// components/features/LoginForm/LoginForm.tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

type LoginFormData = z.infer<typeof loginSchema>;

export function LoginForm() {
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (data: LoginFormData) => {
    // call mutation
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <input {...register('email')} type="email" placeholder="Email"
          className={cn('input', errors.email && 'input-error')} />
        {errors.email && <p className="text-sm text-red-600 mt-1">{errors.email.message}</p>}
      </div>
      <Button type="submit" isLoading={isSubmitting} className="w-full">Sign in</Button>
    </form>
  );
}
```

## Error Boundary Pattern

```tsx
// components/ui/ErrorBoundary/ErrorBoundary.tsx
'use client';
import { Component, type ReactNode, type ErrorInfo } from 'react';

interface Props { children: ReactNode; fallback?: (error: Error, reset: () => void) => ReactNode; }
interface State { error: Error | null; }

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    console.error('ErrorBoundary caught:', error, info);
  }

  render(): ReactNode {
    if (this.state.error) {
      const reset = () => this.setState({ error: null });
      return this.props.fallback
        ? this.props.fallback(this.state.error, reset)
        : <div className="p-4 text-red-600">Something went wrong. <button onClick={reset}>Retry</button></div>;
    }
    return this.props.children;
  }
}
```

## Tailwind Class Ordering Convention

Order classes: layout → display → position → box model → typography → visual → interactive
```tsx
// Correct order:
className="flex flex-col relative w-full max-w-md mt-4 px-6 py-4 text-sm font-medium text-gray-900 bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200"

// Use cn() to separate concerns:
cn(
  'flex items-center gap-2',           // layout
  'w-full px-4 py-2',                  // box model
  'text-sm font-medium',               // typography
  'bg-blue-600 text-white rounded-md', // visual
  'hover:bg-blue-700 transition-colors', // interactive
  className                            // override from props
)
```
