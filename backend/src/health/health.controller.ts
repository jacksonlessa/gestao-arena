import { Controller, Get } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

export interface RespostaHealthcheck {
  status: 'ok' | 'degradado';
  aplicacao: string;
  versao: string;
  banco: 'ok' | 'indisponivel';
  ambiente: string;
  horario: string;
}

/**
 * Healthcheck público do backend (RF08).
 *
 * É chamado diretamente e também pelo healthcheck de cada frontend, a partir
 * do navegador e com credenciais (RF20a) — é essa chamada que prova, numa
 * tela só, que CORS, conectividade e cookie estão corretos.
 */
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  @Get()
  async verificar(): Promise<RespostaHealthcheck> {
    const bancoOk = await this.prisma.verificarConexao();

    return {
      status: bancoOk ? 'ok' : 'degradado',
      aplicacao: this.config.get<string>('APP_NAME') ?? 'gestao-arena-api',
      versao: this.config.get<string>('APP_VERSION') ?? '0.0.0',
      banco: bancoOk ? 'ok' : 'indisponivel',
      ambiente: this.config.get<string>('NODE_ENV') ?? 'development',
      horario: new Date().toISOString(),
    };
  }
}
