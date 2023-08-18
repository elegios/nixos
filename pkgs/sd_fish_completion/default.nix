{ buildFishPlugin }:

buildFishPlugin rec {
  pname = "sd_fish_completion";
  version = "1";
  src = ./.;
}
