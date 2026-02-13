jest.mock('axios', () => {
  const mockAxiosInstance = {
    get: jest.fn(),
    post: jest.fn(),
    interceptors: {
      response: { use: jest.fn() },
      request: { use: jest.fn() },
    },
  };
  return {
    __esModule: true,
    default: { create: jest.fn(() => mockAxiosInstance) },
    create: jest.fn(() => mockAxiosInstance),
  };
});

import axios from 'axios';
import {
  getRoutes,
  getTechnicians,
  getWorkOrders,
  runOptimization,
  getDashboardMetrics,
} from '@/services/api';

// Get the mocked axios instance
const mockedAxios = axios as jest.Mocked<typeof axios>;
const mockInstance = mockedAxios.create() as jest.Mocked<ReturnType<typeof axios.create>>;

describe('API Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Re-obtain the mock instance since create is called on module load
    (mockInstance.get as jest.Mock).mockReset();
    (mockInstance.post as jest.Mock).mockReset();
  });

  describe('getRoutes', () => {
    it('calls get with correct URL and params', async () => {
      const mockRoutes = [{ id: 'route-1', technicianName: 'John' }];
      (mockInstance.get as jest.Mock).mockResolvedValue({
        data: { data: mockRoutes },
      });

      const result = await getRoutes('2026-02-12');

      expect(mockInstance.get).toHaveBeenCalledWith('/api/routes', {
        params: { date: '2026-02-12' },
      });
      expect(result).toEqual(mockRoutes);
    });
  });

  describe('getTechnicians', () => {
    it('calls get with correct URL', async () => {
      const mockTechs = [{ id: 'tech-1', name: 'John' }];
      (mockInstance.get as jest.Mock).mockResolvedValue({
        data: { data: mockTechs },
      });

      const result = await getTechnicians();

      expect(mockInstance.get).toHaveBeenCalledWith('/api/technicians');
      expect(result).toEqual(mockTechs);
    });
  });

  describe('getWorkOrders', () => {
    it('passes filter params', async () => {
      const mockOrders = [{ id: 'wo-1', title: 'Fix pipe' }];
      const filters = { status: 'pending', priority: 'high' };
      (mockInstance.get as jest.Mock).mockResolvedValue({
        data: { data: mockOrders },
      });

      const result = await getWorkOrders(filters);

      expect(mockInstance.get).toHaveBeenCalledWith('/api/work-orders', {
        params: filters,
      });
      expect(result).toEqual(mockOrders);
    });
  });

  describe('runOptimization', () => {
    it('posts to correct URL with config body', async () => {
      const mockRun = { id: 'run-1', status: 'running' };
      const config = { date: '2026-02-12', algorithm: 'vrp' as const };
      (mockInstance.post as jest.Mock).mockResolvedValue({
        data: { data: mockRun },
      });

      const result = await runOptimization(config);

      expect(mockInstance.post).toHaveBeenCalledWith(
        '/api/optimization/run',
        config
      );
      expect(result).toEqual(mockRun);
    });
  });

  describe('getDashboardMetrics', () => {
    it('calls get with date param', async () => {
      const mockMetrics = { totalRoutes: 5, totalDistance: 120 };
      (mockInstance.get as jest.Mock).mockResolvedValue({
        data: { data: mockMetrics },
      });

      const result = await getDashboardMetrics('2026-02-12');

      expect(mockInstance.get).toHaveBeenCalledWith('/api/dashboard/metrics', {
        params: { date: '2026-02-12' },
      });
      expect(result).toEqual(mockMetrics);
    });
  });

  describe('return values', () => {
    it('functions return response.data.data', async () => {
      const innerData = { totalRoutes: 10 };
      (mockInstance.get as jest.Mock).mockResolvedValue({
        data: { data: innerData, success: true },
      });

      const result = await getDashboardMetrics('2026-02-12');
      expect(result).toEqual(innerData);
      // Verify it doesn't return the wrapper
      expect(result).not.toHaveProperty('success');
    });
  });
});
