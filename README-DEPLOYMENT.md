# GetAJobCLI Deployment Guide

This guide covers building and distributing production-ready executables of GetAJobCLI using PackageCompiler.jl.

## Quick Start

### One-Line Installation
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/GetAJobCLI/main/install.sh | bash
```

### Build from Source
```bash
make build install
```

## Build Methods

### Method 1: Using Make (Recommended)
The Makefile provides convenient targets for the entire build process:

```bash
# Full build pipeline
make deps build install

# Development setup
make dev

# Create release packages
make release

# Clean build artifacts
make clean
```

### Method 2: Manual Build Process
1. **Install dependencies:**
   ```bash
   julia --project=. -e "using Pkg; Pkg.instantiate()"
   ```

2. **Test precompilation:**
   ```bash
   julia --project=. precompile_workload.jl
   ```

3. **Build application:**
   ```bash
   julia --project=. build_app.jl
   ```

4. **Install executable:**
   ```bash
   cp build/getajobcli/bin/getajobcli ~/.local/bin/
   ```

### Method 3: Using Installation Script
The install script supports multiple installation methods:

```bash
# Build from source (default)
./install.sh --method=build

# Development setup
./install.sh --method=dev

# Download pre-built binary (if available)
./install.sh --method=prebuilt
```

## File Structure

After building, the following files are created:

```
GetAJobCLI/
├── build/
│   └── getajobcli/
│       ├── bin/
│       │   └── getajobcli          # Main executable
│       ├── lib/                    # Shared libraries
│       └── share/                  # Resources
├── dist/                           # Distribution packages
├── precompile_workload.jl          # Precompilation script
├── build_app.jl                    # Build script
├── install.sh                      # Installation script
└── Makefile                        # Build automation
```

## Distribution

### Creating Distribution Packages
```bash
make package
```

This creates:
- `getajobcli-linux-x86_64.tar.gz` (Linux)
- `getajobcli-macos-x86_64.tar.gz` (macOS)
- `getajobcli-windows-x86_64.zip` (Windows)

### Manual Distribution
The entire `build/getajobcli/` directory must be distributed together:
- Don't distribute just the executable
- Include all libraries and dependencies
- Maintain directory structure

## Platform Support

### Linux
- **Requirements:** glibc 2.17+ (most modern distributions)
- **Tested on:** Ubuntu 20.04+, CentOS 8+, Fedora 35+
- **Architecture:** x86_64

### macOS
- **Requirements:** macOS 10.14+
- **Architecture:** x86_64 (Intel), ARM64 (Apple Silicon) via Rosetta
- **Note:** Code signing may be required for distribution

### Windows
- **Requirements:** Windows 10+
- **Architecture:** x86_64
- **Dependencies:** Visual C++ Redistributable (usually pre-installed)

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build-and-release.yml`) automatically:

1. **Builds for all platforms** when tags are pushed
2. **Creates release packages** with proper naming
3. **Tests executables** on each platform
4. **Publishes releases** with downloadable binaries

### Triggering Releases
```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0

# Or use GitHub web interface to create release
```

## Optimization Tips

### Build Performance
- Use `JULIA_NUM_THREADS=auto` for parallel compilation
- Enable CPU-specific optimizations: `JULIA_CPU_TARGET=native`
- Use `--optimize=3` for maximum optimization

### Runtime Performance
- The precompilation script ensures fast startup
- Critical paths are pre-compiled during build
- First-run performance is optimized

### Size Optimization
- Remove unused dependencies from Project.toml
- Use `include_lazy_artifacts = false` if artifacts aren't needed
- Consider system-specific builds for smaller binaries

## Troubleshooting

### Build Issues
- **"C compiler not found":** Install build tools (`build-essential` on Ubuntu, Xcode on macOS)
- **"PackageCompiler failed":** Check Julia version (1.6+ required)
- **Memory issues:** Increase available RAM or use swap

### Runtime Issues
- **"Library not found":** Ensure complete directory structure is preserved
- **"Permission denied":** Make executable with `chmod +x`
- **API key issues:** Use `getajobcli setup-keys` to configure

### Platform-Specific Issues

#### Linux
- **GLIBC version errors:** Build on older Linux version for compatibility
- **Missing libraries:** Install `libc6-dev` and `libssl-dev`

#### macOS
- **"App is damaged":** Disable Gatekeeper or properly code-sign
- **Architecture mismatch:** Use Universal Binary or build for specific arch

#### Windows
- **Antivirus blocking:** Add exception for executable
- **DLL missing:** Install Visual C++ Redistributable

## Advanced Configuration

### Custom Precompilation
Modify `precompile_workload.jl` to include your specific use cases:

```julia
# Add custom workload
using GetAJobCLI
GetAJobCLI.my_custom_function()
```

### Build Customization
Edit `build_app.jl` to customize the build:

```julia
create_app(
    PROJECT_DIR,
    APP_BUILD_PATH;
    app_name = "custom_name",
    precompile_execution_file = "custom_precompile.jl",
    cpu_target = "native",
    optimize = 3
)
```

### Cross-Compilation
PackageCompiler supports limited cross-compilation. For full cross-platform support, use CI/CD or build on target platforms.

## Security Considerations

- **Code signing:** Required for macOS/Windows distribution
- **Virus scanning:** Some antivirus may flag compiled binaries
- **Dependency scanning:** Audit dependencies for vulnerabilities
- **Distribution:** Use HTTPS for download links

## Monitoring and Analytics

Consider adding:
- **Usage tracking:** Anonymous usage statistics
- **Error reporting:** Crash reporting service
- **Update checking:** Automatic update notifications

## Support and Maintenance

### Version Management
- Use semantic versioning (v1.0.0)
- Tag releases consistently
- Maintain changelog

### User Support
- Provide clear installation instructions
- Include troubleshooting guide
- Set up issue templates

---

## Example Usage

After installation, users can run:

```bash
# Start the CLI
getajobcli

# Check version
getajobcli --version

# Show help
getajobcli help
```

The application provides an interactive CLI for data science interview preparation with AI-powered lesson generation and quizzing.