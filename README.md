# AWS Infrastructure Project

[![CI/CD Pipeline](https://github.com/codewesleylima/aws-infra-project/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/codewesleylima/aws-infra-project/actions/workflows/ci-cd.yml)
[![Security Scan](https://github.com/codewesleylima/aws-infra-project/actions/workflows/security.yml/badge.svg)](https://github.com/codewesleylima/aws-infra-project/actions/workflows/security.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform)](https://www.terraform.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Infraestrutura AWS completa com CI/CD, seguindo as melhores práticas de segurança e IaC (Infrastructure as Code).

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Configuração Rápida](#configuração-rápida)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Ambientes](#ambientes)
- [CI/CD Pipeline](#cicd-pipeline)
- [Segurança](#segurança)
- [Contribuição](#contribuição)

## Visão Geral

Este projeto implementa uma infraestrutura AWS escalável e segura utilizando Terraform, com pipeline CI/CD automatizado via GitHub Actions.

**Recursos principais:**
- VPC com subnets públicas e privadas
- ECS Fargate para containerização
- RDS PostgreSQL com backups automáticos
- S3 para armazenamento com criptografia
- IAM com políticas de menor privilégio
- Secrets Manager para credenciais

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
- [AWS CLI](https://aws.amazon.com/cli/) configurado
- [Git](https://git-scm.com/)
- Conta AWS com permissões adequadas

## Configuração Rápida

### 1) AWS real (quando disponível)
```bash
# Clone o repositório
git clone https://github.com/codewesleylima/aws-infra-project.git
cd aws-infra-project

# Configure as variáveis de ambiente AWS
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Inicialize e aplique (ambiente dev)
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 2) Local (sem AWS) usando LocalStack + Docker
Recomendado se você não tem credenciais AWS:

```bash
# Instale LocalStack (Docker deve estar instalado)
docker run --rm -d --name localstack -p 4566:4566 -p 4571:4571 localstack/localstack

# Vá para o diretório do projeto
git clone https://github.com/codewesleylima/aws-infra-project.git
cd aws-infra-project/terraform/environments/dev

# Execute com LocalStack
terraform init
terraform plan -var='use_localstack=true' -var='localstack_endpoint=http://localhost:4566'
# Se quiser apply (local apenas)
terraform apply -var='use_localstack=true' -var='localstack_endpoint=http://localhost:4566' -auto-approve
```

> Teste recomendável: `terraform fmt -recursive` e `terraform validate` antes de `plan`.

## Estrutura do Projeto

```
aws-infra-project/
├── .github/
│   ├── workflows/
│   │   ├── ci-cd.yml          # Pipeline principal
│   │   └── security.yml       # Scans de segurança
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── terraform/
│   ├── modules/
│   │   ├── vpc/               # Rede e subnets
│   │   ├── ecs/               # Containers
│   │   ├── rds/               # Banco de dados
│   │   ├── s3/                # Armazenamento
│   │   ├── iam/               # Permissões
│   │   └── secrets/           # Credenciais
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── scripts/
│   └── setup.sh
├── docs/
│   └── ARCHITECTURE.md
├── .gitignore
├── CONTRIBUTING.md
├── SECURITY.md
└── README.md
```

## Ambientes

| Ambiente | Descrição | Branch |
|----------|-----------|--------|
| `dev` | Desenvolvimento e testes | `develop` |
| `staging` | Validação pré-produção | `staging` |
| `prod` | Produção | `main` |

## CI/CD Pipeline

O pipeline executa automaticamente:

1. **Validação** - Lint e formato do Terraform
2. **Segurança** - Scan com Checkov e tfsec
3. **Plan** - Preview das mudanças
4. **Apply** - Deploy (apenas em branches protegidas)

### Proteções de Branch

- `main`: Requer 2 aprovações + CI verde
- `staging`: Requer 1 aprovação + CI verde
- `develop`: Requer CI verde

## Segurança

- 🔒 Secrets gerenciados via AWS Secrets Manager
- 🔐 Criptografia em repouso e trânsito
- 🛡️ Security Groups com menor privilégio
- 📝 Logs centralizados no CloudWatch
- 🔍 Scan automático de vulnerabilidades

## Contribuição

Consulte [CONTRIBUTING.md](CONTRIBUTING.md) para guidelines de contribuição.

**Commits seguem o padrão [Conventional Commits](https://www.conventionalcommits.org/):**

```
feat: adiciona módulo de monitoramento
fix: corrige timeout no health check
docs: atualiza documentação da VPC
chore: atualiza versão do Terraform
```

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).
