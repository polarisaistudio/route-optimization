'use client';

import React, { Fragment, useState } from 'react';
import { Listbox, Transition } from '@headlessui/react';
import {
  CalendarDaysIcon,
  ChevronUpDownIcon,
  CheckIcon,
  FunnelIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';
import clsx from 'clsx';
import type { Technician, FilterState } from '@/types';

interface FilterPanelProps {
  technicians: Technician[];
  filters: FilterState;
  onFiltersChange: (filters: FilterState) => void;
  onApply: () => void;
  onReset: () => void;
}

const priorities = [
  { value: '', label: 'All Priorities' },
  { value: 'emergency', label: 'Emergency' },
  { value: 'high', label: 'High' },
  { value: 'medium', label: 'Medium' },
  { value: 'low', label: 'Low' },
];

const algorithms = [
  { value: '', label: 'All Algorithms' },
  { value: 'vrp', label: 'VRP (OR-Tools)' },
  { value: 'greedy', label: 'Greedy Nearest' },
  { value: 'genetic', label: 'Genetic Algorithm' },
];

const zones = [
  { value: '', label: 'All Zones' },
  { value: 'zone-north', label: 'North Denver' },
  { value: 'zone-south', label: 'South Denver' },
  { value: 'zone-east', label: 'East Denver' },
  { value: 'zone-west', label: 'West Denver' },
  { value: 'zone-central', label: 'Central Denver' },
];

export default function FilterPanel({
  technicians,
  filters,
  onFiltersChange,
  onApply,
  onReset,
}: FilterPanelProps) {
  const selectedTechs = technicians.filter((t) =>
    filters.technicianIds.includes(t.id)
  );

  const techLabel =
    selectedTechs.length === 0
      ? 'All Technicians'
      : selectedTechs.length === 1
        ? selectedTechs[0].name
        : `${selectedTechs.length} technicians`;

  return (
    <div className="card">
      <div className="px-5 py-3.5 flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2 text-sm font-semibold text-neutral-700">
          <FunnelIcon className="h-4 w-4 text-neutral-400" />
          Filters
        </div>

        <div className="h-5 w-px bg-neutral-200 hidden sm:block" />

        {/* Date picker */}
        <div className="relative">
          <CalendarDaysIcon className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-neutral-400" />
          <input
            type="date"
            value={filters.date}
            onChange={(e) =>
              onFiltersChange({ ...filters, date: e.target.value })
            }
            className="rounded-lg border border-neutral-300 bg-white pl-9 pr-3 py-1.5 text-sm text-neutral-700 focus:border-primary-500 focus:ring-1 focus:ring-primary-500 outline-none"
          />
        </div>

        {/* Technician multi-select */}
        <Listbox
          value={filters.technicianIds}
          onChange={(ids: string[]) =>
            onFiltersChange({ ...filters, technicianIds: ids })
          }
          multiple
        >
          <div className="relative">
            <Listbox.Button className="relative w-48 rounded-lg border border-neutral-300 bg-white py-1.5 pl-3 pr-10 text-left text-sm text-neutral-700 cursor-pointer focus:border-primary-500 focus:ring-1 focus:ring-primary-500 outline-none">
              <span className="block truncate">{techLabel}</span>
              <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
                <ChevronUpDownIcon className="h-4 w-4 text-neutral-400" />
              </span>
            </Listbox.Button>
            <Transition
              as={Fragment}
              leave="transition ease-in duration-100"
              leaveFrom="opacity-100"
              leaveTo="opacity-0"
            >
              <Listbox.Options className="absolute z-10 mt-1 max-h-60 w-56 overflow-auto rounded-lg bg-white py-1 shadow-lg ring-1 ring-neutral-200 focus:outline-none text-sm">
                {technicians.map((tech) => (
                  <Listbox.Option
                    key={tech.id}
                    value={tech.id}
                    className={({ active }) =>
                      clsx(
                        'relative cursor-pointer select-none py-2 pl-10 pr-4',
                        active ? 'bg-primary-50 text-primary-900' : 'text-neutral-700'
                      )
                    }
                  >
                    {({ selected }) => (
                      <>
                        <span
                          className={clsx(
                            'block truncate',
                            selected ? 'font-semibold' : 'font-normal'
                          )}
                        >
                          {tech.name}
                        </span>
                        {selected && (
                          <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-primary-600">
                            <CheckIcon className="h-4 w-4" />
                          </span>
                        )}
                      </>
                    )}
                  </Listbox.Option>
                ))}
              </Listbox.Options>
            </Transition>
          </div>
        </Listbox>

        {/* Zone filter */}
        <Listbox
          value={filters.zoneId}
          onChange={(val: string) =>
            onFiltersChange({ ...filters, zoneId: val })
          }
        >
          <div className="relative">
            <Listbox.Button className="relative w-40 rounded-lg border border-neutral-300 bg-white py-1.5 pl-3 pr-10 text-left text-sm text-neutral-700 cursor-pointer focus:border-primary-500 focus:ring-1 focus:ring-primary-500 outline-none">
              <span className="block truncate">
                {zones.find((z) => z.value === filters.zoneId)?.label || 'All Zones'}
              </span>
              <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
                <ChevronUpDownIcon className="h-4 w-4 text-neutral-400" />
              </span>
            </Listbox.Button>
            <Transition
              as={Fragment}
              leave="transition ease-in duration-100"
              leaveFrom="opacity-100"
              leaveTo="opacity-0"
            >
              <Listbox.Options className="absolute z-10 mt-1 max-h-60 w-48 overflow-auto rounded-lg bg-white py-1 shadow-lg ring-1 ring-neutral-200 focus:outline-none text-sm">
                {zones.map((zone) => (
                  <Listbox.Option
                    key={zone.value}
                    value={zone.value}
                    className={({ active }) =>
                      clsx(
                        'relative cursor-pointer select-none py-2 pl-10 pr-4',
                        active ? 'bg-primary-50 text-primary-900' : 'text-neutral-700'
                      )
                    }
                  >
                    {({ selected }) => (
                      <>
                        <span
                          className={clsx(
                            'block truncate',
                            selected ? 'font-semibold' : 'font-normal'
                          )}
                        >
                          {zone.label}
                        </span>
                        {selected && (
                          <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-primary-600">
                            <CheckIcon className="h-4 w-4" />
                          </span>
                        )}
                      </>
                    )}
                  </Listbox.Option>
                ))}
              </Listbox.Options>
            </Transition>
          </div>
        </Listbox>

        {/* Priority filter */}
        <Listbox
          value={filters.priority}
          onChange={(val: string) =>
            onFiltersChange({ ...filters, priority: val })
          }
        >
          <div className="relative">
            <Listbox.Button className="relative w-36 rounded-lg border border-neutral-300 bg-white py-1.5 pl-3 pr-10 text-left text-sm text-neutral-700 cursor-pointer focus:border-primary-500 focus:ring-1 focus:ring-primary-500 outline-none">
              <span className="block truncate">
                {priorities.find((p) => p.value === filters.priority)?.label ||
                  'All Priorities'}
              </span>
              <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
                <ChevronUpDownIcon className="h-4 w-4 text-neutral-400" />
              </span>
            </Listbox.Button>
            <Transition
              as={Fragment}
              leave="transition ease-in duration-100"
              leaveFrom="opacity-100"
              leaveTo="opacity-0"
            >
              <Listbox.Options className="absolute z-10 mt-1 max-h-60 w-44 overflow-auto rounded-lg bg-white py-1 shadow-lg ring-1 ring-neutral-200 focus:outline-none text-sm">
                {priorities.map((p) => (
                  <Listbox.Option
                    key={p.value}
                    value={p.value}
                    className={({ active }) =>
                      clsx(
                        'relative cursor-pointer select-none py-2 pl-10 pr-4',
                        active ? 'bg-primary-50 text-primary-900' : 'text-neutral-700'
                      )
                    }
                  >
                    {({ selected }) => (
                      <>
                        <span
                          className={clsx(
                            'block truncate',
                            selected ? 'font-semibold' : 'font-normal'
                          )}
                        >
                          {p.label}
                        </span>
                        {selected && (
                          <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-primary-600">
                            <CheckIcon className="h-4 w-4" />
                          </span>
                        )}
                      </>
                    )}
                  </Listbox.Option>
                ))}
              </Listbox.Options>
            </Transition>
          </div>
        </Listbox>

        {/* Algorithm selector */}
        <Listbox
          value={filters.algorithm}
          onChange={(val: string) =>
            onFiltersChange({ ...filters, algorithm: val })
          }
        >
          <div className="relative">
            <Listbox.Button className="relative w-44 rounded-lg border border-neutral-300 bg-white py-1.5 pl-3 pr-10 text-left text-sm text-neutral-700 cursor-pointer focus:border-primary-500 focus:ring-1 focus:ring-primary-500 outline-none">
              <span className="block truncate">
                {algorithms.find((a) => a.value === filters.algorithm)?.label ||
                  'All Algorithms'}
              </span>
              <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
                <ChevronUpDownIcon className="h-4 w-4 text-neutral-400" />
              </span>
            </Listbox.Button>
            <Transition
              as={Fragment}
              leave="transition ease-in duration-100"
              leaveFrom="opacity-100"
              leaveTo="opacity-0"
            >
              <Listbox.Options className="absolute z-10 mt-1 max-h-60 w-48 overflow-auto rounded-lg bg-white py-1 shadow-lg ring-1 ring-neutral-200 focus:outline-none text-sm">
                {algorithms.map((a) => (
                  <Listbox.Option
                    key={a.value}
                    value={a.value}
                    className={({ active }) =>
                      clsx(
                        'relative cursor-pointer select-none py-2 pl-10 pr-4',
                        active ? 'bg-primary-50 text-primary-900' : 'text-neutral-700'
                      )
                    }
                  >
                    {({ selected }) => (
                      <>
                        <span
                          className={clsx(
                            'block truncate',
                            selected ? 'font-semibold' : 'font-normal'
                          )}
                        >
                          {a.label}
                        </span>
                        {selected && (
                          <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-primary-600">
                            <CheckIcon className="h-4 w-4" />
                          </span>
                        )}
                      </>
                    )}
                  </Listbox.Option>
                ))}
              </Listbox.Options>
            </Transition>
          </div>
        </Listbox>

        {/* Spacer */}
        <div className="flex-1" />

        {/* Action buttons */}
        <div className="flex items-center gap-2">
          <button onClick={onReset} className="btn-secondary text-xs gap-1.5">
            <ArrowPathIcon className="h-3.5 w-3.5" />
            Reset
          </button>
          <button onClick={onApply} className="btn-primary text-xs">
            Apply Filters
          </button>
        </div>
      </div>
    </div>
  );
}
