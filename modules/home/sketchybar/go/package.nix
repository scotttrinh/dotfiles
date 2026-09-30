{ buildGoModule }:
buildGoModule {
  pname = "sketchybar-plugins";
  version = "0.1.0";
  src = ./.;
  vendorHash = null;
  postInstall = ''
    mv "$out/bin/go" "$out/bin/sketchybar-plugins"
  '';
}
