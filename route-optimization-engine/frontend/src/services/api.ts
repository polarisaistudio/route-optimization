import axios, { AxiosInstance, AxiosError } from 'axios';
import type {
  Route,
  Technician,
  WorkOrder,
  OptimizationConfig,
  OptimizationRun,
  DashboardMetrics,
} from '@/types';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';

const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    const message =
      error.response?.data &&
      typeof error.response.data === 'object' &&
      'message' in error.response.data
        ? (error.response.data as { message: string }).message
        : error.message;

    console.error(`API Error [${error.config?.method?.toUpperCase()} ${error.config?.url}]:`, message);
    return Promise.reject(new Error(message));
  }
);

export interface ApiResponse<T> {
  data: T;
  success: boolean;
  error?: string;
}

async function apiCall<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('An unexpected error occurred');
  }
}

export async function getRoutes(date: string): Promise<Route[]> {
  return apiCall(async () => {
    const response = await apiClient.get<ApiResponse<Route[]>>('/api/routes', {
      params: { date },
    });
    return response.data.data;
  });
}

export async function getRouteById(id: string): Promise<Route> {
  return apiCall(async () => {
    const response = await apiClient.get<ApiResponse<Route>>(`/api/routes/${id}`);
    return response.data.data;
  });
}

export async function getTechnicians(): Promise<Technician[]> {
  return apiCall(async () => {
    const response = await apiClient.get<ApiResponse<Technician[]>>('/api/technicians');
    return response.data.data;
  });
}

export async function getWorkOrders(filters?: {
  status?: string;
  priority?: string;
  date?: string;
}): Promise<WorkOrder[]> {
  return apiCall(async () => {
    const response = await apiClient.get<ApiResponse<WorkOrder[]>>('/api/work-orders', {
      params: filters,
    });
    return response.data.data;
  });
}

export async function runOptimization(
  config: OptimizationConfig
): Promise<OptimizationRun> {
  return apiCall(async () => {
    const response = await apiClient.post<ApiResponse<OptimizationRun>>(
      '/api/optimization/run',
      config
    );
    return response.data.data;
  });
}

export async function getOptimizationStatus(
  runId: string
): Promise<OptimizationRun> {
  return apiCall(async () => {
    const response = await apiClient.get<ApiResponse<OptimizationRun>>(
      `/api/optimization/${runId}`
    );
    return response.data.data;
  });
}

export async function getDashboardMetrics(
  date: string
): Promise<DashboardMetrics> {
  return apiCall(async () => {
    const response = await apiClient.get<ApiResponse<DashboardMetrics>>(
      '/api/dashboard/metrics',
      { params: { date } }
    );
    return response.data.data;
  });
}

export default apiClient;
