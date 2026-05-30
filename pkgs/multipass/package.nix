{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  dnsmasq,
  fmt,
  git,
  iproute2,
  iptables,
  libapparmor,
  libvirt,
  libxml2,
  makeWrapper,
  openssl,
  OVMF,
  pkg-config,
  poco,
  protobuf,
  qemu,
  qemu-utils,
  qt6,
  slang,
  xterm,
}:

let
  version = "1.16.2";

  multipassSrc = fetchFromGitHub {
    owner = "canonical";
    repo = "multipass";
    rev = "refs/tags/v${version}";
    hash = "sha256-LfSdZAGIY40ReuZ6kZM/60PRkj/1DAhNlmTKeaj0OGs=";
  };

  grpcSrc = fetchFromGitHub {
    owner = "grpc";
    repo = "grpc";
    rev = "refs/tags/v1.68.2";
    hash = "sha256-GxD/1qoLIjQzgYyNuK4zLvBZtOcV+w+KamnUS2qcesw=";
    fetchSubmodules = true;
  };

  yamlCppSrc = fetchFromGitHub {
    owner = "canonical";
    repo = "yaml-cpp";
    rev = "d96aa990060b147e4e2b296c92491d039a5a6bd7";
    hash = "sha256-JI0oCUcZJ+V8e31eEe0i2Iiv8zhcf6Y4RScfnaNwjbU=";
  };

  libsshSrc = fetchFromGitHub {
    owner = "CanonicalLtd";
    repo = "libssh";
    rev = "f23d1454e50d0dbb314edd9bf4227ab72303484b";
    hash = "sha256-pOygL6T9TN1giAsRUNpzLcTiZT8l/uX0crwo1VxKCGQ=";
  };

  xzEmbeddedSrc = fetchFromGitHub {
    owner = "tukaani-project";
    repo = "xz-embedded";
    rev = "62d5603b5114c5aa8bb5f6bb461efbe0e3b51891";
    hash = "sha256-u4wdf3rQSBQT+ZwDcy+6GTW+11+SgI/WNW6dDzCeo6U=";
  };

  semverSrc = fetchFromGitHub {
    owner = "CanonicalLtd";
    repo = "semver";
    rev = "69e1b1ed0d8e59389fd98b445b0a4e8096472102";
    hash = "sha256-hLajxp6oAdNPXsmOppjMoUBrIF4eO4rC5dS5nuTh/rA=";
  };

  scopeGuardSrc = fetchFromGitHub {
    owner = "ricab";
    repo = "scope_guard";
    rev = "ee296e156cf01f9b8cf223f3f0b39501a6d4cb82";
    hash = "sha256-7McJrwVcyMcotd0y2thgdQQthXNZhU26YRQvP5q/OLc=";
  };
in
stdenv.mkDerivation {
  pname = "multipass";
  inherit version;

  src = multipassSrc;

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    git
    makeWrapper
    pkg-config
    qt6.wrapQtAppsHook
    slang
  ];

  buildInputs = [
    fmt
    libapparmor
    libvirt
    libxml2
    openssl
    poco
    poco.dev
    protobuf
    qt6.qtbase
    qt6.qtwayland
  ];

  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DMULTIPASS_ENABLE_FLUTTER_GUI=false"
    "-DMULTIPASS_ENABLE_TESTS=false"
  ];

  postPatch = ''
    sed -i '/set(CMAKE_TOOLCHAIN_FILE/,/CACHE STRING "Vcpkg toolchain file")/d' CMakeLists.txt
    find . \( -name CMakeLists.txt -o -name '*.cmake' \) -exec sed -i 's/-Werror//g' {} +

    substituteInPlace CMakeLists.txt \
      --replace-fail 'find_package(OpenSSL CONFIG REQUIRED)' 'find_package(OpenSSL REQUIRED)' \
      --replace-fail 'find_package(gRPC CONFIG REQUIRED)' '# gRPC is vendored by the Nix package' \
      --replace-fail "determine_version(MULTIPASS_VERSION)" "" \
      --replace-fail 'set(MULTIPASS_VERSION ''${MULTIPASS_VERSION})' 'set(MULTIPASS_VERSION "v${version}")'

    substituteInPlace CMakeLists.txt \
      --replace-fail "add_subdirectory(data)" "" \
      --replace-fail "include(packaging/cpack.cmake OPTIONAL)" ""

    substituteInPlace src/client/CMakeLists.txt \
      --replace-fail "add_subdirectory(gui)" ""

    substituteInPlace src/platform/update/default_update_prompt.cpp \
      --replace-fail "update_info->set_url(new_release->url.toEncoded());" \
                     "update_info->set_url(new_release->url.toEncoded().toStdString());"

    substituteInPlace src/platform/platform_linux.cpp \
      --replace-fail 'Path{"/usr/local/etc"}' 'Path{"/var/lib"}'

    substituteInPlace src/platform/backends/lxd/lxd_request.h \
      --replace-fail "unix:///var/snap/lxd/common/lxd/unix.socket@1.0" "unix:///var/lib/lxd/unix.socket@1.0"

    substituteInPlace src/platform/backends/qemu/linux/qemu_platform_detail_linux.cpp \
      --replace-fail "OVMF.fd" "${OVMF.fd}/FV/OVMF.fd" \
      --replace-fail "QEMU_EFI.fd" "${OVMF.fd}/FV/QEMU_EFI.fd"

    rm -rf 3rd-party/grpc 3rd-party/yaml-cpp 3rd-party/libssh/libssh \
      3rd-party/xz-decoder/xz-embedded 3rd-party/semver 3rd-party/scope_guard \
      3rd-party/vcpkg 3rd-party/flutter 3rd-party/protobuf.dart

    cp -r --no-preserve=mode ${grpcSrc} 3rd-party/grpc
    cp -r --no-preserve=mode ${yamlCppSrc} 3rd-party/yaml-cpp
    cp -r --no-preserve=mode ${libsshSrc} 3rd-party/libssh/libssh
    cp -r --no-preserve=mode ${xzEmbeddedSrc} 3rd-party/xz-decoder/xz-embedded
    cp -r --no-preserve=mode ${semverSrc} 3rd-party/semver
    cp -r --no-preserve=mode ${scopeGuardSrc} 3rd-party/scope_guard

    sed -i '1i #include <cstdint>' 3rd-party/yaml-cpp/src/emitterutils.cpp

    substituteInPlace 3rd-party/CMakeLists.txt \
      --replace-fail 'function(add_subdirectory_compat)' 'include(FetchContent)
set(FETCHCONTENT_QUIET FALSE)

FetchContent_Declare(gRPC
  DOWNLOAD_COMMAND true
  SOURCE_DIR ''${CMAKE_CURRENT_SOURCE_DIR}/grpc
)

set(gRPC_SSL_PROVIDER "package" CACHE STRING "Provider of ssl library")
set(gRPC_INSTALL OFF CACHE BOOL "Disable gRPC install rules" FORCE)
set(gRPC_BUILD_TESTS OFF CACHE BOOL "Disable gRPC tests" FORCE)
set(protobuf_INSTALL OFF CACHE BOOL "Disable protobuf install rules" FORCE)
set(protobuf_BUILD_TESTS OFF CACHE BOOL "Disable protobuf tests" FORCE)
FetchContent_MakeAvailable(gRPC)
include_directories(''${grpc_SOURCE_DIR}/third_party/zlib)
set_property(DIRECTORY ''${grpc_SOURCE_DIR} PROPERTY EXCLUDE_FROM_ALL YES)

function(add_subdirectory_compat)' \
      --replace-fail 'COMMAND $<TARGET_FILE:protobuf::protoc>' 'COMMAND $<TARGET_FILE:protoc>' \
      --replace-fail '--plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>' '--plugin=protoc-gen-grpc=$<TARGET_FILE:grpc_cpp_plugin>' \
      --replace-fail 'DEPENDS ''${ABS_FIL}' 'DEPENDS ''${ABS_FIL} protoc grpc_cpp_plugin' \
      --replace-fail 'gRPC::grpc++' 'grpc++' \
      --replace-fail 'protobuf::libprotobuf)' 'libprotobuf
  zlibstatic)'

    substituteInPlace 3rd-party/CMakeLists.txt \
      --replace-fail 'add_library(gRPC INTERFACE)' 'add_library(gRPC INTERFACE)
target_include_directories(gRPC INTERFACE
  ''${CMAKE_CURRENT_SOURCE_DIR}/grpc/include
  ''${CMAKE_CURRENT_SOURCE_DIR}/grpc/third_party/protobuf/src)'
  '';

  postInstall = ''
    wrapProgram $out/bin/multipassd --prefix PATH : ${
      lib.makeBinPath [
        dnsmasq
        iproute2
        iptables
        OVMF.fd
        qemu
        qemu-utils
        xterm
      ]
    }
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Backend server and client for managing on-demand Ubuntu VMs";
    homepage = "https://multipass.run";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
