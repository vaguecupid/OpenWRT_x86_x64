#!/usr/bin/env python3
"""Fix known package-name and Kconfig-conflict collisions from the source root."""
from pathlib import Path
import re


def fix(root):
    vendor = root / 'package/community/5G-Modem-Support'
    cm = vendor / 'quectel_cm_5G/Makefile'
    metadata = root / 'scripts/package-metadata.pl'
    if not cm.is_file() or not metadata.is_file():
        raise SystemExit('Expected 5G package and package-metadata.pl are missing')
    changes = {}
    text = cm.read_text()
    old_definition = 'define Package/quectel-cm\n'
    new_definition = 'define Package/quectel-cm-5g\n'
    if old_definition in text:
        if text.count(old_definition) != 1 or '$(call BuildPackage,quectel-cm)' not in text:
            raise SystemExit('Unexpected vendor quectel-cm definition; review before modifying')
        # Keep PKG_NAME and source version unchanged; only rename the output package.
        text = re.sub(r'Package/quectel-cm(?=/|\s|$)', 'Package/quectel-cm-5g', text)
        text = text.replace('$(call BuildPackage,quectel-cm)', '$(call BuildPackage,quectel-cm-5g)')
        changes[cm] = text
    elif new_definition not in text:
        raise SystemExit('Vendor Quectel package layout changed')

    # Vendor modem applications and MHI driver use the vendor dialer.
    # The feeds quectel-cm package and luci-proto-quectel keep their original names.
    for path in sorted(vendor.rglob('Makefile')):
        if path == cm:
            continue
        old = path.read_text()
        new = re.sub(r'\+quectel-cm(?=\s|$)', '+quectel-cm-5g', old)
        if new != old:
            changes[path] = new

    # Keep both runtime CONFLICTS declarations. The two symmetric Kconfig
    # constraints are redundant; emit only alpha -> meta for this known pair.
    original = metadata.read_text()
    marker = '# OpenWRT_x86_x64: symmetric mihomo conflict guard'
    if marker not in original:
        start = original.index('sub mconf_conflicts {')
        end = original.index('\n}\n', start) + 3
        body = original[start:end]
        needle = '\t\tnext unless $package{$depend};\n'
        if body.count(needle) != 1:
            raise SystemExit('mconf_conflicts changed; refusing an unverified edit')
        guard = (needle + '\t\t' + marker + '\n'
                 + '\t\tnext if $pkgname eq "mihomo-meta" && $depend eq "mihomo-alpha";\n')
        changes[metadata] = original[:start] + body.replace(needle, guard, 1) + original[end:]
    # Apply only after all expected source patterns are verified.
    for path, text in changes.items():
        path.write_text(text)
        print('Fixed:', path.relative_to(root))
    if not changes:
        print('Dependency fixes are already applied')
    # Regenerate metadata on the next make defconfig; do not edit generated Kconfig.
    for name in ['.packageinfo', '.config-package.in', '.packageauxvars', '.packagedeps']:
        (root / 'tmp' / name).unlink(missing_ok=True)


if __name__ == '__main__':
    fix(Path.cwd())
