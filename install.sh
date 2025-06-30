#!/bin/bash
"""
GetAJobCLI Installation Script

This script provides multiple installation methods for GetAJobCLI:
1. Build from source using PackageCompiler
2. Install pre-built binary (if available)
3. Development setup

Usage:
  curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/GetAJobCLI/main/install.sh | bash
  or
  ./install.sh [--method=build|--method=dev]
"""

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/YOUR_USERNAME/GetAJobCLI.git"  # Update with your repo
APP_NAME="getajobcli"
INSTALL_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.getajobcli"

# Helper functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $OS in
        linux*)     OS="linux" ;;
        darwin*)    OS="macos" ;;
        msys*|mingw*|cygwin*) OS="windows" ;;
        *)          print_error "Unsupported OS: $OS"; exit 1 ;;
    esac
    
    case $ARCH in
        x86_64|amd64)   ARCH="x86_64" ;;
        arm64|aarch64)  ARCH="aarch64" ;;
        *)              print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    print_status "Detected platform: $OS-$ARCH"
}

# Check Julia installation
check_julia() {
    if ! command_exists julia; then
        print_error "Julia is not installed. Please install Julia 1.6+ from https://julialang.org/downloads/"
        print_status "After installing Julia, run this script again."
        exit 1
    fi
    
    JULIA_VERSION=$(julia --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    print_success "Found Julia $JULIA_VERSION"
}

# Create installation directories
setup_directories() {
    print_status "Setting up directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$APP_DIR"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
        print_status "Added $INSTALL_DIR to PATH in ~/.bashrc"
        print_warning "Please run 'source ~/.bashrc' or restart your terminal"
    fi
}

# Build from source method
build_from_source() {
    print_status "Building GetAJobCLI from source..."
    
    # Clone or update repository
    if [ -d "$APP_DIR/source" ]; then
        print_status "Updating existing repository..."
        cd "$APP_DIR/source"
        git pull
    else
        print_status "Cloning repository..."
        git clone "$REPO_URL" "$APP_DIR/source"
        cd "$APP_DIR/source"
    fi
    
    # Install dependencies
    print_status "Installing Julia dependencies..."
    julia --project=. -e "using Pkg; Pkg.instantiate()"
    
    # Run precompilation workload test
    print_status "Testing precompilation workload..."
    julia --project=. precompile_workload.jl
    
    # Build the application
    print_status "Building standalone application (this may take 5-10 minutes)..."
    julia --project=. build_app.jl
    
    # Copy executable to install directory
    BUILT_EXECUTABLE="build/$APP_NAME/bin/$APP_NAME"
    if [ "$OS" = "windows" ]; then
        BUILT_EXECUTABLE="$BUILT_EXECUTABLE.exe"
    fi
    
    if [ -f "$BUILT_EXECUTABLE" ]; then
        cp "$BUILT_EXECUTABLE" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$APP_NAME"
        print_success "Installed $APP_NAME to $INSTALL_DIR"
    else
        print_error "Build failed - executable not found"
        exit 1
    fi
}

# Development setup method
setup_development() {
    print_status "Setting up development environment..."
    
    # Clone repository
    if [ -d "$APP_DIR/dev" ]; then
        print_status "Development directory already exists at $APP_DIR/dev"
    else
        git clone "$REPO_URL" "$APP_DIR/dev"
        cd "$APP_DIR/dev"
    fi
    
    cd "$APP_DIR/dev"
    
    # Install dependencies
    julia --project=. -e "using Pkg; Pkg.instantiate()"
    
    # Create wrapper script
    cat > "$INSTALL_DIR/$APP_NAME" << EOF
#!/bin/bash
cd "$APP_DIR/dev"
julia --project=. -e "using GetAJobCLI; GetAJobCLI.main()" "\$@"
EOF
    
    chmod +x "$INSTALL_DIR/$APP_NAME"
    print_success "Development setup complete"
    print_status "Source code available at: $APP_DIR/dev"
}

# Install pre-built binary (if available)
install_prebuilt() {
    print_status "Checking for pre-built binaries..."
    
    # This would download from GitHub releases
    DOWNLOAD_URL="https://github.com/YOUR_USERNAME/GetAJobCLI/releases/latest/download/$APP_NAME-$OS-$ARCH"
    if [ "$OS" = "windows" ]; then
        DOWNLOAD_URL="$DOWNLOAD_URL.exe"
    fi
    
    print_status "Downloading from: $DOWNLOAD_URL"
    
    if curl -fL "$DOWNLOAD_URL" -o "$INSTALL_DIR/$APP_NAME"; then
        chmod +x "$INSTALL_DIR/$APP_NAME"
        print_success "Pre-built binary installed successfully"
    else
        print_warning "Pre-built binary not available, falling back to source build"
        build_from_source
    fi
}

# Main installation function
install_getajobcli() {
    print_status "Starting GetAJobCLI installation..."
    
    detect_platform
    setup_directories
    
    # Parse installation method
    METHOD="auto"
    for arg in "$@"; do
        case $arg in
            --method=build)     METHOD="build" ;;
            --method=prebuilt)  METHOD="prebuilt" ;;
            --method=dev)       METHOD="dev" ;;
        esac
    done
    
    case $METHOD in
        build)
            check_julia
            build_from_source
            ;;
        prebuilt)
            install_prebuilt
            ;;
        dev)
            check_julia
            setup_development
            ;;
        auto)
            if command_exists julia; then
                print_status "Julia found, attempting pre-built installation..."
                install_prebuilt
            else
                print_error "Julia required for installation. Install from https://julialang.org/"
                exit 1
            fi
            ;;
    esac
}

# Test installation
test_installation() {
    print_status "Testing installation..."
    
    if command_exists "$APP_NAME"; then
        print_success "Installation successful!"
        print_status "You can now run: $APP_NAME"
        print_status "For help, run: $APP_NAME help"
    else
        print_error "Installation verification failed"
        print_status "Try running 'source ~/.bashrc' and test again"
        exit 1
    fi
}

# Show banner
echo -e "${GREEN}"
cat << "EOF"
  ____      _                 _       _     
 / ___| ___| |_    __ _      | | ___ | |__  
 | |  _ / _ \ __|  / _` |  _  | |/ _ \| '_ \ 
 | |_| |  __/ |_  | (_| | | |_| | (_) | |_) |
 \____|\___|\__|  \__,_|  \___/ \___/|_.__/ 
                                            
           GetAJobCLI Installer             
EOF
echo -e "${NC}"

# Run installation
install_getajobcli "$@"
test_installation

print_success "Installation complete!"
print_status "Run '$APP_NAME' to get started"