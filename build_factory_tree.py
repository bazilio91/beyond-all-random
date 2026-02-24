#!/usr/bin/env python3
"""
Parse Beyond All Reason unit definition files to build a factory tree
mapping factories to their combat buildoptions, grouped by faction.
"""

import os
import re
import glob
from collections import defaultdict

UNITS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "Beyond-All-Reason", "units")
OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "factory_tree.lua")

# Directories to skip (not regular faction units)
SKIP_DIRS = {"Scavengers", "other"}

FACTION_MAP = {
    "arm": "armada",
    "cor": "cortex",
    "leg": "legion",
}


def get_faction(unit_name):
    """Determine faction from unit name prefix."""
    for prefix, faction in FACTION_MAP.items():
        if unit_name.startswith(prefix):
            return faction
    return None


def find_all_lua_files():
    """Find all .lua unit definition files, skipping non-faction dirs."""
    results = {}
    for root, dirs, files in os.walk(UNITS_DIR):
        # Skip excluded directories
        rel = os.path.relpath(root, UNITS_DIR)
        top_dir = rel.split(os.sep)[0]
        if top_dir in SKIP_DIRS:
            continue
        for f in files:
            if f.endswith(".lua"):
                unit_name = f[:-4]  # strip .lua
                results[unit_name] = os.path.join(root, f)
    return results


def extract_buildoptions(filepath):
    """Extract buildoptions list from a Lua unit file using regex."""
    with open(filepath, "r", encoding="utf-8", errors="replace") as fh:
        content = fh.read()

    # Check if file has buildoptions
    match = re.search(r'buildoptions\s*=\s*\{(.*?)\}', content, re.DOTALL)
    if not match:
        return None

    # Extract quoted unit names from buildoptions block
    options_block = match.group(1)
    units = re.findall(r'"(\w+)"', options_block)
    return units if units else None


def has_weapondefs(filepath):
    """Check if a unit file contains weapondefs (making it a combat unit)."""
    with open(filepath, "r", encoding="utf-8", errors="replace") as fh:
        content = fh.read()
    return bool(re.search(r'weapondefs\s*=\s*\{', content, re.IGNORECASE))


def get_unit_name_from_file(filepath):
    """Extract the top-level unit name key from the Lua return table."""
    with open(filepath, "r", encoding="utf-8", errors="replace") as fh:
        content = fh.read()
    # Pattern: return { unitname = {
    match = re.search(r'return\s*\{\s*(\w+)\s*=\s*\{', content)
    if match:
        return match.group(1)
    return None


def is_factory(filepath):
    """Check if a unit is a factory (has buildoptions and is a building/lab)."""
    options = extract_buildoptions(filepath)
    return options is not None


def main():
    print(f"Scanning units in: {UNITS_DIR}")

    all_lua_files = find_all_lua_files()
    print(f"Found {len(all_lua_files)} unit files")

    # Build index: unit_name -> filepath (also index by file's internal name)
    unit_index = {}
    for unit_name, filepath in all_lua_files.items():
        unit_index[unit_name] = filepath
        # Also index by internal name if different
        internal = get_unit_name_from_file(filepath)
        if internal and internal != unit_name:
            unit_index[internal] = filepath

    # Find factories and their combat buildoptions
    # factory_name -> list of buildoption unit names
    factories = {}
    for unit_name, filepath in all_lua_files.items():
        buildoptions = extract_buildoptions(filepath)
        if buildoptions is None:
            continue

        # Use the internal unit name as the factory key
        internal = get_unit_name_from_file(filepath)
        factory_name = internal if internal else unit_name
        faction = get_faction(factory_name)
        if faction is None:
            continue

        # Filter: only keep factories that are buildings (have buildoptions
        # and are not constructors/commanders - we identify factories by
        # checking customparams unitgroup=builder or by checking if they're
        # in a Factory/Lab directory, or simply by having buildoptions and
        # being in a building/lab path)
        rel_path = os.path.relpath(filepath, UNITS_DIR).lower()
        is_building_factory = any(kw in rel_path for kw in
                                   ["factor", "lab", "gant", "plat",
                                    "shipyard", "hasy", "sasy", "amsub",
                                    "fhp", "sy.lua", "ap.lua", "aap.lua",
                                    "avp.lua", "havp.lua", "hp.lua",
                                    "vp.lua"])

        if not is_building_factory:
            # Also check: if not in a recognized factory path, skip
            # (this filters out commanders, constructors, etc.)
            continue

        factories[factory_name] = buildoptions

    print(f"Found {len(factories)} factories")

    # Track which units appear in multiple factories (shared units)
    unit_to_factories = defaultdict(list)
    for factory_name, buildoptions in factories.items():
        for unit in buildoptions:
            unit_to_factories[unit].append(factory_name)

    shared_units = {u: facs for u, facs in unit_to_factories.items()
                    if len(facs) > 1}
    if shared_units:
        print(f"\nShared units (appear in multiple factories):")
        for unit, facs in sorted(shared_units.items()):
            fac_factions = set()
            for f in facs:
                fc = get_faction(f)
                if fc:
                    fac_factions.add(fc)
            if len(fac_factions) > 1:
                print(f"  {unit} -> {', '.join(sorted(facs))} (CROSS-FACTION)")
            else:
                print(f"  {unit} -> {', '.join(sorted(facs))}")

    # Check which buildable units are combat (have weapondefs)
    combat_cache = {}

    def is_combat(unit_name):
        if unit_name in combat_cache:
            return combat_cache[unit_name]
        filepath = unit_index.get(unit_name)
        if filepath is None:
            # Try to find it by globbing
            matches = glob.glob(os.path.join(UNITS_DIR, "**", unit_name + ".lua"),
                                recursive=True)
            # Skip scavenger/other matches
            matches = [m for m in matches
                       if not any(s in m for s in ["/Scavengers/", "/other/"])]
            if matches:
                filepath = matches[0]
                unit_index[unit_name] = filepath

        if filepath and os.path.exists(filepath):
            result = has_weapondefs(filepath)
        else:
            print(f"  WARNING: Could not find unit file for '{unit_name}'")
            result = False
        combat_cache[unit_name] = result
        return result

    # Build the faction-grouped tree with only combat units
    # faction -> factory_name -> [combat_units]
    tree = defaultdict(lambda: defaultdict(list))

    for factory_name, buildoptions in sorted(factories.items()):
        faction = get_faction(factory_name)
        if not faction:
            continue
        combat_units = [u for u in buildoptions if is_combat(u)]
        if combat_units:
            tree[faction][factory_name] = combat_units

    # Print summary
    for faction in sorted(tree):
        print(f"\n{faction.upper()}:")
        for factory in sorted(tree[faction]):
            units = tree[faction][factory]
            print(f"  {factory}: {', '.join(units)}")

    # Write output Lua file
    with open(OUTPUT_FILE, "w", encoding="utf-8") as fh:
        fh.write("-- Auto-generated factory tree from BAR game data\n")
        fh.write("factory_tree = {\n")
        for faction in sorted(tree):
            fh.write(f"  {faction} = {{\n")
            for factory in sorted(tree[faction]):
                units = tree[faction][factory]
                units_str = ", ".join(f'"{u}"' for u in units)
                fh.write(f"    {factory} = {{ {units_str} }},\n")
            fh.write("  },\n")
        fh.write("}\n")

    print(f"\nOutput written to: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
