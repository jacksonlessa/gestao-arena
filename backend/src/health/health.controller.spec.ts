import { ConfigService } from '@nestjs/config';
import { HealthController } from './health.controller';
import { PrismaService } from '../prisma/prisma.service';

describe('HealthController', () => {
  const config = {
    get: (chave: string) =>
      ({ APP_NAME: 'api-teste', APP_VERSION: '1.2.3', NODE_ENV: 'test' })[
        chave
      ],
  } as unknown as ConfigService;

  it('should report ok when database responds', async () => {
    const prisma = { verificarConexao: async () => true } as PrismaService;
    const controller = new HealthController(prisma, config);

    const resposta = await controller.verificar();

    expect(resposta.status).toBe('ok');
    expect(resposta.banco).toBe('ok');
    expect(resposta.aplicacao).toBe('api-teste');
  });

  it('should report degraded when database is unreachable', async () => {
    const prisma = { verificarConexao: async () => false } as PrismaService;
    const controller = new HealthController(prisma, config);

    const resposta = await controller.verificar();

    expect(resposta.status).toBe('degradado');
    expect(resposta.banco).toBe('indisponivel');
  });
});
