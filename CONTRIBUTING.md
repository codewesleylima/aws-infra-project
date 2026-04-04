# Guia de Contribuição

Obrigado por considerar contribuir com este projeto! Este documento fornece diretrizes para garantir um processo de contribuição consistente e de qualidade.

## 📋 Índice

- [Código de Conduta](#código-de-conduta)
- [Como Contribuir](#como-contribuir)
- [Conventional Commits](#conventional-commits)
- [Padrões de Código](#padrões-de-código)
- [Pull Requests](#pull-requests)
- [Revisão de Código](#revisão-de-código)

## Código de Conduta

Este projeto segue um código de conduta profissional. Esperamos que todos os contribuidores:

- Sejam respeitosos e inclusivos
- Aceitem feedback construtivo
- Foquem no que é melhor para o projeto
- Demonstrem empatia com outros membros da comunidade

## Como Contribuir

### 1. Fork e Clone

```bash
# Fork o repositório via GitHub UI, depois:
git clone https://github.com/SEU_USUARIO/aws-infra-project.git
cd aws-infra-project
git remote add upstream https://github.com/codewesleylima/aws-infra-project.git
```

### 2. Crie uma Branch

```bash
# Atualize sua main
git checkout main
git pull upstream main

# Crie uma branch descritiva
git checkout -b feat/nome-da-feature
# ou
git checkout -b fix/descricao-do-bug
```

### 3. Faça suas Mudanças

- Siga os padrões de código
- Adicione testes se aplicável
- Atualize a documentação

### 4. Commit e Push

```bash
git add .
git commit -m "feat: adiciona módulo de monitoramento CloudWatch"
git push origin feat/nome-da-feature
```

### 5. Abra um Pull Request

- Use o template de PR
- Vincule issues relacionadas
- Aguarde a revisão

## Conventional Commits

Este projeto usa [Conventional Commits](https://www.conventionalcommits.org/) para mensagens de commit padronizadas.

### Formato

```
<tipo>[escopo opcional]: <descrição>

[corpo opcional]

[rodapé opcional]
```

### Tipos Permitidos

| Tipo | Descrição |
|------|-----------|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `docs` | Apenas documentação |
| `style` | Formatação (sem mudança de código) |
| `refactor` | Refatoração de código |
| `perf` | Melhoria de performance |
| `test` | Adição ou correção de testes |
| `build` | Mudanças no build ou dependências |
| `ci` | Mudanças em CI/CD |
| `chore` | Outras mudanças (configs, etc) |
| `revert` | Reverter commit anterior |

### Exemplos

```bash
# Feature nova
feat(ecs): adiciona auto-scaling baseado em memória

# Correção
fix(rds): corrige timeout de conexão em ambientes de produção

# Documentação
docs: atualiza instruções de instalação no README

# CI/CD
ci: adiciona scan de vulnerabilidades com Trivy

# Breaking change (usar ! ou BREAKING CHANGE no rodapé)
feat(vpc)!: remove suporte para VPC peering legado

BREAKING CHANGE: a variável vpc_peering_id foi removida.
Use vpc_peering_config ao invés.

# Com escopo
refactor(modules/s3): simplifica configuração de lifecycle

# Multi-linha
fix(ecs): corrige health check falhando após deploy

O health check estava configurado com timeout muito curto
para containers que demoram para inicializar.

Aumentado timeout de 5s para 30s.

Closes #123
```

### Escopos Recomendados

- `vpc` - Módulo de rede
- `ecs` - Módulo de containers
- `rds` - Módulo de banco de dados
- `s3` - Módulo de storage
- `iam` - Módulo de permissões
- `ci` - GitHub Actions
- `docs` - Documentação

## Padrões de Código

### Terraform

```hcl
# ✅ Bom: Use snake_case para nomes
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# ✅ Bom: Sempre adicione tags
tags = merge(var.tags, {
  Name = "${var.project_name}-resource"
})

# ✅ Bom: Documente variáveis
variable "instance_class" {
  description = "Classe da instância RDS (ex: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

# ✅ Bom: Use validação quando apropriado
variable "environment" {
  description = "Ambiente de deploy"
  type        = string
  validation {
    condition     = contains(["dev", "hom", "prod"], var.environment)
    error_message = "Environment deve ser: dev, hom ou prod."
  }
}
```

### Formatação

```bash
# Sempre formate antes de commitar
terraform fmt -recursive

# Valide a sintaxe
terraform validate
```

### Segurança

- Nunca commit secrets ou credenciais
- Use AWS Secrets Manager para dados sensíveis
- Aplique princípio de menor privilégio em IAM
- Habilite criptografia em todos os recursos

## Pull Requests

### Checklist do PR

- [ ] Branch atualizada com main
- [ ] Commits seguem Conventional Commits
- [ ] `terraform fmt` executado
- [ ] `terraform validate` passou
- [ ] Documentação atualizada
- [ ] Sem secrets no código
- [ ] Tests passando (se aplicável)

### Tamanho do PR

- Mantenha PRs pequenos e focados
- Um PR = Uma funcionalidade ou correção
- PRs grandes são mais difíceis de revisar

## Revisão de Código

### Para Autores

- Responda aos comentários de forma construtiva
- Faça as mudanças solicitadas ou explique por que não
- Mantenha a discussão focada

### Para Revisores

- Seja construtivo e respeitoso
- Explique o "porquê" das sugestões
- Aprove quando estiver satisfeito
- Use "Request changes" apenas para issues críticos

### Critérios de Aprovação

- [ ] Código segue os padrões do projeto
- [ ] Mudanças são seguras
- [ ] Documentação está adequada
- [ ] Não há regressões óbvias

---

## Dúvidas?

Abra uma issue com a label `question` ou entre em contato com os mantenedores.

Obrigado por contribuir! 🎉
