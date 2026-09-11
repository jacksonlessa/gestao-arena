import type { ReactNode } from 'react';
import { headers } from 'next/headers';
import { PainelHealthcheck } from '@/components/painel-healthcheck';

export const dynamic = 'force-dynamic';

export default async function HealthcheckOperacao(): Promise<ReactNode> {
  const host = (await headers()).get('host') ?? 'desconhecido';
  return <PainelHealthcheck superficie="Operação" host={host} />;
}
