import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import FilterPanel from '@/components/Filters/FilterPanel';
import type { Technician, FilterState } from '@/types';

// Mock heroicons
jest.mock('@heroicons/react/24/outline', () => ({
  CalendarDaysIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="calendar-icon" {...props} />,
  ChevronUpDownIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="chevron-icon" {...props} />,
  CheckIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="check-icon" {...props} />,
  FunnelIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="funnel-icon" {...props} />,
  ArrowPathIcon: (props: React.SVGProps<SVGSVGElement>) => <svg data-testid="arrow-path-icon" {...props} />,
}));

const mockTechnicians: Technician[] = [
  {
    id: 'tech-1',
    name: 'John Doe',
    email: 'john@example.com',
    skills: ['plumbing'],
    homeBase: { lat: 39.7392, lng: -104.9903 },
    availabilityStatus: 'available',
    maxDailyHours: 8,
  },
  {
    id: 'tech-2',
    name: 'Jane Smith',
    email: 'jane@example.com',
    skills: ['electrical'],
    homeBase: { lat: 39.7392, lng: -104.9903 },
    availabilityStatus: 'available',
    maxDailyHours: 8,
  },
];

const defaultFilters: FilterState = {
  date: '2026-02-12',
  technicianIds: [],
  zoneId: '',
  priority: '',
  algorithm: '',
};

describe('FilterPanel', () => {
  const defaultProps = {
    technicians: mockTechnicians,
    filters: defaultFilters,
    onFiltersChange: jest.fn(),
    onApply: jest.fn(),
    onReset: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders the Filters label', () => {
    render(<FilterPanel {...defaultProps} />);
    expect(screen.getByText('Filters')).toBeInTheDocument();
  });

  it('renders date input with correct value', () => {
    render(<FilterPanel {...defaultProps} />);
    const dateInput = screen.getByDisplayValue('2026-02-12');
    expect(dateInput).toBeInTheDocument();
    expect(dateInput).toHaveAttribute('type', 'date');
  });

  it('renders Apply and Reset buttons', () => {
    render(<FilterPanel {...defaultProps} />);
    expect(screen.getByText('Apply Filters')).toBeInTheDocument();
    expect(screen.getByText('Reset')).toBeInTheDocument();
  });

  it('calls onReset when Reset is clicked', () => {
    const onReset = jest.fn();
    render(<FilterPanel {...defaultProps} onReset={onReset} />);
    fireEvent.click(screen.getByText('Reset'));
    expect(onReset).toHaveBeenCalledTimes(1);
  });

  it('calls onApply when Apply Filters is clicked', () => {
    const onApply = jest.fn();
    render(<FilterPanel {...defaultProps} onApply={onApply} />);
    fireEvent.click(screen.getByText('Apply Filters'));
    expect(onApply).toHaveBeenCalledTimes(1);
  });

  it('calls onFiltersChange when date is changed', () => {
    const onFiltersChange = jest.fn();
    render(<FilterPanel {...defaultProps} onFiltersChange={onFiltersChange} />);
    const dateInput = screen.getByDisplayValue('2026-02-12');
    fireEvent.change(dateInput, { target: { value: '2026-03-01' } });
    expect(onFiltersChange).toHaveBeenCalledWith({
      ...defaultFilters,
      date: '2026-03-01',
    });
  });

  it('shows "All Technicians" when no technicians selected', () => {
    render(<FilterPanel {...defaultProps} />);
    expect(screen.getByText('All Technicians')).toBeInTheDocument();
  });
});
