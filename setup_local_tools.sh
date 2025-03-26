#!/usr/bin/env bash

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

mkdir -p ~/rust_tools && pushd ~/rust_tools

# Install helix editor
mkdir -p ~/.config/helix
git clone https://github.com/helix-editor/helix || pushd helix && git pull
RUSTFLAGS="-C target-feature=-crt-static -C target-cpu=native" cargo install --path helix-term --locked
rm -rf ~/.config/helix/runtime && ln -Ts $PWD/runtime ~/.config/helix/runtime
cat > ~/.config/helix/config.toml << EOF
theme = "monokai"
[keys.normal."space"]
o = "file_picker_in_current_buffer_directory"
[editor.lsp]
display-inlay-hints = true
[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"
[editor]
true-color = true
EOF
popd

# Install zellij
git clone https://github.com/zellij-org/zellij.git || pushd zellij && git pull
RUSTFLAGS="-C target-feature=-crt-static -C target-cpu=native" cargo install --locked --path .
popd
