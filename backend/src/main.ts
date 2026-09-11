import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import cookieParser from 'cookie-parser';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  app.use(cookieParser());

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // CORS por superfície (RF10). Lista explícita, nunca curinga — o navegador
  // recusa curinga combinado com credenciais, e as duas superfícies precisam
  // ser distinguíveis para a validação de origem das rotas de backoffice,
  // que entra junto com a primeira delas, no PRD 01.
  const origensPermitidas = [
    config.get<string>('CORS_ORIGIN_OPERACAO'),
    config.get<string>('CORS_ORIGIN_BACKOFFICE'),
  ].filter((origem): origem is string => Boolean(origem));

  app.enableCors({
    origin: origensPermitidas,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  await app.listen(config.get<number>('PORT') ?? 3001);
}

void bootstrap();
