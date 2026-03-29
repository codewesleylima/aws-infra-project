#!/bin/bash
# ==============================================
# Validar que não há secrets no repositório
# ==============================================
# Executar antes de fazer commit:
#   bash scripts/validate-no-secrets.sh

set -euo pipefail

echo "🔐 Verificando secrets..."

# Arquivos sensíveis que NÃO devem existir
SENSITIVE_FILES=(
  ".env"
  ".env.local"
  ".env.prod"
  ".env.staging"
  "secrets.txt"
  "aws_credentials.json"
  "*.key"
  "*.pem"
)

# Padrões de credenciais que NÃO devem estar no código
SENSITIVE_PATTERNS=(
  "AKIA[0-9A-Z]\{16\}"  # AWS Access Keys
  "aws_secret_access_key"
  "BEGIN RSA PRIVATE KEY"
  "BEGIN PRIVATE KEY"
  "password.*=.*[a-zA-Z0-9]"
)

FOUND_ISSUES=0

# Verificar arquivo .gitignore
if [ ! -f ".gitignore" ]; then
  echo "❌ Arquivo .gitignore não encontrado"
  FOUND_ISSUES=1
else
  if ! grep -q "\.env" .gitignore; then
    echo "❌ .env não está em .gitignore"
    FOUND_ISSUES=1
  else
    echo "✅ .env protegido em .gitignore"
  fi
fi

# Verificar se arquivos sensíveis existem
for file in "${SENSITIVE_FILES[@]}"; do
  if find . -name "$file" -not -path "./.git/*" 2>/dev/null | grep -q .; then
    echo "❌ Arquivo sensível encontrado: $file"
    FOUND_ISSUES=1
  fi
done

# Escanear por padrões perigosos (exceto docs)
echo "Escaneando por padrões de credenciais..."
for pattern in "${SENSITIVE_PATTERNS[@]}"; do
  if grep -r "$pattern" . \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=build \
    --exclude="*.md" \
    --exclude="SECURITY_SECRETS.md" \
    2>/dev/null | grep -v ".example" | grep -q .; then
    echo "⚠️  Possível credencial encontrada: $pattern"
    grep -r "$pattern" . \
      --exclude-dir=.git \
      --exclude-dir=node_modules \
      --exclude="*.md" 2>/dev/null || true
    FOUND_ISSUES=1
  fi
done

# Verificar .env.example (deve existir mas sem valores reais)
if [ -f ".env.example" ]; then
  echo "✅ .env.example encontrado (referência segura)"
  if grep -E "=[a-zA-Z0-9]{20,}" .env.example | grep -v "seu_\|exemplo" >/dev/null 2>&1; then
    echo "⚠️  AVISO: .env.example contém valores que parecem reais!"
    FOUND_ISSUES=1
  fi
else
  echo "⚠️  .env.example não encontrado (recomendado para referência)"
fi

# Verificar commits históricos (se git está disponível)
if command -v git &> /dev/null; then
  echo "Verificando histórico git para credenciais..."
  if git log -p | grep -E "AKIA[0-9A-Z]{16}|BEGIN PRIVATE KEY" >/dev/null 2>&1; then
    echo "❌ Credenciais encontradas no histórico git!"
    echo "   Execute: git secrets --scan"
    FOUND_ISSUES=1
  fi
fi

echo ""
if [ $FOUND_ISSUES -eq 0 ]; then
  echo "✅ Validação OK - Nenhum secret encontrado"
  exit 0
else
  echo "❌ Problemas encontrados - veja acima"
  exit 1
fi
