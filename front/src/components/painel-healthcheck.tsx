'use client';

import { useEffect, useState, type ReactNode } from 'react';

interface RespostaBackend {
  status: string;
  aplicacao: string;
  versao: string;
  banco: string;
  ambiente: string;
  horario: string;
}

type Estado =
  | { fase: 'verificando' }
  | { fase: 'ok'; dados: RespostaBackend }
  | { fase: 'erro'; mensagem: string };

const API = process.env.NEXT_PUBLIC_API_URL;

/**
 * Healthcheck da superfície (RF20 e RF20a).
 *
 * Além de reportar o próprio estado, chama o healthcheck do backend **a partir
 * do navegador e com credenciais**. É essa chamada que prova, numa tela só,
 * que CORS, conectividade e configuração de cookie estão corretos — e ela
 * funciona igual em ambiente local e em produção.
 */
export function PainelHealthcheck({
  superficie,
  host,
}: {
  superficie: string;
  host: string;
}): ReactNode {
  const [estado, setEstado] = useState<Estado>({ fase: 'verificando' });

  useEffect(() => {
    if (!API) {
      setEstado({
        fase: 'erro',
        mensagem: 'NEXT_PUBLIC_API_URL não está definida.',
      });
      return;
    }

    fetch(`${API}/health`, { credentials: 'include' })
      .then(async (resposta) => {
        if (!resposta.ok) {
          throw new Error(`Backend respondeu ${resposta.status}.`);
        }
        setEstado({ fase: 'ok', dados: (await resposta.json()) as RespostaBackend });
      })
      .catch((erro: Error) => {
        setEstado({
          fase: 'erro',
          mensagem:
            `${erro.message} — se a requisição nem chegou a sair, ` +
            'verifique CORS_ORIGIN no backend e o valor de NEXT_PUBLIC_API_URL.',
        });
      });
  }, []);

  return (
    <main className="mx-auto flex max-w-2xl flex-col gap-6 p-8">
      <header>
        <h1 className="text-xl font-semibold">Healthcheck — {superficie}</h1>
        <p className="text-sm text-neutral-500">Gestão de Arena</p>
      </header>

      <section className="rounded-lg border border-neutral-200 p-4 dark:border-neutral-800">
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-500">
          Frontend
        </h2>
        <Linha rotulo="Situação" valor="ok" />
        <Linha rotulo="Superfície" valor={superficie} />
        <Linha rotulo="Host" valor={host} />
      </section>

      <section className="rounded-lg border border-neutral-200 p-4 dark:border-neutral-800">
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-500">
          Backend (via navegador, com credenciais)
        </h2>

        {estado.fase === 'verificando' && (
          <p className="text-sm text-neutral-500">Verificando…</p>
        )}

        {estado.fase === 'erro' && (
          <p className="text-sm text-red-600 dark:text-red-400">
            {estado.mensagem}
          </p>
        )}

        {estado.fase === 'ok' && (
          <>
            <Linha rotulo="Situação" valor={estado.dados.status} />
            <Linha rotulo="Aplicação" valor={estado.dados.aplicacao} />
            <Linha rotulo="Versão" valor={estado.dados.versao} />
            <Linha rotulo="Banco" valor={estado.dados.banco} />
            <Linha rotulo="Ambiente" valor={estado.dados.ambiente} />
            <p className="mt-3 text-xs text-green-700 dark:text-green-400">
              CORS e conectividade confirmados: a resposta acima foi lida pelo
              navegador, não pelo servidor.
            </p>
          </>
        )}
      </section>
    </main>
  );
}

function Linha({ rotulo, valor }: { rotulo: string; valor: string }): ReactNode {
  return (
    <div className="flex justify-between border-b border-neutral-100 py-1 text-sm last:border-0 dark:border-neutral-800">
      <span className="text-neutral-500">{rotulo}</span>
      <span className="font-mono">{valor}</span>
    </div>
  );
}
