#!/bin/bash

# MultiLineDiff Website Deployment Script
# Usage: ./deploy.sh [environment]
# Environments: dev, staging, production

set -e

ENVIRONMENT=${1:-dev}
SITE_URL="https://diff.xcf.ai"

echo "🚀 Deploying MultiLineDiff Website to $ENVIRONMENT..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if we're in the website directory
if [ ! -f "index.html" ]; then
    print_error "Please run this script from the website directory"
    exit 1
fi

# Validate HTML
print_status "Validating HTML..."
if command -v html5validator &> /dev/null; then
    html5validator --root . --also-check-css
    print_success "HTML validation passed"
else
    print_warning "html5validator not found, skipping HTML validation"
fi

# Check for required files
print_status "Checking required files..."
required_files=("index.html" "css/styles.css" "js/main.js" "images/favicon.svg")

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file missing: $file"
        exit 1
    fi
done

print_success "All required files present"

# Optimize files for production
if [ "$ENVIRONMENT" = "production" ]; then
    print_status "Optimizing files for production..."
    
    # Create optimized directory
    mkdir -p dist
    cp -r . dist/
    cd dist
    
    # Remove development files
    rm -f deploy.sh README.md
    
    # Minify CSS (if csso is available)
    if command -v csso &> /dev/null; then
        print_status "Minifying CSS..."
        for css_file in css/*.css; do
            csso "$css_file" --output "$css_file"
        done
        print_success "CSS minified"
    else
        print_warning "csso not found, skipping CSS minification"
    fi
    
    # Minify JavaScript (if uglifyjs is available)
    if command -v uglifyjs &> /dev/null; then
        print_status "Minifying JavaScript..."
        for js_file in js/*.js; do
            uglifyjs "$js_file" --compress --mangle --output "$js_file"
        done
        print_success "JavaScript minified"
    else
        print_warning "uglifyjs not found, skipping JavaScript minification"
    fi
    
    cd ..
    print_success "Production optimization complete"
fi

# Deploy based on environment
case $ENVIRONMENT in
    "dev")
        print_status "Starting local development server..."
        if command -v python3 &> /dev/null; then
            python3 -m http.server 8000
        elif command -v python &> /dev/null; then
            python -m http.server 8000
        elif command -v php &> /dev/null; then
            php -S localhost:8000
        else
            print_error "No suitable HTTP server found. Please install Python or PHP."
            exit 1
        fi
        ;;
        
    "staging")
        print_status "Deploying to staging environment..."
        # Add staging deployment logic here
        # Example: rsync to staging server
        # rsync -avz --delete . user@staging-server:/var/www/staging/
        print_warning "Staging deployment not configured"
        ;;
        
    "production")
        print_status "Deploying to production environment..."
        
        # Example Netlify deployment
        if command -v netlify &> /dev/null; then
            print_status "Deploying to Netlify..."
            if [ -d "dist" ]; then
                netlify deploy --prod --dir=dist
            else
                netlify deploy --prod --dir=.
            fi
            print_success "Deployed to Netlify"
        else
            print_warning "Netlify CLI not found"
            print_status "Manual deployment required:"
            echo "1. Upload files to your hosting provider"
            echo "2. Configure domain: $SITE_URL"
            echo "3. Enable HTTPS"
            echo "4. Set up CDN if available"
        fi
        ;;
        
    *)
        print_error "Unknown environment: $ENVIRONMENT"
        print_status "Available environments: dev, staging, production"
        exit 1
        ;;
esac

print_success "Deployment complete! 🎉"

if [ "$ENVIRONMENT" = "dev" ]; then
    echo ""
    print_status "Local development server running at:"
    echo "  http://localhost:8000"
    echo ""
    print_status "Press Ctrl+C to stop the server"
elif [ "$ENVIRONMENT" = "production" ]; then
    echo ""
    print_status "Production site should be available at:"
    echo "  $SITE_URL"
    echo ""
    print_status "Don't forget to:"
    echo "  • Test the live site"
    echo "  • Update DNS if needed"
    echo "  • Monitor performance"
    echo "  • Check analytics"
fi 