'use client';

import React, { useState } from 'react';
import Sidebar from './Sidebar';
import {
  Bars3Icon,
  CalendarDaysIcon,
  BellIcon,
} from '@heroicons/react/24/outline';
import { format } from 'date-fns';

interface AppLayoutProps {
  children: React.ReactNode;
}

export default function AppLayout({ children }: AppLayoutProps) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const currentPath = '/'; // In a real app, derive from router

  return (
    <div className="min-h-screen bg-neutral-50">
      <Sidebar
        currentPath={currentPath}
        mobileOpen={mobileOpen}
        onClose={() => setMobileOpen(false)}
      />

      {/* Main content area offset by sidebar width */}
      <div className="lg:pl-64">
        {/* Top header bar */}
        <header className="sticky top-0 z-30 flex h-16 items-center gap-4 border-b border-neutral-200 bg-white/80 backdrop-blur-sm px-4 sm:px-6">
          {/* Mobile hamburger */}
          <button
            className="lg:hidden -ml-1 p-1.5 text-neutral-600 hover:text-neutral-900"
            onClick={() => setMobileOpen(true)}
          >
            <Bars3Icon className="h-6 w-6" />
          </button>

          {/* Title */}
          <div className="flex-1 min-w-0">
            <h1 className="text-lg font-semibold text-neutral-900 truncate">
              Route Optimization Engine
            </h1>
            <p className="text-xs text-neutral-500 hidden sm:block">
              Field Service Operations Dashboard
            </p>
          </div>

          {/* Right side controls */}
          <div className="flex items-center gap-3">
            {/* Date display */}
            <div className="hidden sm:flex items-center gap-2 rounded-lg bg-neutral-100 px-3 py-1.5 text-sm text-neutral-600">
              <CalendarDaysIcon className="h-4 w-4 text-neutral-400" />
              <span>{format(new Date(), 'EEEE, MMM d, yyyy')}</span>
            </div>

            {/* Notifications */}
            <button className="relative rounded-lg p-2 text-neutral-500 hover:bg-neutral-100 hover:text-neutral-700 transition-colors">
              <BellIcon className="h-5 w-5" />
              <span className="absolute top-1.5 right-1.5 h-2 w-2 rounded-full bg-danger-500" />
            </button>

            {/* User avatar */}
            <div className="h-8 w-8 rounded-full bg-primary-600 flex items-center justify-center cursor-pointer hover:ring-2 hover:ring-primary-300 transition-all">
              <span className="text-xs font-semibold text-white">XW</span>
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="p-4 sm:p-6">{children}</main>
      </div>
    </div>
  );
}
