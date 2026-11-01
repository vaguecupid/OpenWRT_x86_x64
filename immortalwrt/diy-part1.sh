#!/bin/bash
set -euo pipefail
export GIT_TERMINAL_PROMPT=0

# Merge_package
function merge_package(){
    repo=`echo $1 | rev | cut -d'/' -f 1 | rev`
    pkg=`echo $2 | rev | cut -d'/' -f 1 | rev`
    # find package/ -follow -name $pkg -not -path "package/openwrt-packages/*" | xargs -rt rm -rf
    git clone --depth=1 --single-branch $1
    [ -d package/openwrt-packages ] || mkdir -p package/openwrt-packages
    mv $2 package/openwrt-packages/
    rm -rf $repo
}

rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config

# Clone community packages to package/community
mkdir -p package/community
pushd package/community
git clone --depth=1 https://github.com/fw876/helloworld
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki
git clone --depth=1 https://github.com/DHDAXCW/dhdaxcw-app
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config
git clone --depth=1 https://github.com/DHDAXCW/istore
git clone --depth=1 https://github.com/Siriling/5G-Modem-Support && rm -rf 5G-Modem-Support/rooter
git clone --depth=1 https://github.com/gdy666/luci-app-lucky
popd

# add luci-app-mosdns
rm -rf feeds/packages/net/v2ray-geodata
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# Fix the archived ndisc6 source URL without changing version or hash.
sed -i \
  's|^PKG_SOURCE_URL:=.*|PKG_SOURCE_URL:=https://www.remlab.net/files/ndisc6/archive|' \
  package/community/5G-Modem-Support/ndisc/Makefile

# ImmortalWrt 24.10 provides wget-ssl, not wget-any.
sed -i 's/wget-any/wget-ssl/g' package/community/luci-theme-argon/Makefile

# Apply package dependency repairs before generating Kconfig.
DIY_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python3 "$DIY_SCRIPT_DIR/../scripts/fix-package-dependencies.py"
