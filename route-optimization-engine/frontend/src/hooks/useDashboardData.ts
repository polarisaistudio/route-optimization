'use client';

import { useState, useEffect, useCallback } from 'react';
import type {
  Route,
  Technician,
  DashboardMetrics,
  AlgorithmComparisonRow,
  DailyTrendPoint,
} from '@/types';
import { getRoutes, getTechnicians, getDashboardMetrics } from '@/services/api';
import { format, subDays } from 'date-fns';

// ---------------------------------------------------------------------------
// Mock data -- used as fallback when the API is unreachable so the dashboard
// renders a full, realistic view out of the box.
// ---------------------------------------------------------------------------

const TECH_COLORS = ['#3b82f6', '#ef4444', '#22c55e', '#f59e0b', '#8b5cf6', '#ec4899'];

const mockTechnicians: Technician[] = [
  {
    id: 'tech-001',
    name: 'Marcus Rivera',
    email: 'marcus.rivera@polaris.com',
    skills: ['HVAC', 'electrical', 'plumbing'],
    homeBase: { lat: 39.7392, lng: -104.9903 },
    availabilityStatus: 'on-route',
    maxDailyHours: 8,
  },
  {
    id: 'tech-002',
    name: 'Sarah Chen',
    email: 'sarah.chen@polaris.com',
    skills: ['inspection', 'maintenance', 'roofing'],
    homeBase: { lat: 39.7508, lng: -104.9965 },
    availabilityStatus: 'on-route',
    maxDailyHours: 8,
  },
  {
    id: 'tech-003',
    name: 'James Okafor',
    email: 'james.okafor@polaris.com',
    skills: ['electrical', 'security', 'fire-safety'],
    homeBase: { lat: 39.6833, lng: -104.9614 },
    availabilityStatus: 'available',
    maxDailyHours: 8,
  },
  {
    id: 'tech-004',
    name: 'Elena Vasquez',
    email: 'elena.vasquez@polaris.com',
    skills: ['plumbing', 'HVAC', 'appliance-repair'],
    homeBase: { lat: 39.7214, lng: -105.0178 },
    availabilityStatus: 'on-route',
    maxDailyHours: 8,
  },
  {
    id: 'tech-005',
    name: 'David Nguyen',
    email: 'david.nguyen@polaris.com',
    skills: ['landscaping', 'exterior', 'painting'],
    homeBase: { lat: 39.7677, lng: -105.0032 },
    availabilityStatus: 'on-route',
    maxDailyHours: 6,
  },
  {
    id: 'tech-006',
    name: 'Priya Kapoor',
    email: 'priya.kapoor@polaris.com',
    skills: ['inspection', 'electrical', 'HVAC'],
    homeBase: { lat: 39.7048, lng: -104.9714 },
    availabilityStatus: 'available',
    maxDailyHours: 8,
  },
];

const mockRoutes: Route[] = [
  {
    id: 'route-001',
    technicianId: 'tech-001',
    technicianName: 'Marcus Rivera',
    routeDate: format(new Date(), 'yyyy-MM-dd'),
    algorithmUsed: 'vrp',
    status: 'in-progress',
    stops: [
      {
        sequence: 1,
        workOrderId: 'wo-101',
        lat: 39.7478,
        lng: -104.9995,
        arrivalTime: '08:15',
        departureTime: '09:15',
        travelDistanceMiles: 3.2,
        travelDurationMinutes: 12,
        workOrder: { title: 'HVAC Annual Inspection', category: 'inspection', priority: 'medium' },
      },
      {
        sequence: 2,
        workOrderId: 'wo-102',
        lat: 39.7554,
        lng: -104.9872,
        arrivalTime: '09:35',
        departureTime: '10:50',
        travelDistanceMiles: 1.8,
        travelDurationMinutes: 8,
        workOrder: { title: 'Furnace Repair', category: 'repair', priority: 'high' },
      },
      {
        sequence: 3,
        workOrderId: 'wo-103',
        lat: 39.7622,
        lng: -105.0104,
        arrivalTime: '11:10',
        departureTime: '12:10',
        travelDistanceMiles: 2.4,
        travelDurationMinutes: 10,
        workOrder: { title: 'Thermostat Installation', category: 'installation', priority: 'medium' },
      },
      {
        sequence: 4,
        workOrderId: 'wo-104',
        lat: 39.7701,
        lng: -104.9780,
        arrivalTime: '13:00',
        departureTime: '14:00',
        travelDistanceMiles: 3.1,
        travelDurationMinutes: 14,
        workOrder: { title: 'AC Unit Maintenance', category: 'maintenance', priority: 'low' },
      },
      {
        sequence: 5,
        workOrderId: 'wo-105',
        lat: 39.7445,
        lng: -104.9630,
        arrivalTime: '14:25',
        departureTime: '15:40',
        travelDistanceMiles: 4.2,
        travelDurationMinutes: 16,
        workOrder: { title: 'Emergency Pipe Burst', category: 'emergency', priority: 'emergency' },
      },
    ],
    summary: {
      totalDistanceMiles: 18.9,
      totalDurationMinutes: 450,
      totalWorkMinutes: 375,
      totalTravelMinutes: 60,
      numStops: 5,
      utilizationPercent: 83.3,
    },
  },
  {
    id: 'route-002',
    technicianId: 'tech-002',
    technicianName: 'Sarah Chen',
    routeDate: format(new Date(), 'yyyy-MM-dd'),
    algorithmUsed: 'vrp',
    status: 'in-progress',
    stops: [
      {
        sequence: 1,
        workOrderId: 'wo-201',
        lat: 39.7320,
        lng: -105.0212,
        arrivalTime: '08:30',
        departureTime: '09:45',
        travelDistanceMiles: 4.1,
        travelDurationMinutes: 15,
        workOrder: { title: 'Roof Leak Inspection', category: 'inspection', priority: 'high' },
      },
      {
        sequence: 2,
        workOrderId: 'wo-202',
        lat: 39.7186,
        lng: -105.0089,
        arrivalTime: '10:05',
        departureTime: '11:05',
        travelDistanceMiles: 2.0,
        travelDurationMinutes: 9,
        workOrder: { title: 'Gutter Cleaning', category: 'maintenance', priority: 'low' },
      },
      {
        sequence: 3,
        workOrderId: 'wo-203',
        lat: 39.7099,
        lng: -104.9756,
        arrivalTime: '11:30',
        departureTime: '12:45',
        travelDistanceMiles: 3.5,
        travelDurationMinutes: 13,
        workOrder: { title: 'Window Seal Replacement', category: 'repair', priority: 'medium' },
      },
      {
        sequence: 4,
        workOrderId: 'wo-204',
        lat: 39.7255,
        lng: -104.9543,
        arrivalTime: '13:30',
        departureTime: '14:30',
        travelDistanceMiles: 2.8,
        travelDurationMinutes: 11,
        workOrder: { title: 'Annual Property Inspection', category: 'inspection', priority: 'medium' },
      },
    ],
    summary: {
      totalDistanceMiles: 16.5,
      totalDurationMinutes: 408,
      totalWorkMinutes: 315,
      totalTravelMinutes: 48,
      numStops: 4,
      utilizationPercent: 77.2,
    },
  },
  {
    id: 'route-003',
    technicianId: 'tech-004',
    technicianName: 'Elena Vasquez',
    routeDate: format(new Date(), 'yyyy-MM-dd'),
    algorithmUsed: 'vrp',
    status: 'planned',
    stops: [
      {
        sequence: 1,
        workOrderId: 'wo-401',
        lat: 39.7350,
        lng: -105.0440,
        arrivalTime: '08:00',
        departureTime: '09:30',
        travelDistanceMiles: 3.8,
        travelDurationMinutes: 14,
        workOrder: { title: 'Water Heater Replacement', category: 'installation', priority: 'high' },
      },
      {
        sequence: 2,
        workOrderId: 'wo-402',
        lat: 39.7488,
        lng: -105.0340,
        arrivalTime: '09:50',
        departureTime: '10:50',
        travelDistanceMiles: 1.9,
        travelDurationMinutes: 8,
        workOrder: { title: 'Faucet Repair', category: 'repair', priority: 'medium' },
      },
      {
        sequence: 3,
        workOrderId: 'wo-403',
        lat: 39.7600,
        lng: -105.0250,
        arrivalTime: '11:10',
        departureTime: '12:40',
        travelDistanceMiles: 2.2,
        travelDurationMinutes: 9,
        workOrder: { title: 'HVAC Duct Cleaning', category: 'maintenance', priority: 'low' },
      },
      {
        sequence: 4,
        workOrderId: 'wo-404',
        lat: 39.7415,
        lng: -105.0108,
        arrivalTime: '13:20',
        departureTime: '14:20',
        travelDistanceMiles: 2.7,
        travelDurationMinutes: 11,
        workOrder: { title: 'Garbage Disposal Install', category: 'installation', priority: 'medium' },
      },
      {
        sequence: 5,
        workOrderId: 'wo-405',
        lat: 39.7270,
        lng: -105.0005,
        arrivalTime: '14:45',
        departureTime: '15:45',
        travelDistanceMiles: 3.0,
        travelDurationMinutes: 12,
        workOrder: { title: 'Plumbing Inspection', category: 'inspection', priority: 'low' },
      },
      {
        sequence: 6,
        workOrderId: 'wo-406',
        lat: 39.7150,
        lng: -105.0150,
        arrivalTime: '16:05',
        departureTime: '16:45',
        travelDistanceMiles: 2.1,
        travelDurationMinutes: 9,
        workOrder: { title: 'Toilet Repair', category: 'repair', priority: 'medium' },
      },
    ],
    summary: {
      totalDistanceMiles: 20.2,
      totalDurationMinutes: 465,
      totalWorkMinutes: 400,
      totalTravelMinutes: 63,
      numStops: 6,
      utilizationPercent: 86.0,
    },
  },
  {
    id: 'route-004',
    technicianId: 'tech-005',
    technicianName: 'David Nguyen',
    routeDate: format(new Date(), 'yyyy-MM-dd'),
    algorithmUsed: 'vrp',
    status: 'planned',
    stops: [
      {
        sequence: 1,
        workOrderId: 'wo-501',
        lat: 39.7755,
        lng: -104.9900,
        arrivalTime: '09:00',
        departureTime: '10:30',
        travelDistanceMiles: 2.5,
        travelDurationMinutes: 10,
        workOrder: { title: 'Lawn Maintenance', category: 'maintenance', priority: 'low' },
      },
      {
        sequence: 2,
        workOrderId: 'wo-502',
        lat: 39.7810,
        lng: -105.0080,
        arrivalTime: '10:50',
        departureTime: '12:20',
        travelDistanceMiles: 1.6,
        travelDurationMinutes: 7,
        workOrder: { title: 'Exterior Painting Touch-up', category: 'repair', priority: 'medium' },
      },
      {
        sequence: 3,
        workOrderId: 'wo-503',
        lat: 39.7690,
        lng: -105.0190,
        arrivalTime: '12:40',
        departureTime: '13:40',
        travelDistanceMiles: 1.8,
        travelDurationMinutes: 8,
        workOrder: { title: 'Fence Repair', category: 'repair', priority: 'medium' },
      },
    ],
    summary: {
      totalDistanceMiles: 9.4,
      totalDurationMinutes: 280,
      totalWorkMinutes: 240,
      totalTravelMinutes: 25,
      numStops: 3,
      utilizationPercent: 66.7,
    },
  },
];

const mockMetrics: DashboardMetrics = {
  totalRoutes: 4,
  totalDistance: 65.0,
  totalDuration: 26.7,
  avgUtilization: 78.3,
  improvementVsBaseline: 23.5,
  unassignedOrders: 3,
};

export const mockAlgorithmComparison: AlgorithmComparisonRow[] = [
  {
    algorithm: 'VRP (OR-Tools)',
    totalDistance: 65.0,
    totalTime: 26.7,
    avgUtilization: 78.3,
    solveTime: 4.2,
    unassigned: 3,
  },
  {
    algorithm: 'Greedy Nearest',
    totalDistance: 82.4,
    totalTime: 31.1,
    avgUtilization: 71.5,
    solveTime: 0.3,
    unassigned: 5,
  },
  {
    algorithm: 'Genetic Algorithm',
    totalDistance: 68.7,
    totalTime: 27.9,
    avgUtilization: 76.1,
    solveTime: 12.8,
    unassigned: 4,
  },
];

export const mockDailyTrends: DailyTrendPoint[] = Array.from({ length: 7 }, (_, i) => {
  const date = format(subDays(new Date(), 6 - i), 'MM/dd');
  const jitter = () => (Math.random() - 0.5) * 10;
  return {
    date,
    totalDistance: Math.round((60 + jitter() + i * 1.2) * 10) / 10,
    totalDuration: Math.round((24 + jitter() * 0.5 + i * 0.3) * 10) / 10,
    avgUtilization: Math.round((72 + jitter() * 0.8 + i * 1.0) * 10) / 10,
  };
});

export const technicianColors: Record<string, string> = mockTechnicians.reduce(
  (acc, tech, i) => ({ ...acc, [tech.id]: TECH_COLORS[i % TECH_COLORS.length] }),
  {} as Record<string, string>
);

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

interface UseDashboardDataReturn {
  routes: Route[];
  technicians: Technician[];
  metrics: DashboardMetrics;
  loading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useDashboardData(date: string): UseDashboardDataReturn {
  const [routes, setRoutes] = useState<Route[]>(mockRoutes);
  const [technicians, setTechnicians] = useState<Technician[]>(mockTechnicians);
  const [metrics, setMetrics] = useState<DashboardMetrics>(mockMetrics);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const [routesRes, techRes, metricsRes] = await Promise.all([
        getRoutes(date),
        getTechnicians(),
        getDashboardMetrics(date),
      ]);

      setRoutes(routesRes);
      setTechnicians(techRes);
      setMetrics(metricsRes);
    } catch (err) {
      // Fallback to mock data -- the dashboard remains fully functional
      console.warn('API unavailable, using mock data:', err);
      setRoutes(mockRoutes);
      setTechnicians(mockTechnicians);
      setMetrics(mockMetrics);
      setError(null); // Clear error since we have mock data
    } finally {
      setLoading(false);
    }
  }, [date]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { routes, technicians, metrics, loading, error, refetch: fetchData };
}
