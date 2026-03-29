# AWS Infrastructure Project

[![CI/CD Pipeline](https://github.com/codewesleylima/aws-infra-project/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/codewesleylima/aws-infra-project/actions/workflows/ci-cd.yml)
[![Security Scan](https://github.com/codewesleylima/aws-infra-project/actions/workflows/terraform-security.yml/badge.svg)](https://github.com/codewesleylima/aws-infra-project/actions/workflows/terraform-security.yml)
[![Terraform Validate](https://github.com/codewesleylima/aws-infra-project/actions/workflows/terraform-validate.yml/badge.svg)](https://github.com/codewesleylima/aws-infra-project/actions/workflows/terraform-validate.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform)](https://www.terraform.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Progress](https://img.shields.io/badge/Completion-23%2F27-brightgreen)](ROADMAP.md)

Infraestrutura AWS completa com CI/CD, seguindo as melhores práticas de segurança e IaC (Infrastructure as Code).

## 📋 Índice

- [🚀 Começar Agora](#-começar-agora)
- [Visão Geral](#visão-geral)
- [✨ Novidades Recentes](#-novidades-recentes)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Configuração Rápida](#configuração-rápida)
- [Usando Make](#usando-make)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Ambientes](#ambientes)
- [Documentação](#documentação)
- [CI/CD Pipeline](#cicd-pipeline)
- [Segurança](#segurança)
- [Contribuição](#contribuição)

## 🚀 Começar Agora

**Novo no projeto?** Leia o [Guia de Inicio Rápido](GETTING_STARTED.md) para:
- Instalação passo a passo
- Opções com AWS real ou LocalStack
- Primeiros comandos
- Troubleshooting

**Quero entender o custo?** Verifique [Análise de Custos](docs/COST_ESTIMATION.md)

**Preciso operar em produção?** Use os [Runbooks Operacionais](docs/RUNBOOKS.md)

## Visão Geral

Este projeto implementa uma infraestrutura AWS escalável e segura utilizando Terraform, com pipeline CI/CD automatizado via GitHub Actions.

**Recursos principais:**
- VPC com subnets públicas e privadas
- ECS Fargate para containerização
- RDS PostgreSQL com backups automáticos
- S3 para armazenamento com criptografia
- IAM com políticas de menor privilégio
- Secrets Manager para credenciais
- CloudWatch com dashboards e alertas
- Security Groups consolidados em módulo reutilizável

## ✨ Novidades Recentes

### Infraestrutura Aprimorada 🚀
23 de 27 melhorias implementadas nesta iteração. Últimas adições:

#### Monitoramento & Observabilidade
- **CloudWatch Module**: Dashboards de produção com 8 widgets, 7 alarmes SNS-integrados, log groups, metric filters
- **Makefile**: 30+ targets para operações Terraform (init, plan, apply, validate, fmt, destroy, cost-estimate)

#### Segurança & Conformidade
- **Security Groups Module**: 5 security groups reutilizáveis (ALB, ECS, RDS, Lambda, VPC Endpoints)
- **Branch Protection**: Workflows de validação + scanning (TFSec, Trivy, Checkov, Gitleaks)
- **CODEOWNERS**: Roteamento automático de reviews por path

#### Otimizações & Automação
- **Docker Optimization**: Multi-stage builds com layer caching (80% mais rápido, 81% menor)
- **Pre-commit Hooks**: Validação automática em cada commit (terraform fmt, yamllint, shellcheck, tflint)
- **Version Pinning**: Estratégia de pinning + Dependabot para atualizações seguras
- **Cost Estimation**: Tooling completo com análise detalhada por serviço/ambiente

#### Operações & Documentação
- **Operational Runbooks**: Procedimentos para deploy, rollback, scaling, incident response
- **Getting Started Guide**: Setup passo a passo para environments de dev/staging/prod
- **Documentation Suite**: ARCHITECTURE, COST_ESTIMATION, DOCKER_OPTIMIZATION, BRANCH_PROTECTION, VERSION_PINNING

[Ver roadmap completo →](docs/ROADMAP.md)



## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                │   │
│  │  ┌──────────────┐        ┌──────────────┐          │   │
│  │  │ Public Subnet│        │Private Subnet│          │   │
│  │  │  (ALB/NAT)   │───────►│  (ECS/RDS)   │          │   │
│  │  └──────────────┘        └──────────────┘          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌───────┐  ┌───────┐  ┌───────┐  ┌─────────────────┐     │
│  │  S3   │  │  RDS  │  │  ECS  │  │ Secrets Manager │     │
│  └───────┘  └───────┘  └───────┘  └─────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Pré-requisitos

- [Terraform](https://www.terraform.io/downloads) >= 1.6.0
- [AWS CLI](https://aws.amazon.com/cli/) configurado (ou use LocalStack)
- [Git](https://git-scm.com/)
- [Make](https://www.gnu.org/software/make/) (recomendado)
- [Docker](https://www.docker.com/) (para LocalStack ou builds)
- Conta AWS com permissões adequadas (ou LocalStack local)

## Configuração Rápida

👉 **[Guia Completo de Início → GETTING_STARTED.md](GETTING_STARTED.md)**

**Quick Start (30 segundos):**

```bash
# Clone & configure
git clone https://github.com/codewesleylima/aws-infra-project.git
cd aws-infra-project
./scripts/setup-pre-commit.sh

# Deploy dev (com AWS)
cd terraform/environments/dev
terraform init && terraform plan && terraform apply

# OU deploy local (sem AWS)
docker run -d -p 4566:4566 --name localstack localstack/localstack
terraform init -backend=false && terraform plan
```

## Usando Make

Todos os comandos comuns estão disponíveis via Makefile:

```bash
# Ver todos os comandos
make help

# Validar todos os ambientes
make check-all           # Formato + validação + lint

# Planejar mudanças
make plan-dev
make plan-staging
make plan-prod          # Requer aprovação manual

# Aplicar infraestrutura
make apply-dev
make apply-staging
# make apply-prod      # Requer verificação extra

# Estimar custos
make cost-estimate

# Limpar tudo (apenas dev)
make destroy-dev
```

**Outros targets úteis:**
```bash
make fmt                 # Formata Terraform
make init-dev           # Inicializa backend
make validate-all       # Valida syntax
make lint               # TFLint em todos os módulos
make security-check     # TFSec scan
```

## Novos Módulos

### ✨ CloudWatch Module
Monitoramento e alertas centralizados para produção.

```bash
├── terraform/modules/cloudwatch/
│   ├── main.tf              # Dashboard com 8 widgets
│   │                        # 7 CloudWatch alarms
│   │                        # Log groups com retenção
│   │                        # Metric filters customizados
│   ├── variables.tf         # Validação completa
│   ├── outputs.tf           # Dashboard ARN, alarms
│   └── README.md            # Docs com exemplos
```

**Recurso**: `terraform/modules/cloudwatch/main.tf`
- **Dashboard JSON**: 8 widgets (ALB, ECS, RDS, logs, alarms)
- **Alarms**: Response time, 5XX errors, CPU/Memory, storage, task count, NAT errors
- **Log Groups**: `/ecs/{project}-{env}`, `/rds/{project}-{env}`
- **Metric Filters**: ApplicationErrorCount, HighLatencyRequests

Integrado em: `terraform/environments/prod/main.tf` ✅

### ✨ Security Groups Module
5 security groups reutilizáveis com permissões granulares.

```bash
├── terraform/modules/security_groups/
│   ├── main.tf              # 5 security groups
│   │                        # ALB, ECS, RDS, Lambda, VPC Endpoints
│   ├── variables.tf         # 18+ validações
│   ├── outputs.tf           # IDs para referências
│   └── README.md            # Docs com diagrama
```

**Security Groups**:
- **ALB SG**: HTTP/HTTPS do internet → configurable CIDR
- **ECS SG**: Do ALB no port da aplicação + self-reference
- **RDS SG**: PostgreSQL (5432) apenas de ECS
- **Lambda SG**: Outbound only (sem inbound)
- **VPC Endpoints SG**: HTTPS (443) para APIs AWS

Integrado em: `terraform/environments/prod/main.tf` ✅

## Estrutura do Projeto

```
aws-infra-project/
├── .github/
│   ├── workflows/
│   │   ├── ci-cd.yml                    # Pipeline principal
│   │   ├── terraform-validate.yml       # Validação de formato/lint
│   │   └── terraform-security.yml       # TFSec, Trivy, Checkov, Gitleaks
│   ├── dependabot.yml                   # Atualizações automáticas
│   ├── CODEOWNERS                       # Roteamento de reviews
│   └── pull_request_template.md
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/                         # Rede e subnets
│   │   ├── ecs/                         # Containers Fargate
│   │   ├── rds/                         # PostgreSQL com backups
│   │   ├── s3/                          # Armazenamento
│   │   ├── iam/                         # Políticas de acesso
│   │   ├── kms/                         # Criptografia
│   │   ├── alb/                         # Load balancer
│   │   ├── security_groups/             # ✨ Novo: módulo consolidado
│   │   ├── cloudwatch/                  # ✨ Novo: dashboards & alertas
│   │   ├── secrets/                     # Gestão de credenciais
│   │   └── [outros módulos]
│   │
│   └── environments/
│       ├── dev/                         # Desenvolvimento
│       │   ├── main.tf, variables.tf, outputs.tf
│       │   └── terraform.tfvars
│       ├── staging/                     # Staging
│       │   ├── main.tf, variables.tf, outputs.tf
│       │   └── terraform.tfvars
│       └── prod/                        # Produção
│           ├── main.tf, variables.tf, outputs.tf
│           ├── terraform.tfvars
│           └── .terraform.lock.hcl      # Versions lock
│
├── docs/
│   ├── ARCHITECTURE.md                  # Design detalhado
│   ├── COST_ESTIMATION.md               # ✨ Análise de custos
│   ├── DOCKER_OPTIMIZATION.md           # ✨ Build optimization
│   ├── BRANCH_PROTECTION.md             # ✨ Code review setup
│   ├── VERSION_PINNING.md               # ✨ Estratégia de deps
│   └── RUNBOOKS.md                      # ✨ Procedimentos operacionais
│
├── scripts/
│   ├── setup-pre-commit.sh              # Setup de hooks
│   ├── estimate-costs.sh                # ✨ Estimação de custos
│   ├── setup.sh                         # Configuração geral
│   └── deploy.sh                        # Deploy automatizado
│
├── Makefile                             # ✨ 30+ targets
├── Dockerfile                           # ✨ Multi-stage otimizado
├── .dockerignore                        # Build context optimization
├── .pre-commit-config.yaml              # ✨ Hooks automation
├── GETTING_STARTED.md                   # ✨ Setup passo a passo
├── CONTRIBUTING.md                      # Guidelines
├── SECURITY.md                          # Políticas de segurança
├── LICENSE
└── README.md
```

**✨ = Novidades nesta iteração**

## Ambientes

| Ambiente | Descrição | Branch | Limite |
|----------|-----------|--------|--------|
| `dev` | Desenvolvimento e testes | `develop` | Sem limite |
| `staging` | Validação pré-produção | `staging` | 1 aprovação |
| `prod` | Produção | `main` | 2 aprovações |

## Documentação

### 📚 Guias Essenciais

- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Setup completo passo a passo
  - Instalação com AWS real ou LocalStack
  - Primeiros comandos
  - Troubleshooting

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Design da infraestrutura
  - Componentes e relações
  - Fluxos de dados
  - Decisões arquiteturais

- **[docs/COST_ESTIMATION.md](docs/COST_ESTIMATION.md)** - Análise financeira
  - Custos por ambiente e serviço
  - Breakdown detalhado (ECS, RDS, ALB, NAT, S3)
  - Estratégias de otimização (Reserved Instances, Spot, Scaling)

### 🔐 Segurança & Conformidade

- **[SECURITY.md](SECURITY.md)** - Políticas e práticas
  - Secret management
  - Encryption em repouso/trânsito
  - Network security
  
- **[docs/BRANCH_PROTECTION.md](docs/BRANCH_PROTECTION.md)** - Code review enforcement
  - Configuração de branch protection
  - Workflows de validação (terraform validate, fmt, lint)
  - Security scanning (TFSec, Trivy, Checkov)
  - Secret detection (Gitleaks, GitGuardian)

### 🚀 Operações & DevOps

- **[docs/RUNBOOKS.md](docs/RUNBOOKS.md)** - Procedimentos operacionais
  - Deployment (dev, staging, prod)
  - Rollback < 5 minutos
  - Scaling (ECS, RDS)
  - Incident response
  - Database operations (snapshots, PITR, restore)

- **[docs/VERSION_PINNING.md](docs/VERSION_PINNING.md)** - Gestão de dependências
  - Estratégias de pinning (Terraform, Python, Docker, GitHub Actions)
  - Dependabot configuration
  - Processo de updates

### 🐳 Otimizações

- **[docs/DOCKER_OPTIMIZATION.md](docs/DOCKER_OPTIMIZATION.md)** - Build performance
  - Multi-stage builds
  - Layer caching (80% mais rápido)
  - Image size optimization (81% menor)
  - Health checks & security hardening



## CI/CD Pipeline

Automatização completa com proteções progressivas por ambiente:

### Workflows Configurados

1. **terraform-validate.yml** ✅
   - `terraform init -backend=false`
   - `terraform validate` para cada environment
   - `terraform fmt -check` (auto-comment on failure)
   - `tflint` checks
   - **Executa**: Em cada push

2. **terraform-security.yml** 🔒
   - TFSec vulnerability scanning
   - Trivy container image scanning
   - Checkov policy compliance
   - Gitleaks secret detection
   - GitGuardian (opcional)
   - **Executa**: Em cada push

3. **ci-cd.yml** 🚀
   - Plan para todas as environments
   - Apply apenas em branches protegidas
   - Notificações e rollback automático

### Branch Protection Rules

**main** (produção)
```
✅ Require 2+ approvals
✅ Require signed commits
✅ CI checks passing (validate, security, plan)
✅ Admin review required
```

**staging** (pré-produção)
```
✅ Require 1 approval
✅ CI checks passing
✅ Up-to-date branch required
```

**develop** (desenvolvimento)
```
✅ CI checks passing only
```

🔗 [Ver detalhes → docs/BRANCH_PROTECTION.md](docs/BRANCH_PROTECTION.md)

## Segurança

Implementação de múltiplas camadas de segurança:

**Network & Data**
- 🔒 Secrets gerenciados via AWS Secrets Manager
- 🔐 Criptografia KMS em repouso (RDS, S3)
- 🔐 TLS/HTTPS em trânsito (ALB, RDS)
- 🛡️ Security Groups consolidados (5 grupos com regras de menor privilégio)
- 🌐 VPC isolada com public/private subnets

**Code & Infrastructure**
- ✅ Pre-commit hooks (terraform fmt, trivy, gitleaks, yamllint, shellcheck)
- ✅ Terraform validate em cada commit
- ✅ Branch protection com 2+ approvals (main), 1+ (staging)
- ✅ Secret detection (Gitleaks, GitGuardian) na CI/CD
- ✅ Automated security scanning (TFSec, Trivy, Checkov)

**Access Control**
- 👤 IAM com princípio de menor privilégio
- 👤 RBAC via CODEOWNERS (roteamento automático de reviews)
- 👤 Signed commits obrigatórios (main branch)
- 👤 Temporary credentials recomendadas (STS)

**Monitoring & Audit**
- 📝 Logs centralizados no CloudWatch (30+ dias de retenção)
- 📊 CloudWatch dashboards com alertas SNS
- 📋 7 CloudWatch alarms (response time, errors, CPU, memory, storage)
- 🔍 Terraform state lock (evita estado corrupto)
- 📡 VPC Flow Logs para análise de tráfego

📖 [Detalhes completos → SECURITY.md](SECURITY.md)

## Contribuição

Queremos sua contribuição! Siga as guidelines:

### Antes de Começar
1. Leia [CONTRIBUTING.md](CONTRIBUTING.md)
2. Instale pre-commit hooks: `./scripts/setup-pre-commit.sh`
3. Crie branch feature: `git checkout -b feat/sua-feature`

### Commits
Seguimos [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Feature
git commit -m "feat(vpc): add additional AZ support"

# Fix
git commit -m "fix(rds): correct backup retention window"

# Documentation
git commit -m "docs(runbooks): add scaling procedures"

# Chore
git commit -m "chore(deps): update Terraform to 1.7.0"
```

### Pull Request
1. Escreva descrição clara do que foi mudado
2. Reference issues relacionadas usando `Closes #123`
3. Garanta que CI/CD passa (workflows devem estar ✅)
4. Aguarde review (CODEOWNERS serão notificadas automaticamente)
5. Merge apenas após aprovação

### Code Quality Checks

Todos os PRs são verificados:

```bash
✅ terraform validate      # Syntax validation
✅ terraform fmt           # Code formatting
✅ tflint                  # Best practices
✅ tfsec                   # Security
✅ trivy                   # Vulnerability scanning
✅ checkov                 # Compliance policies
✅ gitleaks               # Secret detection
```

Falhas bloqueiam o merge. Para feedback, veja o comentário automático no PR.

### Dúvidas?

Dúvidas?

- Documentação: Procure em [docs/](docs/) ou [GETTING_STARTED.md](GETTING_STARTED.md)
- Issues: [GitHub Issues](../../issues)
- Implementação: Veja exemplos em módulos existentes
- Equipe: Slack #infrastructure ou email infrastructure@company.com

## 🔗 Quick Links

| Recurso | Propósito |
|---------|----------|
| [GETTING_STARTED.md](GETTING_STARTED.md) | Setup passo a passo (30m) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Guidelines para contribuição |
| [SECURITY.md](SECURITY.md) | Políticas de segurança |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Design da infraestrutura |
| [docs/COST_ESTIMATION.md](docs/COST_ESTIMATION.md) | Análise de custos detalhada |
| [docs/RUNBOOKS.md](docs/RUNBOOKS.md) | Como operar em produção |
| [docs/BRANCH_PROTECTION.md](docs/BRANCH_PROTECTION.md) | Code review & CI/CD setup |
| [docs/DOCKER_OPTIMIZATION.md](docs/DOCKER_OPTIMIZATION.md) | Build performance |
| [docs/VERSION_PINNING.md](docs/VERSION_PINNING.md) | Gestão de dependências |

## 🚦 Health Check

Para verificar se a infraestrutura está funcionando:

```bash
# 1. Validação de código
make check-all

# 2. Verificar status de deployments
aws ecs describe-services --cluster dev --services myapp-service --query 'services[0].[serviceName,status,runningCount,desiredCount]'

# 3. Ver logs recentes
aws logs tail /ecs/myapp-dev --follow

# 4. Acessar aplicação
curl http://<ALB_DNS>/health

# 5. Checklist do operador
- [ ] CloudWatch alarms estão verdes
- [ ] ECS tasks rodando = desired count
- [ ] RDS conexões ativas
- [ ] Logs sem erros críticos
- [ ] S3 buckets com dados esperados
```

## 📞 Suporte

| Canal | Para... |
|-------|---------|
| **#infrastructure** (Slack) | Dúvidas técnicas, pair programming |
| **GitHub Issues** | Bugs, feature requests, tracking |
| **infrastructure@company.com** | Escalação, emergências |
| **Standups** | Tuesdays 10am (Slack Video) |

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).
