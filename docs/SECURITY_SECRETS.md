# 🔐 Guia de Segurança - Secrets e Dados Sensíveis

## ⚠️ Regras Críticas

1. **NUNCA commitar dados sensíveis** no repositório
2. **SEMPRE usar GitHub Secrets** para credenciais em CI/CD
3. **SEMPRE testar localmente com `.env.example`**
4. **NUNCA logar credenciais reais** em outputs ou logs

---

## 📋 Secrets Necessários no GitHub

Você deve configurar estes secrets no repositório:

```
GitHub > Settings > Secrets and variables > Actions > New repository secret
```

### Para Desenvolvimento (Dev)
- `AWS_ROLE_ARN` — ARN da role IAM para dev
  - Formato: `arn:aws:iam::123456789012:role/github-actions-dev`

### Para Staging
- `AWS_ROLE_ARN_STAGING` — ARN da role IAM para staging
  - Formato: `arn:aws:iam::123456789012:role/github-actions-staging`

### Para Produção (Prod)
- `AWS_ROLE_ARN_PROD` — ARN da role IAM para produção
  - Formato: `arn:aws:iam::123456789012:role/github-actions-prod`

### Alternativa: Credenciais Diretas (menos seguro)
Se não usar OIDC/AssumeRole:
- `AWS_ACCESS_KEY_ID` — sua access key
- `AWS_SECRET_ACCESS_KEY` — sua secret key

---

## 🔧 Como Usar Secrets no Workflow

### ✅ CORRETO — Referência Segura

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

### ❌ ERRADO — NUNCA FAÇA ISSO

```yaml
# Nunca coloque credenciais em plain text no workflow!
- name: Export credentials
  run: |
    export AWS_ACCESS_KEY_ID=AKIA1234567890AB  # ❌ NUNCA!
    export AWS_SECRET_ACCESS_KEY=abc123def456  # ❌ NUNCA!
```

### ❌ ERRADO — Outputs sem Masking

```yaml
# Outputs de secrets não são automaticamente mascarados!
- name: Debug (RUIM)
  run: echo "Key is: ${{ secrets.AWS_SECRET_ACCESS_KEY }}"  # ❌ RUIM!
```

### ✅ CORRETO — Usar `add-mask`

```yaml
- name: Mask sensitive output
  run: |
    echo "::add-mask::${{ secrets.AWS_SECRET_ACCESS_KEY }}"
    echo "Processando com credenciais..."  # Output is safe
```

---

## 🏗️ Estrutura de Arquivos Seguros

```
aws-infra-project/
├── .env.example              # ✅ Compartilhável (sem valores reais)
├── .env                       # ❌ Git-ignored (valores reais LOCAIS)
├── .env.local                 # ❌ Git-ignored (overrides locais)
├── .gitignore                 # ✅ Contém regras para proteger .env
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # ✅ Referencia ${{ secrets.* }}
└── terraform/
    └── environments/
        └── dev/
            └── terraform.tfvars # ❌ Git-ignored (valores reais)
```

### Checklist: O que deve estar em `.gitignore`

```gitignore
# Variáveis de ambiente
.env
.env.local
.env.prod
.env.staging

# Chaves privadas
*.key
*.pem
*.pub

# Arquivos de credenciais
secrets.txt
aws_credentials.json
~/.aws/credentials
```

---

## 🔐 Melhores Práticas para GitHub Actions

### 1. Use OIDC (Recomendado - SEM Credenciais Armazenadas)

```yaml
- name: Configure AWS Credentials (OIDC)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
    # Sem AWS_ACCESS_KEY_ID ou AWS_SECRET_ACCESS_KEY
```

**Vantagens:**
- Sem credenciais de longa validade armazenadas
- Token STS de curta duração gerado automaticamente
- Mais seguro para CI/CD

### 2. Use Environments para Proteção

```yaml
jobs:
  deploy-prod:
    environment: production  # ← Exige aprovação manual
    steps:
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN_PROD }}
```

---

## 🛡️ Auditoria e Validação

### Verificar quais secrets estão configurados

```bash
# Via GitHub CLI
gh secret list

# Via API (autenticado)
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/actions/secrets
```

### Escanear repositório para credenciais vazadas

```bash
# Usar TruffleHog (busca credenciais em histórico git)
trufflehog git https://github.com/seu-usuario/seu-repo

# Usar git-secrets
git secrets --scan
```

---

## 📝 Exemplo Completo Seguro

### `.env.example` (COMPARTILHÁVEL)
```bash
# Local development - use fake values
AWS_REGION=us-east-1
LOCALSTACK_ENDPOINT=http://localhost:4566
```

### `.github/workflows/ci-cd.yml` (Referencias seguras)
```yaml
- name: Setup AWS
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}

- name: Run Terraform
  env:
    TF_VAR_region: ${{ env.AWS_REGION }}
  run: terraform apply
```

### Localmente (`.env` - NUNCA commitar)
```bash
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/my-role
AWS_REGION=us-east-1
```

---

## ✅ Checklist de Segurança

- [ ] `.env` está em `.gitignore`
- [ ] `.env.example` contém APENAS placeholders
- [ ] Nenhum arquivo `.key`, `.pem`, `.cert` commitado
- [ ] Workflow referencia `${{ secrets.* }}` (nunca hardcoded)
- [ ] Secrets estão configurados em GitHub Settings
- [ ] Nenhum secret apareça em logs (ou mascarado com `add-mask`)
- [ ] OIDC/AssumeRole configurado (evita credenciais permanentes)
- [ ] Branch protection exige review para deployments
- [ ] Rotação de credenciais em plano (a cada 90 dias)

---

## 🚨 Se você vazar credenciais acidentalmente

1. **Imediatamente:**
   ```bash
   # Remover do histórico git
   git rm --cached .env
   git commit --amend -m "Remove secrets from history"
   git push --force-with-lease
   ```

2. **No GitHub:**
   - Ir em Settings > Secrets > Delete a secret vazada
   - Criar nova credencial no AWS IAM
   - Atualizar secret no GitHub

3. **No AWS:**
   - Desativar a credencial comprometida
   - Criar nova access key
   - Atualizar no GitHub Secrets

---

## 📚 Referências

- [GitHub Secrets Documentation](https://docs.github.com/pt/actions/security-guides/encrypted-secrets)
- [AWS OIDC no GitHub Actions](https://docs.github.com/pt/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [TruffleHog - Secret Scanner](https://github.com/trufflesecurity/trufflehog)
- [git-secrets Tool](https://github.com/awslabs/git-secrets)

