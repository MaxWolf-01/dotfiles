# .NET toolchain: SDK 8 and the Roslyn C# language server for neovim.
#
# roslyn-ls is built with useDotnetFromEnv, so it runs on the SDK from PATH
# rather than a bundled runtime -- the two belong in the same module.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    dotnet-sdk_8
    roslyn-ls
  ];

  home.sessionVariables.DOTNET_CLI_TELEMETRY_OPTOUT = "1";
}
