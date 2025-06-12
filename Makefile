.PHONY: all zip deploy clean codescanner delete

LAMBDA_NAMES = zendesk_to_aws aws_to_zendesk api_authorizer
LAMBDA_SRC = lambdas
SHARED_SRC = lambdas/shared
ZIP_DIR = dist
BUILD_DIR = build
PLATFORM_DIR = platform
SCRIPTS_DIR = scripts
PYTHON_DEPS = boto3 aws_xray_sdk

validate_token:
	@echo "🔍 Validating bearer token..."
	@python3.13 $(SCRIPTS_DIR)/verify_token_security.py \
		--config-file $(PLATFORM_DIR)/tofill.auto.tfvars.json \
		--exit-on-fail \
		--min-length 15

install: 
	@echo "🔍 Checking for Python 3.13..."
	@command -v python3.13 >/dev/null 2>&1 || (echo "❌ Python 3.13 is not installed. Please install it first." && exit 1)
	@echo "🐍 Python 3.13 found."
	@echo "📦 Installing Python dependencies from requirements.txt..."
	@python3.13 -m pip install --upgrade pip
	@python3.13 -m pip install -r requirements.txt
	@echo "✅ Dependencies installed."


all: install zendesk_oauth zip init deploy zendesk_setup

init: validate_token
	cd $(PLATFORM_DIR) && terraform init


zip: clean_dist $(LAMBDA_NAMES)

$(LAMBDA_NAMES):
	@echo "📦 Building AWS Lambda function: $@"
	rm -rf $(BUILD_DIR)/$@
	mkdir -p $(BUILD_DIR)/$@/python

	# Install Python dependencies
	pip3 install --quiet --target $(BUILD_DIR)/$@/python $(PYTHON_DEPS)

	# Copy source
	cp $(LAMBDA_SRC)/$@/handler.py $(BUILD_DIR)/$@/
	cp -r $(SHARED_SRC) $(BUILD_DIR)/$@/shared

	# Create ZIP
	cd $(BUILD_DIR)/$@ && zip -qr ../../$(ZIP_DIR)/$@.zip .
	@echo "✅ Packaged: $(ZIP_DIR)/$@.zip"

clean_dist:
	rm -rf $(ZIP_DIR)/*
	mkdir -p $(ZIP_DIR)

deploy:
	@echo "🚀 Deploying to AWS with Terraform..."
	cd $(PLATFORM_DIR) && terraform fmt && terraform apply -auto-approve
	@echo "✅ Deployment complete."

delete:
	@echo "🗑️ Destroying Terraform deployment..."
	cd $(PLATFORM_DIR) && terraform destroy -auto-approve
	@echo "✅ Terraform resources destroyed."

clean:
	@echo "🧹 Cleaning build and dist folders"
	rm -rf $(BUILD_DIR) $(ZIP_DIR)

zendesk_oauth:
	@echo "🔐 Generating Zendesk OAuth access token..."
	python3.13 $(SCRIPTS_DIR)/zendesk_oauth_config.py \
		--config-file $(PLATFORM_DIR)/tofill.auto.tfvars.json

zendesk_setup:
	@echo "🚀 Deploying Zendesk configuration..."
	$(eval API_GATEWAY_URL := $(shell cd $(PLATFORM_DIR) && terraform output -raw api_gateway_url))
	python3.13 $(SCRIPTS_DIR)/zendesk_configuration.py \
		--api-gateway-url $(API_GATEWAY_URL) \
		--config-file $(PLATFORM_DIR)/tofill.auto.tfvars.json \
		--action setup \
		#--log-level DEBUG

zendesk_delete:
	@echo "🚀 Deleting Zendesk configuration..."
	python3.13 $(SCRIPTS_DIR)/zendesk_configuration.py \
		--config-file $(PLATFORM_DIR)/tofill.auto.tfvars.json \
		--action delete \
		#--log-level DEBUG

codescanner:
	@echo "🔍 Running security scans..."
	mkdir -p codescans

	@echo "🔍 Bandit..."
	@for name in $(LAMBDA_NAMES); do \
		bandit -r $(LAMBDA_SRC)/$$name -f json > codescans/bandit-$$name.json; \
	done

	@echo "🔍 detect-secrets..."
	detect-secrets scan > codescans/.secrets.baseline

	@echo "🔍 Semgrep..."
	semgrep --config=auto . --sarif > codescans/semgrep_report.sarif

	@echo "🔍 pip-audit..."
	pip-audit -r requirements.txt --format json > codescans/pip-audit.json || echo "[]" > codescans/pip-audit.json

	@echo "🔍 safety check..."
	pip3 install -q safety
	safety check --file=requirements.txt --json > codescans/safety-report.json || echo "[]" > codescans/safety-report.json

	@echo "🔍 Checkov..."
	checkov --skip-framework secrets -d $(PLATFORM_DIR) -o sarif --output-file-path codescans/

	
	@echo "✅ Security scans complete."
