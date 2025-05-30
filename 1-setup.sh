#!/bin/bash
set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Check if required environment variables are set
required_vars=(
    "POLYCLI_REPO"
    "POLYCLI_BRANCH"
    "GAS_PRICE"
    "CALLDATA_FILE"
    "CALLDATA_SIZE"
    "TOTAL_UOP"
    "BATCH_SIZE"
    "CONCURRENCY"
    "RATE_LIMIT"
    "CALLDATA_TYPE"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "Error: The following required environment variables are not set in .env file:"
    printf '%s\n' "${missing_vars[@]}"
    exit 1
fi

# Extract repository name from the URL
REPO_NAME=$(basename "$POLYCLI_REPO" .git)

# Check if repository already exists
if [ -d "$REPO_NAME" ]; then
    echo "Repository already exists, checking branch..."
    cd "$REPO_NAME"
    # Get current branch name
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$POLYCLI_BRANCH" ]; then
        echo "Error: Current branch ($CURRENT_BRANCH) does not match configured branch ($POLYCLI_BRANCH)"
        exit 1
    fi
    git fetch
    git pull
else
    echo "Cloning repository..."
    git clone "$POLYCLI_REPO"
    cd "$REPO_NAME"
    git checkout "$POLYCLI_BRANCH"
    # Get current branch name
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$POLYCLI_BRANCH" ]; then
        echo "Error: Current branch ($CURRENT_BRANCH) does not match configured branch ($POLYCLI_BRANCH)"
        exit 1
    fi
fi

# Run make install
make install

# Return to original directory
cd ..
echo "Installing dependencies..."
yarn
sleep 3
echo "Deploying contracts..."
yarn run deploy
sleep 3
echo "Sending UOP..."
yarn run senduop:local