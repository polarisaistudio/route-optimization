'use client';

import React from 'react';
import clsx from 'clsx';
import {
  HomeIcon,
  MapIcon,
  UserGroupIcon,
  ClipboardDocumentListIcon,
  ChartBarIcon,
  XMarkIcon,
} from '@heroicons/react/24/outline';

interface NavItem {
  name: string;
  href: string;
  icon: React.ComponentType<React.SVGProps<SVGSVGElement>>;
}

const navigation: NavItem[] = [
  { name: 'Dashboard', href: '/', icon: HomeIcon },
  { name: 'Routes', href: '/routes', icon: MapIcon },
  { name: 'Technicians', href: '/technicians', icon: UserGroupIcon },
  { name: 'Work Orders', href: '/work-orders', icon: ClipboardDocumentListIcon },
  { name: 'Analytics', href: '/analytics', icon: ChartBarIcon },
];

interface SidebarProps {
  currentPath: string;
  mobileOpen: boolean;
  onClose: () => void;
}

export default function Sidebar({ currentPath, mobileOpen, onClose }: SidebarProps) {
  return (
    <>
      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-neutral-900/50 lg:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar panel */}
      <aside
        className={clsx(
          'fixed inset-y-0 left-0 z-50 flex w-64 flex-col bg-neutral-900 transition-transform duration-300 ease-in-out lg:translate-x-0',
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        {/* Logo / Brand */}
        <div className="flex h-16 items-center justify-between px-6 border-b border-neutral-800">
          <div className="flex items-center gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-600">
              <MapIcon className="h-5 w-5 text-white" />
            </div>
            <span className="text-lg font-bold text-white tracking-tight">
              Polaris
            </span>
          </div>
          <button
            className="lg:hidden text-neutral-400 hover:text-white"
            onClick={onClose}
          >
            <XMarkIcon className="h-6 w-6" />
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 space-y-1 px-3 py-4 overflow-y-auto scrollbar-thin">
          {navigation.map((item) => {
            const isActive = currentPath === item.href;
            return (
              <a
                key={item.name}
                href={item.href}
                className={clsx(
                  'group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors duration-150',
                  isActive
                    ? 'bg-primary-600/20 text-primary-400'
                    : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'
                )}
              >
                <item.icon
                  className={clsx(
                    'h-5 w-5 flex-shrink-0 transition-colors duration-150',
                    isActive
                      ? 'text-primary-400'
                      : 'text-neutral-500 group-hover:text-neutral-300'
                  )}
                />
                {item.name}
              </a>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="border-t border-neutral-800 p-4">
          <div className="flex items-center gap-3">
            <div className="h-8 w-8 rounded-full bg-primary-700 flex items-center justify-center">
              <span className="text-xs font-semibold text-white">RO</span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-neutral-200 truncate">
                Route Optimizer
              </p>
              <p className="text-xs text-neutral-500 truncate">v1.0.0</p>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
