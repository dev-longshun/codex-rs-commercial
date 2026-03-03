#!/bin/bash
set -euo pipefail

BLOCK_START="# >>> codex-local-config >>>"
BLOCK_END="# <<< codex-local-config <<<"

log() {
  echo "[codex-setup] $*"
}

pause_exit() {
  local code="${1:-0}"
  echo
  read -r -p "按回车键退出..." _
  exit "$code"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

trim() {
  echo "$1" | awk '{$1=$1; print}'
}

mask_api_key() {
  local key="$1"
  local len="${#key}"

  if [[ "$len" -le 6 ]]; then
    echo "******"
    return
  fi

  local prefix="${key:0:4}"
  local suffix="${key: -3}"
  echo "${prefix}******${suffix}"
}

read_profile_value() {
  local file="$1"
  local key="$2"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  awk -v s="$BLOCK_START" -v e="$BLOCK_END" -v k="$key" '
    $0==s {in_block=1; next}
    $0==e {in_block=0; next}
    in_block && $0 ~ "^export "k"=" {
      v=$0
      sub("^export "k"=\"?", "", v)
      sub("\"?$", "", v)
      value=v
    }
    END {
      if (value != "") print value
    }
  ' "$file"
}

current_saved_config() {
  local key="$1"
  local value

  value="$(read_profile_value "$HOME/.zshrc" "$key")"
  if [[ -n "$value" ]]; then
    echo "$value"
    return
  fi

  value="$(read_profile_value "$HOME/.bashrc" "$key")"
  echo "$value"
}

ensure_node_npm() {
  if has_cmd node && has_cmd npm; then
    return 0
  fi
  log "未检测到 Node.js/npm，尝试使用 Homebrew 安装..."
  if ! has_cmd brew; then
    log "未检测到 Homebrew。请先安装 Homebrew 后重试。"
    pause_exit 1
  fi
  brew install node
}

current_codex_version() {
  codex --version 2>/dev/null | awk '{print $NF}' | tr -d '[:space:]'
}

latest_codex_version() {
  npm view @openai/codex version 2>/dev/null | tail -n 1 | tr -d '[:space:]'
}

install_or_update_codex() {
  local local_ver latest_ver

  if has_cmd codex; then
    local_ver="$(current_codex_version)"
  else
    local_ver=""
  fi
  latest_ver="$(latest_codex_version || true)"

  if [[ -n "$local_ver" && -n "$latest_ver" && "$local_ver" == "$latest_ver" ]]; then
    log "Codex CLI 已是最新版本: $local_ver"
    return 0
  fi

  if [[ -n "$local_ver" && -n "$latest_ver" ]]; then
    log "检测到 Codex CLI 可更新: $local_ver -> $latest_ver"
  elif [[ -n "$local_ver" ]]; then
    log "已安装 Codex CLI 版本: $local_ver（无法获取远程版本，将继续使用当前版本）"
    return 0
  else
    log "未检测到 Codex CLI，开始安装..."
  fi

  log "正在安装/更新 Codex CLI..."
  npm install -g @openai/codex@latest
  log "当前版本: $(codex --version)"
}

try_codex_login() {
  local base_url="$1"
  local api_key="$2"

  log "正在写入 Codex 登录态..."
  if printf '%s' "$api_key" | OPENAI_BASE_URL="$base_url" codex login --with-api-key >/dev/null 2>&1; then
    log "Codex 登录态写入成功。"
  else
    log "Codex 登录态写入失败（不影响环境变量配置）。"
    log "可手动执行: OPENAI_BASE_URL=\"$base_url\" codex login --with-api-key"
  fi
}

normalize_base_url() {
  local raw="$1"
  raw="${raw%/}"
  if [[ ! "$raw" =~ ^https?:// ]]; then
    raw="http://$raw"
  fi
  if [[ "$raw" == */v1 ]]; then
    echo "$raw"
  else
    echo "$raw/v1"
  fi
}

write_profile_block() {
  local file="$1"
  local base_url="$2"
  local api_key="$3"

  touch "$file"
  if grep -q "$BLOCK_START" "$file" 2>/dev/null; then
    awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
      $0==s {skip=1; next}
      $0==e {skip=0; next}
      !skip {print}
    ' "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
  fi

  cat >> "$file" <<EOF2
$BLOCK_START
export OPENAI_BASE_URL="$base_url"
export OPENAI_API_KEY="$api_key"
$BLOCK_END
EOF2
}

resolve_config() {
  local existing_url existing_key masked_key answer input_url input_key

  existing_url="$(current_saved_config OPENAI_BASE_URL)"
  existing_key="$(current_saved_config OPENAI_API_KEY)"

  if [[ -n "$existing_url" || -n "$existing_key" ]]; then
    log "检测到当前配置："
    if [[ -n "$existing_url" ]]; then
      log "- URL: $existing_url"
    else
      log "- URL: (未配置)"
    fi

    if [[ -n "$existing_key" ]]; then
      masked_key="$(mask_api_key "$existing_key")"
      log "- API Key: $masked_key"
    else
      log "- API Key: (未配置)"
    fi
  else
    log "未检测到历史配置。"
  fi

  if [[ -n "$existing_url" && -n "$existing_key" ]]; then
    read -r -p "是否更新 URL/API Key？[y/N]: " answer
    answer="$(trim "$answer")"
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      RESOLVED_URL="$existing_url"
      RESOLVED_KEY="$existing_key"
      log "沿用当前配置。"
      return 0
    fi
  fi

  read -r -p "请输入 Base URL（示例: https://your-domain 或 http://127.0.0.1:8317）${existing_url:+（回车沿用当前）}: " input_url
  input_url="$(trim "$input_url")"
  if [[ -z "$input_url" && -n "$existing_url" ]]; then
    input_url="$existing_url"
  fi

  if [[ -n "$existing_key" ]]; then
    read -r -p "请输入 API Key（回车沿用当前）: " input_key
  else
    read -r -p "请输入 API Key: " input_key
  fi
  input_key="$(trim "$input_key")"
  if [[ -z "$input_key" && -n "$existing_key" ]]; then
    input_key="$existing_key"
  fi

  if [[ -z "$input_url" || -z "$input_key" ]]; then
    log "Base URL 和 API Key 不能为空。"
    pause_exit 1
  fi

  RESOLVED_URL="$input_url"
  RESOLVED_KEY="$input_key"
}

main() {
  log "开始配置 Codex 代理接入..."
  ensure_node_npm
  install_or_update_codex

  local base_url
  resolve_config
  base_url="$(normalize_base_url "$RESOLVED_URL")"

  write_profile_block "$HOME/.zshrc" "$base_url" "$RESOLVED_KEY"
  write_profile_block "$HOME/.bashrc" "$base_url" "$RESOLVED_KEY"

  export OPENAI_BASE_URL="$base_url"
  export OPENAI_API_KEY="$RESOLVED_KEY"
  try_codex_login "$base_url" "$RESOLVED_KEY"

  log "配置完成。"
  log "OPENAI_BASE_URL=$OPENAI_BASE_URL"
  log "API Key=$(mask_api_key "$OPENAI_API_KEY")"
  log "已写入 ~/.zshrc 与 ~/.bashrc（下次终端启动自动生效）"
  log "现在可直接运行: codex"
  pause_exit 0
}

main
