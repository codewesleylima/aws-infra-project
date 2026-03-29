# Política de Segurança

## Versões Suportadas

| Versão | Suportada |
|--------|-----------|
| 1.x.x  | ✅        |
| < 1.0  | ❌        |

## Reportando Vulnerabilidades

### ⚠️ NÃO abra issues públicas para vulnerabilidades de segurança

Se você descobrir uma vulnerabilidade de segurança, por favor reporte de forma responsável:

1. **Email**: Envie detalhes para [seu-email@exemplo.com]
2. **Assunto**: `[SECURITY] Descrição breve do problema`
3. **Inclua**:
   - Descrição da vulnerabilidade
   - Passos para reproduzir
   - Impacto potencial
   - Sugestão de correção (se tiver)

### Tempo de Resposta

- **Confirmação inicial**: 48 horas
- **Avaliação**: 7 dias
- **Correção (crítico)**: 14 dias
- **Correção (alto)**: 30 dias
- **Correção (médio/baixo)**: 60 dias

## Práticas de Segurança

### Infraestrutura AWS

Esta infraestrutura implementa as seguintes práticas de segurança:

#### Rede (VPC)
- ✅ Subnets públicas e privadas segregadas
- ✅ NAT Gateway para acesso outbound controlado
- ✅ VPC Flow Logs habilitados
- ✅ Security Groups com menor privilégio

#### Dados (RDS/S3)
- ✅ Criptografia em repouso (KMS)
- ✅ Criptografia em trânsito (TLS)
- ✅ Backups automáticos
- ✅ Multi-AZ em produção
- ✅ Acesso restrito via Security Groups

#### Containers (ECS)
- ✅ Execução em subnets privadas
- ✅ IAM roles com menor privilégio
- ✅ Secrets via AWS Secrets Manager
- ✅ Container Insights habilitado

#### Acesso (IAM)
- ✅ Princípio de menor privilégio
- ✅ Roles ao invés de usuários para serviços
- ✅ MFA requerido para acesso ao console
- ✅ Rotação de credenciais

### CI/CD

- ✅ OIDC para autenticação AWS (sem secrets)
- ✅ Scan de segurança automático (Checkov, tfsec)
- ✅ Detecção de secrets (Gitleaks)
- ✅ Scan de dependências (Trivy)
- ✅ Aprovações obrigatórias para produção

## Checklist de Segurança

Antes de fazer deploy, verifique:

### Terraform
- [ ] Nenhum secret hardcoded
- [ ] Todos os recursos com criptografia
- [ ] Security Groups restritivos
- [ ] IAM policies com menor privilégio
- [ ] Logs habilitados

### Código
- [ ] Sem credenciais no repositório
- [ ] Dependências atualizadas
- [ ] Scan de segurança passou

### Deploy
- [ ] Variáveis sensíveis via Secrets Manager
- [ ] HTTPS habilitado
- [ ] Certificados válidos

## Contatos de Segurança

- **Responsável**: @codewesleylima
- **Email**: [seu-email@exemplo.com]

## Recursos Adicionais

- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
