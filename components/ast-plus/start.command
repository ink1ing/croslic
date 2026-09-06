#!/bin/zsh

cd "$(dirname "$0")"

prompt_from_tty() {
  local message="$1"
  local variable_name="$2"
  local value
  printf "%s" "$message" > /dev/tty
  IFS= read -r value < /dev/tty
  printf -v "$variable_name" "%s" "$value"
}

pause_on_tty() {
  printf "%s" "$1" > /dev/tty
  IFS= read -r _ < /dev/tty
}

echo "AST-plus"
echo ""
prompt_from_tty "Choose language (zh/en) [zh]: " LANGUAGE
LANGUAGE=${LANGUAGE:-zh}

prompt_from_tty "Choose detail (basic/specific) [basic]: " DETAIL
DETAIL=${DETAIL:-basic}

prompt_from_tty "Use deep mode? (y/N) [N]: " DEEP

ARGS=(--once --language "$LANGUAGE" --detail "$DETAIL")

if [[ "$DEEP" == "y" || "$DEEP" == "Y" ]]; then
  ARGS+=(--deep)
fi

echo ""
echo "Starting scan with:"
echo "  language: $LANGUAGE"
echo "  detail:   $DETAIL"
if [[ "$DEEP" == "y" || "$DEEP" == "Y" ]]; then
  echo "  mode:     deep"
else
  echo "  mode:     standard"
fi
echo ""

swift run AST-plus "${ARGS[@]}"
STATUS=$?

echo ""
if [[ $STATUS -ne 0 ]]; then
  echo "AST-plus exited with status $STATUS."
  pause_on_tty "Press Enter to close..."
  exit $STATUS
fi

echo "Finished."
prompt_from_tty "Open result.md now? (Y/n) [Y]: " OPEN_RESULT
OPEN_RESULT=${OPEN_RESULT:-Y}

if [[ "$OPEN_RESULT" != "n" && "$OPEN_RESULT" != "N" ]]; then
  open "$PWD/reports/report.md"
fi

pause_on_tty "Press Enter to close..."
