import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import Sidebar from '@/components/Layout/Sidebar';

// Mock heroicons
jest.mock('@heroicons/react/24/outline', () => ({
  HomeIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="home-icon" {...props} />,
  MapIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="map-icon" {...props} />,
  UserGroupIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="user-group-icon" {...props} />,
  ClipboardDocumentListIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="clipboard-icon" {...props} />,
  ChartBarIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="chart-bar-icon" {...props} />,
  XMarkIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="x-mark-icon" {...props} />,
}));

describe('Sidebar', () => {
  const defaultProps = {
    currentPath: '/',
    mobileOpen: false,
    onClose: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders all navigation items', () => {
    render(<Sidebar {...defaultProps} />);

    expect(screen.getByText('Dashboard')).toBeInTheDocument();
    expect(screen.getByText('Routes')).toBeInTheDocument();
    expect(screen.getByText('Technicians')).toBeInTheDocument();
    expect(screen.getByText('Work Orders')).toBeInTheDocument();
    expect(screen.getByText('Analytics')).toBeInTheDocument();
  });

  it('highlights active navigation item based on currentPath', () => {
    render(<Sidebar {...defaultProps} currentPath="/routes" />);

    const routesLink = screen.getByText('Routes').closest('a');
    const dashboardLink = screen.getByText('Dashboard').closest('a');

    expect(routesLink).toHaveClass('bg-primary-600/20');
    expect(routesLink).toHaveClass('text-primary-400');
    expect(dashboardLink).toHaveClass('text-neutral-400');
  });

  it('shows brand name "Polaris"', () => {
    render(<Sidebar {...defaultProps} />);
    expect(screen.getByText('Polaris')).toBeInTheDocument();
  });

  it('shows version "v1.0.0"', () => {
    render(<Sidebar {...defaultProps} />);
    expect(screen.getByText('v1.0.0')).toBeInTheDocument();
  });

  it('applies -translate-x-full when mobileOpen is false', () => {
    const { container } = render(<Sidebar {...defaultProps} mobileOpen={false} />);
    const aside = container.querySelector('aside');
    expect(aside).toHaveClass('-translate-x-full');
  });

  it('applies translate-x-0 when mobileOpen is true', () => {
    const { container } = render(<Sidebar {...defaultProps} mobileOpen={true} />);
    const aside = container.querySelector('aside');
    expect(aside).toHaveClass('translate-x-0');
  });

  it('calls onClose when close button is clicked', () => {
    const onClose = jest.fn();
    render(<Sidebar {...defaultProps} mobileOpen={true} onClose={onClose} />);

    const closeButton = screen.getByTestId('x-mark-icon').closest('button');
    fireEvent.click(closeButton!);
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('calls onClose when mobile overlay is clicked', () => {
    const onClose = jest.fn();
    const { container } = render(
      <Sidebar {...defaultProps} mobileOpen={true} onClose={onClose} />
    );

    // The overlay is a div with fixed inset-0 class that appears when mobileOpen is true
    const overlay = container.querySelector('.fixed.inset-0.z-40');
    expect(overlay).toBeInTheDocument();
    fireEvent.click(overlay!);
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
