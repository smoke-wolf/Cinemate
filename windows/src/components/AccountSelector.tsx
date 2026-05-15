import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAccounts } from '../hooks/useAccounts';

interface AccountSelectorProps {
  onSelect: () => void;
}

const AVATAR_COLORS = [
  '#d4a017', '#ef4444', '#3b82f6', '#22c55e', '#a855f7',
  '#f97316', '#06b6d4', '#ec4899', '#eab308', '#8b5cf6',
];

export default function AccountSelector({ onSelect }: AccountSelectorProps) {
  const { accounts, setCurrentAccount, loadAccounts, createAccount } = useAccounts();
  const [showCreate, setShowCreate] = useState(false);
  const [showPin, setShowPin] = useState(false);
  const [selectedAccountForPin, setSelectedAccountForPin] = useState<number | null>(null);
  const [pinInput, setPinInput] = useState('');
  const [pinError, setPinError] = useState(false);
  const [newName, setNewName] = useState('');
  const [newColor, setNewColor] = useState(AVATAR_COLORS[0]);
  const [newPin, setNewPin] = useState('');
  const pinInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    loadAccounts();
  }, []);

  // Auto-focus PIN input when dialog opens
  useEffect(() => {
    if (showPin && pinInputRef.current) {
      pinInputRef.current.focus();
    }
  }, [showPin]);

  const handleSelectAccount = (account: typeof accounts[0]) => {
    if (account.pin) {
      setSelectedAccountForPin(account.id);
      setShowPin(true);
      setPinInput('');
      setPinError(false);
    } else {
      setCurrentAccount(account);
      onSelect();
    }
  };

  const handlePinSubmit = () => {
    const account = accounts.find((a) => a.id === selectedAccountForPin);
    if (account && account.pin === pinInput) {
      setCurrentAccount(account);
      setShowPin(false);
      onSelect();
    } else {
      setPinError(true);
      setPinInput('');
      // Shake animation is handled by the AnimatePresence key change
    }
  };

  const handleCreateAccount = async () => {
    if (!newName.trim()) return;
    await createAccount({
      name: newName.trim(),
      avatar_color: newColor,
      pin: newPin || undefined,
    });
    setNewName('');
    setNewPin('');
    setNewColor(AVATAR_COLORS[0]);
    setShowCreate(false);
    await loadAccounts();
  };

  return (
    <motion.div
      className="fixed inset-0 bg-cinema-bg flex items-center justify-center"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.5 }}
    >
      {/* Background */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <motion.div
          className="absolute top-1/3 left-1/2 -translate-x-1/2 w-[700px] h-[700px] rounded-full blur-3xl"
          style={{ background: 'radial-gradient(circle, rgba(212,160,23,0.04) 0%, transparent 70%)' }}
          animate={{ scale: [1, 1.1, 1] }}
          transition={{ duration: 8, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      <div className="relative z-10 max-w-2xl w-full px-8">
        {/* Header */}
        <motion.div
          className="text-center mb-14"
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.5 }}
        >
          <h1 className="text-4xl font-bold text-white mb-2">Who's watching?</h1>
        </motion.div>

        {/* Profile grid */}
        <div className="flex flex-wrap justify-center gap-8 mb-8">
          <AnimatePresence mode="popLayout">
            {accounts.map((account, i) => (
              <motion.button
                key={account.id}
                initial={{ opacity: 0, scale: 0.7, y: 20 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.7 }}
                transition={{ delay: 0.1 * i, duration: 0.4, ease: [0.34, 1.56, 0.64, 1] }}
                whileHover={{ scale: 1.08 }}
                whileTap={{ scale: 0.95 }}
                onClick={() => handleSelectAccount(account)}
                className="group flex flex-col items-center gap-3 focus:outline-none"
              >
                <div className="relative">
                  <div
                    className="w-28 h-28 rounded-2xl flex items-center justify-center text-3xl font-bold text-white
                               transition-all duration-300
                               group-hover:shadow-2xl"
                    style={{
                      backgroundColor: account.avatar_color,
                      boxShadow: `0 4px 20px ${account.avatar_color}30`,
                    }}
                  >
                    {account.name.charAt(0).toUpperCase()}
                  </div>
                  {/* Hover glow ring */}
                  <div
                    className="absolute -inset-1 rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 -z-10"
                    style={{
                      boxShadow: `0 0 30px ${account.avatar_color}50, 0 0 60px ${account.avatar_color}20`,
                    }}
                  />
                  {/* Selection ring */}
                  <div className="absolute -inset-[3px] rounded-[18px] border-2 border-white/0 group-hover:border-white/40 transition-all duration-300" />
                </div>
                <span className="text-cinema-text-secondary text-sm font-medium group-hover:text-white transition-colors duration-200">
                  {account.name}
                </span>
                {account.pin && (
                  <svg className="w-3 h-3 text-cinema-text-dim -mt-1" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clipRule="evenodd" />
                  </svg>
                )}
              </motion.button>
            ))}

            {/* Add profile button */}
            <motion.button
              initial={{ opacity: 0, scale: 0.7, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              transition={{ delay: 0.1 * accounts.length, duration: 0.4, ease: [0.34, 1.56, 0.64, 1] }}
              whileHover={{ scale: 1.08 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => setShowCreate(true)}
              className="group flex flex-col items-center gap-3 focus:outline-none"
            >
              <div className="w-28 h-28 rounded-2xl border-2 border-dashed border-cinema-border
                            flex items-center justify-center text-cinema-text-dim
                            group-hover:border-cinema-gold/50 group-hover:text-cinema-gold
                            group-hover:bg-cinema-gold/5
                            transition-all duration-300">
                <svg className="w-10 h-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 4v16m8-8H4" />
                </svg>
              </div>
              <span className="text-cinema-text-dim text-sm font-medium group-hover:text-cinema-gold transition-colors duration-200">
                Add Profile
              </span>
            </motion.button>
          </AnimatePresence>
        </div>
      </div>

      {/* PIN dialog */}
      <AnimatePresence>
        {showPin && (
          <motion.div
            className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={() => setShowPin(false)}
          >
            <motion.div
              className="glass rounded-2xl p-8 w-96"
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              transition={{ type: 'spring', stiffness: 400, damping: 30 }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex justify-center mb-5">
                <div className="w-12 h-12 rounded-full bg-cinema-gold/10 flex items-center justify-center">
                  <svg className="w-6 h-6 text-cinema-gold" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clipRule="evenodd" />
                  </svg>
                </div>
              </div>
              <h3 className="text-xl font-semibold text-white text-center mb-6">Enter PIN</h3>
              <motion.input
                ref={pinInputRef}
                type="password"
                value={pinInput}
                onChange={(e) => { setPinInput(e.target.value); setPinError(false); }}
                onKeyDown={(e) => e.key === 'Enter' && handlePinSubmit()}
                maxLength={6}
                className={`w-full bg-cinema-bg/60 border rounded-lg px-4 py-3.5 text-white text-center text-2xl
                           tracking-[0.5em] focus:outline-none transition-all duration-200
                           ${pinError ? 'border-cinema-red/60 focus:border-cinema-red/80' : 'border-cinema-border focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20'}`}
                animate={pinError ? { x: [-8, 8, -6, 6, -4, 4, 0] } : {}}
                transition={{ duration: 0.4 }}
                placeholder="------"
              />
              <AnimatePresence>
                {pinError && (
                  <motion.p
                    className="text-cinema-red text-xs text-center mt-2"
                    initial={{ opacity: 0, y: -5 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0 }}
                  >
                    Incorrect PIN
                  </motion.p>
                )}
              </AnimatePresence>
              <motion.button
                onClick={handlePinSubmit}
                className="w-full mt-5 py-3 bg-cinema-gold hover:bg-cinema-gold-hover text-black font-semibold rounded-lg
                           transition-all duration-200 hover:shadow-lg hover:shadow-cinema-gold/20"
                whileTap={{ scale: 0.98 }}
              >
                Continue
              </motion.button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Create account dialog */}
      <AnimatePresence>
        {showCreate && (
          <motion.div
            className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={() => setShowCreate(false)}
          >
            <motion.div
              className="glass rounded-2xl p-8 w-[420px]"
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              transition={{ type: 'spring', stiffness: 400, damping: 30 }}
              onClick={(e) => e.stopPropagation()}
            >
              <h3 className="text-xl font-semibold text-white text-center mb-6">Create Profile</h3>

              {/* Avatar preview */}
              <motion.div
                className="flex justify-center mb-6"
                animate={{ scale: [1, 1.02, 1] }}
                transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
              >
                <div
                  className="w-22 h-22 rounded-2xl flex items-center justify-center text-3xl font-bold text-white
                             transition-all duration-400"
                  style={{
                    width: '5.5rem',
                    height: '5.5rem',
                    backgroundColor: newColor,
                    boxShadow: `0 8px 30px ${newColor}40`,
                  }}
                >
                  {newName ? newName.charAt(0).toUpperCase() : '?'}
                </div>
              </motion.div>

              {/* Name */}
              <label className="block text-cinema-text-secondary text-xs font-medium mb-2 uppercase tracking-wider">
                Name
              </label>
              <input
                type="text"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                className="w-full bg-cinema-bg/60 border border-cinema-border rounded-lg px-4 py-3 text-white text-sm
                           focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                           transition-all duration-200 mb-4"
                placeholder="Profile name"
                autoFocus
              />

              {/* Color picker */}
              <label className="block text-cinema-text-secondary text-xs font-medium mb-2 uppercase tracking-wider">
                Avatar Color
              </label>
              <div className="flex gap-2 mb-4 flex-wrap">
                {AVATAR_COLORS.map((color) => (
                  <motion.button
                    key={color}
                    onClick={() => setNewColor(color)}
                    className="w-8 h-8 rounded-full transition-all duration-200 relative"
                    style={{ backgroundColor: color }}
                    whileHover={{ scale: 1.15 }}
                    whileTap={{ scale: 0.9 }}
                  >
                    {newColor === color && (
                      <motion.div
                        className="absolute -inset-[3px] rounded-full border-2 border-white"
                        layoutId="color-ring"
                        transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                      />
                    )}
                  </motion.button>
                ))}
              </div>

              {/* Optional PIN */}
              <label className="block text-cinema-text-secondary text-xs font-medium mb-2 uppercase tracking-wider">
                PIN (optional)
              </label>
              <input
                type="password"
                value={newPin}
                onChange={(e) => setNewPin(e.target.value)}
                maxLength={6}
                className="w-full bg-cinema-bg/60 border border-cinema-border rounded-lg px-4 py-3 text-white text-sm
                           focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                           transition-all duration-200 mb-6"
                placeholder="Leave empty for no PIN"
              />

              {/* Actions */}
              <div className="flex gap-3">
                <motion.button
                  onClick={() => setShowCreate(false)}
                  className="flex-1 py-3 border border-cinema-border rounded-lg text-cinema-text-secondary
                             hover:text-white hover:border-cinema-border-hover hover:bg-cinema-surface/50 transition-all duration-200"
                  whileTap={{ scale: 0.98 }}
                >
                  Cancel
                </motion.button>
                <motion.button
                  onClick={handleCreateAccount}
                  disabled={!newName.trim()}
                  className="flex-1 py-3 bg-cinema-gold hover:bg-cinema-gold-hover text-black font-semibold rounded-lg
                             transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed
                             hover:shadow-lg hover:shadow-cinema-gold/20"
                  whileTap={{ scale: 0.98 }}
                >
                  Create
                </motion.button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
