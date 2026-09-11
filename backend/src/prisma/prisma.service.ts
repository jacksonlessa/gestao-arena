import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

/**
 * Único ponto de instanciação do Prisma Client em toda a aplicação.
 * Nenhum outro arquivo cria um PrismaClient — a camada de isolamento por
 * organização (PRD 01) depende de todo acesso passar por aqui.
 */
@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }

  /** Verificação de conectividade usada pelo healthcheck. */
  async verificarConexao(): Promise<boolean> {
    try {
      await this.$queryRaw`SELECT 1`;
      return true;
    } catch {
      return false;
    }
  }
}
