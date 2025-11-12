{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  packages = with pkgs; [
    # rustup
    cmake
    clang
    pkg-config
    wayland
    glfw
    wayland-scanner

    xorg.libXrandr
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXi
    xorg.libX11
    xorg.libXcursor
    xorg.libXfixes
    xorg.libX11
    libxkbcommon
  ];

  LD_LIBRARY_PATH = with pkgs;
    lib.makeLibraryPath [
      libGL
      xorg.libXrandr
      xorg.libXinerama
      xorg.libXcursor
      xorg.libXi
      xorg.libX11
      xorg.libXcursor
      xorg.libXfixes
      libxkbcommon
    ];
  # LIBCLANG_PATH = "${pkgs.llvmPackages_16.libclang.lib}/lib";
  # llvmPackages.libcxxClang
}
