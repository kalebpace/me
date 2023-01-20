{ pkgs, secrets, ... }:
let
  buildInputs = with pkgs; [
    zola
    wrangler
  ];
in
{
  packages.default = pkgs.stdenv.mkDerivation {
    name = "site";
    src = ./.;
    buildInputs = buildInputs;
    phases = [ "unpackPhase" "buildPhase" "installPhase" ];
    buildPhase = ''
      zola build
    '';
    installPhase = ''
      mkdir -p $out
      cp -r ./public/* $out/
    '';
  };

  devShells.default = with pkgs; mkShell {
    buildInputs = [
      buildInputs
    ];
  };

  tfConfig = {
    resource.cloudflare_record.read = {
      zone_id = "\${ data.cloudflare_zone.kalebpaceme.id }";
      name = "read";
      value = "\${ cloudflare_pages_project.read.subdomain }";
      type = "CNAME";
      proxied = true;
      ttl = 1;
    };

    resource.cloudflare_pages_project.read = {
      account_id = "\${ data.cloudflare_zone.kalebpaceme.account_id }";
      name = "read";
      production_branch = "main";
    };

    resource.cloudflare_pages_domain.read = {
      account_id = "\${ data.cloudflare_zone.kalebpaceme.account_id }";
      project_name = "read";
      domain = "read.kalebpace.me";
    };
  };
}
