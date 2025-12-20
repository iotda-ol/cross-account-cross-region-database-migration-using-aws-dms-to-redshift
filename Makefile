# Makefile for DMS Migration Project

.PHONY: help init install test lint format clean deploy destroy validate

# Default target
help:
	@echo "DMS Migration Project - Available Commands:"
	@echo ""
	@echo "  make init       - Initialize Terraform and Python environment"
	@echo "  make install    - Install Python dependencies"
	@echo "  make test       - Run Python tests"
	@echo "  make lint       - Run linters (Python and Terraform)"
	@echo "  make format     - Format code (Python and Terraform)"
	@echo "  make validate   - Validate Terraform configuration"
	@echo "  make plan       - Run Terraform plan"
	@echo "  make deploy     - Deploy infrastructure with Terraform"
	@echo "  make destroy    - Destroy infrastructure"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make docs       - Generate documentation"
	@echo "  make pre-check  - Run pre-migration validation"
	@echo ""

# Initialize project
init:
	@echo "Initializing project..."
	cd terraform/environments/dev && terraform init
	cd python && python -m venv venv
	@echo "✓ Project initialized"

# Install Python dependencies
install:
	@echo "Installing Python dependencies..."
	cd python && . venv/bin/activate && pip install -r requirements.txt
	@echo "✓ Dependencies installed"

# Run tests
test:
	@echo "Running tests..."
	cd python && . venv/bin/activate && pytest tests/ -v --cov=src
	@echo "✓ Tests completed"

# Run linters
lint:
	@echo "Running linters..."
	cd python && . venv/bin/activate && flake8 src/ tests/
	cd python && . venv/bin/activate && mypy src/
	cd terraform && terraform fmt -check -recursive
	@echo "✓ Linting completed"

# Format code
format:
	@echo "Formatting code..."
	cd python && . venv/bin/activate && black src/ tests/
	cd python && . venv/bin/activate && isort src/ tests/
	cd terraform && terraform fmt -recursive
	@echo "✓ Code formatted"

# Validate Terraform
validate:
	@echo "Validating Terraform..."
	cd terraform/environments/dev && terraform validate
	@echo "✓ Terraform validation completed"

# Terraform plan
plan:
	@echo "Running Terraform plan..."
	cd terraform/environments/dev && terraform plan -out=tfplan
	@echo "✓ Terraform plan completed"

# Deploy infrastructure
deploy:
	@echo "Deploying infrastructure..."
	cd terraform/environments/dev && terraform apply tfplan
	@echo "✓ Infrastructure deployed"

# Destroy infrastructure
destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform/environments/dev && terraform destroy; \
		echo "✓ Infrastructure destroyed"; \
	else \
		echo "Cancelled"; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .mypy_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	cd terraform/environments/dev && rm -f tfplan 2>/dev/null || true
	@echo "✓ Cleaned build artifacts"

# Generate documentation
docs:
	@echo "Generating documentation..."
	@echo "Documentation is available in docs/ directory"
	@echo "✓ Documentation generated"

# Run pre-migration check
pre-check:
	@echo "Running pre-migration validation..."
	cd python && . venv/bin/activate && python scripts/pre_migration_check.py --config ../config/examples/dev-config.json
	@echo "✓ Pre-migration check completed"

# Install pre-commit hooks
install-hooks:
	@echo "Installing pre-commit hooks..."
	cd python && . venv/bin/activate && pre-commit install
	@echo "✓ Pre-commit hooks installed"

# Run all checks
check: lint test validate
	@echo "✓ All checks passed"
