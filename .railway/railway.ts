import { defineRailway, github, postgres, preserve, project, service, volume } from "railway/iac";

// Infraestrutura da Railway declarada em código, substituindo o railway.json
// (Config as Code), descontinuado pela Railway e válido até 2026-12-01.
//
// Gerado a partir do estado real do projeto (`railway config pull`), e não da
// tradução automática do railway.json (`railway config migrate`): aquela
// omite `builder` e `dockerfilePath`, emitindo os dois como comentário. O
// serviço tem RAILPACK gravado como builder, e é o railway.json que o
// sobrescreve para DOCKERFILE a cada deploy — sem esses campos aqui, o app
// passaria a ser construído por Railpack em vez do Dockerfile.
export default defineRailway(() => {
  const Postgres = postgres("Postgres", { region: "ams" });

  const eloshopWebVolume = volume("eloshop-web-volume", {
    alerts: { usage: { "80": {}, "95": {}, "100": {} } },
    allowOnlineResize: true,
    region: "ams",
    sizeMB: 500,
  });

  const postgresVolume = volume("postgres-volume", {
    alerts: { usage: { "80": {}, "95": {}, "100": {} } },
    allowOnlineResize: true,
    region: "ams",
    sizeMB: 500,
  });

  const eloshopWeb = service("eloshop-web", {
    // Deploy automático a cada push no main, e só depois que os check suites
    // do GitHub passam (checkSuites). Um CI quebrado bloqueia o deploy.
    source: github("urieljuliatti85/eloshop", { branch: "main", checkSuites: true }),

    // Vinha do railway.json — precisa ser explícito aqui, ver comentário no
    // topo do arquivo.
    build: {
      builder: "DOCKERFILE",
      dockerfilePath: "Dockerfile",
    },

    // Idem: healthcheck e política de restart também vinham do railway.json.
    //
    // `restartPolicyType: "ON_FAILURE"` está deliberadamente ausente: é o
    // default da Railway, e a API grava null ao recebê-lo. Declarar aqui
    // deixaria `railway config plan` sempre acusando uma mudança pendente que
    // nunca se resolve — e um plan que nunca fica limpo ensina a ignorar o
    // plan, que é o detector de drift. O comportamento é o mesmo; só o
    // maxRetries precisa ser explícito, porque o default é 10.
    deploy: {
      // /up prova que o processo iniciou; /ready também confirma que o banco
      // primário, dependência essencial de toda compra, aceita consultas.
      healthcheckPath: "/ready",
      healthcheckTimeout: 30,
      restartPolicyMaxRetries: 3,
    },

    replicas: { ams: 1 },

    // Active Storage grava aqui. Sem o volume, as imagens de produto somem a
    // cada redeploy — o resto do filesystem do container é efêmero.
    volumeMounts: { "/rails/storage": eloshopWebVolume },

    // preserve() mantém os valores já configurados na Railway sem trazer
    // segredo nenhum para o repositório.
    env: {
      DATABASE_URL: preserve(),
      RAILS_MASTER_KEY: preserve(),
      RAILS_STORAGE_PATH: preserve(),
    },
  });

  return project("eloshop", {
    resources: [Postgres, eloshopWeb, eloshopWebVolume, postgresVolume],
  });
});
