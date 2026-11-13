#!/bin/bash

echo "正在生成 REALITY 密钥对..."

# 运行 xray 生成密钥
docker run --rm ghcr.io/xtls/xray-core:latest x25519 > reality_keys.txt

echo "REALITY 密钥对已生成，保存在 reality_keys.txt"
echo ""
echo "请将以下内容复制到 config/config.json 中："
echo ""
cat reality_keys.txt
