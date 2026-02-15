#!/bin/sh

EMU_EXE=easyrpg
CORES_PATH=$(dirname "$0")

###############################

EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM_IN="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG"
mkdir -p "$SAVES_PATH/$EMU_TAG"
mkdir -p "$CHEATS_PATH/$EMU_TAG"
mkdir -p "/tmp/nextarch/$EMU_TAG"

RTP2K_EMU="$BIOS_PATH/$EMU_TAG/rtp/2000"
RTP2K3_EMU="$BIOS_PATH/$EMU_TAG/rtp/2003"
RTP2K_LEGACY="$BIOS_PATH/easyrpg-player/rtp/2000"
RTP2K3_LEGACY="$BIOS_PATH/easyrpg-player/rtp/2003"

mkdir -p "$RTP2K_EMU"
mkdir -p "$RTP2K3_EMU"

export RPG2K_RTP_PATH="$RTP2K_EMU:$RTP2K_LEGACY"
export RPG2K3_RTP_PATH="$RTP2K3_EMU:$RTP2K3_LEGACY"
export RPG_RTP_PATH="$RPG2K_RTP_PATH:$RPG2K3_RTP_PATH"

HOME="$USERDATA_PATH"
cd "$HOME"

derive_save_id() {
	ROM_PATH="$1"
	BASE_NAME=$(basename "$ROM_PATH")
	NORM_BASE=$(echo "$BASE_NAME" | tr '[:upper:]' '[:lower:]')
	if [ "$NORM_BASE" = "rpg_rt.ldb" ]; then
		BASE_NAME=$(basename "$(dirname "$ROM_PATH")")
	fi
	SAVE_ID="$BASE_NAME.sav"
	echo "$SAVE_ID" | tr '/\\:' '_'
}

export EASYRPG_SAVE_ID="$(derive_save_id "$ROM_IN")"

ROM="$ROM_IN"
EXTRACT_DIR="/tmp/nextarch/$EMU_TAG/extracted"
EXTRACTED=0

extract_zip_if_possible() {
	ZIP_IN="$1"
	BASE_NAME=$(basename "$ZIP_IN")
	BASE_NAME="${BASE_NAME%.*}"
	TARGET_DIR="$EXTRACT_DIR/$BASE_NAME"

	rm -rf "$TARGET_DIR"
	mkdir -p "$TARGET_DIR"

	if command -v unzip >/dev/null 2>&1; then
		unzip -oq "$ZIP_IN" -d "$TARGET_DIR" >/dev/null 2>&1 || return 1
		return 0
	fi

	if command -v bsdtar >/dev/null 2>&1; then
		bsdtar -xf "$ZIP_IN" -C "$TARGET_DIR" >/dev/null 2>&1 || return 1
		return 0
	fi

	if command -v tar >/dev/null 2>&1; then
		tar -xf "$ZIP_IN" -C "$TARGET_DIR" >/dev/null 2>&1 || return 1
		return 0
	fi

	return 1
}

count_files() {
	find "$1" -type f 2>/dev/null | wc -l
}

normalize_name() {
	echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

build_virtual_ldb_path() {
	REAL_LDB="$1"
	ROM_HINT="$2"
	BASE_HINT=$(basename "$ROM_HINT")
	BASE_HINT="${BASE_HINT%.*}"
	if [ -z "$BASE_HINT" ]; then
		BASE_HINT=$(basename "$(dirname "$REAL_LDB")")
	fi
	BASE_HINT=$(echo "$BASE_HINT" | tr '/\\' '_' | tr -cd '[:alnum:]_.-')
	if [ -z "$BASE_HINT" ]; then
		BASE_HINT="easyrpg_game"
	fi
	echo "$(dirname "$REAL_LDB")/$BASE_HINT.ldb"
}

find_ldb_near_zip() {
	ZIP_IN="$1"
	BASE_NAME=$(basename "$ZIP_IN")
	BASE_NAME="${BASE_NAME%.*}"
	ROM_DIR=$(dirname "$ZIP_IN")
	NORM_BASE=$(normalize_name "$BASE_NAME")

	find "$ROM_DIR" -type f -iname "RPG_RT.ldb" | while IFS= read -r LDB; do
		PARENT=$(basename "$(dirname "$LDB")")
		NORM_PARENT=$(normalize_name "$PARENT")
		if [ "$NORM_PARENT" = "$NORM_BASE" ]; then
			echo "$LDB"
			exit 0
		fi
	done
}

if [ -d "$ROM_IN" ]; then
	CANDIDATE=$(find "$ROM_IN" -type f -iname "RPG_RT.ldb" | head -n 1)
	if [ -n "$CANDIDATE" ]; then
		ROM=$(build_virtual_ldb_path "$CANDIDATE" "$ROM_IN")
	fi
else
	case "$ROM_IN" in
		*.zip|*.ZIP)
			if extract_zip_if_possible "$ROM_IN"; then
				CANDIDATE=$(find "$TARGET_DIR" -type f -iname "RPG_RT.ldb" | head -n 1)
				if [ -n "$CANDIDATE" ]; then
					ROM=$(build_virtual_ldb_path "$CANDIDATE" "$ROM_IN")
					EXTRACTED=1
				fi
			else
				BASE_NAME=$(basename "$ROM_IN")
				BASE_NAME="${BASE_NAME%.*}"
				SIDE_DIR="$(dirname "$ROM_IN")/$BASE_NAME"
				if [ -d "$SIDE_DIR" ]; then
					CANDIDATE=$(find "$SIDE_DIR" -type f -iname "RPG_RT.ldb" | head -n 1)
					if [ -n "$CANDIDATE" ]; then
						ROM=$(build_virtual_ldb_path "$CANDIDATE" "$ROM_IN")
						EXTRACTED=2
					fi
				fi
				if [ -z "$CANDIDATE" ]; then
					CANDIDATE=$(find_ldb_near_zip "$ROM_IN" | head -n 1)
					if [ -n "$CANDIDATE" ]; then
						ROM=$(build_virtual_ldb_path "$CANDIDATE" "$ROM_IN")
						EXTRACTED=3
					fi
				fi
			fi
			;;
		*.ldb|*.LDB)
			FILE_BASE=$(basename "$ROM_IN")
			NORM_FILE_BASE=$(normalize_name "${FILE_BASE%.*}")
			if [ "$NORM_FILE_BASE" = "rpgrt" ]; then
				ROM=$(build_virtual_ldb_path "$ROM_IN" "$(dirname "$ROM_IN")")
			fi
			;;
		*.lzh|*.LZH|*.easyrpg|*.EASYRPG)
			;;
		*)
			GAME_DIR=$(dirname "$ROM_IN")
			CANDIDATE=$(find "$GAME_DIR" -type f -iname "RPG_RT.ldb" | head -n 1)
			if [ -n "$CANDIDATE" ]; then
				ROM=$(build_virtual_ldb_path "$CANDIDATE" "$ROM_IN")
			fi
			;;
	esac
fi

if [ "$EXTRACTED" -eq 0 ]; then
	case "$ROM_IN" in
		*.zip|*.ZIP)
			if [ "$ROM" = "$ROM_IN" ]; then
				ROM="$ROM_IN"
			fi
			;;
	esac
fi

{
	echo "ROM_IN=$ROM_IN"
	echo "ROM_RESOLVED=$ROM"
	echo "ROM_PROJECT_LDB=$CANDIDATE"
	echo "EXTRACTED=$EXTRACTED"
	echo "EXTRACT_DIR=$EXTRACT_DIR"
	echo "EASYRPG_SAVE_ID=$EASYRPG_SAVE_ID"
	echo "RPG2K_RTP_PATH=$RPG2K_RTP_PATH"
	echo "RPG2K3_RTP_PATH=$RPG2K3_RTP_PATH"
	echo "RPG_RTP_PATH=$RPG_RTP_PATH"
	echo "CORE=$CORES_PATH/${EMU_EXE}_libretro.so"
	if [ -d "$RTP2K_EMU" ]; then
		echo "RTP2000_EMU_FILES=$(count_files "$RTP2K_EMU")"
	fi
	if [ -d "$RTP2K3_EMU" ]; then
		echo "RTP2003_EMU_FILES=$(count_files "$RTP2K3_EMU")"
	fi
	if [ -d "$RTP2K_LEGACY" ]; then
		echo "RTP2000_LEGACY_FILES=$(count_files "$RTP2K_LEGACY")"
	fi
	if [ -d "$RTP2K3_LEGACY" ]; then
		echo "RTP2003_LEGACY_FILES=$(count_files "$RTP2K3_LEGACY")"
	fi
} > "$LOGS_PATH/$EMU_TAG.txt" 2>&1

minarch.elf "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM" >> "$LOGS_PATH/$EMU_TAG.txt" 2>&1
