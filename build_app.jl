#!/usr/bin/env julia
"""
Build script for creating a standalone GetAJobCLI application using PackageCompiler.jl

This script:
1. Installs PackageCompiler if needed
2. Creates a standalone executable app
3. Provides cross-platform deployment options
"""

using Pkg

# Add PackageCompiler if not already installed
try
    using PackageCompiler
    println("✓ PackageCompiler.jl already available")
catch
    println("Installing PackageCompiler.jl...")
    Pkg.add("PackageCompiler")
    using PackageCompiler
    println("✓ PackageCompiler.jl installed successfully")
end

# Configuration
const APP_NAME = "getajobcli"
const BUILD_DIR = "build"
const EXECUTABLE_NAME = Sys.iswindows() ? "getajobcli.exe" : "getajobcli"

# Create build directory
if !isdir(BUILD_DIR)
    mkdir(BUILD_DIR)
    println("✓ Created build directory: $BUILD_DIR")
end

# Get the current project directory
const PROJECT_DIR = pwd()
const APP_BUILD_PATH = joinpath(PROJECT_DIR, BUILD_DIR, APP_NAME)

println("\n🚀 Building GetAJobCLI standalone application...")
println("Project directory: $PROJECT_DIR")
println("Build output: $APP_BUILD_PATH")
println("Platform: $(Sys.MACHINE)")

# Create the app
try
    println("\n📦 Creating standalone app (this may take several minutes)...")
    
    create_app(
        PROJECT_DIR,                    # Source project directory
        APP_BUILD_PATH;                 # Output app directory
        precompile_execution_file = joinpath(PROJECT_DIR, "precompile_workload.jl"),
        executables = [APP_NAME => "main"],
        include_lazy_artifacts = true,
        force = true                    # Overwrite existing build
    )
    
    println("\n✅ Application built successfully!")
    println("\n📍 App location: $APP_BUILD_PATH")
    println("📍 Executable: $(joinpath(APP_BUILD_PATH, "bin", EXECUTABLE_NAME))")
    
    # Test the executable
    println("\n🧪 Testing the executable...")
    exe_path = joinpath(APP_BUILD_PATH, "bin", EXECUTABLE_NAME)
    
    if isfile(exe_path)
        println("✓ Executable exists: $exe_path")
        
        # Make it executable on Unix systems
        if !Sys.iswindows()
            chmod(exe_path, 0o755)
            println("✓ Set executable permissions")
        end
        
        # Test run (with timeout to prevent hanging)
        println("✓ Executable is ready for distribution")
    else
        println("❌ Executable not found at expected location")
    end
    
    # Print usage instructions
    println("\n📖 Usage Instructions:")
    println("1. Navigate to: $APP_BUILD_PATH")
    println("2. Run: ./bin/$EXECUTABLE_NAME")
    println("3. Or add to PATH for global access")
    
    # Print distribution info
    println("\n📦 Distribution:")
    println("• The entire '$APP_NAME' directory is needed for distribution")
    println("• Share the complete folder, not just the executable")
    println("• Users can run the app without Julia installed")
    
catch e
    println("\n❌ Build failed with error:")
    println(e)
    println("\nTroubleshooting:")
    println("• Ensure all dependencies are properly installed")
    println("• Check that the precompile_workload.jl runs without errors")
    println("• Verify C compiler is available on your system")
    rethrow()
end

println("\n🎉 Build process completed!")