## Descrição

<!-- Descreva suas mudanças de forma clara e objetiva -->

## Tipo de Mudança

- [ ] 🐛 Bug fix (correção que não quebra funcionalidades existentes)
- [ ] ✨ Nova feature (mudança que adiciona funcionalidade)
- [ ] 💥 Breaking change (correção ou feature que causa mudança em funcionalidades existentes)
- [ ] 📚 Documentação (atualização ou adição de documentação)
- [ ] 🔧 Configuração (mudanças em CI/CD, configs, etc)
- [ ] ♻️ Refactoring (mudança que não adiciona feature nem corrige bug)

## Ambiente Afetado

- [ ] 🟢 Dev
- [ ] 🟡 Staging
- [ ] 🔴 Production

## Checklist

### Código
- [ ] Meu código segue as guidelines do projeto
- [ ] Realizei self-review do meu código
- [ ] Comentei partes complexas do código
- [ ] Minhas mudanças não geram novos warnings

### Terraform
- [ ] `terraform fmt` foi executado
- [ ] `terraform validate` passou sem erros
- [ ] `terraform plan` foi revisado
- [ ] Recursos sensíveis estão usando KMS para criptografia
- [ ] Security Groups seguem o princípio de menor privilégio

### Segurança
- [ ] Não há secrets ou credenciais no código
- [ ] Checkov/tfsec não reportaram novos issues críticos
- [ ] IAM policies seguem o princípio de menor privilégio

### Documentação
- [ ] README foi atualizado (se necessário)
- [ ] Variáveis têm descrições adequadas
- [ ] Outputs estão documentados

## Screenshots/Logs

<!-- Se aplicável, adicione screenshots ou logs do terraform plan -->

<details>
<summary>Terraform Plan Output</summary>

```
Cole o output do terraform plan aqui
```

</details>

## Notas Adicionais

<!-- Qualquer informação adicional para os revisores -->
