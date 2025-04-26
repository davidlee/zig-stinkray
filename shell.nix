{pkgs ?  import <nixpkgs> {}  } : pkgs.mkShell {
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

  # programs.nix-ld.libraries = with pkgs; [
  #   wayland-scanner
  #   raylib
  #   egl-wayland
  #   libxkbcommon
  #   kdePackages.wayland
  #   kdePackages.kwayland
  #   glfw-wayland

  #   libGL
  #   xorg.libX11
  #   xorg.libXcursor
  #   xorg.libXrandr
  #   xorg.libXinerama
  #   xorg.libXi
    
  # ];
  
  LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
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
  LIBCLANG_PATH = "${pkgs.llvmPackages_16.libclang.lib}/lib";
}
