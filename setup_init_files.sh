#!/bin/bash
# setup_init_files.sh - Create all necessary __init__.py files for the project

echo "🔧 Setting up __init__.py files for Python package structure..."

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Navigate to the project root (assuming script is in ddos-detection-system/)
cd "$SCRIPT_DIR"

# Check if we're in the right directory
if [ ! -d "src" ]; then
    echo "❌ Error: src/ directory not found. Are you in the ddos-detection-system directory?"
    echo "Current directory: $(pwd)"
    echo "Please navigate to your ddos-detection-system directory and run this script again."
    exit 1
fi

echo "📁 Current directory: $(pwd)"
echo "✅ Found src/ directory"

# Create __init__.py files
echo "📝 Creating __init__.py files..."

# Main src package
touch src/__init__.py
echo "✅ Created src/__init__.py"

# Data generation package
touch src/data_generation/__init__.py
echo "✅ Created src/data_generation/__init__.py"

# Data preprocessing package  
touch src/data_preprocessing/__init__.py
echo "✅ Created src/data_preprocessing/__init__.py"

# Models package
touch src/models/__init__.py
echo "✅ Created src/models/__init__.py"

# Services package
touch src/services/__init__.py
echo "✅ Created src/services/__init__.py"

# Utils package
touch src/utils/__init__.py
echo "✅ Created src/utils/__init__.py"

# Tests package (if it exists)
if [ -d "tests" ]; then
    touch tests/__init__.py
    echo "✅ Created tests/__init__.py"
fi

echo ""
echo "🎉 All __init__.py files created successfully!"
echo ""
echo "📋 Package structure:"
find src -name "__init__.py" -type f | sort
if [ -f "tests/__init__.py" ]; then
    echo "tests/__init__.py"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Run: python3 scripts/generate_synthetic_data.py"
echo "2. If you get import errors, make sure you have the required packages:"
echo "   pip3 install pandas numpy scikit-learn matplotlib seaborn"