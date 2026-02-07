#!/usr/bin/env bash
#
# ssm-deploy-wrapper.sh - Wrapper script for SSM Run Command deployments
#
# This wrapper sets up the environment for SSM execution context and calls
# the main deployment script. It handles SSM-specific logging and returns
# proper exit codes for SSM command tracking.
#
# Usage: This script is invoked via AWS SSM Send-Command
#
# Exit codes: Inherits from update-stack.sh
#   0 - Deployment successful
#   1 - General error
#   2 - Backup creation failed
#   3 - Service shutdown failed
#   4 - Service startup failed
#   5 - Health check failed
#   6 - Rollback failed

set -euo pipefail

# Configuration
STACK_DIR="/opt/stacks/n8n"
DEPLOYMENT_SCRIPT="${STACK_DIR}/update-stack.sh"
ENV_FILE="${STACK_DIR}/.env"
SSM_LOG="/var/log/ssm-deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function for SSM context
log_ssm() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Log to SSM log file
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${SSM_LOG}"

    # Also log to stdout for SSM command output
    case "${level}" in
        INFO)
            echo -e "${GREEN}[INFO]${NC} ${message}"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}"
            ;;
        *)
            echo -e "${BLUE}[${level}]${NC} ${message}"
            ;;
    esac
}

# Error handler
error_exit() {
    local exit_code="${1:-1}"
    local message="${2:-Unknown error during SSM deployment}"
    log_ssm ERROR "${message}"
    log_ssm ERROR "SSM deployment failed with exit code: ${exit_code}"
    exit "${exit_code}"
}

# Main wrapper function
main() {
    log_ssm INFO "=========================================="
    log_ssm INFO "SSM Deployment Wrapper Starting"
    log_ssm INFO "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    log_ssm INFO "Invocation ID: ${AWS_SSM_COMMAND_ID:-not-set}"
    log_ssm INFO "=========================================="

    # Verify stack directory exists
    if [[ ! -d "${STACK_DIR}" ]]; then
        error_exit 1 "Stack directory ${STACK_DIR} does not exist"
    fi

    # Change to stack directory
    cd "${STACK_DIR}" || error_exit 1 "Cannot change to stack directory"
    log_ssm INFO "Changed to stack directory: ${STACK_DIR}"

    # Source environment file if it exists
    if [[ -f "${ENV_FILE}" ]]; then
        log_ssm INFO "Sourcing environment file: ${ENV_FILE}"
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}" || error_exit 1 "Failed to source environment file"
        set +a
        log_ssm INFO "Environment variables loaded successfully"
    else
        log_ssm WARN "Environment file not found: ${ENV_FILE}"
        log_ssm WARN "Proceeding without environment file (may use defaults)"
    fi

    # Verify deployment script exists and is executable
    if [[ ! -f "${DEPLOYMENT_SCRIPT}" ]]; then
        error_exit 1 "Deployment script not found: ${DEPLOYMENT_SCRIPT}"
    fi

    if [[ ! -x "${DEPLOYMENT_SCRIPT}" ]]; then
        log_ssm WARN "Deployment script not executable, setting permissions..."
        chmod +x "${DEPLOYMENT_SCRIPT}" || error_exit 1 "Failed to set executable permission on deployment script"
    fi

    log_ssm INFO "Deployment script verified: ${DEPLOYMENT_SCRIPT}"

    # Execute the main deployment script
    log_ssm INFO "=========================================="
    log_ssm INFO "Executing main deployment script"
    log_ssm INFO "=========================================="

    local exit_code=0
    if "${DEPLOYMENT_SCRIPT}"; then
        exit_code=0
        log_ssm INFO "=========================================="
        log_ssm INFO "Deployment script completed successfully"
        log_ssm INFO "=========================================="
    else
        exit_code=$?
        log_ssm ERROR "=========================================="
        log_ssm ERROR "Deployment script failed with exit code: ${exit_code}"
        log_ssm ERROR "=========================================="
    fi

    # Return the exit code from the deployment script
    if [[ ${exit_code} -eq 0 ]]; then
        log_ssm INFO "SSM deployment completed successfully"
        log_ssm INFO "Deployment logs available at: /var/log/n8n-deployment.log"
        log_ssm INFO "SSM logs available at: ${SSM_LOG}"
    else
        log_ssm ERROR "SSM deployment failed"
        log_ssm ERROR "Check logs for details:"
        log_ssm ERROR "  - Deployment logs: /var/log/n8n-deployment.log"
        log_ssm ERROR "  - SSM logs: ${SSM_LOG}"
    fi

    return ${exit_code}
}

# Run main function
main "$@"
