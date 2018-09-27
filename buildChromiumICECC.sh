#!/bin/bash

if [ -z "$1" ]
then
   echo "No build mode input"
   echo "Usage : ./buildChromium.sh Debug or Release or sync [blink_tests]"
   exit 1
fi

export CCACHE_PREFIX=icecc
export CCACHE_BASEDIR=$HOME/git/chromium/
export CHROME_DEVEL_SANDBOX=/usr/local/sbin/chrome-devel-sandbox
export ICECC_CLANG_REMOTE_CPP=1

# Please set your path to ICECC_VERSION and CHROMIUM_SRC.
export ICECC_VERSION=$HOME/git/chromium/clang.tar.gz
export CHROMIUM_SRC=$HOME/git/chromium/src

export PATH=/usr/lib/ccache:/usr/lib/icecc/bin:$PATH
export PATH=$CHROMIUM_SRC/third_party/llvm-build/Release+Asserts/bin:$PATH
export CHROMIUM_BUILDTOOLS_PATH=$CHROMIUM_SRC/buildtools

# Do gclient sync. 
if [ "$1" == sync ];
then
  export TMP_CLANG_DIR=tmp-clang
  timestamp=$(date +"%T")
  echo "[$timestamp] Start gclient sync."
  gclient sync
  timestamp=$(date +"%T")
  echo "[$timestamp] Finish gclient sync."

  timestamp=$(date +"%T")
  echo "[$timestamp] Create a new clang based on patched Chromium."
  if [ ! -d $TMP_CLANG_DIR ]; then
    mkdir $TMP_CLANG_DIR
  fi
  cd tmp-clang
  /usr/local/bin/icecc-create-env --clang $CHROMIUM_SRC/third_party/llvm-build/Release+Asserts/bin/clang /usr/local/libexec/icecc/compilerwrapper
  mv *.tar.gz $ICECC_VERSION
  cd ..
  rm -rf $TMP_CLANG_DIR
  timestamp=$(date +"%T")
  echo "[$timestamp] Finish gclient sync and create the new clang.tar.gz."
  exit 0
fi

# Set Chromium gn build arguments.
export GN_DEFINES='is_component_build=false'
export GN_DEFINES=$GN_DEFINES' enable_nacl=false treat_warnings_as_errors=false'
export GN_DEFINES=$GN_DEFINES' proprietary_codecs=true ffmpeg_branding="Chrome"'
export GN_DEFINES=$GN_DEFINES' linux_use_bundled_binutils=false clang_use_chrome_plugins=false cc_wrapper="ccache" ffmpeg_use_atomics_fallback=true enable_swiftshader=false use_jumbo_build = false '
export GN_DEFINES=$GN_DEFINES' google_api_key="???" google_default_client_id="??.com" google_default_client_secret="??"'
timestamp=$(date +"%T")
echo "[$timestamp] 1. Configuration"

# Start building Chromium using the gn configuration.
if [ "$1" == Debug ];
then
 # export GN_DEFINES=$GN_DEFINES' use_ozone=true enable_mus=true use_xkbcommon=true'
  export GN_DEFINES=$GN_DEFINES' dcheck_always_on=false'
  echo "GN_DEFINES: "$GN_DEFINES
  gn gen out/Debug "--args=is_debug=true $GN_DEFINES"
elif [ "$1" == Release ];
then
  #export GN_DEFINES=$GN_DEFINES' use_ozone=true enable_mus=true use_xkbcommon=true'
  echo "GN_DEFINES: "$GN_DEFINES
  gn gen out/Release "--args=is_debug=false $GN_DEFINES"
elif [ "$1" == vulkan ];
then
  export GN_DEFINES=$GN_DEFINES' enable_vulkan=true'
  echo "GN_DEFINES: "$GN_DEFINES
  gn gen out/vulkan "--args=is_debug=true $GN_DEFINES"
elif [ "$1" == gbm_cros ];
then
  export GN_DEFINES=$GN_DEFINES' target_os="chromeos" use_ozone=true'
  export GN_DEFINES=$GN_DEFINES' ozone_platform_gbm=true ozone_platform_x11=false ozone_platform_wayland=false ozone_auto_platforms=false use_cups=false'
  export GN_DEFINES=$GN_DEFINES' cc_wrapper="ccache"'
  export GN_DEFINES=$GN_DEFINES' use_intel_minigbm = true'
  echo "GN_DEFINES: "$GN_DEFINES
  gn gen out/gbm_cros "--args=is_debug=true $GN_DEFINES"
elif [ "$1" == gbm_rel_cros ];
then
  export GN_DEFINES=$GN_DEFINES' target_os="chromeos" use_ozone=true'
  export GN_DEFINES=$GN_DEFINES' ozone_platform_gbm=true ozone_platform_x11=false ozone_platform_wayland=false ozone_auto_platforms=false use_cups=false'
  export GN_DEFINES=$GN_DEFINES' cc_wrapper="ccache"'
  export GN_DEFINES=$GN_DEFINES' use_intel_minigbm = true'
  export GN_DEFINES=$GN_DEFINES' toolkit_views = true'
  echo "GN_DEFINES: "$GN_DEFINES
  gn gen out/gbm_rel_cros "--args=is_debug=false $GN_DEFINES"
elif [ "$1" == gbm_rel ];
then
  export GN_DEFINES=$GN_DEFINES' use_ozone=true ozone_platform_gbm=true'
  export GN_DEFINES=$GN_DEFINES' remove_webcore_debug_symbols=true'
  export GN_DEFINES=$GN_DEFINES' cc_wrapper="ccache"'
  export GN_DEFINES=$GN_DEFINES' use_intel_minigbm = true'
  export GN_DEFINES=$GN_DEFINES' build_display_configuration = true'
  export GN_DEFINES=$GN_DEFINES' toolkit_views = false use_vaapi = true' 
  export GN_DEFINES=$GN_DEFINES' is_debug=false' 
  echo "GN_DEFINES: "$GN_DEFINES
  gn gen out/gbm_rel "--args=$GN_DEFINES"
elif [ "$1" == gbm_debug ];
then
  export GN_DEFINES=$GN_DEFINES' use_ozone=true ozone_platform_gbm=true'
  export GN_DEFINES=$GN_DEFINES' remove_webcore_debug_symbols=true'
  export GN_DEFINES=$GN_DEFINES' cc_wrapper="ccache"'
  export GN_DEFINES=$GN_DEFINES' use_intel_minigbm = true'
  export GN_DEFINES=$GN_DEFINES' build_display_configuration = true'
  export GN_DEFINES=$GN_DEFINES' toolkit_views = false use_vaapi = true' 
  echo "GN_DEFINES: "$GN_DEFINES
  gn gen out/gbm_debug "--args=$GN_DEFINES"
else
  echo "Undefined Debug or Release."
  exit 0
fi
echo ""

start_timestamp=$(date +"%T")
echo "[$start_timestamp] 2. Start compiling Chromium on $1 mode"
ninja -j 150 -C out/"$1" $2
end_timestamp=$(date +"%T")
echo ""
echo "[$end_timestamp] 3. Finish to compile Chromium."
