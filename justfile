# reschedule-mono justfile

# Pull all submodules to latest
pull:
    git submodule update --remote --merge

# Install dependencies in both submodules
install:
    cd Reschedule-Flow && pnpm install
    cd reschedule-ui && pnpm install

# Start the UI dev server
dev:
    cd reschedule-ui && pnpm dev

# Run tests across both submodules
test:
    cd Reschedule-Flow && pnpm test
    cd reschedule-ui && pnpm test

# Build both projects
build:
    cd Reschedule-Flow && pnpm build
    cd reschedule-ui && pnpm build

# Typecheck both projects
typecheck:
    cd Reschedule-Flow && pnpm typecheck
    cd reschedule-ui && pnpm typecheck

# Show git status of all submodules
status:
    @echo "── Reschedule-Flow ──"
    @cd Reschedule-Flow && git status --short
    @echo ""
    @echo "── reschedule-ui ──"
    @cd reschedule-ui && git status --short

# Run the CLI scenario runner
demo:
    cd Reschedule-Flow && pnpm dev
