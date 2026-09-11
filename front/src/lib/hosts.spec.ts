import { ehCaminhoFisico, superficiePorHost } from './hosts';

const HOSTS = {
  operacao: 'arenas.entretimes.com.br',
  backoffice: 'backoffice-arenas.entretimes.com.br',
};

describe('superficiePorHost', () => {
  it('should resolve operacao when host matches', () => {
    expect(superficiePorHost('arenas.entretimes.com.br', HOSTS)).toBe(
      'operacao',
    );
  });

  it('should resolve backoffice when host matches', () => {
    expect(
      superficiePorHost('backoffice-arenas.entretimes.com.br', HOSTS),
    ).toBe('backoffice');
  });

  it('should ignore port when resolving host', () => {
    expect(superficiePorHost('arenas.entretimes.com.br:3000', HOSTS)).toBe(
      'operacao',
    );
  });

  it('should return null when host is unknown', () => {
    expect(superficiePorHost('qualquer.coisa.com', HOSTS)).toBeNull();
  });
});

describe('ehCaminhoFisico', () => {
  it('should reject the physical prefix of a surface', () => {
    expect(ehCaminhoFisico('/backoffice')).toBe(true);
    expect(ehCaminhoFisico('/backoffice/healthcheck')).toBe(true);
    expect(ehCaminhoFisico('/operacao')).toBe(true);
  });

  it('should allow a normal path', () => {
    expect(ehCaminhoFisico('/healthcheck')).toBe(false);
    expect(ehCaminhoFisico('/')).toBe(false);
  });
});
