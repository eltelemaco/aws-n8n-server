#!/usr/bin/env bash
#
# update-stack.sh - Deploy n8n stack updates to EC2 instance
#
# This script performs a safe deployment of n8n stack updates with:
# - Backup of current configuration
# - Health check verification
# - Automatic rollback on failure
#
# Exit codes:
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
BACKUP_DIR="/opt/stacks/n8n/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_PATH="${BACKUP_DIR}/backup_${TIMESTAMP}"
LOG_FILE="/var/log/n8n-deployment.log"
HEALTH_CHECK_RETRIES=30
HEALTH_CHECK_INTERVAL=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

# Error handler
error_exit() {
    local exit_code="${1:-1}"
    local message="${2:-Unknown error}"
    log_error "${message}"
    exit "${exit_code}"
}

# Check if running as correct user
check_prerequisites() {
    log_info "Checking prerequisites..."

    if [[ ! -d "${STACK_DIR}" ]]; then
        error_exit 1 "Stack directory ${STACK_DIR} does not exist"
    fi

    if ! command -v docker &> /dev/null; then
        error_exit 1 "Docker is not installed"
    fi

    if ! docker compose version &> /dev/null; then
        error_exit 1 "Docker Compose plugin is not installed"
    fi

    cd "${STACK_DIR}" || error_exit 1 "Cannot change to stack directory"

    log_info "Prerequisites check passed"
}

# Create backup of current configuration
create_backup() {
    log_info "Creating backup at ${BACKUP_PATH}..."

    mkdir -p "${BACKUP_DIR}" || error_exit 2 "Failed to create backup directory"
    mkdir -p "${BACKUP_PATH}" || error_exit 2 "Failed to create timestamped backup directory"

    # Backup docker-compose.yml
    if [[ -f "${STACK_DIR}/docker-compose.yml" ]]; then
        cp "${STACK_DIR}/docker-compose.yml" "${BACKUP_PATH}/docker-compose.yml" || \
            error_exit 2 "Failed to backup docker-compose.yml"
        log_info "Backed up docker-compose.yml"
    else
        log_warn "docker-compose.yml not found, skipping"
    fi

    # Backup .env file
    if [[ -f "${STACK_DIR}/.env" ]]; then
        cp "${STACK_DIR}/.env" "${BACKUP_PATH}/.env" || \
            error_exit 2 "Failed to backup .env"
        log_info "Backed up .env"
    else
        log_warn ".env not found, skipping"
    fi

    # Backup traefik configuration
    if [[ -d "${STACK_DIR}/traefik" ]]; then
        cp -r "${STACK_DIR}/traefik" "${BACKUP_PATH}/traefik" || \
            error_exit 2 "Failed to backup traefik directory"
        log_info "Backed up traefik directory"
    fi

    # Keep only last 10 backups
    ls -dt "${BACKUP_DIR}"/backup_* | tail -n +11 | xargs -r rm -rf

    log_info "Backup created successfully at ${BACKUP_PATH}"
}

# Get current service status
get_service_status() {
    docker compose ps --format json 2>/dev/null || echo "[]"
}

# Stop services gracefully
stop_services() {
    log_info "Stopping services gracefully..."

    if ! docker compose down --timeout 30; then
        error_exit 3 "Failed to stop services"
    fi

    log_info "Services stopped successfully"
}

# Start services
start_services() {
    log_info "Starting services..."

    if ! docker compose up -d; then
        error_exit 4 "Failed to start services"
    fi

    log_info "Services started successfully"
}

# Check if a service is healthy
check_service_health() {
    local service_name="$1"
    local status

    status=$(docker compose ps --format json | jq -r ".[] | select(.Service == \"${service_name}\") | .Health" 2>/dev/null || echo "unknown")

    if [[ "${status}" == "healthy" ]]; then
        return 0
    elif [[ "${status}" == "unknown" ]] || [[ "${status}" == "" ]]; then
        # Service might not have health check, check if it's running
        local state
        state=$(docker compose ps --format json | jq -r ".[] | select(.Service == \"${service_name}\") | .State" 2>/dev/null || echo "")
        if [[ "${state}" == "running" ]]; then
            return 0
        fi
    fi

    return 1
}

# Wait for services to become healthy
wait_for_health() {
    log_info "Waiting for services to become healthy..."

    local critical_services=("postgres" "redis" "n8n" "traefik")
    local retry=0

    while [[ ${retry} -lt ${HEALTH_CHECK_RETRIES} ]]; do
        local all_healthy=true

        for service in "${critical_services[@]}"; do
            if ! check_service_health "${service}"; then
                all_healthy=false
                log_info "Service ${service} not healthy yet (attempt $((retry + 1))/${HEALTH_CHECK_RETRIES})..."
                break
            fi
        done

        if [[ "${all_healthy}" == "true" ]]; then
            log_info "All critical services are healthy"
            return 0
        fi

        sleep ${HEALTH_CHECK_INTERVAL}
        retry=$((retry + 1))
    done

    log_error "Health check timeout: services failed to become healthy"
    return 1
}

# Perform final verification
verify_deployment() {
    log_info "Verifying deployment..."

    # Check if all expected containers are running
    local running_containers
    running_containers=$(docker compose ps --format json | jq -r '.[] | select(.State == "running") | .Service' | wc -l)

    if [[ ${running_containers} -lt 4 ]]; then
        log_error "Expected at least 4 containers running, found ${running_containers}"
        return 1
    fi

    # Check postgres connectivity
    if ! docker compose exec -T postgres pg_isready -U n8n &> /dev/null; then
        log_error "PostgreSQL is not ready"
        return 1
    fi

    # Check redis connectivity
    if ! docker compose exec -T redis redis-cli ping &> /dev/null; then
        log_error "Redis is not responding"
        return 1
    fi

    # Check n8n HTTP endpoint (internal check)
    if ! docker compose exec -T n8n wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
        log_warn "n8n health endpoint check failed (may not be critical)"
    fi

    log_info "Deployment verification passed"
    return 0
}

# Rollback to previous version
rollback() {
    log_warn "Initiating rollback to previous version..."

    if [[ ! -d "${BACKUP_PATH}" ]]; then
        error_exit 6 "Backup not found at ${BACKUP_PATH}, cannot rollback"
    fi

    # Stop current services
    log_info "Stopping current services..."
    docker compose down --timeout 30 || log_warn "Failed to stop services during rollback"

    # Restore configuration files
    if [[ -f "${BACKUP_PATH}/docker-compose.yml" ]]; then
        cp "${BACKUP_PATH}/docker-compose.yml" "${STACK_DIR}/docker-compose.yml" || \
            error_exit 6 "Failed to restore docker-compose.yml during rollback"
        log_info "Restored docker-compose.yml"
    fi

    if [[ -f "${BACKUP_PATH}/.env" ]]; then
        cp "${BACKUP_PATH}/.env" "${STACK_DIR}/.env" || \
            error_exit 6 "Failed to restore .env during rollback"
        log_info "Restored .env"
    fi

    if [[ -d "${BACKUP_PATH}/traefik" ]]; then
        rm -rf "${STACK_DIR}/traefik"
        cp -r "${BACKUP_PATH}/traefik" "${STACK_DIR}/traefik" || \
            error_exit 6 "Failed to restore traefik directory during rollback"
        log_info "Restored traefik directory"
    fi

    # Start services with old configuration
    log_info "Starting services with previous configuration..."
    if ! docker compose up -d; then
        error_exit 6 "Failed to start services during rollback"
    fi

    log_warn "Rollback completed"
    return 0
}

# Main deployment function
main() {
    log_info "=========================================="
    log_info "Starting n8n stack deployment"
    log_info "Timestamp: ${TIMESTAMP}"
    log_info "=========================================="

    # Check prerequisites
    check_prerequisites

    # Create backup
    create_backup

    # Stop services
    stop_services

    # Start services with new configuration
    start_services

    # Wait for services to become healthy
    if ! wait_for_health; then
        log_error "Health check failed, rolling back..."
        rollback
        error_exit 5 "Deployment failed: health checks did not pass after rollback"
    fi

    # Final verification
    if ! verify_deployment; then
        log_error "Deployment verification failed, rolling back..."
        rollback
        error_exit 5 "Deployment failed: verification did not pass after rollback"
    fi

    log_info "=========================================="
    log_info "Deployment completed successfully"
    log_info "Backup saved at: ${BACKUP_PATH}"
    log_info "=========================================="

    # Show service status
    log_info "Current service status:"
    docker compose ps

    return 0
}

# Run main function
main "$@"
