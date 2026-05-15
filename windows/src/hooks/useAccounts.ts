import { createContext, useContext } from 'react';
import type { Account } from '../api/types';

export interface AccountContextType {
  accounts: Account[];
  currentAccount: Account | null;
  setCurrentAccount: (account: Account | null) => void;
  loadAccounts: () => Promise<void>;
  createAccount: (data: { name: string; avatar_color: string; pin?: string }) => Promise<Account>;
}

export const AccountContext = createContext<AccountContextType>({
  accounts: [],
  currentAccount: null,
  setCurrentAccount: () => {},
  loadAccounts: async () => {},
  createAccount: async () => ({ id: 0, name: '', avatar_color: '' }),
});

export function useAccounts() {
  return useContext(AccountContext);
}
