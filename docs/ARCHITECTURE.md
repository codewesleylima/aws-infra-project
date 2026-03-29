# Arquitetura do Projeto

## Visão Geral

Este documento descreve a arquitetura da infraestrutura AWS implementada neste projeto.

## Diagrama de Arquitetura

```
                                    ┌─────────────────────────────────────────────────────────────────┐
                                    │                         AWS Cloud                                │
                                    │                                                                  │
    ┌──────────┐                   │  ┌─────────────────────────────────────────────────────────┐    │
    │  GitHub  │───CI/CD──────────►│  │                    VPC (10.0.0.0/16)                    │    │
    │ Actions  │   (OIDC)          │  │                                                         │    │
    └──────────┘                   │  │   ┌─────────────────┐     ┌─────────────────┐          │    │
                                    │  │   │  Public Subnet  │     │  Public Subnet  │          │    │
         │                          │  │   │   (AZ-1a)       │     │   (AZ-1b)       │          │    │
    Usuários                        │  │   │                 │     │                 │          │    │
         │                          │  │   │  ┌───────────┐  │     │  ┌───────────┐  │          │    │
         │                          │  │   │  │    NAT    │  │     │  │    NAT    │  │          │    │
         ▼                          │  │   │  │  Gateway  │  │     │  │  Gateway  │  │          │    │
    ┌──────────┐                   │  │   │  └─────┬─────┘  │     │  └─────┬─────┘  │          │    │
    │  Route   │                   │  │   │        │        │     │        │        │          │    │
    │   53     │                   │  │   └────────┼────────┘     └────────┼────────┘          │    │
    └────┬─────┘                   │  │            │                       │                    │    │
         │                          │  │   ┌───────▼───────────────────────▼───────┐            │    │
         │                          │  │   │            Application Load Balancer  │            │    │
         │                          │  │   │                (HTTPS:443)            │            │    │
         │                          │  │   └───────────────────┬───────────────────┘            │    │
         │                          │  │                       │                                │    │
         │                          │  │   ┌───────────────────▼───────────────────┐            │    │
         │                          │  │   │            Private Subnets            │            │    │
         │                          │  │   │  ┌─────────────────────────────────┐  │            │    │
         │                          │  │   │  │          ECS Cluster            │  │            │    │
         │                          │  │   │  │  ┌───────┐  ┌───────┐  ┌─────┐  │  │            │    │
         └──────────────────────────┼──┼───┼──┼─►│ Task  │  │ Task  │  │ ... │  │  │            │    │
                                    │  │   │  │  │ (App) │  │ (App) │  │     │  │  │            │    │
                                    │  │   │  │  └───┬───┘  └───┬───┘  └──┬──┘  │  │            │    │
                                    │  │   │  └──────┼──────────┼─────────┼─────┘  │            │    │
                                    │  │   │         │          │         │        │            │    │
                                    │  │   │         ▼          ▼         ▼        │            │    │
                                    │  │   │  ┌─────────────────────────────────┐  │            │    │
                                    │  │   │  │      RDS PostgreSQL (Multi-AZ)  │  │            │    │
                                    │  │   │  │           (Encrypted)           │  │            │    │
                                    │  │   │  └─────────────────────────────────┘  │            │    │
                                    │  │   └───────────────────────────────────────┘            │    │
                                    │  └─────────────────────────────────────────────────────────┘    │
                                    │                                                                  │
                                    │  ┌──────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────┐  │
                                    │  │    S3    │  │   Secrets    │  │ CloudWatch │  │   KMS    │  │
                                    │  │ (Storage)│  │   Manager    │  │   (Logs)   │  │  (Keys)  │  │
                                    │  └──────────┘  └──────────────┘  └────────────┘  └──────────┘  │
                                    └─────────────────────────────────────────────────────────────────┘
```

## Componentes

### Rede (VPC)

| Componente | Descrição |
|------------|-----------|
| VPC | Rede isolada com CIDR 10.0.0.0/16 |
| Public Subnets | Hospedam ALB e NAT Gateways |
| Private Subnets | Hospedam ECS tasks e RDS |
| NAT Gateway | Permite acesso outbound das subnets privadas |
| Internet Gateway | Permite acesso público ao ALB |

### Compute (ECS Fargate)

| Componente | Descrição |
|------------|-----------|
| ECS Cluster | Cluster gerenciado com Container Insights |
| ECS Service | Gerencia tasks com health checks |
| Task Definition | Define container, recursos e secrets |
| Auto Scaling | Escala baseado em CPU (target 70%) |

### Banco de Dados (RDS)

| Componente | Descrição |
|------------|-----------|
| RDS PostgreSQL | Banco gerenciado com Multi-AZ em prod |
| Parameter Group | Configurações otimizadas (SSL, logs) |
| Subnet Group | Distribui em múltiplas AZs |
| Automated Backups | Retenção de 7-30 dias |

### Armazenamento (S3)

| Componente | Descrição |
|------------|-----------|
| S3 Bucket | Storage com versionamento |
| Lifecycle Rules | Transição para Glacier/IA |
| Encryption | SSE-S3 ou SSE-KMS |

### Segurança

| Componente | Descrição |
|------------|-----------|
| Security Groups | Firewall por recurso |
| IAM Roles | OIDC para CI/CD, roles para ECS |
| Secrets Manager | Armazena credenciais com rotação |
| KMS | Chaves de criptografia gerenciadas |

## Fluxo de Dados

```
1. Usuário → Route 53 (DNS)
2. Route 53 → ALB (HTTPS termination)
3. ALB → ECS Tasks (Health check, load balance)
4. ECS Task → RDS (Database queries)
5. ECS Task → S3 (File storage)
6. ECS Task → Secrets Manager (Credentials)
7. Todos os componentes → CloudWatch (Logs/Metrics)
```

## Ambientes

### Development (dev)
- Single NAT Gateway
- RDS: db.t3.micro, single-AZ
- ECS: 1-5 tasks, 256 CPU / 512 MB
- Backups: 7 dias

### Staging
- Single NAT Gateway
- RDS: db.t3.small, single-AZ
- ECS: 2-10 tasks, 512 CPU / 1024 MB
- Backups: 14 dias

### Production (prod)
- NAT Gateway por AZ (HA)
- RDS: db.r6g.large, Multi-AZ
- ECS: 3-20 tasks, 1024 CPU / 2048 MB
- Backups: 30 dias
- Deletion protection habilitado

## CI/CD Pipeline

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Commit    │────►│   Validate  │────►│  Security   │────►│    Plan     │
│             │     │  (fmt/lint) │     │   (scan)    │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
                                                                    │
                                                                    ▼
                    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
                    │  Deploy     │◄────│  Approval   │◄────│  PR Review  │
                    │  (apply)    │     │  (if prod)  │     │             │
                    └─────────────┘     └─────────────┘     └─────────────┘
```

## Custos Estimados (USD/mês)

| Ambiente | Estimativa |
|----------|------------|
| Dev | ~$100-150 |
| Staging | ~$200-300 |
| Prod | ~$500-1000+ |

*Valores variam conforme uso e região*

## Próximos Passos

1. [ ] Implementar módulo de CDN (CloudFront)
2. [ ] Adicionar WAF para proteção
3. [ ] Configurar alertas SNS
4. [ ] Implementar DR cross-region
5. [ ] Adicionar módulo de Redis/ElastiCache
