{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    terranix.url = "github:terranix/terranix";
    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, terranix, npmlock2nix, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgs-x86_64-linux = import nixpkgs { system = "x86_64-linux"; };
        secrets = import "${builtins.getEnv "PWD"}/secrets.nix";

        projects = rec {
          _ = import ./_ { inherit pkgs npmlock2nix; };
          book = import ./book { };
          source = import ./source { inherit pkgs pkgs-x86_64-linux; };
          know = import ./know { inherit pkgs npmlock2nix; };
          pay = import ./pay { inherit pkgs secrets; };
          read = import ./read { inherit pkgs secrets resume; };
          resume = import ./_/assets/resume { inherit pkgs; };
        };

        tfConfig = terranix.lib.terranixConfiguration {
          inherit system;
          modules = [
            (import ./config.nix {
              inherit secrets;
            })
            # projects._.tfConfig
            # projects.book.tfConfig
            # projects.source.tfConfig
            # projects.know.tfConfig
            # projects.pay.tfConfig
            projects.read.tfConfig
            ({
              resource.cloudflare_ruleset.redirects = {
                zone_id     = "\${ data.cloudflare_zone.kalebpaceme.id }";
                name        = "redirects";
                description = "Redirect ruleset";
                kind        = "zone";
                phase       = "http_request_dynamic_redirect";

                rules = {
                  action = "redirect";
                  action_parameters = {
                    from_value = {
                      status_code = 302;
                      target_url = {
                        value = "https://kalebpace.notion.site/Resume-d2ff276fc6c64f19a69e582d3175d9bb";
                      };
                    };
                  };
                  expression  = "(http.request.uri.path == \"/resume\")";
                  description = "redirect resume path to notion";
                  enabled     = true;
                };
              };
            })
          ];
        };
      in
      rec {
        packages = {
          _ = projects._.packages.default;
          source = projects.source.packages.default;
          know = projects.know.packages.default;
          pay = projects.pay.packages.default;
          read = projects.read.packages.default;
          resume = projects.resume.packages.default;
        };

        devShells = {
          _ = projects._.devShells.default;
          source = projects.source.devShells.default;
          know = projects.know.devShells.default;
          pay = projects.pay.devShells.default;
          read = projects.read.devShells.default;
          default = with pkgs; mkShell {
            buildInputs = [
              (vscode-with-extensions.override {
                vscode = vscodium;
                vscodeExtensions = with vscode-extensions; [
                  jnoortheen.nix-ide
                  viktorqvarfordt.vscode-pitch-black-theme
                  asvetliakov.vscode-neovim
                  foam.foam-vscode
                  svelte.svelte-vscode
                  tamasfe.even-better-toml
                  mhutchie.git-graph
                  tomoki1207.pdf
                  bradlc.vscode-tailwindcss
                ];
              })
            ];
          };
        };

        apps = {
          # nix run ".#apply"
          apply = {
            type = "app";
            program = toString (pkgs.writers.writeBash "apply" ''
              if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
              cp ${tfConfig} config.tf.json \
                && ${pkgs.terraform}/bin/terraform init \
                && ${pkgs.terraform}/bin/terraform apply
            '');
          };

          # nix run ".#destroy"
          destroy = {
            type = "app";
            program = toString (pkgs.writers.writeBash "destroy" ''
              if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
              cp ${tfConfig} config.tf.json \
                && ${pkgs.terraform}/bin/terraform init \
                && ${pkgs.terraform}/bin/terraform destroy
            '');
          };

          # nix run ".#deploy"
          deploy = {
            type = "app";
            program = toString (pkgs.writers.writeBash "deploy" ''
              export CLOUDFLARE_API_KEY=${secrets.CF_API_TOKEN}
              ${pkgs.wrangler}/bin/wrangler pages publish ${projects.read.packages.default} --project-name read --branch main
            '');
          };
        };
      }
    );
}
