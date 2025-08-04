#!/bin/bash

# Security Audit Script for Globtim Project
# Run this periodically to check for security issues

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Running Globtim Security Audit...${NC}"

# Check for sensitive files in repository
echo -e "\n${YELLOW}1. Checking for sensitive files...${NC}"
SENSITIVE_PATTERNS=("*.key" "*.pem" "*password*" "*secret*" "*token*" "*.p12" "*.pfx")
FOUND_SENSITIVE=false

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    FILES=$(find . -name "$pattern" -not -path "./.git/*" 2>/dev/null)
    if [ -n "$FILES" ]; then
        echo -e "${RED}⚠️  Found sensitive files matching $pattern:${NC}"
        echo "$FILES"
        FOUND_SENSITIVE=true
    fi
done

if [ "$FOUND_SENSITIVE" = false ]; then
    echo -e "${GREEN}✓ No sensitive files found${NC}"
fi

# Check SSH key permissions
echo -e "\n${YELLOW}2. Checking SSH key permissions...${NC}"
SSH_KEYS=$(find ~/.ssh -name "id_*" -not -name "*.pub" 2>/dev/null)
for key in $SSH_KEYS; do
    if [ -f "$key" ]; then
        PERMS=$(stat -f "%A" "$key" 2>/dev/null || stat -c "%a" "$key" 2>/dev/null)
        if [ "$PERMS" = "600" ]; then
            echo -e "${GREEN}✓ $key has correct permissions (600)${NC}"
        else
            echo -e "${RED}⚠️  $key has incorrect permissions ($PERMS), should be 600${NC}"
        fi
    fi
done

# Check .gitignore coverage
echo -e "\n${YELLOW}3. Checking .gitignore coverage...${NC}"
REQUIRED_PATTERNS=("*.key" "*.pem" "*password*" "*secret*" "cluster_config.sh")
for pattern in "${REQUIRED_PATTERNS[@]}"; do
    if grep -q "$pattern" .gitignore; then
        echo -e "${GREEN}✓ $pattern is gitignored${NC}"
    else
        echo -e "${RED}⚠️  $pattern is NOT gitignored${NC}"
    fi
done

# Check for hardcoded credentials in scripts
echo -e "\n${YELLOW}4. Checking for hardcoded credentials...${NC}"
CRED_PATTERNS=("password=" "token=" "secret=" "key=" "@.*:")
FOUND_CREDS=false

for pattern in "${CRED_PATTERNS[@]}"; do
    FILES=$(grep -r -l "$pattern" --include="*.sh" --include="*.jl" . 2>/dev/null | grep -v ".git")
    if [ -n "$FILES" ]; then
        echo -e "${RED}⚠️  Potential hardcoded credentials found (pattern: $pattern):${NC}"
        echo "$FILES"
        FOUND_CREDS=true
    fi
done

if [ "$FOUND_CREDS" = false ]; then
    echo -e "${GREEN}✓ No hardcoded credentials detected${NC}"
fi

# Summary
echo -e "\n${YELLOW}Security Audit Complete${NC}"
echo -e "${GREEN}Remember to:${NC}"
echo "• Never commit SSH keys or passwords"
echo "• Use environment variables or config files for sensitive data"
echo "• Regularly rotate SSH keys"
echo "• Keep your local machine secure"
