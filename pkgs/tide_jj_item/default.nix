{ buildFishPlugin }:

buildFishPlugin rec {
  pname = "tide_jj_item";
  version = "1";
  src = ./.;
}
