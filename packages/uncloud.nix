{ pkgs }:

pkgs.buildGoModule {
  pname = "uncloud";
  version = "0.8.0";

  src = pkgs.fetchFromGitHub {
    owner = "psviderski";
    repo = "uncloud";
    rev = "v0.8.0";
    sha256 = "sha256-yc5CJPS3dX8KRXlXFobNOcWsUpfugDPIID5D81vlErc=";
  };

  vendorHash = "sha256-yh+omv8XnwiQv3JGTBV+1v3NvOTRQSJJ/AaeXOCBMH4=";

  doCheck = false;

  meta = {
    description = "A lightweight tool for deploying and managing containerised applications across a network of Docker hosts. Bridging the gap between Docker and Kubernetes.";
    homepage = "https://uncloud.run";
    license = pkgs.lib.licenses.asl20;
  };
}
