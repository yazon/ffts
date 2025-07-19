#!/usr/bin/env python3
"""
FFTS Unified Build Interface
Modern build system for FFTS (Fastest Fourier Transform in the South)

This script provides a unified interface for building FFTS across different
platforms and architectures with modern tooling and developer-friendly features.
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class Colors:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class BuildConfig:
    """Build configuration management"""
    
    def __init__(self):
        self.config_file = Path("build_config.json")
        self.presets = {
            "debug": {
                "build_type": "Debug",
                "enable_tests": True,
                "enable_coverage": True,
                "enable_sanitizers": True,
                "enable_static": True,
                "enable_shared": False
            },
            "release": {
                "build_type": "Release",
                "enable_tests": True,
                "enable_coverage": False,
                "enable_sanitizers": False,
                "enable_static": True,
                "enable_shared": True
            },
            "minimal": {
                "build_type": "Release",
                "enable_tests": False,
                "enable_coverage": False,
                "enable_sanitizers": False,
                "enable_static": True,
                "enable_shared": False,
                "disable_dynamic_code": True
            },
            "android": {
                "build_type": "Release",
                "enable_tests": False,
                "enable_static": True,
                "enable_shared": False,
                "enable_neon": True,
                "generate_position_independent_code": True
            },
            "ios": {
                "build_type": "Release",
                "enable_tests": False,
                "enable_static": True,
                "enable_shared": False,
                "enable_neon": True,
                "generate_position_independent_code": True
            }
        }
        self.current_config = self.load_config()
    
    def load_config(self) -> Dict:
        """Load configuration from file or return defaults"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                print(f"{Colors.WARNING}Warning: Could not load config file, using defaults{Colors.ENDC}")
        
        return self.get_default_config()
    
    def save_config(self, config: Dict):
        """Save configuration to file"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
        except IOError as e:
            print(f"{Colors.FAIL}Error: Could not save config file: {e}{Colors.ENDC}")
    
    def get_default_config(self) -> Dict:
        """Get default configuration based on platform"""
        system = platform.system().lower()
        machine = platform.machine().lower()
        
        config = {
            "build_type": "Release",
            "build_dir": "build",
            "install_dir": "install",
            "enable_tests": True,
            "enable_examples": False,
            "enable_benchmarks": False,
            "enable_documentation": False,
            "enable_coverage": False,
            "enable_sanitizers": False,
            "enable_static": True,
            "enable_shared": False,
            "enable_neon": False,
            "enable_vfp": False,
            "enable_sse": True,
            "enable_sse2": True,
            "enable_sse3": True,
            "enable_avx": False,
            "enable_avx2": False,
            "disable_dynamic_code": False,
            "generate_position_independent_code": False,
            "parallel_jobs": os.cpu_count() or 1
        }
        
        # Platform-specific defaults
        if system == "linux":
            if "arm" in machine or "aarch64" in machine:
                config["enable_neon"] = True
            elif "x86_64" in machine or "amd64" in machine:
                config["enable_sse"] = True
                config["enable_sse2"] = True
                config["enable_sse3"] = True
        elif system == "darwin":
            if "arm64" in machine:
                config["enable_neon"] = True
            config["generate_position_independent_code"] = True
        elif system == "windows":
            config["enable_shared"] = True
            config["enable_static"] = True
        
        return config
    
    def apply_preset(self, preset_name: str) -> Dict:
        """Apply a preset configuration"""
        if preset_name not in self.presets:
            raise ValueError(f"Unknown preset: {preset_name}")
        
        config = self.current_config.copy()
        config.update(self.presets[preset_name])
        return config


class BuildSystem:
    """Main build system class"""
    
    def __init__(self, config: BuildConfig):
        self.config = config
        self.project_root = Path(__file__).parent
        self.build_dir = Path(self.config.current_config["build_dir"])
        self.install_dir = Path(self.config.current_config["install_dir"])
    
    def check_requirements(self) -> bool:
        """Check if build requirements are met"""
        print(f"{Colors.OKBLUE}Checking build requirements...{Colors.ENDC}")
        
        # Check CMake
        if not shutil.which("cmake"):
            print(f"{Colors.FAIL}Error: CMake not found. Please install CMake 3.25 or later.{Colors.ENDC}")
            return False
        
        # Check CMake version
        try:
            result = subprocess.run(["cmake", "--version"], 
                                  capture_output=True, text=True, check=True)
            version_line = result.stdout.split('\n')[0]
            version_str = version_line.split()[2]
            major, minor = map(int, version_str.split('.')[:2])
            
            if major < 3 or (major == 3 and minor < 25):
                print(f"{Colors.FAIL}Error: CMake version {version_str} is too old. "
                      f"Please install CMake 3.25 or later.{Colors.ENDC}")
                return False
            
            print(f"{Colors.OKGREEN}✓ CMake {version_str} found{Colors.ENDC}")
        except (subprocess.CalledProcessError, ValueError, IndexError):
            print(f"{Colors.FAIL}Error: Could not determine CMake version{Colors.ENDC}")
            return False
        
        # Check compiler
        compilers = ["gcc", "clang", "cc"]
        compiler_found = False
        
        for compiler in compilers:
            if shutil.which(compiler):
                try:
                    result = subprocess.run([compiler, "--version"], 
                                          capture_output=True, text=True, check=True)
                    version_line = result.stdout.split('\n')[0]
                    print(f"{Colors.OKGREEN}✓ {compiler}: {version_line}{Colors.ENDC}")
                    compiler_found = True
                    break
                except subprocess.CalledProcessError:
                    continue
        
        if not compiler_found:
            print(f"{Colors.FAIL}Error: No suitable C compiler found{Colors.ENDC}")
            return False
        
        return True
    
    def configure(self, config: Dict) -> bool:
        """Configure the build with CMake"""
        print(f"{Colors.OKBLUE}Configuring build...{Colors.ENDC}")
        
        # Create build directory
        self.build_dir.mkdir(exist_ok=True)
        
        # Prepare CMake arguments
        cmake_args = [
            "cmake",
            "-S", str(self.project_root),
            "-B", str(self.build_dir),
            f"-DCMAKE_BUILD_TYPE={config['build_type']}",
            f"-DCMAKE_INSTALL_PREFIX={self.install_dir.absolute()}",
            f"-DENABLE_TESTS={'ON' if config['enable_tests'] else 'OFF'}",
            f"-DENABLE_EXAMPLES={'ON' if config['enable_examples'] else 'OFF'}",
            f"-DENABLE_BENCHMARKS={'ON' if config['enable_benchmarks'] else 'OFF'}",
            f"-DENABLE_DOCUMENTATION={'ON' if config['enable_documentation'] else 'OFF'}",
            f"-DENABLE_COVERAGE={'ON' if config['enable_coverage'] else 'OFF'}",
            f"-DENABLE_SANITIZERS={'ON' if config['enable_sanitizers'] else 'OFF'}",
            f"-DENABLE_STATIC={'ON' if config['enable_static'] else 'OFF'}",
            f"-DENABLE_SHARED={'ON' if config['enable_shared'] else 'OFF'}",
            f"-DENABLE_NEON={'ON' if config['enable_neon'] else 'OFF'}",
            f"-DENABLE_VFP={'ON' if config['enable_vfp'] else 'OFF'}",
            f"-DENABLE_SSE={'ON' if config['enable_sse'] else 'OFF'}",
            f"-DENABLE_SSE2={'ON' if config['enable_sse2'] else 'OFF'}",
            f"-DENABLE_SSE3={'ON' if config['enable_sse3'] else 'OFF'}",
            f"-DENABLE_AVX={'ON' if config['enable_avx'] else 'OFF'}",
            f"-DENABLE_AVX2={'ON' if config['enable_avx2'] else 'OFF'}",
            f"-DDISABLE_DYNAMIC_CODE={'ON' if config['disable_dynamic_code'] else 'OFF'}",
            f"-DGENERATE_POSITION_INDEPENDENT_CODE={'ON' if config['generate_position_independent_code'] else 'OFF'}"
        ]
        
        try:
            result = subprocess.run(cmake_args, check=True, capture_output=True, text=True)
            print(f"{Colors.OKGREEN}✓ Configuration successful{Colors.ENDC}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"{Colors.FAIL}Error: Configuration failed{Colors.ENDC}")
            print(f"Command: {' '.join(cmake_args)}")
            print(f"Error output: {e.stderr}")
            return False
    
    def build(self, config: Dict) -> bool:
        """Build the project"""
        print(f"{Colors.OKBLUE}Building project...{Colors.ENDC}")
        
        if not self.build_dir.exists():
            print(f"{Colors.FAIL}Error: Build directory not found. Run configure first.{Colors.ENDC}")
            return False
        
        # Prepare build arguments
        build_args = [
            "cmake", "--build", str(self.build_dir),
            "--parallel", str(config["parallel_jobs"])
        ]
        
        if config["build_type"] == "Debug":
            build_args.append("--config")
            build_args.append("Debug")
        
        try:
            result = subprocess.run(build_args, check=True)
            print(f"{Colors.OKGREEN}✓ Build successful{Colors.ENDC}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"{Colors.FAIL}Error: Build failed{Colors.ENDC}")
            return False
    
    def test(self) -> bool:
        """Run tests"""
        print(f"{Colors.OKBLUE}Running tests...{Colors.ENDC}")
        
        if not self.build_dir.exists():
            print(f"{Colors.FAIL}Error: Build directory not found. Run build first.{Colors.ENDC}")
            return False
        
        try:
            result = subprocess.run(["ctest", "--test-dir", str(self.build_dir)], 
                                  check=True, capture_output=True, text=True)
            print(f"{Colors.OKGREEN}✓ Tests passed{Colors.ENDC}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"{Colors.FAIL}Error: Tests failed{Colors.ENDC}")
            print(f"Error output: {e.stderr}")
            return False
    
    def install(self) -> bool:
        """Install the project"""
        print(f"{Colors.OKBLUE}Installing project...{Colors.ENDC}")
        
        if not self.build_dir.exists():
            print(f"{Colors.FAIL}Error: Build directory not found. Run build first.{Colors.ENDC}")
            return False
        
        try:
            result = subprocess.run(["cmake", "--install", str(self.build_dir)], check=True)
            print(f"{Colors.OKGREEN}✓ Installation successful{Colors.ENDC}")
            print(f"Installed to: {self.install_dir.absolute()}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"{Colors.FAIL}Error: Installation failed{Colors.ENDC}")
            return False
    
    def clean(self) -> bool:
        """Clean build artifacts"""
        print(f"{Colors.OKBLUE}Cleaning build artifacts...{Colors.ENDC}")
        
        if self.build_dir.exists():
            try:
                shutil.rmtree(self.build_dir)
                print(f"{Colors.OKGREEN}✓ Build directory cleaned{Colors.ENDC}")
            except OSError as e:
                print(f"{Colors.FAIL}Error: Could not clean build directory: {e}{Colors.ENDC}")
                return False
        
        if self.install_dir.exists():
            try:
                shutil.rmtree(self.install_dir)
                print(f"{Colors.OKGREEN}✓ Install directory cleaned{Colors.ENDC}")
            except OSError as e:
                print(f"{Colors.FAIL}Error: Could not clean install directory: {e}{Colors.ENDC}")
                return False
        
        return True
    
    def show_config(self, config: Dict):
        """Display current configuration"""
        print(f"{Colors.HEADER}Current Build Configuration:{Colors.ENDC}")
        print(f"  Build type: {config['build_type']}")
        print(f"  Build directory: {config['build_dir']}")
        print(f"  Install directory: {config['install_dir']}")
        print(f"  Parallel jobs: {config['parallel_jobs']}")
        print(f"  Tests: {'Enabled' if config['enable_tests'] else 'Disabled'}")
        print(f"  Static library: {'Enabled' if config['enable_static'] else 'Disabled'}")
        print(f"  Shared library: {'Enabled' if config['enable_shared'] else 'Disabled'}")
        print(f"  NEON: {'Enabled' if config['enable_neon'] else 'Disabled'}")
        print(f"  VFP: {'Enabled' if config['enable_vfp'] else 'Disabled'}")
        print(f"  SSE: {'Enabled' if config['enable_sse'] else 'Disabled'}")
        print(f"  Dynamic code: {'Disabled' if config['disable_dynamic_code'] else 'Enabled'}")
        print(f"  PIC: {'Enabled' if config['generate_position_independent_code'] else 'Disabled'}")


def interactive_config(config: BuildConfig) -> Dict:
    """Interactive configuration wizard"""
    print(f"{Colors.HEADER}FFTS Interactive Configuration Wizard{Colors.ENDC}")
    print("This will guide you through the build configuration.\n")
    
    current = config.current_config.copy()
    
    # Build type
    print("Build type options:")
    print("  1. Debug (with symbols, no optimization)")
    print("  2. Release (optimized)")
    print("  3. RelWithDebInfo (optimized with debug info)")
    print("  4. MinSizeRel (size optimized)")
    
    while True:
        choice = input(f"Select build type (1-4) [default: {current['build_type']}]: ").strip()
        if not choice:
            break
        if choice == "1":
            current["build_type"] = "Debug"
            break
        elif choice == "2":
            current["build_type"] = "Release"
            break
        elif choice == "3":
            current["build_type"] = "RelWithDebInfo"
            break
        elif choice == "4":
            current["build_type"] = "MinSizeRel"
            break
        else:
            print("Invalid choice. Please select 1-4.")
    
    # Library types
    print("\nLibrary configuration:")
    static = input(f"Build static library? (y/n) [default: {'y' if current['enable_static'] else 'n'}]: ").strip().lower()
    if static in ['y', 'yes']:
        current["enable_static"] = True
    elif static in ['n', 'no']:
        current["enable_static"] = False
    
    shared = input(f"Build shared library? (y/n) [default: {'y' if current['enable_shared'] else 'n'}]: ").strip().lower()
    if shared in ['y', 'yes']:
        current["enable_shared"] = True
    elif shared in ['n', 'no']:
        current["enable_shared"] = False
    
    # Tests
    tests = input(f"Build tests? (y/n) [default: {'y' if current['enable_tests'] else 'n'}]: ").strip().lower()
    if tests in ['y', 'yes']:
        current["enable_tests"] = True
    elif tests in ['n', 'no']:
        current["enable_tests"] = False
    
    # Architecture optimizations
    print("\nArchitecture optimizations:")
    neon = input(f"Enable NEON (ARM)? (y/n) [default: {'y' if current['enable_neon'] else 'n'}]: ").strip().lower()
    if neon in ['y', 'yes']:
        current["enable_neon"] = True
    elif neon in ['n', 'no']:
        current["enable_neon"] = False
    
    sse = input(f"Enable SSE (x86)? (y/n) [default: {'y' if current['enable_sse'] else 'n'}]: ").strip().lower()
    if sse in ['y', 'yes']:
        current["enable_sse"] = True
    elif sse in ['n', 'no']:
        current["enable_sse"] = False
    
    # Save configuration
    save = input("\nSave this configuration? (y/n) [default: y]: ").strip().lower()
    if save not in ['n', 'no']:
        config.save_config(current)
        print(f"{Colors.OKGREEN}Configuration saved to {config.config_file}{Colors.ENDC}")
    
    return current


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="FFTS Unified Build Interface",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s configure              # Configure with default settings
  %(prog)s build                  # Build the project
  %(prog)s test                   # Run tests
  %(prog)s install                # Install the project
  %(prog)s clean                  # Clean build artifacts
  %(prog)s --preset release build # Build with release preset
  %(prog)s --interactive          # Interactive configuration
  %(prog)s --show-config          # Show current configuration
        """
    )
    
    parser.add_argument("action", nargs="?", choices=["configure", "build", "test", "install", "clean", "all"],
                       help="Build action to perform")
    parser.add_argument("--preset", choices=["debug", "release", "minimal", "android", "ios"],
                       help="Use a preset configuration")
    parser.add_argument("--interactive", "-i", action="store_true",
                       help="Run interactive configuration wizard")
    parser.add_argument("--show-config", action="store_true",
                       help="Show current configuration")
    parser.add_argument("--clean", action="store_true",
                       help="Clean before building")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Verbose output")
    
    args = parser.parse_args()
    
    # Initialize build system
    config = BuildConfig()
    build_system = BuildSystem(config)
    
    # Handle special actions
    if args.show_config:
        build_system.show_config(config.current_config)
        return 0
    
    if args.interactive:
        new_config = interactive_config(config)
        config.current_config = new_config
        build_system.show_config(new_config)
        return 0
    
    # Apply preset if specified
    if args.preset:
        try:
            config.current_config = config.apply_preset(args.preset)
            print(f"{Colors.OKGREEN}Applied preset: {args.preset}{Colors.ENDC}")
        except ValueError as e:
            print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
            return 1
    
    # Determine action
    if not args.action:
        if args.interactive or args.show_config:
            return 0
        else:
            parser.print_help()
            return 1
    
    # Check requirements
    if not build_system.check_requirements():
        return 1
    
    # Execute action
    success = True
    
    if args.action == "configure":
        success = build_system.configure(config.current_config)
    elif args.action == "build":
        if args.clean:
            build_system.clean()
        success = build_system.configure(config.current_config) and build_system.build(config.current_config)
    elif args.action == "test":
        success = build_system.test()
    elif args.action == "install":
        success = build_system.install()
    elif args.action == "clean":
        success = build_system.clean()
    elif args.action == "all":
        if args.clean:
            build_system.clean()
        success = (build_system.configure(config.current_config) and 
                  build_system.build(config.current_config) and 
                  build_system.test() and 
                  build_system.install())
    
    if success:
        print(f"{Colors.OKGREEN}✓ Action '{args.action}' completed successfully{Colors.ENDC}")
        return 0
    else:
        print(f"{Colors.FAIL}✗ Action '{args.action}' failed{Colors.ENDC}")
        return 1


if __name__ == "__main__":
    sys.exit(main())