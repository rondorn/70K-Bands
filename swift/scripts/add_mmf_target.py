#!/usr/bin/env python3
"""Duplicate the MDF Bands Xcode target as MMF Bands."""

import re
import uuid
from pathlib import Path
from typing import Optional

PROJECT = Path(__file__).resolve().parent.parent / "70K Bands.xcodeproj" / "project.pbxproj"

TARGET_OBJECT_IDS = [
    "1172EDF52E5A1C4D006E3596",
    "1172EDF72E5A1C4D006E3596",
    "1172EE272E5A1C4D006E3596",
    "1172EE342E5A1C4D006E3596",
    "119717BD2E5E4F8400D500C9",
    "1172EE352E5A1C4D006E3596",
    "716395E5DAFB8CD768AFABDF",
    "B09391A028CD4320A77ADCD1",
]
CONFIG_OBJECT_IDS = [
    "1172EE452E5A1C4D006E3596",
    "1172EE462E5A1C4D006E3596",
]
PRODUCT_OBJECT_ID = "1172EE472E5A1C4D006E3596"


def new_id() -> str:
    return uuid.uuid4().hex[:24].upper()


def extract_object(text: str, obj_id: str) -> Optional[str]:
    pattern = re.compile(
        rf"\t\t{re.escape(obj_id)} /\* .+? \*/ = \{{",
        re.DOTALL,
    )
    match = pattern.search(text)
    if not match:
        return None
    start = match.start()
    brace = text.find("{", start)
    depth = 0
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 2]
    return None


def remap_block(block: str, id_map: dict[str, str]) -> str:
    out = block
    for old, new in sorted(id_map.items(), key=lambda kv: len(kv[0]), reverse=True):
        out = out.replace(old, new)
    return (
        out.replace("MDF Bands", "MMF Bands")
        .replace("Pods-MDF Bands", "Pods-MMF Bands")
        .replace("Pods_MDF_Bands", "Pods_MMF_Bands")
        .replace("FESTIVAL_MDF", "FESTIVAL_MMF")
        .replace("com.rdorn.mdfbands", "com.rdorn.mmfbands")
        .replace("Info-MDF.plist", "Info-MMF.plist")
        .replace("GoogleService-Info-MDF.plist", "GoogleService-Info-MMF.plist")
        .replace("UILaunchScreen-MDF.xib", "UILaunchScreen-MMF.xib")
    )


def main() -> None:
    text = PROJECT.read_text()
    if "MMF Bands" in text:
        print("MMF Bands target already exists")
        return

    mdf_build_file_ids = sorted(
        set(
            re.findall(
                r"^\t\t(1172E[A-F0-9]{19}) /\* .* \*/ = \{isa = PBXBuildFile;",
                text,
                re.MULTILINE,
            )
        )
    )
    mdf_build_file_ids += ["9DE58C80B71FF2933BD45C36", "1116C9D62F63033300E1ACC1"]

    all_old_ids = TARGET_OBJECT_IDS + CONFIG_OBJECT_IDS + [PRODUCT_OBJECT_ID, "1172EE442E5A1C4D006E3596"] + mdf_build_file_ids
    id_map = {old: new_id() for old in all_old_ids}

    mmf_firebase_ref = new_id()
    mmf_info_ref = new_id()
    mmf_launch_ref = new_id()
    mmf_firebase_build = new_id()
    mmf_info_build = new_id()
    mmf_launch_build = new_id()
    pods_mmf_framework_ref = new_id()
    pods_mmf_framework_build = new_id()
    pods_mmf_debug_xcconfig = new_id()
    pods_mmf_release_xcconfig = new_id()

    mmf_target_id = id_map["1172EDF52E5A1C4D006E3596"]
    mmf_resources_id = id_map["1172EE352E5A1C4D006E3596"]
    mmf_frameworks_id = id_map["1172EE272E5A1C4D006E3596"]
    mmf_pods_embed_id = id_map["716395E5DAFB8CD768AFABDF"]
    mmf_product_ref = id_map[PRODUCT_OBJECT_ID]
    debug_id = id_map["1172EE452E5A1C4D006E3596"]
    release_id = id_map["1172EE462E5A1C4D006E3596"]
    config_list_id = id_map["1172EE442E5A1C4D006E3596"]

    build_file_lines = []
    for old in mdf_build_file_ids:
        start = text.find(f"\t\t{old} /*")
        end = text.find("\n", start)
        build_file_lines.append(remap_block(text[start:end], id_map))
    build_file_lines.extend(
        [
            f"\t\t{pods_mmf_framework_build} /* Pods_MMF_Bands.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {pods_mmf_framework_ref} /* Pods_MMF_Bands.framework */; }};",
            f"\t\t{mmf_firebase_build} /* GoogleService-Info-MMF.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {mmf_firebase_ref} /* GoogleService-Info-MMF.plist */; }};",
            f"\t\t{mmf_info_build} /* Info-MMF.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {mmf_info_ref} /* Info-MMF.plist */; }};",
            f"\t\t{mmf_launch_build} /* UILaunchScreen-MMF.xib in Resources */ = {{isa = PBXBuildFile; fileRef = {mmf_launch_ref} /* UILaunchScreen-MMF.xib */; }};",
        ]
    )
    text = text.replace(
        "/* End PBXBuildFile section */",
        "\n".join(build_file_lines) + "\n/* End PBXBuildFile section */",
    )

    file_ref_lines = [
        f"\t\t{mmf_firebase_ref} /* GoogleService-Info-MMF.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"GoogleService-Info-MMF.plist\"; sourceTree = \"<group>\"; }};",
        f"\t\t{mmf_info_ref} /* Info-MMF.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"Info-MMF.plist\"; sourceTree = \"<group>\"; }};",
        f"\t\t{mmf_launch_ref} /* UILaunchScreen-MMF.xib */ = {{isa = PBXFileReference; lastKnownFileType = file.xib; path = \"UILaunchScreen-MMF.xib\"; sourceTree = \"<group>\"; }};",
        f"\t\t{pods_mmf_framework_ref} /* Pods_MMF_Bands.framework */ = {{isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = Pods_MMF_Bands.framework; sourceTree = BUILT_PRODUCTS_DIR; }};",
        f"\t\t{pods_mmf_debug_xcconfig} /* Pods-MMF Bands.debug.xcconfig */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = \"Pods-MMF Bands.debug.xcconfig\"; path = \"Target Support Files/Pods-MMF Bands/Pods-MMF Bands.debug.xcconfig\"; sourceTree = \"<group>\"; }};",
        f"\t\t{pods_mmf_release_xcconfig} /* Pods-MMF Bands.release.xcconfig */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = \"Pods-MMF Bands.release.xcconfig\"; path = \"Target Support Files/Pods-MMF Bands/Pods-MMF Bands.release.xcconfig\"; sourceTree = \"<group>\"; }};",
        remap_block(extract_object(text, PRODUCT_OBJECT_ID), id_map),
    ]
    text = text.replace(
        "/* End PBXFileReference section */",
        "\n".join(file_ref_lines) + "\n/* End PBXFileReference section */",
    )

    target_blocks = [remap_block(extract_object(text, obj_id), id_map) for obj_id in TARGET_OBJECT_IDS]
    text = text.replace(
        "/* End PBXNativeTarget section */",
        "\n".join(target_blocks) + "\n/* End PBXNativeTarget section */",
    )

    config_blocks = []
    for obj_id in CONFIG_OBJECT_IDS:
        block = remap_block(extract_object(text, obj_id), id_map)
        if "name = Debug;" in block:
            block = re.sub(
                r"baseConfigurationReference = [A-F0-9]{24}",
                f"baseConfigurationReference = {pods_mmf_debug_xcconfig}",
                block,
                count=1,
            )
        elif "name = Release;" in block:
            block = re.sub(
                r"baseConfigurationReference = [A-F0-9]{24}",
                f"baseConfigurationReference = {pods_mmf_release_xcconfig}",
                block,
                count=1,
            )
        config_blocks.append(block)
    text = text.replace(
        "/* End XCBuildConfiguration section */",
        "\n".join(config_blocks) + "\n/* End XCBuildConfiguration section */",
    )

    text = text.replace(
        "/* End XCConfigurationList section */",
        f"\t\t{config_list_id} /* Build configuration list for PBXNativeTarget \"MMF Bands\" */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{debug_id} /* Debug */,\n"
        f"\t\t\t\t{release_id} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};\n"
        "/* End XCConfigurationList section */",
    )

    def replace_object(obj_id: str, new_block: str) -> None:
        nonlocal text
        old = extract_object(text, obj_id)
        if old:
            text = text.replace(old, new_block)

    resources_block = remap_block(extract_object(text, mmf_resources_id), id_map)
    resources_block = resources_block.replace(
        id_map["1172EE4A2E5A2604006E3596"],
        mmf_firebase_build,
    ).replace(
        id_map["1172EE5E2E5A292E006E3596"],
        mmf_info_build,
    ).replace(
        id_map["1172EE682E5A3486006E3596"],
        mmf_launch_build,
    )
    replace_object(mmf_resources_id, resources_block)

    frameworks_block = remap_block(extract_object(text, mmf_frameworks_id), id_map)
    frameworks_block = frameworks_block.replace(
        id_map["9DE58C80B71FF2933BD45C36"],
        pods_mmf_framework_build,
    )
    replace_object(mmf_frameworks_id, frameworks_block)

    pods_embed_block = remap_block(extract_object(text, mmf_pods_embed_id), id_map)
    replace_object(mmf_pods_embed_id, pods_embed_block)

    pods_check_id = id_map["B09391A028CD4320A77ADCD1"]
    pods_check_block = remap_block(extract_object(text, pods_check_id), id_map)
    replace_object(pods_check_id, pods_check_block)

    text = text.replace(
        "\t\t\t\t1172EE472E5A1C4D006E3596 /* MDF Bands.app */,\n",
        f"\t\t\t\t1172EE472E5A1C4D006E3596 /* MDF Bands.app */,\n\t\t\t\t{mmf_product_ref} /* MMF Bands.app */,\n",
    )
    text = text.replace(
        "\t\t\t\t1172EE492E5A2604006E3596 /* GoogleService-Info-MDF.plist */,\n",
        f"\t\t\t\t1172EE492E5A2604006E3596 /* GoogleService-Info-MDF.plist */,\n\t\t\t\t{mmf_firebase_ref} /* GoogleService-Info-MMF.plist */,\n",
    )
    text = text.replace(
        "\t\t\t\t1172EE542E5A292E006E3596 /* Info-MDF.plist */,\n",
        f"\t\t\t\t1172EE542E5A292E006E3596 /* Info-MDF.plist */,\n\t\t\t\t{mmf_info_ref} /* Info-MMF.plist */,\n",
    )
    text = text.replace(
        "\t\t\t\t1172EE652E5A3486006E3596 /* UILaunchScreen-MDF.xib */,\n",
        f"\t\t\t\t1172EE652E5A3486006E3596 /* UILaunchScreen-MDF.xib */,\n\t\t\t\t{mmf_launch_ref} /* UILaunchScreen-MMF.xib */,\n",
    )
    text = text.replace(
        "\t\t\t\tDDAE333FDF216D5113AD6F14 /* Pods_MDF_Bands.framework */,\n",
        f"\t\t\t\tDDAE333FDF216D5113AD6F14 /* Pods_MDF_Bands.framework */,\n\t\t\t\t{pods_mmf_framework_ref} /* Pods_MMF_Bands.framework */,\n",
    )
    text = text.replace(
        "\t\t\t\tE5280282B2B9A8824CA090AF /* Pods-MDF Bands.release.xcconfig */,\n",
        f"\t\t\t\tE5280282B2B9A8824CA090AF /* Pods-MDF Bands.release.xcconfig */,\n\t\t\t\t{pods_mmf_debug_xcconfig} /* Pods-MMF Bands.debug.xcconfig */,\n\t\t\t\t{pods_mmf_release_xcconfig} /* Pods-MMF Bands.release.xcconfig */,\n",
    )
    text = text.replace(
        "\t\t\t\t1172EDF52E5A1C4D006E3596 /* MDF Bands */,\n",
        f"\t\t\t\t1172EDF52E5A1C4D006E3596 /* MDF Bands */,\n\t\t\t\t{mmf_target_id} /* MMF Bands */,\n",
    )

    PROJECT.write_text(text)

    scheme_path = PROJECT.parent / "xcshareddata" / "xcschemes" / "MMF Bands.xcscheme"
    if scheme_path.exists():
        scheme_path.write_text(
            scheme_path.read_text().replace("MMF_TARGET_ID_PLACEHOLDER", mmf_target_id)
        )

    print(f"Added MMF Bands target (id: {mmf_target_id})")


if __name__ == "__main__":
    main()
