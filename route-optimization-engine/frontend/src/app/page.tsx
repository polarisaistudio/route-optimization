'use client';

import React, { useState, useCallback } from 'react';
import { format } from 'date-fns';
import {
  useDashboardData,
  mockAlgorithmComparison,
  mockDailyTrends,
} from '@/hooks/useDashboardData';
import MetricsCards from '@/components/Dashboard/MetricsCards';
import AlgorithmComparison from '@/components/Dashboard/AlgorithmComparison';
import UtilizationChart from '@/components/Dashboard/UtilizationChart';
import DailyTrends from '@/components/Dashboard/DailyTrends';
import MapWrapper from '@/components/Map/MapWrapper';
import FilterPanel from '@/components/Filters/FilterPanel';
import type { FilterState } from '@/types';
import { ExclamationCircleIcon, ArrowPathIcon } from '@heroicons/react/24/outline';

const defaultFilters: FilterState = {
  date: format(new Date(), 'yyyy-MM-dd'),
  technicianIds: [],
  zoneId: '',
  priority: '',
  algorithm: '',
};

export default function DashboardPage() {
  const [filters, setFilters] = useState<FilterState>(defaultFilters);
  const { routes, technicians, metrics, loading, error, refetch } =
    useDashboardData(filters.date);

  const handleApply = useCallback(() => {
    refetch();
  }, [refetch]);

  const handleReset = useCallback(() => {
    setFilters(defaultFilters);
  }, []);

  // Error state
  if (error) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-center">
        <div className="rounded-full bg-danger-100 p-4 mb-4">
          <ExclamationCircleIcon className="h-10 w-10 text-danger-600" />
        </div>
        <h2 className="text-xl font-semibold text-neutral-900 mb-2">
          Failed to Load Dashboard
        </h2>
        <p className="text-neutral-500 max-w-md mb-6">{error}</p>
        <button onClick={refetch} className="btn-primary gap-2">
          <ArrowPathIcon className="h-4 w-4" />
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Filter Panel */}
      <FilterPanel
        technicians={technicians}
        filters={filters}
        onFiltersChange={setFilters}
        onApply={handleApply}
        onReset={handleReset}
      />

      {/* Metrics Cards */}
      <MetricsCards metrics={metrics} loading={loading} />

      {/* Main content: Map + Utilization side by side */}
      <div className="grid grid-cols-1 xl:grid-cols-5 gap-6">
        {/* Map - takes 3/5 of the width */}
        <div className="xl:col-span-3">
          <div className="card overflow-hidden" style={{ minHeight: 500 }}>
            <div className="card-header flex items-center justify-between">
              <div>
                <h3 className="text-sm font-semibold text-neutral-900">
                  Route Visualization
                </h3>
                <p className="text-xs text-neutral-500 mt-0.5">
                  {routes.length} routes &middot;{' '}
                  {routes.reduce((sum, r) => sum + r.summary.numStops, 0)} total
                  stops &middot; Denver Metro Area
                </p>
              </div>
              <div className="flex items-center gap-2">
                <span className="badge-success">Live</span>
              </div>
            </div>
            <div style={{ height: 480 }}>
              {loading ? (
                <div className="flex items-center justify-center h-full bg-neutral-100 animate-pulse">
                  <span className="text-sm text-neutral-400">Loading map data...</span>
                </div>
              ) : (
                <MapWrapper
                  routes={routes}
                  technicians={technicians}
                  selectedTechIds={
                    filters.technicianIds.length > 0
                      ? filters.technicianIds
                      : undefined
                  }
                />
              )}
            </div>
          </div>
        </div>

        {/* Utilization Chart - takes 2/5 */}
        <div className="xl:col-span-2">
          {loading ? (
            <div className="card p-6">
              <div className="skeleton h-4 w-40 mb-6" />
              <div className="space-y-4">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex items-center gap-3">
                    <div className="skeleton h-3 w-16" />
                    <div className="skeleton h-6 flex-1 rounded-full" />
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <UtilizationChart routes={routes} />
          )}
        </div>
      </div>

      {/* Bottom section: Algorithm Comparison + Daily Trends */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <AlgorithmComparison data={mockAlgorithmComparison} />

        {loading ? (
          <div className="card p-6">
            <div className="skeleton h-4 w-48 mb-6" />
            <div className="skeleton h-64 w-full rounded-lg" />
          </div>
        ) : (
          <DailyTrends data={mockDailyTrends} />
        )}
      </div>

      {/* Route summary table */}
      <div className="card">
        <div className="card-header">
          <h3 className="text-sm font-semibold text-neutral-900">
            Route Details
          </h3>
          <p className="text-xs text-neutral-500 mt-0.5">
            Summary of all optimized routes for{' '}
            {format(new Date(filters.date), 'MMMM d, yyyy')}
          </p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-neutral-100">
                <th className="px-6 py-3 text-left text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Technician
                </th>
                <th className="px-4 py-3 text-center text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Stops
                </th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Distance
                </th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Work Time
                </th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Travel Time
                </th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Utilization
                </th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                  Algorithm
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-50">
              {loading
                ? Array.from({ length: 4 }).map((_, i) => (
                    <tr key={i}>
                      {Array.from({ length: 8 }).map((__, j) => (
                        <td key={j} className="px-4 py-3.5">
                          <div className="skeleton h-4 w-full" />
                        </td>
                      ))}
                    </tr>
                  ))
                : routes.map((route) => (
                    <tr
                      key={route.id}
                      className="hover:bg-neutral-50 transition-colors"
                    >
                      <td className="px-6 py-3.5 font-medium text-neutral-900 whitespace-nowrap">
                        {route.technicianName}
                      </td>
                      <td className="px-4 py-3.5 text-center">
                        <span
                          className={
                            route.status === 'in-progress'
                              ? 'badge-success'
                              : route.status === 'planned'
                                ? 'badge-primary'
                                : 'badge-warning'
                          }
                        >
                          {route.status}
                        </span>
                      </td>
                      <td className="px-4 py-3.5 text-right tabular-nums text-neutral-700">
                        {route.summary.numStops}
                      </td>
                      <td className="px-4 py-3.5 text-right tabular-nums text-neutral-700">
                        {route.summary.totalDistanceMiles.toFixed(1)} mi
                      </td>
                      <td className="px-4 py-3.5 text-right tabular-nums text-neutral-700">
                        {Math.round(route.summary.totalWorkMinutes)} min
                      </td>
                      <td className="px-4 py-3.5 text-right tabular-nums text-neutral-700">
                        {Math.round(route.summary.totalTravelMinutes)} min
                      </td>
                      <td className="px-4 py-3.5 text-right">
                        <span
                          className={
                            route.summary.utilizationPercent >= 80
                              ? 'font-semibold text-success-700'
                              : route.summary.utilizationPercent >= 60
                                ? 'font-semibold text-primary-700'
                                : 'font-semibold text-warning-700'
                          }
                        >
                          {route.summary.utilizationPercent.toFixed(1)}%
                        </span>
                      </td>
                      <td className="px-4 py-3.5 text-right text-neutral-500 uppercase text-xs font-medium">
                        {route.algorithmUsed}
                      </td>
                    </tr>
                  ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
