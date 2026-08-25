install_lua_packages() {
  local lua_packages=(
    "luasocket"
    "lua-cjson"
  )

  for p in "${lua_packages[@]}"; do
    if luarocks list --porcelain | grep -w "$p" >/dev/null; then
      warn "LuaRocks package $p is already installed"
    else
      info "Installing LuaRocks package < $p >"
      luarocks install "$p"
    fi
  done
}
