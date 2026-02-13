'use client';

import React from 'react';
import clsx from 'clsx';
import {
  MapIcon,
  TruckIcon,
  ClockIcon,
  ChartBarIcon,
  ArrowTrendingUpIcon,
  ExclamationTriangleIcon,
} from '@heroicons/react/24/outline';
import type { DashboardMetrics } from '@/types';

interface MetricCardConfig {
  key: keyof DashboardMetrics;
  label: string;
  icon: React.ComponentType<React.SVGProps<SVGSVGElement>>;
  format: (value: number) => string;
  color: 'primary' | 'success' | 'warning' | 'danger';
  trendDirection: 'up-good' | 'down-good';
  suffix?: string;
}

const cardConfigs: MetricCardConfig[] = [
  {
    key: 'totalRoutes',
    label: 'Total Routes',
    icon: MapIcon,
    format: (v) => v.toFixed(0),
    color: 'primary',
    trendDirection: 'up-good',
  },
  {
    key: 'totalDistance',
    label: 'Total Distance',
    icon: TruckIcon,
    format: (v) => v.toFixed(1),
    color: 'primary',
    trendDirection: 'down-good',
    suffix: 'mi',
  },
  {
    key: 'totalDuration',
    label: 'Total Duration',
    icon: ClockIcon,
    format: (v) => v.toFixed(1),
    color: 'primary',
    trendDirection: 'down-good',
    suffix: 'hrs',
  },
  {
    key: 'avgUtilization',
    label: 'Avg Utilization',
    icon: ChartBarIcon,
    format: (v) => v.toFixed(1),
    color: 'success',
    trendDirection: 'up-good',
    suffix: '%',
  },
  {
    key: 'improvementVsBaseline',
    label: 'vs Baseline',
    icon: ArrowTrendingUpIcon,
    format: (v) => `+${v.toFixed(1)}`,
    color: 'success',
    trendDirection: 'up-good',
    suffix: '%',
  },
  {
    key: 'unassignedOrders',
    label: 'Unassigned Orders',
    icon: ExclamationTriangleIcon,
    format: (v) => v.toFixed(0),
    color: 'danger',
    trendDirection: 'down-good',
  },
];

const colorMap = {
  primary: {
    bg: 'bg-primary-50',
    icon: 'text-primary-600',
    ring: 'ring-primary-100',
    accent: 'text-primary-700',
  },
  success: {
    bg: 'bg-success-50',
    icon: 'text-success-600',
    ring: 'ring-success-100',
    accent: 'text-success-700',
  },
  warning: {
    bg: 'bg-warning-50',
    icon: 'text-warning-600',
    ring: 'ring-warning-100',
    accent: 'text-warning-700',
  },
  danger: {
    bg: 'bg-danger-50',
    icon: 'text-danger-600',
    ring: 'ring-danger-100',
    accent: 'text-danger-700',
  },
};

interface MetricsCardsProps {
  metrics: DashboardMetrics;
  loading?: boolean;
}

export default function MetricsCards({ metrics, loading }: MetricsCardsProps) {
  if (loading) {
    return (
      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="metric-card animate-pulse">
            <div className="flex items-center gap-3 mb-3">
              <div className="h-10 w-10 rounded-lg bg-neutral-200" />
              <div className="h-3 w-16 bg-neutral-200 rounded" />
            </div>
            <div className="h-8 w-20 bg-neutral-200 rounded mb-1" />
            <div className="h-3 w-12 bg-neutral-100 rounded" />
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
      {cardConfigs.map((config) => {
        const value = metrics[config.key];
        const colors = colorMap[config.color];

        return (
          <div key={config.key} className="metric-card">
            <div className="flex items-center gap-3 mb-3">
              <div
                className={clsx(
                  'flex h-10 w-10 items-center justify-center rounded-lg ring-1',
                  colors.bg,
                  colors.ring
                )}
              >
                <config.icon className={clsx('h-5 w-5', colors.icon)} />
              </div>
            </div>
            <div className="flex items-baseline gap-1.5">
              <span className={clsx('text-2xl font-bold tracking-tight', colors.accent)}>
                {config.format(value)}
              </span>
              {config.suffix && (
                <span className="text-sm font-medium text-neutral-400">
                  {config.suffix}
                </span>
              )}
            </div>
            <p className="mt-1 text-xs font-medium text-neutral-500 uppercase tracking-wider">
              {config.label}
            </p>
          </div>
        );
      })}
    </div>
  );
}
