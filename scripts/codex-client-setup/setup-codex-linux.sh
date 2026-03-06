#!/usr/bin/env bash
set -euo pipefail

BLOCK_START="# >>> codex-local-config >>>"
BLOCK_END="# <<< codex-local-config <<<"

log() {
  echo "[codex-setup] $*"
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

install_node() {
  if has_cmd apt-get; then
    sudo apt-get update
    sudo apt-get install -y nodejs npm
    return
  fi
  if has_cmd dnf; then
    sudo dnf install -y nodejs npm
    return
  fi
  if has_cmd yum; then
    sudo yum install -y nodejs npm
    return
  fi
  if has_cmd pacman; then
    sudo pacman -Sy --noconfirm nodejs npm
    return
  fi
  echo "Unsupported distro: please install Node.js and npm manually." >&2
  exit 1
}

ensure_node_npm() {
  if has_cmd node && has_cmd npm; then
    return
  fi
  log "未检测到 Node.js/npm，尝试自动安装..."
  install_node
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

write_codex_config_toml() {
  local config_dir="$HOME/.codex"
  local config_file="$config_dir/config.toml"
  local base_url="$1"
  local tmp_file

  mkdir -p "$config_dir"
  tmp_file="$(mktemp)"

  if [[ -f "$config_file" ]]; then
    awk '
      BEGIN { skip_provider = 0 }
      {
        line = $0

        if (!skip_provider && line ~ /^[[:space:]]*\[model_providers\.bigmodeltoken\][[:space:]]*$/) {
          skip_provider = 1
          next
        }
        if (skip_provider) {
          if (line ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/ || line ~ /^[[:space:]]*\[\[[^]]+\]\][[:space:]]*$/) {
            skip_provider = 0
          } else {
            next
          }
        }

        if (line ~ /^[[:space:]]*model_provider[[:space:]]*=/) next
        if (line ~ /^[[:space:]]*model[[:space:]]*=/) next
        if (line ~ /^[[:space:]]*model_reasoning_effort[[:space:]]*=/) next
        if (line ~ /^[[:space:]]*network_access[[:space:]]*=/) next
        if (line ~ /^[[:space:]]*disable_response_storage[[:space:]]*=/) next
        if (line ~ /^[[:space:]]*windows_wsl_setup_acknowledged[[:space:]]*=/) next
        if (line ~ /^[[:space:]]*model_verbosity[[:space:]]*=/) next

        print line
      }
    ' "$config_file" > "$tmp_file"
  else
    : > "$tmp_file"
  fi

  cat > "$config_file" <<EOF2
model_provider = "bigmodeltoken"
model = "gpt-5.4"
model_reasoning_effort = "high"
network_access = "enabled"
disable_response_storage = true
windows_wsl_setup_acknowledged = true
model_verbosity = "high"

[model_providers.bigmodeltoken]
name = "bigmodeltoken"
base_url = "$base_url"
wire_api = "responses"
requires_openai_auth = true
EOF2

  if [[ -s "$tmp_file" ]]; then
    printf '\n' >> "$config_file"
    cat "$tmp_file" >> "$config_file"
  fi

  rm -f "$tmp_file"
}

read_config_block() {
  local line block=""
  while IFS= read -r line; do
    line="$(trim "$line")"
    if [[ -z "$line" ]]; then
      break
    fi
    block+="$line"$'\n'
  done
  printf '%s' "$block"
}

extract_config_value() {
  local block="$1"
  local field="$2"

  printf '%s\n' "$block" | awk -v field="$field" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    {
      line=$0
      gsub(/\r/, "", line)
      low=tolower(line)

      if (field == "url") {
        if (low ~ /^[[:space:]]*api[[:space:]]*base[[:space:]]*url[[:space:]]*:/ ||
            low ~ /^[[:space:]]*base[[:space:]]*url[[:space:]]*:/ ||
            low ~ /^[[:space:]]*url[[:space:]]*:/ ||
            low ~ /^[[:space:]]*openai_base_url[[:space:]]*=/) {
          if (low ~ /^[[:space:]]*openai_base_url[[:space:]]*=/) {
            sub(/^[^=]*=[[:space:]]*/, "", line)
          } else {
            sub(/^[^:]*:[[:space:]]*/, "", line)
          }
          print trim(line)
          exit
        }
      }

      if (field == "key") {
        if (low ~ /^[[:space:]]*api[[:space:]]*key[[:space:]]*:/ ||
            low ~ /^[[:space:]]*key[[:space:]]*:/ ||
            low ~ /^[[:space:]]*openai_api_key[[:space:]]*=/) {
          if (low ~ /^[[:space:]]*openai_api_key[[:space:]]*=/) {
            sub(/^[^=]*=[[:space:]]*/, "", line)
          } else {
            sub(/^[^:]*:[[:space:]]*/, "", line)
          }
          print trim(line)
          exit
        }
      }
    }
  '
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

resolve_config() {
  local existing_url existing_key masked_key input_block input_url input_key

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

  log "请粘贴配置文本（支持以下格式）："
  log "API Base URL: https://your-domain"
  log "API Key: sk-xxxxxx"
  log "粘贴完成后，输入一个空行结束。"
  if [[ -n "$existing_url" && -n "$existing_key" ]]; then
    log "直接输入空行可沿用当前配置。"
  fi

  input_block="$(read_config_block)"
  if [[ -z "$input_block" ]]; then
    if [[ -n "$existing_url" && -n "$existing_key" ]]; then
      RESOLVED_URL="$existing_url"
      RESOLVED_KEY="$existing_key"
      log "沿用当前配置。"
      return 0
    fi
    echo "未读取到配置文本。" >&2
    exit 1
  fi

  input_url="$(extract_config_value "$input_block" "url")"
  input_key="$(extract_config_value "$input_block" "key")"

  if [[ -z "$input_url" ]]; then
    input_url="$(printf '%s\n' "$input_block" | grep -Eo 'https?://[^[:space:]]+' | head -n 1 || true)"
  fi

  if [[ -z "$input_key" ]]; then
    input_key="$(printf '%s\n' "$input_block" | grep -Eo 'sk-[A-Za-z0-9._-]+' | head -n 1 || true)"
  fi

  input_url="$(trim "$input_url")"
  input_key="$(trim "$input_key")"

  if [[ -z "$input_url" || -z "$input_key" ]]; then
    echo "无法识别 Base URL 或 API Key，请按示例格式重新输入。" >&2
    exit 1
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

  write_profile_block "$HOME/.bashrc" "$base_url" "$RESOLVED_KEY"
  if [[ -f "$HOME/.zshrc" ]]; then
    write_profile_block "$HOME/.zshrc" "$base_url" "$RESOLVED_KEY"
  fi
  write_codex_config_toml "$base_url"

  export OPENAI_BASE_URL="$base_url"
  export OPENAI_API_KEY="$RESOLVED_KEY"
  try_codex_login "$base_url" "$RESOLVED_KEY"

  log "配置完成。"
  log "OPENAI_BASE_URL=$OPENAI_BASE_URL"
  log "API Key=$(mask_api_key "$OPENAI_API_KEY")"
  log "已写入 ~/.codex/config.toml（默认模型 gpt-5.4，推理强度 high）"
  log "请执行: source ~/.bashrc（或重开终端）后运行 codex"
}

main
