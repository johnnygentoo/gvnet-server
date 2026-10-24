#!/usr/bin/env bash
# build.sh [PROTOBUF_BUILD]: builds gvnet-server, the matching server for the GUNDAM VERSUS and
# MAXIBOOST ON Linux ports. Nothing else is needed on the machine that runs it: no GPU library,
# no game, no game files.
#
# Needs g++ (C++20) and protobuf: the system's (protoc and pkg-config's protobuf), or
# PROTOBUF_BUILD, the path to a CMake build of protobuf with abseil fetched (such as shadnet-p2p's
# build directory: externals/protobuf/protoc-*, libprotobuf.a, _deps/absl-build), linked
# statically. Writes out/gvnet-server.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
out=$root/out
mkdir -p "$out/gen"
proto=$root/proto
if [[ -n ${1:-} ]]; then
    build=$(cd "$1" && pwd)
    src=$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$build/CMakeCache.txt")
    protoc=$(ls "$build"/externals/protobuf/protoc-* | head -1)
    abseil=$(find "$build/_deps/absl-build" -name 'libabsl*.a')
    utf8=$build/externals/protobuf/third_party/utf8_range
    "$protoc" --proto_path="$proto" --cpp_out="$out/gen" "$proto/shadnet.proto"
    # shellcheck disable=SC2086
    g++ -std=c++20 -O2 -o "$out/gvnet-server" "$root/src/gvnet_server.cpp" \
        "$out/gen/shadnet.pb.cc" -I"$out/gen" -I"$src/externals/protobuf/src" \
        -I"$src/externals/protobuf/third_party/utf8_range" -I"$build/_deps/absl-src" \
        "$build/externals/protobuf/libprotobuf.a" -Wl,--start-group $abseil \
        "$utf8/libutf8_validity.a" "$utf8/libutf8_range.a" -Wl,--end-group -lpthread
else
    protoc --proto_path="$proto" --cpp_out="$out/gen" "$proto/shadnet.proto"
    # shellcheck disable=SC2046
    g++ -std=c++20 -O2 -o "$out/gvnet-server" "$root/src/gvnet_server.cpp" \
        "$out/gen/shadnet.pb.cc" -I"$out/gen" $(pkg-config --cflags --libs protobuf) -lpthread
fi
echo "Built $out/gvnet-server"
