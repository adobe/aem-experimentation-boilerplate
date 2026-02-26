#!/usr/bin/env bash
#
# AEM Experimentation instrumentation script.
# Run with:
#   curl -s https://raw.githubusercontent.com/adobe/aem-experimentation-boilerplate/main/bin/instrument.sh | bash
#
# Or download and run:
#   curl -sO https://raw.githubusercontent.com/adobe/aem-experimentation-boilerplate/main/bin/instrument.sh && bash instrument.sh
#
set -e

# Base URL for this script and other assets (curl location)
SRC_PATH="https://raw.githubusercontent.com/adobe/aem-experimentation-boilerplate/main/"

# When run via "curl ... | bash", we have no script path; run from cwd and find git root.
SCRIPT_SOURCE="curl | bash"

echo "AEM Experimentation instrumentation"
echo ""

# Find git root (walk up from current directory)
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || true
if [[ -z "$GIT_ROOT" ]]; then
  echo "Error: Not inside a git repository. Run this script from your project root (or any subdirectory)." >&2
  exit 1
fi

# Ensure we're in a GitHub repository
REMOTE="$(git -C "$GIT_ROOT" remote get-url origin 2>/dev/null)" || true
if [[ -z "$REMOTE" ]] || [[ "$REMOTE" != *github.com* ]]; then
  echo "Error: This is not a GitHub repository (no origin or origin is not GitHub)." >&2
  exit 1
fi

# Require scripts/scripts.js and scripts/aem.js from repo root
for f in scripts/scripts.js scripts/aem.js; do
  if [[ ! -f "$GIT_ROOT/$f" ]]; then
    echo "Error: Missing required file: $f (from repo root: $GIT_ROOT)" >&2
    exit 1
  fi
done

echo "Repository: $GIT_ROOT"
echo "Required files present: scripts/scripts.js, scripts/aem.js"
echo ""

# Ask user the supported content type (select from options)
echo "Select supported content type:"
echo "  1) AEMCS"
echo "  2) DA"
echo "  3) GoogleDoc"
echo "  4) Sharepoint"
CONTENT_TYPE=""
while [[ -z "$CONTENT_TYPE" ]]; do
  echo -n "Enter choice [1-4]: "
  read -r choice </dev/tty || true
  case "$choice" in
    1) CONTENT_TYPE="AEMCS" ;;
    2) CONTENT_TYPE="DA" ;;
    3) CONTENT_TYPE="GoogleDoc" ;;
    4) CONTENT_TYPE="Sharepoint" ;;
    *) echo "Error: Invalid choice. Enter 1, 2, 3, or 4." >&2 ;;
  esac
done
echo "Using content type: $CONTENT_TYPE"

# Ask user Editor to use (select from options)
echo ""
echo "Select Editor to use:"
echo "  1) AEM Page Editor"
echo "  2) Universal Editor"
echo "  3) EDS SideKick"
EDITOR=""
while [[ -z "$EDITOR" ]]; do
  echo -n "Enter choice [1-3]: "
  read -r choice </dev/tty || true
  case "$choice" in
    1) EDITOR="AEM Page Editor" ;;
    2) EDITOR="Universal Editor" ;;
    3) EDITOR="EDS SideKick" ;;
    *) echo "Error: Invalid choice. Enter 1, 2, or 3." >&2 ;;
  esac
done
echo "Using editor: $EDITOR"
echo ""

# AEMCS + AEM Page Editor: engine is already instrumented, no need to run
if [[ "$CONTENT_TYPE" == "AEMCS" && "$EDITOR" == "AEM Page Editor" ]]; then
  echo "Engine is already instrumented in AEMCS, please use latest version."
  exit 0
fi

# Ask for prodHost (customer-facing external hostname)
PROD_HOST=""
while [[ -z "${PROD_HOST// }" ]]; do
  echo -n "Enter prodHost (customer-facing external hostname, e.g. www.my-site.com): "
  read -r PROD_HOST </dev/tty || true
  if [[ -z "${PROD_HOST// }" ]]; then
    echo "Error: prodHost cannot be empty." >&2
  fi
done
echo "Using prodHost: $PROD_HOST"
echo ""

# Experimentation plugin: add if missing, or offer to update
EXPERIMENTATION_PLUGIN="$GIT_ROOT/plugins/experimentation"
SUBTREE_REMOTE="git@github.com:adobe/aem-experimentation.git"
SUBTREE_REF="v2"

if [[ ! -d "$EXPERIMENTATION_PLUGIN" ]]; then
  echo "Adding experimentation plugin (git subtree add)..."
  git -C "$GIT_ROOT" subtree add --squash --prefix plugins/experimentation "$SUBTREE_REMOTE" "$SUBTREE_REF" || {
    echo "Error: Failed to add experimentation plugin (git subtree add). Check network and access to $SUBTREE_REMOTE." >&2
    exit 1
  }
  echo "Plugin added."
else
  echo "Plugin plugins/experimentation already exists."
  echo -n "Update to latest v2? [y/N] "
  read -r answer </dev/tty || true
  if [[ "${answer,,}" != "y" && "${answer,,}" != "yes" ]]; then
    echo "Skipping update. Exiting."
    exit 0
  fi
  echo "Updating experimentation plugin (git subtree pull)..."
  git -C "$GIT_ROOT" subtree pull --squash --prefix plugins/experimentation "$SUBTREE_REMOTE" "$SUBTREE_REF" || {
    echo "Error: Failed to update experimentation plugin (git subtree pull)." >&2
    exit 1
  }
  echo "Plugin updated."
fi

# Copy experiment-loader.js from SRC_PATH to scripts/
echo "Copying experiment-loader.js to scripts/..."
curl -sSf "${SRC_PATH}scripts/experiment-loader.js" -o "$GIT_ROOT/scripts/experiment-loader.js" || {
  echo "Error: Failed to download experiment-loader.js from ${SRC_PATH}scripts/experiment-loader.js (network or HTTP error)." >&2
  exit 1
}
[[ -s "$GIT_ROOT/scripts/experiment-loader.js" ]] || {
  echo "Error: experiment-loader.js is missing or empty after download." >&2
  exit 1
}
echo "Done: scripts/experiment-loader.js"

# Add experiment-loader import and experimentation config to scripts/scripts.js just after the last import
SCRIPTS_JS="$GIT_ROOT/scripts/scripts.js"
if grep -q "experiment-loader.js" "$SCRIPTS_JS" 2>/dev/null && grep -q "experimentationConfig" "$SCRIPTS_JS" 2>/dev/null; then
  echo "scripts/scripts.js already contains experiment-loader import and experimentationConfig; skipping insert."
else
  LAST_IMPORT_LINE="$(
    grep -n "from ['\"]\.\/" "$SCRIPTS_JS" | tail -1 | cut -d: -f1
  )" || true
  if [[ -z "$LAST_IMPORT_LINE" ]]; then
    echo "Error: Could not find an import line in scripts/scripts.js to insert experimentation config after." >&2
    exit 1
  fi
  # Escape PROD_HOST for use inside a single-quoted JavaScript string
  PROD_HOST_ESC="${PROD_HOST//\\/\\\\}"
  PROD_HOST_ESC="${PROD_HOST_ESC//\'/\\\'}"
  SNIPPET="import {
  runExperimentation,
  showExperimentationRail,
} from './experiment-loader.js';

const experimentationConfig = {
  prodHost: '$PROD_HOST_ESC',
  audiences: {
    mobile: () => window.innerWidth < 600,
    desktop: () => window.innerWidth >= 600,
    // define your custom audiences here as needed
  },
};
"
  {
    head -n "$LAST_IMPORT_LINE" "$SCRIPTS_JS"
    printf '%s' "$SNIPPET"
    tail -n +"$((LAST_IMPORT_LINE + 1))" "$SCRIPTS_JS"
  } > "$SCRIPTS_JS.tmp" || {
    echo "Error: Failed to insert experimentation config into scripts/scripts.js." >&2
    exit 1
  }
  mv "$SCRIPTS_JS.tmp" "$SCRIPTS_JS"
  echo "Added experiment-loader import and experimentationConfig to scripts/scripts.js (prodHost: $PROD_HOST)."
fi

# Add "await runExperimentation(doc, experimentationConfig);" in loadEager: after decorateTemplateAndTheme() if present, else at start of loadEager
RUN_EXP_LINE='  await runExperimentation(doc, experimentationConfig);'
if grep -q "runExperimentation(doc" "$SCRIPTS_JS" 2>/dev/null || grep -q "runExperimentation(document" "$SCRIPTS_JS" 2>/dev/null; then
  echo "runExperimentation call already present in scripts/scripts.js; skipping."
else
  DECORATE_LINE="$(grep -n "decorateTemplateAndTheme();" "$SCRIPTS_JS" | head -1 | cut -d: -f1)" || true
  if [[ -n "$DECORATE_LINE" ]]; then
    INSERT_AT="$DECORATE_LINE"
    echo "Adding runExperimentation call just after decorateTemplateAndTheme();"
  else
    LOADEAGER_LINE="$(grep -n "async function loadEager\|function loadEager" "$SCRIPTS_JS" | head -1 | cut -d: -f1)" || true
    if [[ -z "$LOADEAGER_LINE" ]]; then
      echo "Error: Could not find loadEager function in scripts/scripts.js." >&2
      exit 1
    fi
    # Find the opening brace of loadEager (same line or next)
    BRACE_REL="$(sed -n "${LOADEAGER_LINE},\$p" "$SCRIPTS_JS" | grep -n "{" | head -1 | cut -d: -f1)" || true
    if [[ -z "$BRACE_REL" ]]; then
      echo "Error: Could not find loadEager function body in scripts/scripts.js." >&2
      exit 1
    fi
    INSERT_AT="$((LOADEAGER_LINE + BRACE_REL - 1))"
    echo "Adding runExperimentation call at beginning of loadEager (decorateTemplateAndTheme not found)."
  fi
  {
    head -n "$INSERT_AT" "$SCRIPTS_JS"
    echo "$RUN_EXP_LINE"
    tail -n +"$((INSERT_AT + 1))" "$SCRIPTS_JS"
  } > "$SCRIPTS_JS.tmp" || {
    echo "Error: Failed to insert runExperimentation call into scripts/scripts.js." >&2
    exit 1
  }
  mv "$SCRIPTS_JS.tmp" "$SCRIPTS_JS"
  echo "Added await runExperimentation(doc, experimentationConfig); to loadEager."
fi

# Add "await showExperimentationRail(doc, experimentationConfig);" at end of loadLazy (before closing brace)
SHOW_RAIL_LINE='  await showExperimentationRail(doc, experimentationConfig);'
if grep -q "showExperimentationRail(doc" "$SCRIPTS_JS" 2>/dev/null || grep -q "showExperimentationRail(document" "$SCRIPTS_JS" 2>/dev/null; then
  echo "showExperimentationRail call already present in scripts/scripts.js; skipping."
else
  LOADLAZY_LINE="$(grep -n "async function loadLazy(doc)" "$SCRIPTS_JS" | head -1 | cut -d: -f1)" || true
  if [[ -z "$LOADLAZY_LINE" ]]; then
    echo "Error: Could not find async function loadLazy(doc) in scripts/scripts.js." >&2
    exit 1
  fi
  # Find closing brace of loadLazy by counting braces from function start
  CLOSE_LINE="$(
    awk -v start="$LOADLAZY_LINE" '
      NR < start { next }
      NR >= start {
        for (i = 1; i <= length; i++) {
          c = substr($0, i, 1)
          if (c == "{") depth++
          if (c == "}") { depth--; if (depth == 0) { print NR; exit } }
        }
      }
    ' "$SCRIPTS_JS"
  )" || true
  if [[ -z "$CLOSE_LINE" ]]; then
    echo "Error: Could not find end of loadLazy function in scripts/scripts.js." >&2
    exit 1
  fi
  # Insert just before the closing brace
  INSERT_AT="$((CLOSE_LINE - 1))"
  {
    head -n "$INSERT_AT" "$SCRIPTS_JS"
    echo "$SHOW_RAIL_LINE"
    tail -n +"$CLOSE_LINE" "$SCRIPTS_JS"
  } > "$SCRIPTS_JS.tmp" || {
    echo "Error: Failed to insert showExperimentationRail call into scripts/scripts.js." >&2
    exit 1
  }
  mv "$SCRIPTS_JS.tmp" "$SCRIPTS_JS"
  echo "Added await showExperimentationRail(doc, experimentationConfig); at end of loadLazy."
fi

echo ""
echo "Done."

