'use client';

import React from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ReferenceLine,
  ResponsiveContainer,
  Cell,
} from 'recharts';
import type { Route } from '@/types';
import { technicianColors } from '@/hooks/useDashboardData';

interface UtilizationChartProps {
  routes: Route[];
}

function getUtilizationColor(utilization: number): string {
  if (utilization >= 85) return '#16a34a'; // success-600
  if (utilization >= 70) return '#2563eb'; // primary-600
  if (utilization >= 50) return '#d97706'; // warning-600
  return '#dc2626'; // danger-600
}

export default function UtilizationChart({ routes }: UtilizationChartProps) {
  const data = routes.map((route) => ({
    name: route.technicianName.split(' ')[0],
    fullName: route.technicianName,
    utilization: route.summary.utilizationPercent,
    stops: route.summary.numStops,
    techId: route.technicianId,
  }));

  const CustomTooltip = ({ active, payload }: { active?: boolean; payload?: Array<{ payload: typeof data[0] }> }) => {
    if (!active || !payload?.length) return null;
    const d = payload[0].payload;
    return (
      <div className="rounded-lg bg-white px-4 py-3 shadow-lg ring-1 ring-neutral-200 text-sm">
        <p className="font-semibold text-neutral-900">{d.fullName}</p>
        <div className="mt-1.5 space-y-0.5 text-neutral-600">
          <p>
            Utilization:{' '}
            <span className="font-semibold" style={{ color: getUtilizationColor(d.utilization) }}>
              {d.utilization.toFixed(1)}%
            </span>
          </p>
          <p>
            Stops: <span className="font-semibold text-neutral-900">{d.stops}</span>
          </p>
        </div>
      </div>
    );
  };

  return (
    <div className="card">
      <div className="card-header">
        <h3 className="text-sm font-semibold text-neutral-900">
          Technician Utilization
        </h3>
        <p className="text-xs text-neutral-500 mt-0.5">
          Percentage of available hours utilized
        </p>
      </div>
      <div className="card-body">
        <ResponsiveContainer width="100%" height={280}>
          <BarChart data={data} layout="vertical" margin={{ top: 5, right: 30, left: 10, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" horizontal={false} />
            <XAxis
              type="number"
              domain={[0, 100]}
              tick={{ fontSize: 12, fill: '#64748b' }}
              tickFormatter={(v) => `${v}%`}
              axisLine={{ stroke: '#e2e8f0' }}
              tickLine={false}
            />
            <YAxis
              type="category"
              dataKey="name"
              tick={{ fontSize: 12, fill: '#334155', fontWeight: 500 }}
              axisLine={false}
              tickLine={false}
              width={70}
            />
            <Tooltip content={<CustomTooltip />} cursor={{ fill: '#f1f5f9' }} />
            <ReferenceLine
              x={80}
              stroke="#94a3b8"
              strokeDasharray="4 4"
              strokeWidth={1.5}
              label={{
                value: 'Target 80%',
                position: 'top',
                fill: '#64748b',
                fontSize: 11,
              }}
            />
            <Bar dataKey="utilization" radius={[0, 6, 6, 0]} barSize={24}>
              {data.map((entry, index) => (
                <Cell
                  key={index}
                  fill={
                    technicianColors[entry.techId] || getUtilizationColor(entry.utilization)
                  }
                  opacity={0.85}
                />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
