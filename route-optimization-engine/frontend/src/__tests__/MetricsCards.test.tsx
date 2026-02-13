import React from 'react';
import { render, screen } from '@testing-library/react';
import MetricsCards from '@/components/Dashboard/MetricsCards';
import type { DashboardMetrics } from '@/types';

// Mock heroicons to avoid SVG rendering issues
jest.mock('@heroicons/react/24/outline', () => ({
  MapIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="map-icon" {...props} />,
  TruckIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="truck-icon" {...props} />,
  ClockIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="clock-icon" {...props} />,
  ChartBarIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="chart-bar-icon" {...props} />,
  ArrowTrendingUpIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="arrow-trending-up-icon" {...props} />,
  ExclamationTriangleIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="exclamation-triangle-icon" {...props} />,
}));

const mockMetrics: DashboardMetrics = {
  totalRoutes: 12,
  totalDistance: 245.6,
  totalDuration: 18.3,
  avgUtilization: 87.5,
  improvementVsBaseline: 14.2,
  unassignedOrders: 3,
};

describe('MetricsCards', () => {
  it('renders loading skeletons when loading=true', () => {
    const { container } = render(
      <MetricsCards metrics={mockMetrics} loading={true} />
    );
    const skeletons = container.querySelectorAll('.animate-pulse');
    expect(skeletons.length).toBe(6);
  });

  it('renders all 6 metric labels when loaded', () => {
    render(<MetricsCards metrics={mockMetrics} loading={false} />);

    expect(screen.getByText('Total Routes')).toBeInTheDocument();
    expect(screen.getByText('Total Distance')).toBeInTheDocument();
    expect(screen.getByText('Total Duration')).toBeInTheDocument();
    expect(screen.getByText('Avg Utilization')).toBeInTheDocument();
    expect(screen.getByText('vs Baseline')).toBeInTheDocument();
    expect(screen.getByText('Unassigned Orders')).toBeInTheDocument();
  });

  it('displays formatted metric values correctly', () => {
    render(<MetricsCards metrics={mockMetrics} loading={false} />);

    // totalRoutes formatted as integer: "12"
    expect(screen.getByText('12')).toBeInTheDocument();
    // totalDistance formatted to 1 decimal: "245.6"
    expect(screen.getByText('245.6')).toBeInTheDocument();
    // totalDuration formatted to 1 decimal: "18.3"
    expect(screen.getByText('18.3')).toBeInTheDocument();
    // avgUtilization formatted to 1 decimal: "87.5"
    expect(screen.getByText('87.5')).toBeInTheDocument();
    // improvementVsBaseline formatted as "+14.2"
    expect(screen.getByText('+14.2')).toBeInTheDocument();
    // unassignedOrders formatted as integer: "3"
    expect(screen.getByText('3')).toBeInTheDocument();
  });

  it('shows suffix units (mi, hrs, %)', () => {
    render(<MetricsCards metrics={mockMetrics} loading={false} />);

    expect(screen.getByText('mi')).toBeInTheDocument();
    expect(screen.getByText('hrs')).toBeInTheDocument();
    // Two "%" suffixes: one for avgUtilization, one for improvementVsBaseline
    const percentElements = screen.getAllByText('%');
    expect(percentElements.length).toBe(2);
  });
});
