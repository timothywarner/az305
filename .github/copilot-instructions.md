# Copilot Instructions for az305

## Project purpose

- AZ-305 certification study repo with course flow, practice questions, and Azure architecture references.
- Primary content types: Markdown study materials, IaC templates, and standalone scripts.

## Key structure and examples

- Course materials and metadata live in [az305-course-flow.md](az305-course-flow.md) and [az305-exam-metadata/](az305-exam-metadata/).
- IaC templates: Bicep preferred in [iac/](iac/) and ARM templates in [resources/templates/](resources/templates/).
- Scripts: PowerShell in [resources/powershell/](resources/powershell/) and [resources/scripts/](resources/scripts/).
- Diagram assets in [diagrams/](diagrams/) and images in [images/](images/).

## Workflow knowledge

- Diagram scraper:
  - Install deps from [requirements.txt](requirements.txt).
  - Run `download_diagrams.py` per [README.md](README.md).
- Bicep deployments typically use `az deployment group create` with a `.bicep` and matching `.parameters.json` per [CLAUDE.md](CLAUDE.md).
- PowerShell scripts are standalone and intended for PowerShell 7.

## Project-specific conventions

- Prefer Bicep over ARM templates when adding IaC (see [iac/](iac/)).
- Azure guidance should favor managed identity, Private Link, Zero Trust, and cost-aware choices (see [CLAUDE.md](CLAUDE.md)).
- Keep responses decisive and concise; favor a single best recommendation (see [.cursorrules](.cursorrules)).

## Integration points

- External references are mostly Microsoft Learn and AZ-305 exam resources (see [README.md](README.md)).
- Templates map to specific Azure services under [resources/templates/](resources/templates/); align new examples with those service folders.
