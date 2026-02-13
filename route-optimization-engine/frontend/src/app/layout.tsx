import type { Metadata } from 'next';
import '@/styles/globals.css';
import 'leaflet/dist/leaflet.css';
import AppLayout from '@/components/Layout/AppLayout';

export const metadata: Metadata = {
  title: 'Route Optimization Engine | Polaris Real Estate',
  description:
    'Optimized technician route planning and visualization for field service operations across the Denver metro area.',
  keywords: [
    'route optimization',
    'field service',
    'technician routing',
    'VRP',
    'fleet management',
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="h-full">
      <head>
        <link
          rel="preconnect"
          href="https://fonts.googleapis.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="h-full">
        <AppLayout>{children}</AppLayout>
      </body>
    </html>
  );
}
