'use client';

import React, { useMemo } from 'react';
import {
  MapContainer,
  TileLayer,
  Polyline,
  Marker,
  Popup,
  CircleMarker,
} from 'react-leaflet';
import L from 'leaflet';
import type { Route, Technician } from '@/types';
import { technicianColors } from '@/hooks/useDashboardData';
import clsx from 'clsx';

// Fix default Leaflet marker icon paths (webpack / Next.js asset issue)
delete (L.Icon.Default.prototype as Record<string, unknown>)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

interface RouteMapProps {
  routes: Route[];
  technicians: Technician[];
  selectedTechIds?: string[];
}

const DENVER_CENTER: [number, number] = [39.7392, -104.9903];

function createStopIcon(color: string, sequence: number): L.DivIcon {
  return L.divIcon({
    className: '',
    html: `
      <div style="
        display: flex;
        align-items: center;
        justify-content: center;
        width: 26px;
        height: 26px;
        border-radius: 50%;
        background: ${color};
        color: white;
        font-size: 11px;
        font-weight: 700;
        border: 2px solid white;
        box-shadow: 0 2px 6px rgba(0,0,0,0.3);
      ">${sequence}</div>
    `,
    iconSize: [26, 26],
    iconAnchor: [13, 13],
  });
}

function createHomeIcon(color: string): L.DivIcon {
  return L.divIcon({
    className: '',
    html: `
      <div style="
        display: flex;
        align-items: center;
        justify-content: center;
        width: 30px;
        height: 30px;
        border-radius: 6px;
        background: ${color};
        color: white;
        font-size: 14px;
        border: 2px solid white;
        box-shadow: 0 2px 8px rgba(0,0,0,0.35);
      ">
        <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='currentColor' width='16' height='16'>
          <path fill-rule='evenodd' d='M9.293 2.293a1 1 0 011.414 0l7 7A1 1 0 0117 11h-1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-3a1 1 0 00-1-1H9a1 1 0 00-1 1v3a1 1 0 01-1 1H5a1 1 0 01-1-1v-6H3a1 1 0 01-.707-1.707l7-7z' clip-rule='evenodd'/>
        </svg>
      </div>
    `,
    iconSize: [30, 30],
    iconAnchor: [15, 15],
  });
}

const priorityBadge: Record<string, string> = {
  emergency: 'bg-danger-100 text-danger-800',
  high: 'bg-warning-100 text-warning-800',
  medium: 'bg-primary-100 text-primary-800',
  low: 'bg-neutral-100 text-neutral-700',
};

export default function RouteMap({
  routes,
  technicians,
  selectedTechIds,
}: RouteMapProps) {
  const filteredRoutes = useMemo(() => {
    if (!selectedTechIds || selectedTechIds.length === 0) return routes;
    return routes.filter((r) => selectedTechIds.includes(r.technicianId));
  }, [routes, selectedTechIds]);

  // Build polyline positions per route
  const routeLines = useMemo(() => {
    return filteredRoutes.map((route) => {
      const tech = technicians.find((t) => t.id === route.technicianId);
      const color = technicianColors[route.technicianId] || '#6b7280';

      // Start from home base, through stops, back home
      const positions: [number, number][] = [];
      if (tech) {
        positions.push([tech.homeBase.lat, tech.homeBase.lng]);
      }
      route.stops.forEach((stop) => {
        positions.push([stop.lat, stop.lng]);
      });
      if (tech) {
        positions.push([tech.homeBase.lat, tech.homeBase.lng]);
      }

      return { route, color, positions };
    });
  }, [filteredRoutes, technicians]);

  return (
    <MapContainer
      center={DENVER_CENTER}
      zoom={12}
      scrollWheelZoom={true}
      className="h-full w-full"
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />

      {/* Technician home bases */}
      {technicians
        .filter(
          (t) =>
            !selectedTechIds ||
            selectedTechIds.length === 0 ||
            selectedTechIds.includes(t.id)
        )
        .map((tech) => {
          const color = technicianColors[tech.id] || '#6b7280';
          return (
            <Marker
              key={`home-${tech.id}`}
              position={[tech.homeBase.lat, tech.homeBase.lng]}
              icon={createHomeIcon(color)}
            >
              <Popup>
                <div className="text-sm min-w-[180px]">
                  <p className="font-bold text-neutral-900">{tech.name}</p>
                  <p className="text-neutral-500 text-xs">Home Base</p>
                  <div className="mt-1 text-xs text-neutral-600">
                    <p>Skills: {tech.skills.join(', ')}</p>
                    <p>Status: {tech.availabilityStatus}</p>
                  </div>
                </div>
              </Popup>
            </Marker>
          );
        })}

      {/* Route polylines */}
      {routeLines.map(({ route, color, positions }) => (
        <Polyline
          key={`line-${route.id}`}
          positions={positions}
          pathOptions={{
            color,
            weight: 3,
            opacity: 0.7,
            dashArray: route.status === 'planned' ? '8 6' : undefined,
          }}
        />
      ))}

      {/* Stop markers */}
      {filteredRoutes.flatMap((route) => {
        const color = technicianColors[route.technicianId] || '#6b7280';
        return route.stops.map((stop) => (
          <Marker
            key={`stop-${route.id}-${stop.sequence}`}
            position={[stop.lat, stop.lng]}
            icon={createStopIcon(color, stop.sequence)}
          >
            <Popup>
              <div className="text-sm min-w-[200px]">
                <div className="flex items-start justify-between gap-2">
                  <p className="font-bold text-neutral-900">
                    {stop.workOrder.title}
                  </p>
                  <span
                    className={clsx(
                      'inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold whitespace-nowrap',
                      priorityBadge[stop.workOrder.priority] || priorityBadge.medium
                    )}
                  >
                    {stop.workOrder.priority}
                  </span>
                </div>
                <p className="text-neutral-500 text-xs mt-0.5">
                  {route.technicianName} &middot; Stop #{stop.sequence}
                </p>
                <div className="mt-2 grid grid-cols-2 gap-x-3 gap-y-0.5 text-xs text-neutral-600">
                  <p>Arrival: <span className="font-medium">{stop.arrivalTime}</span></p>
                  <p>Depart: <span className="font-medium">{stop.departureTime}</span></p>
                  <p>Travel: <span className="font-medium">{stop.travelDistanceMiles} mi</span></p>
                  <p>Category: <span className="font-medium">{stop.workOrder.category}</span></p>
                </div>
              </div>
            </Popup>
          </Marker>
        ));
      })}

      {/* Legend overlay */}
      <div className="leaflet-bottom leaflet-left">
        <div className="leaflet-control bg-white/95 backdrop-blur-sm rounded-lg shadow-lg p-3 m-3 text-xs">
          <p className="font-semibold text-neutral-700 mb-2">Technicians</p>
          {filteredRoutes.map((route) => {
            const color = technicianColors[route.technicianId] || '#6b7280';
            return (
              <div key={route.id} className="flex items-center gap-2 py-0.5">
                <span
                  className="h-3 w-3 rounded-full flex-shrink-0"
                  style={{ backgroundColor: color }}
                />
                <span className="text-neutral-700">{route.technicianName}</span>
                <span className="text-neutral-400">
                  ({route.summary.numStops} stops)
                </span>
              </div>
            );
          })}
          <div className="mt-2 pt-2 border-t border-neutral-200 space-y-0.5">
            <div className="flex items-center gap-2">
              <span className="h-0.5 w-5 bg-neutral-400" />
              <span className="text-neutral-500">In-Progress</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="h-0.5 w-5 bg-neutral-400 border-dashed" style={{ borderTop: '2px dashed #94a3b8', height: 0 }} />
              <span className="text-neutral-500">Planned</span>
            </div>
          </div>
        </div>
      </div>
    </MapContainer>
  );
}
