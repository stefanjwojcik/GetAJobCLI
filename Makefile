#!/usr/bin/make -f
# Makefile for GetAJobCLI
# Provides convenient commands for building, testing, and distributing the application

.PHONY: help build test install clean dev precompile package release

# Configuration
APP_NAME = getajobcli
BUILD_DIR = build
DIST_DIR = dist

# Default target
help:
	@echo "GetAJobCLI Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  build      - Build standalone application using PackageCompiler"
	@echo "  test       - Run test suite"
	@echo "  install    - Install application locally"
	@echo "  dev        - Set up development environment"
	@echo "  precompile - Test precompilation workload"
	@echo "  package    - Create distribution packages"
	@echo "  clean      - Clean build artifacts"
	@echo "  release    - Build release version with optimizations"
	@echo ""
	@echo "Quick start:"
	@echo "  make build    # Build the application"
	@echo "  make install  # Install to ~/.local/bin"

# Check if Julia is available
check-julia:
	@which julia > /dev/null || (echo "Error: Julia not found. Install from https://julialang.org/" && exit 1)
	@echo "✓ Julia found: $$(julia --version | head -1)"

# Install project dependencies
deps: check-julia
	@echo "Installing Julia dependencies..."
	julia --project=. -e "using Pkg; Pkg.instantiate()"
	@echo "✓ Dependencies installed"

# Test precompilation workload
precompile: deps
	@echo "Testing precompilation workload..."
	julia --project=. precompile_workload.jl
	@echo "✓ Precompilation test completed"

# Build the standalone application
build: deps precompile
	@echo "Building standalone application..."
	julia --project=. build_app.jl
	@echo "✓ Build completed"

# Run tests
test: deps
	@echo "Running test suite..."
	julia --project=. -e "using Pkg; Pkg.test()"
	@echo "✓ Tests completed"

# Install locally using the shell script
install:
	@echo "Installing GetAJobCLI..."
	./install.sh --method=build
	@echo "✓ Installation completed"

# Development setup
dev: deps
	@echo "Setting up development environment..."
	julia --project=. -e "using GetAJobCLI"
	@echo "✓ Development environment ready"
	@echo "To start: julia --project=. -e 'using GetAJobCLI; GetAJobCLI.main()'"

# Create distribution packages
package: build
	@echo "Creating distribution packages..."
	@mkdir -p $(DIST_DIR)
	
	# Create tarball for Unix systems
	@if [ -d "$(BUILD_DIR)/$(APP_NAME)" ]; then \
		tar -czf $(DIST_DIR)/$(APP_NAME)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m).tar.gz -C $(BUILD_DIR) $(APP_NAME); \
		echo "✓ Created $(DIST_DIR)/$(APP_NAME)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m).tar.gz"; \
	fi
	
	# Create zip archive (cross-platform)
	@if [ -d "$(BUILD_DIR)/$(APP_NAME)" ]; then \
		cd $(BUILD_DIR) && zip -r ../$(DIST_DIR)/$(APP_NAME)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m).zip $(APP_NAME); \
		echo "✓ Created $(DIST_DIR)/$(APP_NAME)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m).zip"; \
	fi

# Release build with optimizations
release: clean
	@echo "Building optimized release..."
	@export JULIA_NUM_THREADS=auto
	@make build
	@make package
	@echo "✓ Release build completed"
	@echo "Distribution packages available in $(DIST_DIR)/"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(DIST_DIR)
	@rm -f Manifest.toml
	@echo "✓ Clean completed"

# Quick development test
quick-test: deps
	@echo "Running quick functionality test..."
	julia --project=. -e "using GetAJobCLI; println(\"✓ Module loads successfully\")"

# Check project status
status:
	@echo "Project Status:"
	@echo "  Current directory: $$(pwd)"
	@echo "  Julia version: $$(julia --version | head -1)"
	@echo "  Build directory exists: $$(test -d $(BUILD_DIR) && echo 'Yes' || echo 'No')"
	@echo "  Executable exists: $$(test -f $(BUILD_DIR)/$(APP_NAME)/bin/$(APP_NAME) && echo 'Yes' || echo 'No')"
	@echo "  Dependencies: $$(test -f Project.toml && echo 'Project.toml found' || echo 'No Project.toml')"

# Show usage examples
examples:
	@echo "Usage Examples:"
	@echo ""
	@echo "1. First-time setup:"
	@echo "   make deps build install"
	@echo ""
	@echo "2. Development workflow:"
	@echo "   make dev"
	@echo "   # Edit code"
	@echo "   make test"
	@echo "   make build"
	@echo ""
	@echo "3. Create release:"
	@echo "   make release"
	@echo ""
	@echo "4. Quick test:"
	@echo "   make quick-test"