export interface Property {
  id: string;
  address: string;
  city: string;
  state: string;
  zipCode: string;
  lat: number;
  lng: number;
  propertyType: 'residential' | 'commercial' | 'industrial' | 'mixed-use';
  zoneId: string;
}

export interface Technician {
  id: string;
  name: string;
  email: string;
  skills: string[];
  homeBase: {
    lat: number;
    lng: number;
  };
  availabilityStatus: 'available' | 'on-route' | 'off-duty' | 'on-break';
  maxDailyHours: number;
}

export interface WorkOrder {
  id: string;
  propertyId: string;
  title: string;
  category: 'inspection' | 'maintenance' | 'repair' | 'installation' | 'emergency';
  priority: 'emergency' | 'high' | 'medium' | 'low';
  requiredSkills: string[];
  estimatedDurationMinutes: number;
  timeWindowStart: string;
  timeWindowEnd: string;
  status: 'pending' | 'assigned' | 'in-progress' | 'completed' | 'cancelled';
}

export interface RouteStop {
  sequence: number;
  workOrderId: string;
  lat: number;
  lng: number;
  arrivalTime: string;
  departureTime: string;
  travelDistanceMiles: number;
  travelDurationMinutes: number;
  workOrder: {
    title: string;
    category: string;
    priority: string;
  };
}

export interface RouteSummary {
  totalDistanceMiles: number;
  totalDurationMinutes: number;
  totalWorkMinutes: number;
  totalTravelMinutes: number;
  numStops: number;
  utilizationPercent: number;
}

export interface Route {
  id: string;
  technicianId: string;
  technicianName: string;
  routeDate: string;
  stops: RouteStop[];
  summary: RouteSummary;
  algorithmUsed: 'vrp' | 'greedy' | 'genetic';
  status: 'planned' | 'in-progress' | 'completed' | 'cancelled';
}

export interface OptimizationConfig {
  date: string;
  algorithm: 'vrp' | 'greedy' | 'genetic';
  maxTravelMinutes?: number;
  balanceWorkload?: boolean;
  prioritizeEmergency?: boolean;
}

export interface OptimizationRun {
  id: string;
  runDate: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  config: OptimizationConfig;
  results: {
    routes: Route[];
    totalDistance: number;
    totalDuration: number;
    unassignedOrders: number;
    solveTimeMs: number;
  } | null;
}

export interface DashboardMetrics {
  totalRoutes: number;
  totalDistance: number;
  totalDuration: number;
  avgUtilization: number;
  improvementVsBaseline: number;
  unassignedOrders: number;
}

export interface AlgorithmComparisonRow {
  algorithm: string;
  totalDistance: number;
  totalTime: number;
  avgUtilization: number;
  solveTime: number;
  unassigned: number;
}

export interface DailyTrendPoint {
  date: string;
  totalDistance: number;
  totalDuration: number;
  avgUtilization: number;
}

export interface FilterState {
  date: string;
  technicianIds: string[];
  zoneId: string;
  priority: string;
  algorithm: string;
}
