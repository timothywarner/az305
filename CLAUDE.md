# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is Tim Warner's AZ-305 (Azure Solutions Architect Expert) certification teaching repository for O'Reilly Live Learning. Contains study materials, practice questions, IaC templates (Bicep/ARM), and PowerShell scripts organized around 5 course segments:

1. Identity, Governance & Monitoring
2. Data Storage Solutions
3. Business Continuity & DR
4. Infrastructure & Compute Solutions
5. Network Solutions

## Key Directories

- `infra/` - Infrastructure as Code templates (Bicep/ARM)
- `scripts/` - PowerShell, Azure CLI, and KQL scripts organized by category
- `docs/` - Exam objective documentation, practice questions, and reference materials
- `az305-demo/` - Live demo environment documentation
- `az305-demo/diagrams/` - Architecture topology diagrams

## Commands

### Diagram Scraper
```bash
pip install -r requirements.txt
python download_diagrams.py
```

### Bicep Deployment
```bash
az deployment group create --resource-group <rg-name> --template-file <file.bicep> --parameters <file.parameters.json>
```

### PowerShell Scripts
Scripts in `scripts/powershell/` are standalone - run directly with PowerShell 7.

## Technology Preferences (from .cursorrules)

- **IaC**: Bicep over ARM templates
- **Scripting**: PowerShell 7 (not 5.1)
- **Containers**: Azure Container Apps for most scenarios
- **Security**: Zero Trust architecture, managed identities throughout
- **Connectivity**: Private Link enabled resources

## Response Format Guidelines

From .cursorrules - when providing guidance:
1. Be **DECISIVE** - single best recommendation with justification, not multiple options
2. Be **OPINIONATED** - make strong technology choices based on cost, performance, security
3. End implementation responses with **three prioritized next steps**:
   - [IMMEDIATE] - Action to do now
   - [SHORT-TERM] - Follow-up within days
   - [LONG-TERM] - Strategic consideration
4. **CONTEXT EFFICIENCY** - bullet points over paragraphs, skip pleasantries, focus on actionable details

## Architecture Principles

Every demo/solution should:
- Use managed identity (not service principals with secrets)
- Enable Private Link for data services
- Follow Zero Trust patterns
- Consider cost optimization

## Key Files

- `az305-course-flow.md` - 5-segment course schedule with demo flows
- `practice-questions.md` - 100+ exam practice questions with explanations
- `reference-architectures.md` - 9 key reference architectures mapped to exam objectives
- `lab-environment.md` - Free Azure lab setup guidance

## External Resources

- [AZ-305 Exam Page](https://learn.microsoft.com/credentials/certifications/exams/az-305)
- [AZ-305 Study Guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-305)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
- [Microsoft Learning AZ-305 Labs](https://github.com/MicrosoftLearning/AZ-305-DesigningMicrosoftAzureInfrastructureSolutions)
