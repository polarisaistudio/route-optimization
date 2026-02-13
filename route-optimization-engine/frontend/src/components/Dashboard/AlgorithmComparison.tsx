'use client';

import React from 'react';
import clsx from 'clsx';
import { TrophyIcon } from '@heroicons/react/24/solid';
import type { AlgorithmComparisonRow } from '@/types';

interface AlgorithmComparisonProps {
  data: AlgorithmComparisonRow[];
}

type NumericKey = 'totalDistance' | 'totalTime' | 'avgUtilization' | 'solveTime' | 'unassigned';

interface ColumnDef {
  key: NumericKey;
  label: string;
  unit: string;
  format: (v: number) => string;
  lowerIsBetter: boolean;
}

const columns: ColumnDef[] = [
  {
    key: 'totalDistance',
    label: 'Total Distance',
    unit: 'mi',
    format: (v) => v.toFixed(1),
    lowerIsBetter: true,
  },
  {
    key: 'totalTime',
    label: 'Total Time',
    unit: 'hrs',
    format: (v) => v.toFixed(1),
    lowerIsBetter: true,
  },
  {
    key: 'avgUtilization',
    label: 'Avg Utilization',
    unit: '%',
    format: (v) => v.toFixed(1),
    lowerIsBetter: false,
  },
  {
    key: 'solveTime',
    label: 'Solve Time',
    unit: 's',
    format: (v) => v.toFixed(1),
    lowerIsBetter: true,
  },
  {
    key: 'unassigned',
    label: 'Unassigned',
    unit: '',
    format: (v) => v.toFixed(0),
    lowerIsBetter: true,
  },
];

function findBest(data: AlgorithmComparisonRow[], key: NumericKey, lowerIsBetter: boolean): number {
  const values = data.map((d) => d[key]);
  return lowerIsBetter ? Math.min(...values) : Math.max(...values);
}

export default function AlgorithmComparison({ data }: AlgorithmComparisonProps) {
  const bestValues: Record<string, number> = {};
  columns.forEach((col) => {
    bestValues[col.key] = findBest(data, col.key, col.lowerIsBetter);
  });

  return (
    <div className="card">
      <div className="card-header flex items-center justify-between">
        <div>
          <h3 className="text-sm font-semibold text-neutral-900">
            Algorithm Comparison
          </h3>
          <p className="text-xs text-neutral-500 mt-0.5">
            Performance across optimization strategies
          </p>
        </div>
        <TrophyIcon className="h-5 w-5 text-warning-500" />
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-100">
              <th className="px-6 py-3 text-left text-xs font-semibold text-neutral-500 uppercase tracking-wider">
                Algorithm
              </th>
              {columns.map((col) => (
                <th
                  key={col.key}
                  className="px-4 py-3 text-right text-xs font-semibold text-neutral-500 uppercase tracking-wider"
                >
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-50">
            {data.map((row, rowIdx) => (
              <tr
                key={row.algorithm}
                className={clsx(
                  'transition-colors hover:bg-neutral-50',
                  rowIdx === 0 && 'bg-success-50/30'
                )}
              >
                <td className="px-6 py-3.5 font-medium text-neutral-900 whitespace-nowrap">
                  <div className="flex items-center gap-2">
                    {rowIdx === 0 && (
                      <span className="flex h-5 w-5 items-center justify-center rounded-full bg-success-100">
                        <TrophyIcon className="h-3 w-3 text-success-600" />
                      </span>
                    )}
                    {row.algorithm}
                  </div>
                </td>
                {columns.map((col) => {
                  const value = row[col.key];
                  const isBest = value === bestValues[col.key];

                  return (
                    <td
                      key={col.key}
                      className={clsx(
                        'px-4 py-3.5 text-right whitespace-nowrap tabular-nums',
                        isBest
                          ? 'font-bold text-success-700'
                          : 'text-neutral-600'
                      )}
                    >
                      {col.format(value)}
                      {col.unit && (
                        <span className="ml-1 text-xs text-neutral-400">
                          {col.unit}
                        </span>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
